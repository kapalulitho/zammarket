import test from 'node:test';
import assert from 'node:assert/strict';
import {savedProducts,savedListingIds} from '../src/lib/saved.js';

test('saved view contains only the signed-in account’s saved, non-deleted products',()=>{
  const products=[{id:'a',status:'active'},{id:'b',status:'sold'},{id:'c',deleted_at:'2026-10-29'},{id:'d'}];
  const likes=[{user_id:'one',listing_id:'a'},{user_id:'one',listing_id:'b'},{user_id:'one',listing_id:'c'},{user_id:'two',listing_id:'d'}];
  assert.deepEqual(savedProducts(products,likes,'one').map(item=>item.id),['a','b']);
  assert.deepEqual(savedProducts(products,likes,'two').map(item=>item.id),['d']);
  assert.deepEqual(savedProducts(products,likes,null),[]);
});
test('saved IDs tolerate legacy numeric IDs, duplicates, missing data and removed listings',()=>{
  const likes=[{user_id:'one',listing_id:12},{user_id:'one',listing_id:'12'},{user_id:'one',listing_id:null},{user_id:'one',listing_id:'missing'}];
  assert.deepEqual([...savedListingIds(likes,'one')],['12','missing']);
  assert.deepEqual(savedProducts([{id:'12'}],likes,'one'),[{id:'12'}]);
  assert.deepEqual(savedProducts(null,null,'one'),[]);
});
