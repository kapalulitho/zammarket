-- HOLD 034. Requires 010, corrected 014_v2,022,032. No billing or placements activated.
begin;
create table public.marketplace_revenue_settings(singleton boolean primary key default true check(singleton),allow_requests boolean not null default false);
insert into public.marketplace_revenue_settings values(true,false);alter table public.marketplace_revenue_settings enable row level security;
revoke all on public.marketplace_revenue_settings from public,anon,authenticated,service_role;grant select,update(allow_requests) on public.marketplace_revenue_settings to service_role;
create table public.marketplace_plan_catalogue(code text primary key,label text not null,monthly_minor bigint check(monthly_minor>=0),currency text not null default 'ZMW' check(currency='ZMW'),description text not null);
insert into public.marketplace_plan_catalogue values('free','Free account',0,'ZMW','Existing account tools; no paid entitlement'),('business','Business package',null,'ZMW','Pricing and activation require approved terms'),('company','Company package',null,'ZMW','Pricing, staff permissions and activation require separate approval');
alter table public.marketplace_plan_catalogue enable row level security;revoke all on public.marketplace_plan_catalogue from public,anon,authenticated,service_role;grant select on public.marketplace_plan_catalogue to authenticated;create policy revenue_plan_read on public.marketplace_plan_catalogue for select to authenticated using(true);
create table public.marketplace_subscription_requests(id uuid primary key default gen_random_uuid(),owner_id uuid not null references auth.users(id),organisation_id uuid not null references public.business_organisations(id),plan_code text not null references public.marketplace_plan_catalogue(code),idempotency_key uuid not null,state text not null default 'requested' check(state in('requested','approved','rejected','cancelled')),revision bigint not null default 0,created_at timestamptz not null default now(),unique(owner_id,idempotency_key));
create table public.marketplace_promotion_reviews(id uuid primary key default gen_random_uuid(),owner_id uuid not null references auth.users(id),draft_id uuid not null references public.promotion_drafts(id),snapshot jsonb not null,idempotency_key uuid not null,state text not null default 'requested' check(state in('requested','approved','rejected','cancelled')),revision bigint not null default 0,created_at timestamptz not null default now(),unique(owner_id,idempotency_key));
create table public.marketplace_revenue_events(id uuid primary key default gen_random_uuid(),target_kind text not null check(target_kind in('subscription','promotion')),target_id uuid not null,owner_id uuid not null references auth.users(id),actor_id uuid not null references auth.users(id),revision bigint not null,state text not null,note text not null default '' check(length(note)<=2000),created_at timestamptz not null default now(),unique(target_kind,target_id,revision));
create table public.marketplace_commission_entries(id uuid primary key default gen_random_uuid(),seller_id uuid not null references auth.users(id),source_reference text not null unique check(length(source_reference) between 8 and 200),gross_minor bigint not null check(gross_minor between 0 and 100000000000),fee_minor bigint not null check(fee_minor>=0 and fee_minor<=gross_minor),net_minor bigint generated always as(gross_minor-fee_minor) stored,currency text not null default 'ZMW' check(currency='ZMW'),state text not null check(state in('recorded','reversed')),test_only boolean not null default true check(test_only),created_at timestamptz not null default now());
alter table public.marketplace_subscription_requests enable row level security;alter table public.marketplace_promotion_reviews enable row level security;alter table public.marketplace_revenue_events enable row level security;alter table public.marketplace_commission_entries enable row level security;
revoke all on public.marketplace_subscription_requests,public.marketplace_promotion_reviews,public.marketplace_revenue_events,public.marketplace_commission_entries from public,anon,authenticated,service_role;
grant select on public.marketplace_subscription_requests,public.marketplace_promotion_reviews,public.marketplace_revenue_events,public.marketplace_commission_entries to authenticated;
grant select,insert(seller_id,source_reference,gross_minor,fee_minor,state),update(state) on public.marketplace_commission_entries to service_role;
create policy subscription_owner_read on public.marketplace_subscription_requests for select to authenticated using(owner_id=(select auth.uid()) or public.admin_operations_allowed());
create policy promotion_review_owner_read on public.marketplace_promotion_reviews for select to authenticated using(owner_id=(select auth.uid()) or public.admin_operations_allowed());
create policy revenue_event_owner_read on public.marketplace_revenue_events for select to authenticated using(owner_id=(select auth.uid()) or public.admin_operations_allowed());
create policy commission_owner_read on public.marketplace_commission_entries for select to authenticated using(seller_id=(select auth.uid()));
create index revenue_subscription_owner on public.marketplace_subscription_requests(owner_id,created_at desc);create index revenue_promotion_owner on public.marketplace_promotion_reviews(owner_id,created_at desc);create index commission_seller_created on public.marketplace_commission_entries(seller_id,created_at desc);
create function public.revenue_capabilities() returns jsonb language sql stable security definer set search_path='' as $$select jsonb_build_object('version',1,'requests_enabled',coalesce((select allow_requests from public.marketplace_revenue_settings where singleton),false),'payments_enabled',false,'placements_enabled',false,'admin_review',public.admin_operations_allowed());$$;
create function public.revenue_submit(p_kind text,p_target uuid,p_plan text,p_key uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();saved uuid;prior record;draft public.promotion_drafts;body jsonb;
begin
 if caller is null or not public.marketplace_complete_member() or not coalesce((select allow_requests from public.marketplace_revenue_settings where singleton),false) or p_key is null then raise exception 'Revenue requests disabled';end if;
 perform pg_advisory_xact_lock(hashtextextended('revenue-request:'||caller::text,0));
 if p_kind='subscription' then
 select * into prior from public.marketplace_subscription_requests where owner_id=caller and idempotency_key=p_key;
 if found then if prior.organisation_id is distinct from p_target or prior.plan_code is distinct from p_plan then raise exception 'Key reused with different request';end if;return prior.id;end if;
 if not exists(select 1 from public.business_organisations where id=p_target and owner_id=caller) or not exists(select 1 from public.marketplace_plan_catalogue where code=p_plan) then raise exception 'Owned business and recognised package required';end if;
 if (select count(*) from public.marketplace_subscription_requests where owner_id=caller and state='requested')>=10 then raise exception 'Too many pending package requests';end if;
 insert into public.marketplace_subscription_requests(owner_id,organisation_id,plan_code,idempotency_key) values(caller,p_target,p_plan,p_key) returning id into saved;
 elsif p_kind='promotion' then
 select * into draft from public.promotion_drafts where id=p_target and owner_id=caller and state='draft';if draft.id is null then raise exception 'Owned campaign draft required';end if;
 body:=jsonb_build_object('name',draft.name,'kind',draft.kind,'listing_id',draft.listing_id,'budget',draft.budget,'starts_on',draft.starts_on,'ends_on',draft.ends_on,'notes',draft.notes);
 select * into prior from public.marketplace_promotion_reviews where owner_id=caller and idempotency_key=p_key;
 if found then if prior.draft_id<>p_target or prior.snapshot<>body then raise exception 'Key reused after campaign changed';end if;return prior.id;end if;
 if (select count(*) from public.marketplace_promotion_reviews where owner_id=caller and state='requested')>=20 then raise exception 'Too many pending promotions';end if;
 insert into public.marketplace_promotion_reviews(owner_id,draft_id,snapshot,idempotency_key) values(caller,p_target,body,p_key) returning id into saved;
 else raise exception 'Unsupported revenue request';end if;
 insert into public.marketplace_revenue_events(target_kind,target_id,owner_id,actor_id,revision,state) values(p_kind,saved,caller,caller,0,'requested');return saved;
end $$;
create function public.revenue_review(p_kind text,p_id uuid,p_revision bigint,p_action text,p_note text default '') returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();item record;next_state text;
begin
 if caller is null then raise exception 'Sign in required';end if;
 if p_kind='subscription' then select * into item from public.marketplace_subscription_requests where id=p_id and (owner_id=caller or public.admin_operations_allowed()) for update;
 elsif p_kind='promotion' then select * into item from public.marketplace_promotion_reviews where id=p_id for update;
 else raise exception 'Unsupported request';end if;
 if item.id is null or item.revision is distinct from p_revision then raise exception 'Unavailable or stale request';end if;
 if p_action='cancel' and item.owner_id=caller and item.state in('requested','approved') then next_state:='cancelled';
 elsif p_action in('approve','reject') and public.admin_operations_allowed() and item.owner_id<>caller and item.state='requested' and length(btrim(coalesce(p_note,''))) between 10 and 2000 then next_state:=case p_action when 'approve' then 'approved' else 'rejected' end;
 else raise exception 'Action not permitted';end if;
 if p_kind='subscription' then update public.marketplace_subscription_requests set state=next_state,revision=revision+1 where id=p_id;
 else update public.marketplace_promotion_reviews set state=next_state,revision=revision+1 where id=p_id;end if;
 insert into public.marketplace_revenue_events(target_kind,target_id,owner_id,actor_id,revision,state,note) values(p_kind,p_id,item.owner_id,caller,item.revision+1,next_state,coalesce(p_note,''));
 return jsonb_build_object('id',p_id,'state',next_state,'revision',item.revision+1,'activated',false);
end $$;
revoke all on function public.revenue_capabilities(),public.revenue_submit(text,uuid,text,uuid),public.revenue_review(text,uuid,bigint,text,text) from public,anon,authenticated,service_role;
grant execute on function public.revenue_capabilities(),public.revenue_submit(text,uuid,text,uuid),public.revenue_review(text,uuid,bigint,text,text) to authenticated;
commit;
