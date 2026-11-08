const {test} = require('node:test');
const assert = require('node:assert/strict');
const {initializeApp,deleteApp} = require('firebase/app');
const {getAuth,connectAuthEmulator,signInAnonymously} = require('firebase/auth');
const {getFunctions,connectFunctionsEmulator,httpsCallable} = require('firebase/functions');
const {getFirestore,connectFirestoreEmulator,doc,getDoc,getDocs,collection} = require('firebase/firestore');
async function client(name) {
 const app=initializeApp({apiKey:'demo-key',projectId:'demo-feed-connor',appId:'1:123:ios:demo'},name);
 const auth=getAuth(app);connectAuthEmulator(auth,'http://127.0.0.1:9099',{disableWarnings:true});await signInAnonymously(auth);
 const fn=getFunctions(app,'us-central1');connectFunctionsEmulator(fn,'127.0.0.1',5001);
 const db=getFirestore(app);connectFirestoreEmulator(db,'127.0.0.1',8080);
 return {app,auth,db,call:async(n,d)=>(await httpsCallable(fn,n)(d)).data};
}
test('two-person lifecycle and server authorization',async t=>{
 if(!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Use emulators:exec.');
 const parent=await client('parent'),child=await client('child'),outsider=await client('outsider');
 try {
  const {code}=await parent.call('createPair',{role:'parent'});
  await child.call('joinPair',{code});
  const profile=(await getDoc(doc(parent.db,'users',parent.auth.currentUser.uid))).data();const pair=profile.pairID;
  await t.test('pairing code cannot be reused',async()=>{await assert.rejects(outsider.call('joinPair',{code}));});
  await t.test('child cannot send and outsider cannot consume',async()=>{
   await assert.rejects(child.call('sendGift',{food:'apple',requestID:'denied'}));
   await assert.rejects(outsider.call('consumeGift',{giftID:'one'}));
  });
  await t.test('sending is idempotent and later preserves pending',async()=>{
   await parent.call('sendGift',{food:'apple',requestID:'one'});await parent.call('sendGift',{food:'apple',requestID:'one'});
   assert.equal((await getDoc(doc(child.db,`pairs/${pair}/gifts/one`))).data().status,'pending');
   assert.equal((await getDocs(collection(child.db,`pairs/${pair}/gifts`))).size,1);
  });
  await t.test('only child can consume; virtual food never logs a meal',async()=>{
   await assert.rejects(parent.call('consumeGift',{giftID:'one'}));
   await child.call('consumeGift',{giftID:'one'});await child.call('consumeGift',{giftID:'one'});
   const data=(await getDoc(doc(child.db,`pairs/${pair}`))).data();
   assert.equal(data.lastMealAt,null);assert.ok(data.virtualFedUntil);assert.equal(data.pendingCount,0);
   assert.equal((await getDocs(collection(child.db,`pairs/${pair}/meals`))).size,0);
   assert.equal((await getDoc(doc(parent.db,`pairs/${pair}/gifts/one`))).data().status,'consumed');
  });
  await t.test('only child logs meals and network retry creates one event',async()=>{
   await assert.rejects(parent.call('logMeal',{kind:'Lunch',requestID:'meal'}));
   await child.call('logMeal',{kind:'Lunch',requestID:'meal'});await child.call('logMeal',{kind:'Lunch',requestID:'meal'});
   assert.equal((await getDocs(collection(child.db,`pairs/${pair}/meals`))).size,1);
   assert.ok((await getDoc(doc(child.db,`pairs/${pair}`))).data().lastMealAt);
  });
 } finally {await Promise.all([parent,child,outsider].map(c=>deleteApp(c.app)));}
});
