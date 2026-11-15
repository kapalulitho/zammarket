import test from 'node:test';
import assert from 'node:assert/strict';
import { runCleanup } from '../supabase/functions/cleanup-sold-photos/worker.js';

function fixture({paths = ['owner/photo.jpg'], removeError, finishError, disabled = false} = {}) {
  const calls = [];
  let claimed = false;
  const client = {
    rpc: async (name, args) => {
      calls.push({name,args});
      if (name === 'finish_photo_cleanup') return {error:finishError};
      if (disabled || claimed) return {data:null};
      claimed = true;
      return {data:{listing_id:'1', token:'claim',owner_id:'owner',paths}};
    },
    storage: {from: bucket => ({remove: async paths => {calls.push({name:'remove',bucket,paths}); return {error:removeError};}})},
  };
  return {client,calls};
}
test('cleanup disabled: no Storage deletion', async () => {
  const {client,calls} = fixture({disabled:true});
  assert.equal(await runCleanup(client),0);
  assert.equal(calls.length,1);
});
test('cleanup deletes through Storage before clearing references', async () => {
  const {client,calls} = fixture();
  assert.equal(await runCleanup(client),1);
  assert.deepEqual(calls.map(call => call.name),['claim_photo_cleanup','remove','finish_photo_cleanup','claim_photo_cleanup']);
  assert.equal(calls[1].bucket,'listing-images');
  assert.deepEqual(calls[2].args,{p_id:'1',p_token:'claim'});
});
test('rejects foreign, traversal, and empty paths before deletion', async () => {
  for (const paths of [['other/photo.jpg'],['owner/../photo.jpg'],[],['owner/dir\\file']]) {
    const {client,calls} = fixture({paths});
    await assert.rejects(runCleanup(client),/Unsafe/);
    assert.equal(calls.some(call => call.name === 'remove'),false);
  }
});
test('failed deletion does not clear references or unlock restoration', async () => {
  const {client,calls} = fixture({removeError:new Error('Storage unavailable')});
  await assert.rejects(runCleanup(client),/Storage unavailable/);
  assert.equal(calls.some(call => call.name === 'finish_photo_cleanup'),false);
});
test('failed finalization propagates so claim can retry', async () => {
  const {client} = fixture({finishError:new Error('Database unavailable')});
  await assert.rejects(runCleanup(client),/Database unavailable/);
});
