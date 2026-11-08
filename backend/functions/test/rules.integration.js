const {test, before, after} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {initializeTestEnvironment, assertSucceeds, assertFails} = require('@firebase/rules-unit-testing');
const {doc, getDoc, getDocs, setDoc, collection, query, orderBy} = require('firebase/firestore');
let env;
before(async()=>{
 if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Run through firebase emulators:exec; never run against production.');
 env=await initializeTestEnvironment({projectId:'demo-feed-connor',firestore:{rules:fs.readFileSync('../firestore.rules','utf8')}});
 await env.clearFirestore();
 await env.withSecurityRulesDisabled(async ctx=>{
   const db=ctx.firestore();
   await setDoc(doc(db,'users/lydia'),{pairID:'pair',role:'parent'});
   await setDoc(doc(db,'users/connor'),{pairID:'pair',role:'child'});
   await setDoc(doc(db,'users/outsider'),{pairID:'other',role:'parent'});
   await setDoc(doc(db,'pairs/pair'),{parentID:'lydia',childID:'connor'});
   await setDoc(doc(db,'pairs/pair/gifts/one'),{food:'apple',status:'pending',createdAt:new Date()});
   await setDoc(doc(db,'pairs/pair/meals/one'),{kind:'Lunch',at:new Date()});
   await setDoc(doc(db,'devices/lydia'),{token:'secret'});
   await setDoc(doc(db,'invites/code'),{pairID:'pair'});
 });
});
after(async()=>{await env?.cleanup();});
test('both partners can read shared pet, gifts, and meals',async()=>{
 for (const uid of ['lydia','connor']) {
  const db=env.authenticatedContext(uid).firestore();
  await assertSucceeds(getDoc(doc(db,'pairs/pair')));
  await assertSucceeds(getDocs(query(collection(db,'pairs/pair/gifts'),orderBy('createdAt','desc'))));
  await assertSucceeds(getDoc(doc(db,'pairs/pair/meals/one')));
 }
});
test('outsiders and anonymous clients cannot read a pair',async()=>{
 for(const db of [env.authenticatedContext('outsider').firestore(),env.unauthenticatedContext().firestore()]) {
  await assertFails(getDoc(doc(db,'pairs/pair')));await assertFails(getDoc(doc(db,'pairs/pair/gifts/one')));
 }
});
test('clients cannot forge roles, consume gifts, log meals, or read secrets',async()=>{
 const db=env.authenticatedContext('lydia').firestore();
 for(const path of ['users/lydia','pairs/pair','pairs/pair/gifts/one','pairs/pair/meals/one','devices/lydia','invites/code']) await assertFails(setDoc(doc(db,path),{status:'consumed'}));
 for(const path of ['devices/lydia','invites/code','users/connor']) await assertFails(getDoc(doc(db,path)));
 await assertSucceeds(getDoc(doc(db,'users/lydia')));
 await assertFails(getDocs(collection(db,'pairs')));
});
