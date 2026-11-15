// Disposable PostgreSQL only. Never connects to Supabase.
import {PGlite} from '../.validation/node_modules/@electric-sql/pglite/dist/index.js';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
const db=new PGlite();
const full=process.argv.includes('--full');
const a='11111111-1111-4111-8111-111111111111',b='22222222-2222-4222-8222-222222222222',c='33333333-3333-4333-8333-333333333333';
await db.exec(`create role anon;create role authenticated;create role service_role bypassrls;
create schema auth;create schema storage;grant usage on schema auth,storage to anon,authenticated,service_role;
create table auth.users(id uuid primary key,email text,email_confirmed_at timestamptz);
create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
create function auth.jwt() returns jsonb language sql stable as $$select coalesce(nullif(current_setting('request.jwt.claims',true),'')::jsonb,'{}'::jsonb)$$;
create table public.listings(id uuid primary key default gen_random_uuid(),user_id uuid default auth.uid(),seller_id uuid,seller_name text,title text,price numeric,category text,location text,description text,image_urls text[]);
alter table public.listings enable row level security;grant all on public.listings to authenticated;
create policy old_read on public.listings for select to authenticated using(true);
create policy old_insert on public.listings for insert to authenticated with check(true);
create policy old_update on public.listings for update to authenticated using(true) with check(true);
create policy old_delete on public.listings for delete to authenticated using(true);
create table public.likes(listing_id uuid references public.listings(id),user_id uuid);
${full?'':`create table public.messages(sender_id uuid,body text);create table public.conversations(buyer_id uuid);grant insert on public.messages,public.conversations to authenticated;`}
create table storage.objects(id uuid default gen_random_uuid(),bucket_id text,name text);
alter table storage.objects enable row level security;grant all on storage.objects to authenticated;
create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
create function storage.foldername(text) returns text[] language sql immutable as $$select string_to_array($1,'/')$$;
create policy old_upload on storage.objects for insert to authenticated with check(true);
create policy old_read on storage.objects for select to authenticated using(true);
create policy old_update on storage.objects for update to authenticated using(true) with check(true);
create policy old_delete on storage.objects for delete to authenticated using(true);
insert into auth.users values('${a}','private-a@example.invalid',now()),('${b}','private-b@example.invalid',now()),('${c}','unverified@example.invalid',null);
insert into public.listings(user_id,title) values(null,'Preserved old listing');
`);
if(full)await db.exec(await fs.readFile('supabase/review/009_backend_setup_PENDING_APPROVAL.sql','utf8'));
await db.exec(await fs.readFile('supabase/review/010_profiles_registration_PENDING_APPROVAL.sql','utf8'));
let functionMetadataBeforeFix,policiesBeforeFix;
const functionMetadata=()=>db.query("select oid,proname,proowner,proacl::text,prosecdef,proconfig from pg_proc where pronamespace='public'::regnamespace order by oid");
const policyMetadata=()=>db.query('select * from pg_policies order by schemaname,tablename,policyname');
if(process.argv.includes('--with-trigger-fix')){
  functionMetadataBeforeFix=(await functionMetadata()).rows;
  policiesBeforeFix=(await policyMetadata()).rows;
  await db.exec(await fs.readFile('supabase/review/012_message_trigger_fix_PENDING_APPROVAL.sql','utf8'));
  assert.deepEqual((await functionMetadata()).rows,functionMetadataBeforeFix,'012 preserves all function identities, ownership and permissions');
  assert.deepEqual((await policyMetadata()).rows,policiesBeforeFix,'012 changes no RLS policies');
  assert.equal((await db.query('select count(*)::int as n from auth.users')).rows[0].n,3);
  assert.equal((await db.query('select count(*)::int as n from public.listings')).rows[0].n,1);
}
const role=async(name,id='')=>{await db.exec(`reset role;set role ${name}`);await db.query("select set_config('request.jwt.claim.sub',$1,false)",[id]);};
const save=async(profile,confirm=true)=>db.query('select public.save_marketplace_profile($1::jsonb,$2) as profile',[JSON.stringify(profile),confirm]);
await role('authenticated',c);
await assert.rejects(save({username:'unverified',shop_name:'Unverified Shop',account_type:'individual'}));
await assert.rejects(db.exec("insert into public.listings(title) values('Blocked')"));
await role('authenticated',a);
await assert.rejects(save({username:'seller_a',shop_name:'Seller A',account_type:'business'}));
await db.query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({amr:[{method:'otp'}]})]);
await assert.rejects(db.exec("insert into public.listings(title) values('Incomplete')"));
await assert.rejects(full
  ? db.query('insert into public.messages(conversation_id,sender_id,body) values($1,$2,$3)',[b,a,'Incomplete profile'])
  : db.query("insert into public.messages values($1,'incomplete')",[a]), /Complete your verified profile first/);
