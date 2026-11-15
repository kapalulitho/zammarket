-- REVIEW ONLY: unified backend setup. Requires approval for live security changes.
-- Does NOT delete listings/photos, repair ownership, deploy workers, or schedule deletion.
-- Contains 001 + 008 + 004 inside ONE transaction. Do not run the source scripts too.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
-- SOURCE: 001_marketplace.sql
-- REVIEW ONLY. Not applied. Run preflight.sql and review existing policies first.
-- PostgreSQL 15+; existing listings.id may be UUID or bigint (RPC IDs use text).

alter table public.listings
  add column if not exists status text not null default 'active',
  add column if not exists available_from date,
  add column if not exists sold_at timestamptz,
  add column if not exists deleted_at timestamptz,
  add column if not exists image_paths text[] not null default '{}',
  add column if not exists photos_deleted_at timestamptz,
  add column if not exists cleanup_token uuid,
  add column if not exists cleanup_started_at timestamptz,
  add column if not exists revision bigint not null default 0;
alter table public.listings add constraint zammarket_status_check
  check (status in ('active', 'sold', 'temporarily_unavailable'));
alter table public.listings add constraint zammarket_photo_count_check check(cardinality(image_paths)<=5);
create index if not exists zammarket_listings_owner on public.listings(user_id);
create index if not exists zammarket_cleanup_due on public.listings(sold_at)
  where status = 'sold' and photos_deleted_at is null;

-- Date-aware status: no job, login, or previous visit is required for availability.
create view public.marketplace_listings with (security_invoker = true) as
select l.*, case
  when status = 'sold' then 'Sold'
  when status = 'temporarily_unavailable' then 'Temporarily Unavailable'
  when available_from > (now() at time zone 'Africa/Lusaka')::date then 'Coming Soon'
  else 'Available' end as effective_status
from public.listings l;

alter table public.listings enable row level security;
revoke all on public.listings from public, anon, authenticated;
grant select on public.listings to anon, authenticated;
-- New records only. Updates/deletion go through the checked RPC below.
grant insert (user_id,title,price,category,location,description,image_urls,image_paths,available_from)
  on public.listings to authenticated;
revoke all on public.marketplace_listings from public, anon, authenticated;
grant select on public.marketplace_listings to anon, authenticated;
-- Restrictive guards also constrain any older permissive policies left in place.
create policy zammarket_listing_visibility_guard on public.listings as restrictive
  for select to anon, authenticated using (deleted_at is null or user_id = (select auth.uid()));
create policy zammarket_listing_read on public.listings
  for select to anon, authenticated using (deleted_at is null or user_id = (select auth.uid()));
create policy zammarket_listing_insert_guard on public.listings as restrictive
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy zammarket_listing_insert on public.listings
  for insert to authenticated with check (user_id = (select auth.uid()));

-- Only server code can alter status/cleanup metadata; protect path ownership and reuse.
create function public.zammarket_listing_guard() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  perform pg_advisory_xact_lock(hashtextextended(new.user_id::text, 0));
  if tg_op='INSERT' and (new.title is null or length(trim(new.title)) not between 1 and 200
    or new.price is null or new.price < 0
    or new.category is null or length(trim(new.category)) not between 1 and 100
    or new.location is null or length(trim(new.location)) not between 1 and 200
    or new.description is null or length(trim(new.description)) not between 1 and 10000) then
    raise exception 'Invalid listing details';
  end if;
  if exists (select 1 from unnest(new.image_paths) p
    where p not like new.user_id::text || '/%' or p like '%..%' or p like '%\\%') then
    raise exception 'Invalid image ownership';
  end if;
  if exists (select 1 from public.listings l where l.id::text <> new.id::text
      and l.image_paths && new.image_paths) then
    raise exception 'Images cannot be shared between listings';
  end if;
  return new;
end $$;
revoke all on function public.zammarket_listing_guard() from public, anon, authenticated;
create trigger zammarket_listing_guard before insert or update on public.listings
  for each row execute function public.zammarket_listing_guard();

create function public.manage_listing(p_id text, p_revision bigint, p_title text,
  p_price numeric, p_category text, p_location text, p_description text,
  p_status text, p_available_from date, p_delete boolean default false)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare item public.listings;
