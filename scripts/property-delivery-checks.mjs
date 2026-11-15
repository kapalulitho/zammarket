// Disposable local SQL fixtures only. No network or live Supabase access.
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
export async function checkPropertyDelivery(db,{a,b,c,role}){
 await db.exec('reset role');const oldPolicies=(await db.query('select * from pg_policies order by schemaname,tablename,policyname')).rows;const oldBucket=(await db.query('select * from storage.buckets order by id')).rows;
 await db.exec(await fs.readFile('supabase/review/015_property_MARKETPLACE_HOLD_DRAFT.sql','utf8'));await db.exec(await fs.readFile('supabase/review/016_delivery_PLANNING_HOLD_DRAFT.sql','utf8'));
 for(const policy of oldPolicies)assert.deepEqual((await db.query('select * from pg_policies where schemaname=$1 and tablename=$2 and policyname=$3',[policy.schemaname,policy.tablename,policy.policyname])).rows[0],policy);
 assert.deepEqual((await db.query("select * from storage.buckets where id<>'property-media' order by id")).rows,oldBucket);
 await db.exec('grant select on storage.objects to anon'); // mirror Supabase Storage baseline in the minimal fixture
 await role('authenticated',a);await db.query("insert into storage.objects(bucket_id,name) values('property-media',$1)",[`${a}/test.png`]);
 const property=(await db.query("insert into public.property_listings(title,property_type,purpose,location,description,price,price_basis,media_paths) values('Test apartment','Apartment','Rent','Lusaka','Non-sensitive property description',1500,'Per month',$1) returning *",[[`${a}/test.png`]])).rows[0];
 assert.ok(property.agent_name);assert.equal(property.owner_id,a);
 const delivery=(await db.query("insert into public.delivery_drafts(pickup,destination,description,parcel_size) values('Lusaka','Ndola','Packed books','Small parcel') returning *")).rows[0];assert.equal(delivery.state,'planning');
 await db.query("insert into public.courier_profile_drafts(display_name,vehicle,service_area) values('Test courier','Van','Lusaka')");
 await role('authenticated',b);assert.equal((await db.query('select * from public.property_listings')).rows.length,0);assert.equal((await db.query('select * from public.delivery_drafts')).rows.length,0);assert.equal((await db.query('select * from public.courier_profile_drafts')).rows.length,0);
 assert.equal((await db.query("update public.delivery_drafts set notes='Intrusion' where id=$1 returning *",[delivery.id])).rows.length,0);
 assert.equal((await db.query("update public.property_listings set title='Intrusion' where id=$1 returning *",[property.id])).rows.length,0);
 await assert.rejects(db.query("insert into public.delivery_drafts(customer_id,pickup,destination,description,parcel_size) values($1,'Lusaka','Ndola','Spoofed plan','Document')",[a]));
 await assert.rejects(db.query("insert into public.property_saved(property_id) values($1)",[property.id]));
 assert.equal((await db.query("select * from storage.objects where bucket_id='property-media'")).rows.length,0);
 await role('authenticated',a);await db.query("update public.property_listings set status='published' where id=$1",[property.id]);
 await role('anon');assert.equal((await db.query('select * from public.property_listings')).rows.length,1);assert.equal((await db.query("select * from storage.objects where bucket_id='property-media'")).rows.length,1);await assert.rejects(db.query('select * from public.delivery_drafts'));await assert.rejects(db.query('select * from public.property_enquiries'));await assert.rejects(db.query('select * from public.property_saved'));
 await role('authenticated',b);await db.query('insert into public.property_saved(property_id) values($1)',[property.id]);const enquiry=(await db.query("insert into public.property_enquiries(property_id,body) values($1,'Is a viewing possible?') returning *",[property.id])).rows[0];assert.equal(enquiry.recipient_id,a);assert.equal((await db.query("update public.property_enquiries set reply='Impersonation' where id=$1 returning *",[enquiry.id])).rows.length,0);
 await role('authenticated',c);assert.equal((await db.query('select * from public.property_enquiries')).rows.length,0);assert.equal((await db.query('select * from public.property_saved')).rows.length,0);
 await role('authenticated',a);await db.query("update public.property_enquiries set reply='Please propose a day' where id=$1",[enquiry.id]);await db.query("update public.property_listings set status='closed' where id=$1",[property.id]);await assert.rejects(db.query("update public.delivery_drafts set state='booked' where id=$1",[delivery.id]));await assert.rejects(db.query('delete from public.property_listings where id=$1',[property.id]));
 await role('anon');assert.equal((await db.query('select * from public.property_listings')).rows.length,0);assert.equal((await db.query("select * from storage.objects where bucket_id='property-media'")).rows.length,0);
 await role('authenticated',b);assert.equal((await db.query('select reply from public.property_enquiries where id=$1',[enquiry.id])).rows[0].reply,'Please propose a day');await db.query('delete from public.property_saved where property_id=$1',[property.id]);
 console.log('015/016 local checks passed: owner-only drafts/edits, published-only properties/photos, private saved/enquiry/plan/courier data, recipient-only replies, no booked state, preserved old policies/buckets and no property delete grant.');
}
