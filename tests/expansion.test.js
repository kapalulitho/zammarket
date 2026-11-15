import test from 'node:test';
import assert from 'node:assert/strict';
import {verticalDraft,sellerInsights,filterCommunity,campaignPlan} from '../src/lib/expansion.js';
test('campaign planning includes both dates and never fabricates charges',()=>{
 assert.deepEqual(campaignPlan({starts_on:'2026-10-29',ends_on:'2026-10-30',budget:100}),{days:2,dailyBudget:50});
 assert.equal(campaignPlan({budget:''}).dailyBudget,null);
 assert.equal(campaignPlan({starts_on:'2026-10-30',ends_on:'2026-10-29',budget:100}).days,null);
});
test('vertical previews validate without introducing operational state',()=>{
 assert.throws(()=>verticalDraft('Delivery',{title:'Parcel',location:'Lusaka'}));
 assert.throws(()=>verticalDraft('Food',{title:'Lunch',location:'Lusaka',price:'Infinity'}));
 const draft=verticalDraft('Property',{title:'Test home',location:'Ndola',price:'500'});assert.equal(draft.price,'500');assert.equal(draft.status,undefined);
});
test('seller insights count records, not revenue or completed payments',()=>{
 const result=sellerInsights([{status:'sold',category:'Phones',location:'Lusaka',image_urls:['image']},{status:'active',category:'Phones',location:'Ndola'}]);
 assert.equal(result.sold,1);assert.equal(result.missingPhotos,1);assert.deepEqual(result.categories,[['Phones',2]]);assert.equal(result.revenue,undefined);
});
test('community filtering supports words, formats and deadlines',()=>{
 const rows=[{title:'Local coding tutor',location:'Lusaka',format:'Online',deadline:'2026-10-28'},{title:'Coding tutor',location:'Ndola',format:'Online',deadline:'2026-11-01'}];
 assert.equal(filterCommunity(rows,{search:'tutor coding',format:'Online'}).length,2);
 assert.equal(filterCommunity(rows,{upcoming:true,today:'2026-10-29'}).length,1);
 assert.equal(filterCommunity(rows,{location:'Lusaka',format:'In person'}).length,0);
 assert.equal(filterCommunity([{title:'Late event',location:'Lusaka',starts_at:'2026-10-28T22:30:00Z'}],{upcoming:true,today:'2026-10-29'}).length,1);
});
