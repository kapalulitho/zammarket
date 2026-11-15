// Disposable, in-memory PostgreSQL validation. Never connects to Supabase.
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import { PGlite } from '../.validation/node_modules/@electric-sql/pglite/dist/index.js';

const seller = '11111111-1111-4111-8111-111111111111';
const buyer = '22222222-2222-4222-8222-222222222222';
const stranger = '33333333-3333-4333-8333-333333333333';
for (const [imageType, idType] of [['text[]','bigint'], ['jsonb','bigint'], ['text[]','uuid'], ['jsonb','uuid']]) {
  const db = new PGlite();
  await db.exec(`
    create role anon; create role authenticated; create role service_role bypassrls;
    create schema auth; create schema storage;
    create table auth.users(id uuid primary key);
    create function auth.uid() returns uuid language sql stable as
      $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
    grant usage on schema auth,storage to anon,authenticated,service_role;
    grant execute on function auth.uid() to anon,authenticated,service_role;
    insert into auth.users values('${seller}'),('${buyer}'),('${stranger}');
    create table public.listings(id ${idType === 'uuid' ? 'uuid default gen_random_uuid()' : 'bigint generated always as identity'} primary key,
      user_id uuid references auth.users(id),seller_id uuid,seller_name text,title text,price numeric,category text,
      location text,description text,image_urls ${imageType});
    create table public.likes(listing_id ${idType} references public.listings(id), user_id uuid references auth.users(id),primary key(listing_id,user_id));
    create table storage.objects(id uuid default gen_random_uuid(),bucket_id text,name text);
    alter table storage.objects enable row level security;
    grant all on storage.objects to authenticated,service_role;
    create function storage.foldername(text) returns text[] language sql immutable
      as $$ select string_to_array($1,'/') $$;
    create policy legacy_open_upload on storage.objects for insert to authenticated with check(true);
    create policy legacy_open_delete on storage.objects for delete to authenticated using(true);
    create policy legacy_open_update on storage.objects for update to authenticated using(true);
    create policy legacy_open_listing_read on public.listings for select to anon,authenticated using(true);
    create policy legacy_open_listing_insert on public.listings for insert to authenticated with check(true);
    grant usage on all sequences in schema public to authenticated;
    grant update(user_id),insert(user_id) on public.listings to authenticated;
    grant update(user_id) on public.likes to authenticated;
  `);
  for (const name of ['009_backend_setup_PENDING_APPROVAL.sql','002_photo_cleanup.sql']) {
    await db.exec(await fs.readFile(new URL(`../supabase/review/${name}`,import.meta.url),'utf8'));
  }
  const role = async (name, id = '') => {
    await db.exec(`reset role; set role ${name};`);
    await db.query("select set_config('request.jwt.claim.sub',$1,false)",[id]);
  };
  await role('authenticated', seller);
  await db.query(`insert into public.listings(user_id,title,price,category,location,description,image_urls,image_paths,available_from)
    values($1,'Phone',2500,'Phones','Lusaka','A phone',$2,$3,'2099-10-30')`,
    [seller, imageType === 'jsonb' ? JSON.stringify(['https://example.invalid/photo.jpg']) : ['https://example.invalid/photo.jpg'], [`${seller}/photo.jpg`]]);
  const own = (await db.query('select * from public.marketplace_listings')).rows[0];
  const listingId = String(own.id);
  assert.equal(own.effective_status,'Coming Soon');
  assert.equal(own.user_id,seller);
  assert.equal(own.seller_id,seller);
  await db.exec('begin');
  const automatic=(await db.query(`insert into public.listings(title,price,category,location,description)
    values('Auto owner',50,'Phones','Lusaka','Description') returning user_id,seller_id`)).rows[0];
  assert.equal(automatic.user_id,seller); assert.equal(automatic.seller_id,seller);
  await db.exec('rollback');
  await assert.rejects(db.query('update public.listings set user_id=$1',[buyer]));
  await assert.rejects(db.query('update public.likes set user_id=$1',[buyer]));
  await assert.rejects(db.query(`insert into public.listings(user_id,seller_id,title,price,category,location,description)
    values($1,$2,'Spoof seller',5,'Phones','Lusaka','Description')`,[seller,buyer]));
  // Even an administrative ownership update is blocked by the immutable-owner trigger.
  await db.exec('reset role');
  await assert.rejects(db.query('update public.listings set seller_id=$1',[buyer]));
  await role('authenticated', seller);
  await assert.rejects(db.query(`insert into public.listings(user_id,title) values($1,'Spoofed')`,[buyer]));
  await assert.rejects(db.exec("update public.listings set status='sold'"));
  await assert.rejects(db.query("insert into storage.objects(bucket_id,name) values('listing-images',$1)",[`${buyer}/foreign.jpg`]));
  await db.query("insert into storage.objects(bucket_id,name) values('listing-images',$1)",[`${seller}/photo.jpg`]);
  const retained = await db.query("delete from storage.objects where name=$1 returning *",[`${seller}/photo.jpg`]);
  assert.equal(retained.rows.length,0,'referenced photos cannot be deleted through browser API');
  await role('authenticated',buyer);
  const conversation = (await db.query("select public.start_conversation($1) as id",[listingId])).rows[0].id;
  assert.equal((await db.query("select public.start_conversation($1) as id",[listingId])).rows[0].id,conversation);
  await db.query('insert into public.messages(conversation_id,sender_id,body) values($1,$2,$3)',[conversation,buyer,'Is this available?']);
  await assert.rejects(db.query('insert into public.messages(conversation_id,sender_id,body) values($1,$2,$3)',[conversation,seller,'Impersonation']));
  await role('authenticated',stranger);
  assert.equal((await db.query('select * from public.messages')).rows.length,0);
  assert.equal((await db.query('select * from public.conversations')).rows.length,0);
  await assert.rejects(db.query('insert into public.messages(conversation_id,sender_id,body) values($1,$2,$3)',[conversation,stranger,'Intrusion']));
  const manage = async (revision, status, date = null, remove = false) => db.query(
    'select public.manage_listing($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) as item',
    [listingId,revision,'Phone',2500,'Phones','Lusaka','A phone',status,date,remove]);
  await assert.rejects(manage(0,'sold'));
  await role('anon');
  assert.ok((await db.query('select * from public.marketplace_listings')).rows.length>0);
  await assert.rejects(db.exec("insert into public.listings(title) values('Anonymous')"));
  await assert.rejects(db.exec('select * from public.messages'));
  await role('authenticated',seller);
  await assert.rejects(db.query("select public.start_conversation($1)",[listingId]));
  assert.equal((await db.query('select * from public.messages')).rows.length,1);
  await manage(0,'active','2000-10-30');
  assert.equal((await db.query('select effective_status from public.marketplace_listings')).rows[0].effective_status,'Available');
  await assert.rejects(manage(0,'sold'));
  await manage(1,'sold','2099-10-30');
  assert.equal((await db.query('select effective_status from public.marketplace_listings')).rows[0].effective_status,'Sold');
  await role('service_role');
  assert.equal((await db.query('select public.claim_photo_cleanup() as job')).rows[0].job,null);
  await db.exec('reset role; update public.marketplace_cleanup_settings set enabled=true;');
  await db.exec("update public.listings set sold_at=now()-interval '6 days 23 hours'");
  await role('service_role');
  assert.equal((await db.query('select public.claim_photo_cleanup() as job')).rows[0].job,null);
  // Restoring within recovery cancels eligibility.
  await role('authenticated',seller); await manage(2,'active');
  await db.exec("reset role; update public.listings set sold_at=now()-interval '8 days'");
  await role('service_role');
  assert.equal((await db.query('select public.claim_photo_cleanup() as job')).rows[0].job,null);
  await role('authenticated',seller); await manage(3,'sold');
  await db.exec("reset role; update public.listings set sold_at=now()-interval '7 days'");
  await role('service_role');
  const claim = (await db.query('select public.claim_photo_cleanup() as job')).rows[0].job;
  assert.deepEqual(claim.paths,[`${seller}/photo.jpg`]);
  await role('authenticated',seller); await assert.rejects(manage(5,'active'));
  await assert.rejects(db.exec('select public.claim_photo_cleanup()'));
  await db.exec("reset role; update public.listings set cleanup_started_at=now()-interval '11 minutes'");
  await role('service_role');
  const retry = (await db.query('select public.claim_photo_cleanup() as job')).rows[0].job;
  assert.equal(retry.token,claim.token,'retry keeps the same claim token');
  await assert.rejects(db.query('select public.finish_photo_cleanup($1,$2)',[listingId,'44444444-4444-4444-8444-444444444444']));
  await db.query('select public.finish_photo_cleanup($1,$2)',[listingId,claim.token]);
  await role('authenticated',seller);
  const cleaned = (await db.query('select * from public.listings')).rows[0];
  assert.deepEqual(cleaned.image_urls,[]);
  assert.equal(cleaned.status,'sold','cleanup never deletes or changes listing status');
  await manage(cleaned.revision,'temporarily_unavailable');
  let item = (await db.query('select * from public.listings')).rows[0];
  assert.equal(item.status,'temporarily_unavailable');
  await manage(item.revision,'active',null,true);
  await role('anon');
  assert.equal((await db.query('select * from public.marketplace_listings')).rows.length,0,'deleted hidden even with old open policy');
  await role('authenticated',seller);
  assert.equal((await db.query('select * from public.messages')).rows.length,1,'message history preserved');
  await db.close();
  console.log(`Database checks passed (${idType} IDs, ${imageType} photos): migrations, ownership, participant privacy, date logic, retention, retries, cleanup lock, deletion.`);
}