await assert.rejects(save({username:'seller_a',shop_name:'Seller A',account_type:'business'},false));
await assert.rejects(save({username:'seller_a',shop_name:'Seller A',account_type:'business',public_email:'private-a@example.invalid'}));
await assert.rejects(db.query("insert into storage.objects(bucket_id,name) values('avatars',$1)",[`${b}/wrong.png`]));
await db.query("insert into storage.objects(bucket_id,name) values('avatars',$1)",[`${a}/avatar.png`]);
let profile=(await save({username:'seller_a',shop_name:'Seller A',account_type:'business',avatar_path:`${a}/avatar.png`,phone:'+260971234567',show_phone:false,public_email:'contact@example.invalid',show_public_email:true,address:'Private address',show_address:false})).rows[0].profile;
assert.ok(profile.completed_at);assert.equal(profile.id,a);
await assert.rejects(db.query("update public.marketplace_profiles set show_phone=true"));
const listing=(await db.exec("insert into public.listings(title,price,category,location,description) values('Owned listing',50,'Phones','Lusaka','A phone') returning *"))[0].rows[0];
assert.equal(listing.user_id,a);assert.equal(listing.seller_id,a);assert.equal(listing.seller_name,'Seller A');
await role('authenticated',b);
assert.equal((await db.query('select * from public.marketplace_profiles')).rows.length,0,'private profiles cannot be read by others');
await assert.rejects(save({username:'SELLER_A',shop_name:'Other name',account_type:'individual'}));
await assert.rejects(save({username:'other_name',shop_name:'seller a',account_type:'individual'}));
await save({username:'seller_b',shop_name:'Seller B',account_type:'individual'});
const exposed=(await db.query('select public.public_seller_profile($1) as profile',[a])).rows[0].profile;
assert.equal(exposed.phone,null);assert.equal(exposed.address,null);assert.equal(exposed.public_email,'contact@example.invalid');assert.equal(exposed.email,undefined);
assert.equal(JSON.stringify(exposed).includes('private-a@example.invalid'),false);
if(full)await assert.rejects(db.query('update public.listings set title=$1 where id=$2 returning *',['Intrusion',listing.id]));else assert.equal((await db.query('update public.listings set title=$1 where id=$2 returning *',['Intrusion',listing.id])).rows.length,0);
if(full)await assert.rejects(db.query('delete from public.listings where id=$1 returning *',[listing.id]));else assert.equal((await db.query('delete from public.listings where id=$1 returning *',[listing.id])).rows.length,0);
await role('authenticated',a);
await assert.rejects(db.query('update public.listings set user_id=$1 where id=$2',[b,listing.id]));
assert.equal((await db.query("delete from storage.objects where bucket_id='avatars' returning *")).rows.length,0,'avatar bytes are preserved');
if(!full)await assert.rejects(db.query("insert into public.messages values($1,'spoof')",[b]),/Sender mismatch/);
if(full){
  await role('authenticated',b);
  // Exercise real RPC signatures and message columns, not malformed inserts.
  await assert.rejects(db.query(
    'select public.manage_listing($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)',
    [String(listing.id),0,'Intrusion',50,'Phones','Lusaka','A phone','sold',null,false]),/not owned by you/);
  await assert.rejects(save({username:'seller_b',shop_name:'Seller B',account_type:'individual',avatar_path:`${a}/avatar.png`}),/Avatar must be an existing file in your own folder/);
  assert.equal((await db.query("update storage.objects set name=$1 where bucket_id='avatars' and name=$2 returning *",[`${a}/changed.png`,`${a}/avatar.png`])).rows.length,0);
  const thread=(await db.query('select public.start_conversation($1) as id',[String(listing.id)])).rows[0].id;
  await db.query('insert into public.messages(conversation_id,sender_id,body) values($1,$2,$3)',[thread,b,'Non-sensitive local test']);
  await assert.rejects(db.query('insert into public.messages(conversation_id,sender_id,body) values($1,$2,$3)',[thread,a,'Spoofed sender']),/Sender mismatch/);
  assert.equal((await db.query('select * from public.messages')).rows.length,1);
  await role('authenticated',c);
  assert.equal((await db.query('select * from public.messages')).rows.length,0);
  assert.equal((await db.query('select * from public.conversations')).rows.length,0);
  await assert.rejects(db.query('insert into public.messages(conversation_id,sender_id,body) values($1,$2,$3)',[thread,c,'Nonparticipant']));
  await role('authenticated',a);
  assert.equal((await db.query('select * from public.messages')).rows.length,1);
  await db.query('insert into public.messages(conversation_id,sender_id,body) values($1,$2,$3)',[thread,a,'Seller reply']);
  await role('authenticated',b);
  assert.equal((await db.query('select * from public.messages')).rows.length,2);
}
await role('anon');await assert.rejects(db.exec('select * from public.marketplace_profiles'));await assert.rejects(db.query('select public.public_seller_profile($1)',[a]));
await db.exec('reset role');assert.equal((await db.query("select count(*)::int as n from public.listings where title='Preserved old listing'")).rows[0].n,1);
if(process.argv.includes('--audit')){
  const results=await db.exec(await fs.readFile('supabase/review/011_stage1_verification_READ_ONLY.sql','utf8'));
  const report=results.flatMap(result=>result.rows).find(row=>row.stage1_verification_report)?.stage1_verification_report;
  assert.ok(report?.tables.some(table=>table.table==='marketplace_profiles'&&table.rls_enabled));
  assert.ok(report?.functions.some(fn=>fn.name==='save_marketplace_profile'&&!fn.anon_execute&&fn.authenticated_execute));
  console.log('Read-only Stage 1 audit SQL validated locally.');
}
if(process.argv.includes('--with-trigger-fix')){
  await db.exec(await fs.readFile('supabase/review/012_rollback_RESTORE_PREVIOUS_FUNCTION.sql','utf8'));
  const previous=(await db.query("select md5(pg_get_functiondef('public.marketplace_message_membership_guard()'::regprocedure)) as hash")).rows[0].hash;
  assert.ok(['e1731bea1a1daaf2b88cfdb773c67d66','d02fbe83e19f489cff07e31e2707409c'].includes(previous));
  assert.deepEqual((await functionMetadata()).rows,functionMetadataBeforeFix);
  assert.deepEqual((await policyMetadata()).rows,policiesBeforeFix);
  await db.exec(await fs.readFile('supabase/review/012_message_trigger_fix_PENDING_APPROVAL.sql','utf8'));
  const verification=await db.exec(await fs.readFile('supabase/review/012_verify_READ_ONLY.sql','utf8'));
  const checked=verification.flatMap(result=>result.rows).find(row=>row.matches_tested_fix!==undefined);
  assert.equal(checked.matches_tested_fix,true);
  assert.equal(checked.security_invoker,true);
  assert.equal(checked.anon_execute,false);
  assert.equal(checked.authenticated_execute,false);
  await db.exec(await fs.readFile('supabase/review/012_rollback_RESTORE_PREVIOUS_FUNCTION.sql','utf8'));
  const windowsMigration=(await fs.readFile('supabase/review/012_message_trigger_fix_PENDING_APPROVAL.sql','utf8')).replace(/\r?\n/g,'\r\n');
  await db.exec(windowsMigration);
  const windowsVerification=await db.exec(await fs.readFile('supabase/review/012_verify_READ_ONLY.sql','utf8'));
  const windowsChecked=windowsVerification.flatMap(result=>result.rows).find(row=>row.matches_tested_fix!==undefined);
  assert.equal(windowsChecked.definition_fingerprint,'8f359cb0a0f8ce17ae4f45e7ba32cfed');
  assert.equal(windowsChecked.matches_tested_fix,true,'verification accepts only the identical fix after line-ending normalization');
  await db.exec(await fs.readFile('supabase/review/012_rollback_RESTORE_PREVIOUS_FUNCTION.sql','utf8'));
  await db.exec(await fs.readFile('supabase/review/012_message_trigger_fix_PENDING_APPROVAL.sql','utf8'));
  console.log('012 scope, permissions, rollback/reapply and read-only verification checks passed locally.');
}
if(process.argv.includes('--with-stage3')){
 if(!full||!process.argv.includes('--with-trigger-fix'))throw new Error('Stage 3 requires --full --with-trigger-fix');
 const {runStage3Checks}=await import('./stage3-checks.mjs');await runStage3Checks(db,{a,b,c,role,listing});
 if(process.argv.includes('--stage3-v2')){const {checkStage3V2}=await import('./stage3-v2-checks.mjs');await checkStage3V2(db,{a,b,c,role,listing});}
 if(process.argv.includes('--review-stage3')){const {reviewStage3Findings}=await import('./stage3-review-checks.mjs');await reviewStage3Findings(db,{a,b,c,role,listing});}
}
if(process.argv.includes('--with-property-delivery')){const {checkPropertyDelivery}=await import('./property-delivery-checks.mjs');await checkPropertyDelivery(db,{a,b,c,role});}
if(process.argv.includes('--with-service-foundations')){const {checkServiceFoundations}=await import('./service-foundation-checks.mjs');await checkServiceFoundations(db,{a,b,c,role});}
if(process.argv.includes('--with-discovery-catalogues')){const {checkDiscoveryCatalogues}=await import('./discovery-catalogue-checks.mjs');await checkDiscoveryCatalogues(db,{a,b,c,role});}
if(process.argv.includes('--with-business-services')){const {checkBusinessServices}=await import('./business-service-checks.mjs');await checkBusinessServices(db,{a,b,c,role});}
await db.close();console.log((full?`Integrated 009 + 010${process.argv.includes('--with-trigger-fix')?' + proposed 012':''}: `:'Standalone 010: ')+'Local checks passed: uniqueness, verified/reviewed completion, private contacts, visibility projection, ownership, avatar isolation, preserved old data'+(full?', participant messaging and nonparticipant denial.':'.'));
