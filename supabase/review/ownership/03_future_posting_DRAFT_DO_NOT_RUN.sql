-- PROPOSAL ONLY. Not applied. Must be coordinated with the core migration grants.
-- user_id already defaults to auth.uid(); keep it as the canonical owner.
begin;
alter table public.listings alter column user_id set default auth.uid();
alter table public.listings alter column seller_id set default auth.uid();
-- Apply AFTER core 001 so its column grant reset does not remove this permission.
grant insert(seller_id) on public.listings to authenticated;

create function public.zammarket_assign_post_owner() returns trigger
language plpgsql security invoker set search_path='' as $$
declare caller uuid := auth.uid();
begin
  if caller is null then
    raise exception 'Sign in to create a listing. Administrative imports require a separately reviewed path.';
  end if;
  if (new.user_id is not null and new.user_id<>caller)
    or (new.seller_id is not null and new.seller_id<>caller) then
    raise exception 'Listing ownership must match the authenticated account';
  end if;
  new.user_id := caller;
  new.seller_id := caller;
  return new;
end $$;
revoke all on function public.zammarket_assign_post_owner() from public,anon,authenticated;
-- PostgreSQL executes BEFORE triggers alphabetically; assign ownership first.
create trigger a_zammarket_assign_post_owner before insert on public.listings
  for each row execute function public.zammarket_assign_post_owner();
commit;
