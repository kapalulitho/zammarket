import assert from 'node:assert/strict';
export async function checkStage3V2(db,{a,b,c,role,listing}){
 await db.exec('reset role');
 // Supabase's Storage API roles have object SELECT grants; mirror that in this minimal fixture.
 await db.exec('grant select on storage.objects to anon');
 assert.equal((await db.query("select public from storage.buckets where id='marketplace-media'")).rows[0].public,false);
 await role('authenticated',a);
 await db.query('update public.listing_stock set variants=$1 where listing_id=$2',[JSON.stringify([{label:'Safe option',quantity:2,price:null,private_note:'fixture'}]),listing.id]);
 await db.query("insert into storage.objects(bucket_id,name) values('marketplace-media',$1)",[`${a}/private-test.png`]);
 const entry=(await db.query("insert into public.community_entries(kind,title,description,location,media_paths) values('job','Media fixture','Non-sensitive media fixture','Lusaka',$1) returning id",[[`${a}/private-test.png`]])).rows[0];
 await role('authenticated',b);
 assert.equal((await db.query("select * from storage.objects where bucket_id='marketplace-media' and name=$1",[`${a}/private-test.png`])).rows.length,0);
 await role('authenticated',a);await db.query("update public.community_entries set status='published' where id=$1",[entry.id]);
 await role('anon');assert.equal((await db.query("select * from storage.objects where bucket_id='marketplace-media' and name=$1",[`${a}/private-test.png`])).rows.length,1);
 await role('authenticated',a);await db.query("update public.community_entries set status='closed' where id=$1",[entry.id]);
 await role('anon');assert.equal((await db.query("select * from storage.objects where bucket_id='marketplace-media' and name=$1",[`${a}/private-test.png`])).rows.length,0);
 await role('anon');
 const option=(await db.query('select variants from public.marketplace_stock where listing_id=$1',[listing.id])).rows[0].variants[0];
 assert.equal(option.private_note,undefined);assert.equal(option.quantity,2);
 await db.exec('reset role');
 const receipt=(await db.query('select id from public.marketplace_trade_receipts where buyer_id=$1',[b])).rows[0];
 await assert.rejects(db.query('update public.marketplace_trade_receipts set buyer_id=$1 where id=$2',[c,receipt.id]),/immutable/);
 await db.query("update public.marketplace_trade_receipts set state='revoked' where id=$1",[receipt.id]);
 await assert.rejects(db.query("update public.marketplace_trade_receipts set state='completed' where id=$1",[receipt.id]),/final/);
 await role('anon');assert.equal((await db.query('select * from public.public_seller_reviews')).rows.length,0);
 console.log('v2 focused checks passed: private media isolation, canonical public variants, immutable receipts, final revocation and withdrawn verified reviews.');
}
