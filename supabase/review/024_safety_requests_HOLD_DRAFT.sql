-- HOLD DRAFT: not approved for staging or production. Never run automatically.
-- New objects only. Requires existing 010 marketplace_complete_member().
-- No document uploads, public reports, verification badge or moderator permissions.
begin;
create table public.marketplace_safety_requests (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references auth.users(id),
 kind text not null check (kind in ('listing','user','business_verification')),
 target_reference text not null check (length(btrim(target_reference)) between 3 and 200),
 reason text not null check (reason in ('Misleading listing','Suspected scam','Prohibited content','Harassment','Privacy concern','Other')),
 description text not null check (length(btrim(description)) between 20 and 2000),
 state text not null default 'received' check (state in ('received','in_review','closed')),
 created_at timestamptz not null default now()
);
create index marketplace_safety_owner_created on public.marketplace_safety_requests(owner_id,created_at desc);
alter table public.marketplace_safety_requests enable row level security;
revoke all on public.marketplace_safety_requests from public,anon,authenticated;
grant select on public.marketplace_safety_requests to authenticated;
create policy marketplace_safety_owner_read on public.marketplace_safety_requests
 for select to authenticated using (owner_id=(select auth.uid()));
-- Clients cannot insert/update/delete directly, change status, or read others' reports.
create function public.prepare_safety_submission(p_kind text,p_target text,p_reason text,p_description text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_user uuid := auth.uid(); v_id uuid;
begin
 if v_user is null or not public.marketplace_complete_member() then
  raise exception 'A verified, complete account is required.';
 end if;
 -- Serializes concurrent submissions for one account, including rate-limit check.
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_user::text,724));
 if (select count(*) from public.marketplace_safety_requests where owner_id=v_user and created_at>now()-interval '24 hours')>=5 then
  raise exception 'Submission limit reached. Try again later.';
 end if;
 if exists(select 1 from public.marketplace_safety_requests where owner_id=v_user and kind=p_kind and target_reference=btrim(p_target) and reason=p_reason and created_at>now()-interval '24 hours') then
  raise exception 'A request for this reference and reason was already received.';
 end if;
 insert into public.marketplace_safety_requests(owner_id,kind,target_reference,reason,description)
 values(v_user,p_kind,btrim(p_target),p_reason,btrim(p_description)) returning id into v_id;
 return jsonb_build_object('id',v_id,'state','received');
end;
$$;
revoke all on function public.prepare_safety_submission(text,text,text,text) from public,anon,authenticated;
grant execute on function public.prepare_safety_submission(text,text,text,text) to authenticated;
commit;
