import { randomBytes, createHash } from "node:crypto";
import { initializeApp } from "firebase-admin/app";
import { FieldValue, Timestamp, getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { HttpsError, onCall, CallableRequest } from "firebase-functions/v2/https";
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { validRole, validFood, validID, validatePreferences, defaultPreferences, isQuiet, consumptionAllowed, Role } from "./domain";
initializeApp();
const db = getFirestore();
const opts = {region:"us-central1",maxInstances:10};
function fail(message: string): never { throw new HttpsError("failed-precondition",message); }
function auth(req: CallableRequest) { if (!req.auth) throw new HttpsError("unauthenticated","Sign in first."); return req.auth.uid; }
const digest = (code: string)=>createHash("sha256").update(code).digest("hex");
const newCode = ()=>randomBytes(6).toString("hex").toUpperCase();
async function member(req: CallableRequest, role?: Role) {
  const uid = auth(req); const profile = (await db.doc(`users/${uid}`).get()).data();
  if (!profile?.pairID || (role && profile.role !== role)) throw new HttpsError("permission-denied","This role cannot do that.");
  const pairRef = db.doc(`pairs/${profile.pairID}`); const pair = (await pairRef.get()).data();
  if (!pair || pair[`${profile.role}ID`] !== uid) throw new HttpsError("permission-denied","Pair membership required.");
  return {uid,profile,pairRef,pair};
}
export const createPair = onCall(opts,async req=>{
  const uid = auth(req), role = req.data?.role;
  if (!validRole(role)) throw new HttpsError("invalid-argument","Choose parent or child.");
  const code = newCode(), pair = db.collection("pairs").doc();
  await db.runTransaction(async tx=>{
    const user = db.doc(`users/${uid}`);
    if ((await tx.get(user)).exists) fail("Already paired. Create a new invitation in Settings.");
    tx.create(pair,{parentID:role === "parent" ? uid : null,childID:role === "child" ? uid : null,createdAt:FieldValue.serverTimestamp(),lastMealAt:null,virtualFedUntil:null,preferences:defaultPreferences});
    tx.create(user,{pairID:pair.id,role});
    tx.create(db.doc(`invites/${digest(code)}`),{pairID:pair.id,role:role === "parent" ? "child" : "parent",expiresAt:Timestamp.fromMillis(Date.now()+900000),createdBy:uid});
  }); return {code};
});
export const createInvite = onCall(opts,async req=>{
  const m = await member(req), code = newCode(); const opposite = m.profile.role === "parent" ? "child" : "parent";
  await db.runTransaction(async tx=>{
    const pair = (await tx.get(m.pairRef)).data()!;
    if (pair[`${opposite}ID`]) fail("Both roles are already paired.");
    if (pair.lastInviteAt?.toMillis() > Date.now()-60000) throw new HttpsError("resource-exhausted","Wait a minute before requesting another code.");
    tx.update(m.pairRef,{lastInviteAt:FieldValue.serverTimestamp()});
    tx.create(db.doc(`invites/${digest(code)}`),{pairID:m.pairRef.id,role:opposite,expiresAt:Timestamp.fromMillis(Date.now()+900000),createdBy:m.uid});
  }); return {code};
});
export const joinPair = onCall(opts,async req=>{
  const uid = auth(req), code = req.data?.code;
  if (typeof code !== "string" || !/^[0-9A-F]{12}$/.test(code)) throw new HttpsError("invalid-argument","Invalid code.");
  await db.runTransaction(async tx=>{
    const ref = db.doc(`joinAttempts/${uid}`), a = (await tx.get(ref)).data();
    const inWindow = a?.since?.toMillis() > Date.now()-900000;
    if (inWindow && a!.count >= 10) throw new HttpsError("resource-exhausted","Try again in 15 minutes.");
    tx.set(ref,{since:inWindow ? a!.since : Timestamp.now(),count:inWindow ? a!.count+1 : 1});
  });
  await db.runTransaction(async tx=>{
    const user = db.doc(`users/${uid}`), ref = db.doc(`invites/${digest(code)}`);
    const [existing, invitation] = await Promise.all([tx.get(user),tx.get(ref)]); const invite = invitation.data();
    if (existing.exists) fail("This account is already paired.");
    if (!invite || invite.expiresAt.toMillis() < Date.now() || invite.createdBy === uid) fail("Code expired or unavailable.");
    const pairRef = db.doc(`pairs/${invite.pairID}`), pair = (await tx.get(pairRef)).data();
    if (!pair || pair[`${invite.role}ID`]) fail("This role is already taken.");
    tx.update(pairRef,{[`${invite.role}ID`]:uid}); tx.create(user,{pairID:invite.pairID,role:invite.role}); tx.delete(ref);
  }); return {joined:true};
});
export const sendGift = onCall(opts,async req=>{
  const m = await member(req,"parent"), {food,requestID} = req.data ?? {};
  if (!validFood(food) || !validID(requestID)) throw new HttpsError("invalid-argument","Choose a supported food and request ID.");
  const gift = m.pairRef.collection("gifts").doc(requestID);
  await db.runTransaction(async tx=>{
    const [existing,pairDoc] = await Promise.all([tx.get(gift),tx.get(m.pairRef)]); if (existing.exists) return;
    const p = pairDoc.data()!;
    if (!p.childID) fail("Pair with Connor before sending gifts.");
    if (p.lastGiftAt?.toMillis() > Date.now()-30000) throw new HttpsError("resource-exhausted","Wait 30 seconds between gifts.");
    if ((p.pendingCount ?? 0) >= 20) throw new HttpsError("resource-exhausted","Connor has 20 pending gifts.");
    tx.create(gift,{food,status:"pending",createdAt:FieldValue.serverTimestamp(),createdBy:m.uid,consumedAt:null});
    tx.update(m.pairRef,{pendingCount:(p.pendingCount ?? 0)+1,lastGiftAt:FieldValue.serverTimestamp()});
  }); return {giftID:gift.id};
});
export const consumeGift = onCall(opts,async req=>{
  const m = await member(req,"child"), id = req.data?.giftID;
  if (!validID(id)) throw new HttpsError("invalid-argument","Invalid gift.");
  await db.runTransaction(async tx=>{
    const ref = m.pairRef.collection("gifts").doc(id);
    const [doc,pairDoc] = await Promise.all([tx.get(ref),tx.get(m.pairRef)]); const g = doc.data(), p = pairDoc.data()!;
    if (!g) throw new HttpsError("not-found","Gift not found.");
    if (g.status === "consumed") return;
    if (!consumptionAllowed(m.profile.role,g.status)) fail("Gift is not pending.");
    tx.update(ref,{status:"consumed",consumedAt:FieldValue.serverTimestamp()});
    tx.update(m.pairRef,{pendingCount:Math.max(0,(p.pendingCount ?? 1)-1),virtualFedUntil:Timestamp.fromMillis(Date.now()+1800000)});
    // No real meal or lastMealAt write: virtual gifts are strictly separate.
  }); return {consumed:true};
});
export const logMeal = onCall(opts,async req=>{
  const m = await member(req,"child"), {kind,requestID} = req.data ?? {};
  if (!["Breakfast","Lunch","Dinner","Snack"].includes(kind) || !validID(requestID)) throw new HttpsError("invalid-argument","Invalid meal.");
  await db.runTransaction(async tx=>{
    const ref = m.pairRef.collection("meals").doc(requestID); if ((await tx.get(ref)).exists) return;
    tx.create(ref,{kind,at:FieldValue.serverTimestamp(),confirmedBy:m.uid}); tx.update(m.pairRef,{lastMealAt:FieldValue.serverTimestamp()});
  }); return {logged:true};
});
export const savePreferences = onCall(opts,async req=>{
  const m = await member(req,"child"), p = req.data?.preferences;
  if (!validatePreferences(p)) throw new HttpsError("invalid-argument","Invalid schedule or hunger thresholds.");
  const {schedules,hungryAfterHours,tiredAfterHours,remindersEnabled,quietStart,quietEnd,timeZone} = p;
  await m.pairRef.update({preferences:{schedules:schedules.map((s: any)=>({id:s.id,hour:s.hour,minute:s.minute,enabled:s.enabled})),hungryAfterHours,tiredAfterHours,remindersEnabled,quietStart,quietEnd,timeZone}}); return {saved:true};
});
export const registerDevice = onCall(opts,async req=>{
  const m = await member(req), token = req.data?.token;
  if (typeof token !== "string" || token.length < 20 || token.length > 4096) throw new HttpsError("invalid-argument","Invalid push token.");
  await db.doc(`devices/${m.uid}`).set({token,updatedAt:FieldValue.serverTimestamp()}); return {registered:true};
});
async function notify(uid: string | null, pair: any, title: string, body: string, eventID: string) {
  if (!uid) return; const ref = db.doc(`devices/${uid}`), device = (await ref.get()).data(); if (!device?.token) return;
  const quiet = isQuiet(pair.preferences,new Date());
  try {
    await getMessaging().send({token:device.token,data:{eventID},...(quiet ? {} : {notification:{title,body}}),
      apns:{headers:{"apns-push-type":quiet ? "background" : "alert","apns-priority":quiet ? "5" : "10","apns-collapse-id":"feed-connor"},payload:{aps:{contentAvailable:true,...(quiet ? {} : {sound:"default"})}}}});
  } catch (e: any) {
    if (["messaging/registration-token-not-registered","messaging/invalid-registration-token"].includes(e.code)) {
      await db.runTransaction(async tx=>{ if ((await tx.get(ref)).data()?.token === device.token) tx.delete(ref); });
    } else throw e;
  }
}
export const giftCreated = onDocumentCreated({...opts,document:"pairs/{pairID}/gifts/{giftID}"},async event=>{
  const pair = (await db.doc(`pairs/${event.params.pairID}`).get()).data();
  if (pair) await notify(pair.childID,pair,"GIFT","Lydia sent food. Choose Eat or Later in FEED CONNOR.",event.id);
});
export const giftConsumed = onDocumentUpdated({...opts,document:"pairs/{pairID}/gifts/{giftID}"},async event=>{
  if (event.data?.before.data().status !== "pending" || event.data.after.data().status !== "consumed") return;
  const pair = (await db.doc(`pairs/${event.params.pairID}`).get()).data();
  if (pair) await notify(pair.parentID,pair,"FEED CONNOR","Connor accepted your gift.",event.id);
});
export const deleteAccount = onCall(opts,async req=>{
  const uid = auth(req), userRef = db.doc(`users/${uid}`);
  const profile = (await userRef.get()).data();
  if (profile?.pairID) {
    const ref = db.doc(`pairs/${profile.pairID}`);
    await db.runTransaction(async tx=>{
      const p = (await tx.get(ref)).data();
      if (p && p.parentID !== uid && p.childID !== uid) throw new HttpsError("permission-denied","Pair membership required.");
      if (p) for (const memberID of [p.parentID,p.childID]) if (memberID) {
        tx.delete(db.doc(`users/${memberID}`)); tx.delete(db.doc(`devices/${memberID}`));
      }
      tx.delete(ref); tx.delete(userRef);
    });
    await db.recursiveDelete(ref);
    const invites = await db.collection("invites").where("pairID","==",profile.pairID).get();
    const writer = db.bulkWriter(); invites.docs.forEach(d=>writer.delete(d.ref));await writer.close();
  }
  await db.doc(`devices/${uid}`).delete(); await db.doc(`joinAttempts/${uid}`).delete();
  const {getAuth} = await import("firebase-admin/auth"); await getAuth().deleteUser(uid);
  return {deleted:true};
});
