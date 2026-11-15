import test from 'node:test';import assert from 'node:assert/strict';
import {stockInput,stockSummary,slugifyShopName,shopReadiness,promotionInput} from '../src/lib/sellerTools.js';
test('stock derives totals from variants, keeps only public fields, rejects duplicates and excessive totals',()=>{
 assert.deepEqual(stockInput(999,[{label:' Blue / M ',quantity:'2',price:'0',private_note:'omit'}]),{quantity:2,variants:[{label:'Blue / M',quantity:2,price:0}]});
 assert.throws(()=>stockInput(0,[{label:'Blue',quantity:1},{label:'blue',quantity:2}]));assert.throws(()=>stockInput(0,[{label:'A',quantity:900000},{label:'B',quantity:900000}]));assert.throws(()=>stockInput(''));assert.throws(()=>stockInput(1,[{label:'A',quantity:1,price:-1}]));
 assert.deepEqual(stockInput('0'),{quantity:0,variants:[]});
});
test('inventory summaries distinguish unpublished from out-of-stock records',()=>{assert.deepEqual(stockSummary([{id:'a'},{id:'b'},{id:'c'}],[{listing_id:'a',quantity:0},{listing_id:'b',quantity:2},{listing_id:'not-owned',quantity:100}]),{products:3,published:2,unknown:1,units:2,empty:1,low:1});});
test('shop previews validate handle format without claiming server-side uniqueness',()=>{assert.equal(slugifyShopName(' Lusaka & More! '),'lusaka-more');assert.equal(shopReadiness({name:'Shop',slug:'shop',description:'A local shop description',location:'Lusaka'}).every(row=>row.ready),true);assert.equal(shopReadiness({name:'X',slug:'bad name'}).every(row=>row.ready),false);});
test('promotion drafts cannot set an active state and require valid budget/date pairs',()=>{
 const input={name:'Local campaign',kind:'boost',state:'active',budget:'0'};assert.equal(promotionInput(input).state,'draft');assert.equal(promotionInput(input).budget,0);
 assert.throws(()=>promotionInput({...input,budget:'NaN'}));assert.throws(()=>promotionInput({...input,starts_on:'2026-11-01'}));assert.throws(()=>promotionInput({...input,starts_on:'2026-11-02',ends_on:'2026-11-01'}));
});
