-- HOLD 032. Depends on 024,025,022. No administrator provisioned or operations enabled.
-- Private case review and verification decisions; content suppression is NOT activated.
begin;
create table public.marketplace_admin_operation_settings(singleton boolean primary key default true check(singleton),enabled boolean not null default false);
insert into public.marketplace_admin_operation_settings values(true,false);alter table public.marketplace_admin_operation_settings enable row level security;
revoke all on public.marketplace_admin_operation_settings from public,anon,authenticated,service_role;grant select,update(enabled) on public.marketplace_admin_operation_settings to service_role;
create function public.admin_operations_allowed() returns boolean language sql stable security definer set search_path='' as $$select auth.uid() is not null and coalesce(auth.jwt()->>'aal','')='aal2' and public.marketplace_verified_user() and exists(select 1 from public.marketplace_admin_memberships where user_id=auth.uid() and enabled) and coalesce((select enabled from public.marketplace_admin_operation_settings where singleton),false);$$;
create table public.marketplace_review_cases(report_id uuid primary key references public.marketplace_safety_requests(id),state text not null default 'received' check(state in('received','in_review','closed')),revision bigint not null default 0,updated_at timestamptz not null default now());
create table public.marketplace_review_events(report_id uuid not null references public.marketplace_safety_requests(id),revision bigint not null,actor_id uuid not null references auth.users(id),action text not null,note text not null check(length(btrim(note)) between 10 and 2000),created_at timestamptz not null default now(),primary key(report_id,revision));
create table public.marketplace_business_verifications(organisation_id uuid primary key references public.business_organisations(id),report_id uuid not null references public.marketplace_safety_requests(id),decision text not null check(decision in('verified','rejected','revoked')),reviewed_by uuid not null references auth.users(id),reviewed_at timestamptz not null default now());
alter table public.marketplace_review_cases enable row level security;alter table public.marketplace_review_events enable row level security;alter table public.marketplace_business_verifications enable row level security;
revoke all on public.marketplace_review_cases,public.marketplace_review_events,public.marketplace_business_verifications from public,anon,authenticated,service_role;
grant select on public.marketplace_review_cases,public.marketplace_review_events,public.marketplace_business_verifications to authenticated;
create policy admin_case_read on public.marketplace_review_cases for select to authenticated using(public.admin_operations_allowed());
create policy admin_review_event_read on public.marketplace_review_events for select to authenticated using(public.admin_operations_allowed());
create policy business_verification_read on public.marketplace_business_verifications for select to authenticated using(public.admin_operations_allowed() or exists(select 1 from public.business_organisations o where o.id=organisation_id and o.owner_id=(select auth.uid())));
create function public.admin_review_queue() returns jsonb language plpgsql security definer set search_path='' as $$
declare reports jsonb;events jsonb;decisions jsonb;
begin
 if not public.admin_operations_allowed() then raise exception 'Approved MFA administrator required' using errcode='42501';end if;
 select coalesce(jsonb_agg(to_jsonb(row)),'[]') into reports from(select r.id,r.kind,r.target_reference,r.reason,r.description,r.created_at,coalesce(c.state,r.state) state,coalesce(c.revision,0) revision from public.marketplace_safety_requests r left join public.marketplace_review_cases c on c.report_id=r.id order by r.created_at desc limit 100) row;
 select coalesce(jsonb_agg(to_jsonb(row)),'[]') into events from(select report_id,revision,action,note,created_at from public.marketplace_review_events order by created_at desc limit 200) row;
 select coalesce(jsonb_agg(to_jsonb(row)),'[]') into decisions from(select organisation_id,report_id,decision,reviewed_at from public.marketplace_business_verifications order by reviewed_at desc limit 100) row;
 return jsonb_build_object('authorized',true,'reports',reports,'events',events,'verifications',decisions);
end $$;
create function public.admin_review_action(p_report uuid,p_revision bigint,p_action text,p_note text,p_organisation uuid default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare item public.marketplace_safety_requests;current_case public.marketplace_review_cases;next_state text;owner_id uuid;
begin
 if not public.admin_operations_allowed() then raise exception 'Approved MFA administrator required' using errcode='42501';end if;
 if p_note is null or length(btrim(p_note)) not between 10 and 2000 then raise exception 'Audit note required';end if;
 select * into item from public.marketplace_safety_requests where id=p_report for update;
 if item.id is null then raise exception 'Report unavailable';end if;
 insert into public.marketplace_review_cases(report_id,state) values(p_report,item.state) on conflict do nothing;
 select * into current_case from public.marketplace_review_cases where report_id=p_report for update;
 if current_case.revision is distinct from p_revision then raise exception 'Stale review';end if;
 next_state:=current_case.state;
 if p_action='start' and current_case.state='received' then next_state:='in_review';
 elsif p_action='close' and current_case.state='in_review' then next_state:='closed';
 elsif p_action='reopen' and current_case.state='closed' then next_state:='in_review';
 elsif p_action in('request_information','recommend_hide','recommend_restore','escalate') and current_case.state='in_review' then null;
 elsif p_action in('verify_business','reject_business','revoke_business') and current_case.state='in_review' and item.kind='business_verification' then
 select o.owner_id into owner_id from public.business_organisations o where o.id=p_organisation and lower(btrim(item.target_reference))=o.id::text;
 if owner_id is null or owner_id=auth.uid() then raise exception 'Independent matching business review required';end if;
 insert into public.marketplace_business_verifications(organisation_id,report_id,decision,reviewed_by) values(p_organisation,p_report,case p_action when 'verify_business' then 'verified' when 'reject_business' then 'rejected' else 'revoked' end,auth.uid()) on conflict(organisation_id) do update set report_id=excluded.report_id,decision=excluded.decision,reviewed_by=excluded.reviewed_by,reviewed_at=now();
 else raise exception 'Review action unavailable';end if;
 update public.marketplace_review_cases set state=next_state,revision=revision+1,updated_at=now() where report_id=p_report;
 update public.marketplace_safety_requests set state=next_state where id=p_report;
 insert into public.marketplace_review_events(report_id,revision,actor_id,action,note) values(p_report,current_case.revision+1,auth.uid(),p_action,btrim(p_note));
 return jsonb_build_object('id',p_report,'state',next_state,'revision',current_case.revision+1);
end $$;
revoke all on function public.admin_operations_allowed(),public.admin_review_queue(),public.admin_review_action(uuid,bigint,text,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.admin_operations_allowed(),public.admin_review_queue(),public.admin_review_action(uuid,bigint,text,text,uuid) to authenticated;
commit;
