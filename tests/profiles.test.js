import test from 'node:test';
import assert from 'node:assert/strict';
import {profileInput,profileAccess,contactFields,registrationAllowed} from '../src/lib/profiles.js';
import {sortFeedListings} from '../src/lib/availability.js';
const values={username:'Lusaka_Finds',shop_name:' Lusaka Finds ',account_type:'business'};
test('profile names required, normalized, and contact visibility defaults private',()=>{
 const profile=profileInput(values,'private@example.invalid');
 assert.equal(profile.username,'lusaka_finds');assert.equal(profile.shop_name,'Lusaka Finds');
 for(const field of contactFields)assert.equal(profile[`show_${field}`],false);
 for(const bad of ['a','has spaces','with-dash'])assert.throws(()=>profileInput({...values,username:bad}));
 assert.throws(()=>profileInput({...values,shop_name:' '}));
 assert.throws(()=>profileInput({...values,account_type:'admin'}));
});
test('login email is never public, contacts are WhatsApp only, local numbers normalise to +260',()=>{
 assert.equal(profileInput({...values,public_email:'PRIVATE@example.invalid'}).public_email,undefined);
 assert.equal(contactFields.join(','),'whatsapp');
 assert.equal(profileInput({...values,phone:'0971234567'}).phone,undefined,'phone is no longer collected');
 assert.equal(profileInput({...values,whatsapp:'0971234567'}).whatsapp,'+260971234567');
 assert.equal(profileInput({...values,whatsapp:'260971234567'}).whatsapp,'+260971234567');
 assert.throws(()=>profileInput({...values,whatsapp:'12345'}));
 const p=profileInput({...values,whatsapp:'+260 971 234 567',show_whatsapp:'on'});
 assert.equal(p.whatsapp,'+260971234567');assert.equal(p.show_whatsapp,true);
});
test('anonymous, unverified, and incomplete profiles cannot enter marketplace',()=>{
 assert.equal(profileAccess(null,null),'anonymous');
 assert.equal(profileAccess({id:'1'}, {completed_at:'now'}),'verify');
 assert.equal(profileAccess({id:'1',email_confirmed_at:'now'},null),'setup');
 assert.equal(profileAccess({id:'1',email_confirmed_at:'now'},{completed_at:'now'}),'ready');
});
test('default feed prioritizes available items and uses newest-first within status',()=>{
 const now=new Date('2026-10-29T22:00:00Z');
 const rows=[{id:'sold',status:'sold'},{id:'soon',available_from:'2026-11-01'},
 {id:'old',created_at:'2026-01-01'},{id:'new',available_from:'2026-10-30',created_at:'2026-10-28'},
 {id:'unavailable',status:'temporarily_unavailable'}];
 assert.deepEqual(sortFeedListings(rows,'recommended',now).map(x=>x.id),['new','old','soon','unavailable','sold']);
 assert.equal(rows[0].id,'sold','sorting does not mutate existing feed data');
 assert.deepEqual(sortFeedListings([{price:20},{price:10}],'low',now).map(x=>x.price),[10,20]);
});

test('registration fails closed when confirmation is off or settings are unknown',()=>{
 assert.equal(registrationAllowed({mailer_autoconfirm:true,external:{email:true}}),false);
 assert.equal(registrationAllowed({}),false);assert.equal(registrationAllowed(null),false);
 assert.equal(registrationAllowed({mailer_autoconfirm:false,external:{email:true},disable_signup:false}),true);
 assert.equal(registrationAllowed({mailer_autoconfirm:false,external:{email:true},disable_signup:true}),false);
});