begin
  select * into item from public.listings where id::text = p_id for update;
  if auth.uid() is null or item.user_id is distinct from auth.uid() then
    raise exception 'Listing not found or not owned by you';
  end if;
  if item.deleted_at is not null then raise exception 'Listing has been deleted'; end if;
  if item.revision <> p_revision then raise exception 'Listing changed. Refresh and try again.'; end if;
  if item.cleanup_token is not null then
    raise exception 'Photo cleanup is in progress. Please try again after cleanup completes.';
  end if;
  if p_status not in ('active','sold','temporarily_unavailable') or p_status is null
    or length(trim(p_title)) not between 1 and 200 or p_price < 0 or p_price is null
    or length(trim(p_category)) not between 1 and 100
    or length(trim(p_location)) not between 1 and 200
    or length(trim(p_description)) not between 1 and 10000
    or p_title is null or p_category is null or p_location is null or p_description is null then
    raise exception 'Invalid listing details';
  end if;
  update public.listings set title=trim(p_title),price=p_price,category=trim(p_category),
    location=trim(p_location),description=trim(p_description),status=p_status,
    available_from=p_available_from,
    sold_at=case when p_status <> 'sold' then null when item.status='sold' then item.sold_at else now() end,
    deleted_at=case when p_delete then now() else null end, revision=revision+1
    where id::text=p_id returning * into item;
  return to_jsonb(item);
end $$;
revoke all on function public.manage_listing(text,bigint,text,numeric,text,text,text,text,date,boolean) from public, anon;
grant execute on function public.manage_listing(text,bigint,text,numeric,text,text,text,text,date,boolean) to authenticated;

create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  listing_id text not null,
  listing_title text not null,
  buyer_id uuid not null references auth.users(id),
  seller_id uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  check (buyer_id <> seller_id), unique(listing_id,buyer_id)
);
create index on public.conversations(buyer_id);
create index on public.conversations(seller_id);
create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id),
  sender_id uuid not null references auth.users(id),
  body text not null check (length(trim(body)) between 1 and 4000),
  created_at timestamptz not null default now()
);
create index on public.messages(conversation_id,created_at,id);
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
revoke all on public.conversations, public.messages from public, anon, authenticated;
grant select on public.conversations, public.messages to authenticated;
grant insert (conversation_id,sender_id,body) on public.messages to authenticated;
create policy zammarket_participants on public.conversations for select to authenticated
  using ((select auth.uid()) in (buyer_id,seller_id));
create policy zammarket_read_messages on public.messages for select to authenticated
  using (exists (select 1 from public.conversations c where c.id=conversation_id
    and (select auth.uid()) in (c.buyer_id,c.seller_id)));
create policy zammarket_send_message on public.messages for insert to authenticated
  with check (sender_id=(select auth.uid()) and exists (
    select 1 from public.conversations c where c.id=conversation_id
      and (select auth.uid()) in (c.buyer_id,c.seller_id)));

