import test from 'node:test';
import assert from 'node:assert/strict';
import {propertyLink,propertyIdFromSearch,propertyQuery,searchWords,validPropertyRange,PROPERTY_PAGE_SIZE} from '../src/lib/propertyDiscovery.js';
import {filterProperties} from '../src/lib/property.js';
import {courierDraftInput,simulateDeliveryTransition,moneyMinor,foodCartSummary,menuItemInput,restaurantInput,ticketCategoryInput,ticketPlan} from '../src/lib/servicePlanning.js';
test('property links accept persisted UUIDs only and preserve reloadable identity',()=>{
 const id='11111111-1111-4111-8111-111111111111';assert.equal(propertyIdFromSearch(propertyLink(id).split('?')[1]),id);assert.equal(propertyIdFromSearch('?property=local-x'),'invalid');assert.equal(propertyIdFromSearch(''),null);assert.throws(()=>propertyLink('local-preview'));
});
test('server discovery filters avoid REST grammar injection and order pages deterministically',()=>{
 const calls=[];const q=new Proxy({},{get:(_,method)=>(...args)=>{calls.push([method,...args]);return q;}});
 propertyQuery(q,{search:'house),owner_id.eq.secret',location:'A_%',type:'House',purpose:'Rent',basis:'Per month',min:0,max:5000,bedrooms:2,sort:'low'}).range(PROPERTY_PAGE_SIZE,PROPERTY_PAGE_SIZE*2-1);
 assert.ok(calls.filter(row=>row[0]==='or').every(row=>!row[1].includes(')')));assert.ok(calls.some(row=>row[0]==='eq'&&row[1]==='price_basis'));assert.deepEqual(calls.filter(row=>row[0]==='order'),[['order','price'],['order','id']]);assert.deepEqual(calls.at(-1),['range',12,23]);assert.ok(searchWords('中文 café * test').includes('café'));assert.equal(validPropertyRange({min:9,max:2,bedrooms:''}),false);
});
test('property price basis filters prevent mixing monthly and total quotes',()=>{assert.equal(filterProperties([{title:'Home',description:'Home',location:'Lusaka',price:100,price_basis:'Total'},{title:'Flat',description:'Flat',location:'Lusaka',price:100,price_basis:'Per month'}],{basis:'Per month'}).length,1);});
test('courier draft validation strips activation, identity and owner fields',()=>{
 const value=courierDraftInput({display_name:'Test courier',service_area:'Lusaka',vehicle:'Van',about:'',owner_id:'foreign',verified:true,state:'active'});assert.equal(value.owner_id,undefined);assert.equal(value.verified,undefined);assert.equal(value.state,undefined);assert.throws(()=>courierDraftInput({...value,vehicle:'Unknown'}));
});
test('delivery simulator enforces role sequence and terminal states',()=>{
 let state='draft';for(const [action,role] of [['submit','customer'],['accept','courier'],['collect','courier'],['depart','courier'],['deliver','courier']])state=simulateDeliveryTransition(state,action,role);assert.equal(state,'delivered');assert.throws(()=>simulateDeliveryTransition(state,'cancel','customer'));assert.throws(()=>simulateDeliveryTransition('submitted','accept','customer'));assert.equal(simulateDeliveryTransition('accepted','cancel','customer'),'cancelled');
});
test('food price arithmetic uses minor units and unavailable/duplicate dishes cannot be ordered in a plan',()=>{
 assert.equal(moneyMinor('10.10'),1010);assert.throws(()=>moneyMinor('1.111'));assert.throws(()=>moneyMinor('Infinity'));
 const dish={...menuItemInput({name:'Test meal',allergens:'Information unavailable',price:'10.10',available:'on'}),id:'one'};const restaurant={...restaurantInput({name:'Test restaurant',location:'Lusaka',cuisine:'Local',hours:'09–17'}),menu:[dish]};assert.equal(foodCartSummary(restaurant,[{item_id:'one',quantity:3}]).total_minor,3030);assert.throws(()=>foodCartSummary({...restaurant,menu:[{...dish,available:false}]},[{item_id:'one',quantity:1}]));assert.throws(()=>foodCartSummary(restaurant,[{item_id:'one',quantity:1},{item_id:'one',quantity:2}]));assert.throws(()=>foodCartSummary(restaurant,[{item_id:'foreign',quantity:1}]));
});
test('ticket scenarios respect capacity, quantity cap and currency precision',()=>{
 const category={...ticketCategoryInput({label:'Standard',price:'25.50',capacity:4}),id:'a'};assert.equal(ticketPlan([category],{a:2}).total_minor,5100);assert.throws(()=>ticketPlan([category],{a:5}));assert.throws(()=>ticketCategoryInput({label:'VIP',price:2,capacity:0}));
});
