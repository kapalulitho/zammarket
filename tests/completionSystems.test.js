import test from 'node:test';
import assert from 'node:assert/strict';
import {paymentMinor,paymentSources,safeCheckoutUrl,ticketCredential,zambiaMobile} from '../src/lib/completionSystems.js';

const user='388abe0b-0864-4bc0-b970-f97b680bfc60';
test('sensitive client inputs are bounded before any RPC call',()=>{
 assert.equal(zambiaMobile('+260971234567'),true);
 assert.equal(zambiaMobile('+26097123456'),false);
 assert.equal(paymentMinor('12.34'),1234);
 assert.equal(paymentMinor('0'),null);
 assert.equal(paymentMinor('1000000001'),null);
 assert.deepEqual(ticketCredential('4c96a86e-5d82-4ac3-8a35-eae6f06a750a.'+'a'.repeat(64)),{ticketId:'4c96a86e-5d82-4ac3-8a35-eae6f06a750a',token:'a'.repeat(64)});
 assert.equal(ticketCredential('not-a-ticket'),null);
 assert.equal(safeCheckoutUrl('https://sandbox.example.test/continue'),'https://sandbox.example.test/continue');
 assert.equal(safeCheckoutUrl('http://sandbox.example.test/continue'),null);
});

test('payment sources include only the signed-in payer and valid server-priced states',()=>{
 const data={shopOrders:[{id:'shop',buyer_id:user,state:'requested',subtotal_minor:1000},{id:'other',buyer_id:'else',state:'requested',subtotal_minor:1000}],foodOrders:[{id:'food',customer_id:user,state:'ready',total_minor:2000}],stays:[{id:'stay',guest_id:user,state:'declined',subtotal_minor:3000}],reservations:[{id:'event',buyer_id:user,state:'held',quantity:2,unit_price_minor:4000}],work:[{id:'work',requester_id:user,kind:'learning',title_snapshot:'Course',state:'enrolled',quote_minor:5000}],cycles:[{id:'cycle',owner_id:user,state:'due',amount_minor:6000}]};
 assert.deepEqual(paymentSources(data,user).map(row=>row.kind),['shopping','food','event','work','billing']);
});