create function public.start_conversation(p_listing_id text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare item public.listings; result uuid;
begin
  if auth.uid() is null then raise exception 'Sign in to message sellers'; end if;
  select * into item from public.listings where id::text=p_listing_id and deleted_at is null;
  if item.id is null or item.user_id is null then raise exception 'Seller unavailable'; end if;
  if item.user_id=auth.uid() then raise exception 'This is your own listing'; end if;
  insert into public.conversations(listing_id,listing_title,buyer_id,seller_id)
    values(p_listing_id,item.title,auth.uid(),item.user_id)
    on conflict(listing_id,buyer_id) do update set listing_id=excluded.listing_id
    returning id into result;
  return result;
end $$;
revoke all on function public.start_conversation(text) from public, anon;
grant execute on function public.start_conversation(text) to authenticated;

-- Feature readiness and server clock, without exposing private configuration.
create function public.zammarket_features() returns jsonb language sql stable
set search_path = '' as $$ select jsonb_build_object('version',1,'server_now',now(),'recovery_days',7) $$;
revoke all on function public.zammarket_features() from public;
grant execute on function public.zammarket_features() to anon, authenticated;

-- SOURCE: 008_ownership_hardening.sql
-- REVIEW ONLY. Apply after 001, before 004. No automatic deletion or data backfill.

alter table public.listings add column if not exists seller_id uuid;
alter table public.listings add column if not exists seller_name text;
alter table public.listings alter column user_id set default auth.uid();
alter table public.listings alter column seller_id set default auth.uid();

-- REVOKE at table level does not remove independent column grants. Remove both.
DO $$
declare relation_name text; column_name text;
begin
  foreach relation_name in array array['listings','likes'] loop
    for column_name in select a.attname from pg_attribute a
      where a.attrelid=to_regclass('public.'||relation_name) and a.attnum>0 and not a.attisdropped loop
      execute format('revoke all privileges (%I) on table public.%I from public, anon, authenticated',
        column_name,relation_name);
    end loop;
  end loop;
end $$;
revoke all on public.listings,public.likes from public,anon,authenticated;
grant select on public.listings,public.likes to anon,authenticated;
grant insert(user_id,seller_id,seller_name,title,price,category,location,description,image_urls,image_paths,available_from)
  on public.listings to authenticated;
grant insert(listing_id,user_id),delete on public.likes to authenticated;

create function public.zammarket_enforce_owner() returns trigger
language plpgsql security invoker set search_path='' as $$
declare caller uuid := auth.uid();
begin
  if tg_op='INSERT' then
    if caller is null then raise exception 'Sign in before posting a listing'; end if;
    if (new.user_id is not null and new.user_id<>caller)
      or (new.seller_id is not null and new.seller_id<>caller) then
      raise exception 'Listing owner must match the authenticated seller';
    end if;
    new.user_id:=caller;
    new.seller_id:=caller;
    new.seller_name:=coalesce(nullif(trim(new.seller_name),''),'Local seller');
    if length(new.seller_name)>80 then raise exception 'Display name is too long'; end if;
  elsif new.user_id is distinct from old.user_id or new.seller_id is distinct from old.seller_id then
    raise exception 'Listing ownership cannot be reassigned';
  end if;
  return new;
end $$;
revoke all on function public.zammarket_enforce_owner() from public,anon,authenticated;
-- Assign ownership before the core image-path validation trigger runs.
create trigger a_zammarket_enforce_owner before insert or update on public.listings
  for each row execute function public.zammarket_enforce_owner();

-- SOURCE: 004_storage_and_likes_policies.sql
-- REVIEW ONLY. Protects new user/folder uploads; preserves legacy public reads.
-- Existing bucket configuration and legacy paths are NOT rewritten.

create function public.zammarket_photo_unreferenced(p_path text) returns boolean
language sql stable security definer set search_path = '' as $$
  select not exists(select 1 from public.listings where p_path = any(image_paths));
$$;
revoke all on function public.zammarket_photo_unreferenced(text) from public,anon;
grant execute on function public.zammarket_photo_unreferenced(text) to authenticated;

create policy zammarket_image_owner_read on storage.objects
  for select to authenticated using(bucket_id='listing-images'
    and (storage.foldername(name))[1]=(select auth.uid())::text);

create policy zammarket_image_upload_guard on storage.objects as restrictive
  for insert to authenticated with check (bucket_id <> 'listing-images' or
    ((storage.foldername(name))[1]=(select auth.uid())::text and name not like '%..%'));
create policy zammarket_image_upload on storage.objects
  for insert to authenticated with check (bucket_id='listing-images'
    and (storage.foldername(name))[1]=(select auth.uid())::text and name not like '%..%');
-- Disallow overwriting listing files, including files pending cleanup.
create policy zammarket_image_update_guard on storage.objects as restrictive
  for update to authenticated using(bucket_id <> 'listing-images')
  with check(bucket_id <> 'listing-images');
create policy zammarket_image_delete_guard on storage.objects as restrictive
  for delete to authenticated using(bucket_id <> 'listing-images' or
    ((storage.foldername(name))[1]=(select auth.uid())::text
      and public.zammarket_photo_unreferenced(name)));
create policy zammarket_image_delete_unused on storage.objects
  for delete to authenticated using(bucket_id='listing-images'
    and (storage.foldername(name))[1]=(select auth.uid())::text
    and public.zammarket_photo_unreferenced(name));

alter table public.likes enable row level security;
revoke all on public.likes from public,anon,authenticated;
grant select on public.likes to anon,authenticated;
grant insert(listing_id,user_id),delete on public.likes to authenticated;
create policy zammarket_likes_read on public.likes for select to anon,authenticated using(true);
create policy zammarket_likes_insert_guard on public.likes as restrictive for insert to authenticated
  with check(user_id=(select auth.uid()));
create policy zammarket_likes_insert on public.likes for insert to authenticated
  with check(user_id=(select auth.uid()));
create policy zammarket_likes_delete_guard on public.likes as restrictive for delete to authenticated
  using(user_id=(select auth.uid()));
create policy zammarket_likes_delete on public.likes for delete to authenticated
  using(user_id=(select auth.uid()));
COMMIT;
