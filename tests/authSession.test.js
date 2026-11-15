import test from 'node:test';
import assert from 'node:assert/strict';
import {createAuthSession} from '../src/lib/authSession.js';
import {pageFromPath,publicPath,authPath,browsePath} from '../src/lib/routes.js';

const user = {id:'test-account',email:'local@example.invalid'};
const settle = () => new Promise(resolve => setImmediate(resolve));
const deferred = () => {let resolve; const promise = new Promise(done => {resolve=done;}); return {promise,resolve};};
function fixture({initial=null,sessionRequest,validationError=false,logoutError=false}={}) {
  let stored = initial;
  let listener;
  let unsubscribed = false;
  const snapshots=[];
  const auth={
    onAuthStateChange(callback) {listener=callback; return {data:{subscription:{unsubscribe(){unsubscribed=true;}}}};},
    getSession: () => sessionRequest ?? Promise.resolve({data:{session:stored},error:null}),
    getUser: () => Promise.resolve({data:{user:validationError ? null : stored?.user},error:validationError ? new Error('invalid session') : null}),
    async signOut() {
      if (logoutError) return {error:new Error('offline')};
      stored=null; listener('SIGNED_OUT',null); return {error:null};
    },
  };
  const controller=createAuthSession(auth,state => snapshots.push(state));
  return {controller,snapshots,auth,unsubscribed:()=>unsubscribed,
    emit(event,session){stored=session;listener(event,session);},last:()=>snapshots.at(-1)};
}
test('starts loading; no authenticated state before session restoration completes', async () => {
  const pending=deferred(); const f=fixture({sessionRequest:pending.promise});
  assert.equal(f.last().status,'loading'); assert.equal(f.last().user,null);
  pending.resolve({data:{session:null},error:null}); await settle();
  assert.equal(f.last().status,'anonymous'); f.controller.stop();
});
test('restores and validates a persisted Supabase session after refresh', async () => {
  const f=fixture({initial:{user}}); await settle();
  assert.equal(f.last().status,'authenticated'); assert.equal(f.last().user.id,user.id);
  assert.equal(f.last().reason,'restore'); f.controller.stop();
});
test('rejects invalid cached identity instead of showing protected content', async () => {
  const f=fixture({initial:{user},validationError:true}); await settle();
  assert.equal(f.last().status,'error'); assert.equal(f.last().user,null);
  assert.equal(f.snapshots.some(s=>s.status==='authenticated'),false); f.controller.stop();
});
test('signed-in event wins over a stale initial restoration result', async () => {
  const pending=deferred(); const f=fixture({sessionRequest:pending.promise});
  f.emit('SIGNED_IN',{user}); assert.equal(f.last().reason,'signin');
  pending.resolve({data:{session:null},error:null}); await settle();
  assert.equal(f.last().status,'authenticated'); f.controller.stop();
});
test('logout clears identity; a refresh remains signed out', async () => {
  const f=fixture({initial:{user}}); await settle(); await f.controller.signOut();
  assert.equal(f.last().status,'anonymous'); assert.equal(f.last().user,null);
  await f.controller.retry(); assert.equal(f.last().status,'anonymous'); f.controller.stop();
});
test('cross-tab signout wins over in-flight user validation', async () => {
  const pending=deferred(); const f=fixture({initial:{user}});
  f.auth.getUser=()=>pending.promise; await settle(); f.emit('SIGNED_OUT',null);
  pending.resolve({data:{user},error:null}); await settle();
  assert.equal(f.last().status,'anonymous'); f.controller.stop();
});
test('failed logout does not falsely claim that the session was cleared', async () => {
  const f=fixture({initial:{user},logoutError:true}); await settle();
  await assert.rejects(f.controller.signOut(),/offline/);
  assert.equal(f.last().status,'authenticated'); f.controller.stop();
});
test('unmount unsubscribes and ignores late async restoration', async () => {
  const pending=deferred(); const f=fixture({sessionRequest:pending.promise});
  f.controller.stop(); const before=f.snapshots.length;
  pending.resolve({data:{session:{user}},error:null}); await settle();
  assert.equal(f.unsubscribed(),true); assert.equal(f.snapshots.length,before);
});
test('refresh and user-update events preserve authenticated identity without a new login redirect', async () => {
  const f=fixture({initial:{user}}); await settle();
  f.emit('TOKEN_REFRESHED',{user}); assert.equal(f.last().reason,'session');
  f.emit('USER_UPDATED',{user:{...user,user_metadata:{display_name:'Seller'}}});
  assert.equal(f.last().user.user_metadata.display_name,'Seller');
  f.emit('SIGNED_IN',{user:{...user,id:'other-account'}}); assert.equal(f.last().reason,'signin');
  f.controller.stop();
});
test('guests may browse but private actions and unknown URLs require authentication', () => {
  for(const path of ['/','/signin','/create-account','/home','/explore','/categories','/services','/events','/jobs','/learning','/shops','/directory','/delivery','/food','/property','/compare']) assert.equal(publicPath(path),true);
  for(const path of ['/saved','/post','/messages','/orders','/business','/inventory','/storefront','/promotions','/notifications','/enquiries','/profile','/my-listings','/listing/123','/anything']) assert.equal(publicPath(path),false);
  assert.equal(browsePath('/categories'),true);assert.equal(authPath('/categories'),false);
  assert.equal(authPath('/signin'),true);assert.equal(browsePath('/signin'),false);
  assert.equal(pageFromPath('/saved'),'Saved');
  assert.equal(pageFromPath('/post'),'Post'); assert.equal(pageFromPath('/messages'),'Messages');
});
