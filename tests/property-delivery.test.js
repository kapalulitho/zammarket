import test from 'node:test';
import assert from 'node:assert/strict';
import {propertyInput,filterProperties} from '../src/lib/property.js';
import {deliveryInput} from '../src/lib/delivery.js';
const home={title:'Test apartment',description:'Non-sensitive apartment description',location:'Lusaka',property_type:'Apartment',purpose:'Rent',price_basis:'Per month',price:'1500',bedrooms:'2',bathrooms:'1',area_sqm:'50',status:'published'};
test('property input validates sale basis, numeric fields and ignores injected identity',()=>{
 const data=propertyInput({...home,owner_id:'other',agent_name:'Forged',media_paths:['foreign']});assert.equal(data.owner_id,undefined);assert.equal(data.price,1500);assert.equal(data.bedrooms,2);assert.equal(data.media_paths,undefined);
 assert.throws(()=>propertyInput({...home,purpose:'Sale'}));assert.throws(()=>propertyInput({...home,price:'Infinity'}));assert.throws(()=>propertyInput({...home,bedrooms:'2.5'}));assert.throws(()=>propertyInput({...home,price:''}));
});
test('property filters combine type, purpose, town, budget and bedrooms without mutating input',()=>{
 const items=[propertyInput(home),propertyInput({...home,title:'Ndola family house',location:'Ndola',property_type:'House',price:2500,bedrooms:3})];
 assert.equal(filterProperties(items,{location:'lusaka',purpose:'Rent',min:1000,max:2000,bedrooms:2}).length,1);assert.equal(filterProperties(items,{min:4000,max:1000}).length,0);assert.equal(filterProperties(items,{sort:'high'})[0].price,2500);assert.equal(items[0].price,1500);
});
test('delivery plans cannot become bookings and validate parcel size and weight',()=>{
 const data=deliveryInput({pickup:'Lusaka',destination:'Ndola',description:'Packed books',parcel_size:'Small parcel',weight_kg:'2',state:'delivered',driver_id:'forged'});assert.equal(data.state,'planning');assert.equal(data.driver_id,undefined);assert.equal(data.weight_kg,2);
 assert.throws(()=>deliveryInput({...data,weight_kg:0}));assert.throws(()=>deliveryInput({...data,parcel_size:'Unapproved'}));assert.throws(()=>deliveryInput({...data,pickup:''}));
});
