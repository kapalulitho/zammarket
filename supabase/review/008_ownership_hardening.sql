-- REVIEW ONLY. Apply after 001, before 004. No automatic deletion or data backfill.
BEGIN;
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
COMMIT;
