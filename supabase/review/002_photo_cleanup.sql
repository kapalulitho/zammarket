-- REVIEW ONLY. Destructive worker support; not applied or scheduled.
begin;
create table public.marketplace_cleanup_settings (
  singleton boolean primary key default true check(singleton),
  enabled boolean not null default false,
  recovery_days integer not null default 7 check(recovery_days=7)
);
insert into public.marketplace_cleanup_settings(singleton) values(true);
alter table public.marketplace_cleanup_settings enable row level security;
revoke all on public.marketplace_cleanup_settings from public, anon, authenticated;
grant all on public.marketplace_cleanup_settings to service_role;

-- Locks a listing against seller edits before deleting bytes outside the transaction.
-- Retried after 10 minutes with the same token; seller cannot restore during partial deletion.
create function public.claim_photo_cleanup() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare item public.listings;
begin
  if not exists (select 1 from public.marketplace_cleanup_settings where enabled) then return null; end if;
  select * into item from public.listings
  where photos_deleted_at is null and cardinality(image_paths)>0
    and ((status='sold' and sold_at<=now()-interval '7 days')
      or deleted_at<=now()-interval '7 days')
    and (cleanup_started_at is null or cleanup_started_at < now()-interval '10 minutes')
  order by coalesce(deleted_at,sold_at) for update skip locked limit 1;
  if item.id is null then return null; end if;
  update public.listings set cleanup_token=coalesce(cleanup_token,gen_random_uuid()),
    cleanup_started_at=now(),revision=revision+1 where id=item.id returning * into item;
  return jsonb_build_object('listing_id',item.id::text,'token',item.cleanup_token,
    'paths',item.image_paths,'owner_id',item.user_id);
end $$;
create function public.finish_photo_cleanup(p_id text,p_token uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  update public.listings set image_urls=(jsonb_populate_record(null::public.listings,'{"image_urls":[]}'::jsonb)).image_urls,
    image_paths='{}',photos_deleted_at=now(),
    cleanup_token=null,cleanup_started_at=null,revision=revision+1
  where id::text=p_id and cleanup_token=p_token;
  if not found then raise exception 'Cleanup claim changed'; end if;
end $$;
revoke all on function public.claim_photo_cleanup() from public,anon,authenticated;
revoke all on function public.finish_photo_cleanup(text,uuid) from public,anon,authenticated;
grant execute on function public.claim_photo_cleanup() to service_role;
grant execute on function public.finish_photo_cleanup(text,uuid) to service_role;
commit;
