// Narrow review probes; disposable PostgreSQL only. Never reaches Supabase.
import assert from 'node:assert/strict';
export async function reviewStage3Findings(db,{a,b,c,role,listing}){
 await role('authenticated',a);
 await db.query('update public.listing_stock set variants=$1 where listing_id=$2',[JSON.stringify([{label:'Public option',quantity:1,price:null,internal_cost:17,private_note:'Non-sensitive fixture only'}]),listing.id]);
 await role('anon');
 const exposed=(await db.query('select variants from public.marketplace_stock where listing_id=$1',[listing.id])).rows[0].variants[0];
 assert.equal(exposed.internal_cost,17,'current SQL publishes unrecognised JSON keys');
 await db.exec('reset role');
 const receipt=(await db.query('select id from public.marketplace_trade_receipts where buyer_id=$1',[b])).rows[0];
 await db.query("update public.marketplace_trade_receipts set buyer_id=$1,state='completed' where id=$2",[c,receipt.id]);
 await role('anon');
 const reviews=(await db.query('select * from public.public_seller_reviews')).rows;
 assert.equal(reviews.length,1);assert.equal(reviews[0].purchase_verified,true,'current SQL does not bind the published review author to a subsequently changed receipt buyer');
 console.log('Review findings reproduced locally: arbitrary variant keys reach the public view; trusted receipt-identity edits can retain an earlier verified-review badge. No migration source was modified.');
}
