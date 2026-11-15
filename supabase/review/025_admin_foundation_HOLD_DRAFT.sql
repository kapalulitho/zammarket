-- HOLD DRAFT 025: NOT APPROVED FOR ANY ENVIRONMENT.
-- Requires approved baseline plus held 024. Creates only new admin foundation objects.
-- No administrator is seeded. No self-grant RPC or client-writable role metadata.
begin;
create table public.marketplace_admin_memberships (
 user_id uuid primary key references auth.users(id),
 enabled boolean not null default false,
 created_at timestamptz not null default now()
);
alter table public.marketplace_admin_memberships enable row level security;
revoke all on public.marketplace_admin_memberships from public,anon,authenticated;
-- No client SELECT policy: membership is checked only inside the protected definer RPC.
create function public.marketplace_admin_overview()
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
 if auth.uid() is null or not exists(select 1 from public.marketplace_admin_memberships where user_id=auth.uid() and enabled) then
  raise exception 'Administrator access denied.' using errcode='42501';
 end if;
 return jsonb_build_object('authorized',true,'counts',jsonb_build_object(
 'listings',(select count(*) from public.listings),
 'safety_requests',(select count(*) from public.marketplace_safety_requests),
 'pending_safety',(select count(*) from public.marketplace_safety_requests where state<>'closed')));
end;
$$;
revoke all on function public.marketplace_admin_overview() from public,anon,authenticated;
grant execute on function public.marketplace_admin_overview() to authenticated;
commit;
