-- HOLD 029: participant workflows. New tables/functions only; no live activation.
-- Baseline 010 required; optional sources 013_v2/015/020/023 must be reviewed separately.
begin;
create table public.marketplace_work_settings(kind text primary key,source_table text not null,enabled boolean not null default false,edges jsonb not null);
insert into public.marketplace_work_settings values ('job','community_entries',false,'[["submitted","review","reviewed","provider"],["reviewed","shortlist","shortlisted","provider"],["shortlisted","interview","interview_scheduled","provider"],["interview_scheduled","offer","offered","provider"],["offered","accept_offer","accepted","requester"],["reviewed","reject","rejected","provider"],["shortlisted","reject","rejected","provider"],["interview_scheduled","reject","rejected","provider"]]'::jsonb),
('property','property_listings',false,'[["submitted","contact","contacted","provider"],["contacted","schedule","viewing_scheduled","provider"],["viewing_scheduled","viewed","viewed","provider"],["viewed","close","closed","provider"]]'::jsonb),
('logistics','business_service_entries',false,'[["submitted","quote","quoted","provider"],["quoted","accept_quote","accepted","requester"],["accepted","schedule","scheduled","provider"],["scheduled","depart","in_transit","provider"],["in_transit","deliver","delivered","provider"]]'::jsonb),
('learning','community_entries',false,'[["submitted","offer","offered","provider"],["offered","accept_offer","accepted","requester"],["accepted","enrol","enrolled","provider"],["enrolled","complete","completed","provider"]]'::jsonb),
('agriculture','specialist_listings',false,'[["submitted","quote","quoted","provider"],["quoted","accept_quote","accepted","requester"],["accepted","prepare","preparing","provider"],["preparing","ready","ready","provider"],["ready","fulfil","fulfilled","provider"]]'::jsonb),
('service','community_entries',false,'[["submitted","quote","quoted","provider"],["quoted","accept_quote","accepted","requester"],["accepted","schedule","scheduled","provider"],["scheduled","start","in_progress","provider"],["in_progress","complete","completed","provider"]]'::jsonb),
('digital','specialist_listings',false,'[["submitted","quote","quoted","provider"],["quoted","accept_quote","accepted","requester"],["accepted","verify_purchase","awaiting_verification","provider"]]'::jsonb);
alter table public.marketplace_work_settings enable row level security;
revoke all on public.marketplace_work_settings from public,anon,authenticated,service_role;
grant select,update(enabled) on public.marketplace_work_settings to service_role;
create table public.marketplace_work_requests(
 id uuid primary key default gen_random_uuid(),kind text not null references public.marketplace_work_settings(kind),target_id uuid not null,
 requester_id uuid not null references auth.users(id),provider_id uuid not null references auth.users(id),title_snapshot text not null,
 request jsonb not null check(jsonb_typeof(request)='object' and octet_length(request::text)<=15000),idempotency_key uuid not null,
 state text not null default 'submitted',revision bigint not null default 0,quote_minor bigint check(quote_minor between 0 and 100000000000),currency text not null default 'ZMW' check(currency='ZMW'),
 appointment_at timestamptz,progress integer not null default 0 check(progress between 0 and 100),created_at timestamptz not null default now(),unique(requester_id,idempotency_key),check(requester_id<>provider_id)
);
create table public.marketplace_work_events(request_id uuid not null references public.marketplace_work_requests(id),revision bigint not null,actor_id uuid not null references auth.users(id),action text not null,from_state text,to_state text not null,quote_minor bigint,appointment_at timestamptz,created_at timestamptz not null default now(),primary key(request_id,revision));
create table public.marketplace_work_messages(id uuid primary key default gen_random_uuid(),request_id uuid not null references public.marketplace_work_requests(id),actor_id uuid not null references auth.users(id),body text not null check(length(btrim(body)) between 1 and 2000),created_at timestamptz not null default now());
create table public.marketplace_provider_assets(id uuid primary key default gen_random_uuid(),kind text not null references public.marketplace_work_settings(kind),target_id uuid not null,owner_id uuid not null references auth.users(id),label text not null check(length(btrim(label)) between 2 and 120),category text not null check(length(category)<=100),quantity integer not null check(quantity between 0 and 1000000),description text not null default '' check(length(description)<=2000),active boolean not null default true,created_at timestamptz not null default now());
create index work_request_requester on public.marketplace_work_requests(requester_id,kind,created_at desc);
create index work_request_provider on public.marketplace_work_requests(provider_id,kind,created_at desc);
create index work_message_request on public.marketplace_work_messages(request_id,created_at);
create index provider_asset_owner on public.marketplace_provider_assets(owner_id,kind);
alter table public.marketplace_work_requests enable row level security;alter table public.marketplace_work_events enable row level security;alter table public.marketplace_work_messages enable row level security;alter table public.marketplace_provider_assets enable row level security;
revoke all on public.marketplace_work_requests,public.marketplace_work_events,public.marketplace_work_messages,public.marketplace_provider_assets from public,anon,authenticated,service_role;
grant select on public.marketplace_work_requests,public.marketplace_work_events,public.marketplace_work_messages,public.marketplace_provider_assets to authenticated;
create policy work_participants on public.marketplace_work_requests for select to authenticated using((select auth.uid()) in(requester_id,provider_id));
create policy work_event_participants on public.marketplace_work_events for select to authenticated using(exists(select 1 from public.marketplace_work_requests r where r.id=request_id and (select auth.uid()) in(r.requester_id,r.provider_id)));
create policy work_message_participants on public.marketplace_work_messages for select to authenticated using(exists(select 1 from public.marketplace_work_requests r where r.id=request_id and (select auth.uid()) in(r.requester_id,r.provider_id)));
create policy work_asset_owner on public.marketplace_provider_assets for select to authenticated using(owner_id=(select auth.uid()));
-- Fixed source queries, not caller-provided identifiers. Helper is NOT client-executable.
create function public.work_target(p_kind text,p_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare item jsonb;
begin
 if p_kind in('job','learning','service') then
 if to_regclass('public.community_entries') is null then return null;end if;
 execute 'select jsonb_build_object(''owner'',owner_id,''title'',title,''open'',status=''published'' and (kind<>''job'' or deadline is null or deadline>=(now() at time zone ''Africa/Lusaka'')::date)) from public.community_entries where id=$1 and kind=$2' into item using p_id,p_kind;
 elsif p_kind='property' then
 if to_regclass('public.property_listings') is null then return null;end if;
 execute 'select jsonb_build_object(''owner'',owner_id,''title'',title,''open'',status=''published'' and price_basis<>''Per night'') from public.property_listings where id=$1' into item using p_id;
 elsif p_kind='logistics' then
 if to_regclass('public.business_service_entries') is null then return null;end if;
 execute 'select jsonb_build_object(''owner'',owner_id,''title'',name,''open'',public.business_service_visible(id)) from public.business_service_entries where id=$1 and kind=''logistics''' into item using p_id;
 elsif p_kind in('agriculture','digital') then
 if to_regclass('public.specialist_listings') is null then return null;end if;
 execute 'select jsonb_build_object(''owner'',owner_id,''title'',title,''open'',status=''published'' and public.specialist_publication_enabled()) from public.specialist_listings where id=$1 and kind=$2' into item using p_id,p_kind;
 end if;return item;
end $$;
create function public.work_capabilities(p_kind text) returns jsonb language sql stable security definer set search_path='' as $$select jsonb_build_object('version',1,'kind',kind,'enabled',enabled,'source_ready',to_regclass('public.'||source_table) is not null) from public.marketplace_work_settings where kind=p_kind;$$;
create function public.work_submit(p_kind text,p_target uuid,p_request jsonb,p_key uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();target jsonb;prior public.marketplace_work_requests;saved uuid;item record;
begin
 if caller is null or not public.marketplace_complete_member() then raise exception 'Verified complete account required';end if;
 if not coalesce((select enabled from public.marketplace_work_settings where kind=p_kind),false) then raise exception 'Workflow disabled';end if;
 if p_key is null or jsonb_typeof(p_request) is distinct from 'object' or octet_length(p_request::text)>15000 or length(btrim(coalesce(p_request->>'note',''))) not between 10 and 3000 then raise exception 'Invalid request';end if;
 for item in select key,value from jsonb_each(p_request) loop
 if item.key not in('note','skills','experience','requirements','origin_area','destination_area','quantity') or jsonb_typeof(item.value)<>'string' or length(item.value#>>'{}')>case when item.key='note' then 3000 else 1000 end then raise exception 'Unsupported request field';end if;
 end loop;
 perform pg_advisory_xact_lock(hashtextextended('work-requester:'||caller::text,0));
 select * into prior from public.marketplace_work_requests where requester_id=caller and idempotency_key=p_key;
 if prior.id is not null then if prior.kind<>p_kind or prior.target_id<>p_target or prior.request<>p_request then raise exception 'Key reused with different request';end if;return prior.id;end if;
 if (select count(*) from public.marketplace_work_requests where requester_id=caller and state not in('closed','completed','rejected','withdrawn','cancelled','fulfilled','delivered'))>=30 then raise exception 'Too many open requests';end if;
 target:=public.work_target(p_kind,p_target);
 if target is null or not coalesce((target->>'open')::boolean,false) or (target->>'owner')::uuid=caller then raise exception 'Published available target required';end if;
 insert into public.marketplace_work_requests(kind,target_id,requester_id,provider_id,title_snapshot,request,idempotency_key) values(p_kind,p_target,caller,(target->>'owner')::uuid,target->>'title',p_request,p_key) returning id into saved;
 insert into public.marketplace_work_events(request_id,revision,actor_id,action,to_state) values(saved,0,caller,'submit','submitted');return saved;
end $$;
create function public.work_advance(p_id uuid,p_revision bigint,p_action text,p_quote_minor bigint default null,p_appointment timestamptz default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();item public.marketplace_work_requests;next_state text;actor text;
begin
 if caller is null or not public.marketplace_complete_member() then raise exception 'Verified complete account required';end if;
 select * into item from public.marketplace_work_requests where id=p_id and caller in(requester_id,provider_id) for update;
 if item.id is null or item.revision is distinct from p_revision or item.state in('closed','completed','rejected','withdrawn','cancelled','fulfilled','delivered') then raise exception 'Unavailable or stale request';end if;
 actor:=case when caller=item.provider_id then 'provider' else 'requester' end;
 if p_action='withdraw' and actor='requester' then next_state:='withdrawn';elsif p_action='cancel' and actor='provider' then next_state:='cancelled';
 elsif coalesce((select enabled from public.marketplace_work_settings where kind=item.kind),false) then
 select value->>2 into next_state from public.marketplace_work_settings s,jsonb_array_elements(s.edges) where s.kind=item.kind and value->>0=item.state and value->>1=p_action and value->>3=actor;
 end if;
 if next_state is null then raise exception 'Transition not permitted';end if;
 if p_action='quote' then if actor<>'provider' or p_quote_minor is null or p_quote_minor not between 0 and 100000000000 then raise exception 'Valid provider quote required';end if;else if p_quote_minor is not null then raise exception 'Amount only allowed for quotation';end if;end if;
 if p_action in('schedule','interview') then if p_appointment is null or p_appointment<=now() or p_appointment>now()+interval '1 year' then raise exception 'Future appointment within one year required';end if;elsif p_appointment is not null then raise exception 'Appointment only allowed for scheduling';end if;
 update public.marketplace_work_requests set state=next_state,revision=revision+1,quote_minor=coalesce(p_quote_minor,quote_minor),appointment_at=coalesce(p_appointment,appointment_at) where id=p_id;
 insert into public.marketplace_work_events(request_id,revision,actor_id,action,from_state,to_state,quote_minor,appointment_at) values(p_id,item.revision+1,caller,p_action,item.state,next_state,p_quote_minor,p_appointment);
 return jsonb_build_object('id',p_id,'revision',item.revision+1,'state',next_state);
end $$;
create function public.work_message(p_id uuid,p_body text) returns uuid language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();saved uuid;
begin
 if caller is null or not public.marketplace_complete_member() or length(btrim(p_body)) not between 1 and 2000 or not exists(select 1 from public.marketplace_work_requests where id=p_id and caller in(requester_id,provider_id)) then raise exception 'Participant message required';end if;
 perform pg_advisory_xact_lock(hashtextextended('work-message:'||caller::text,0));
 if (select count(*) from public.marketplace_work_messages where actor_id=caller and created_at>now()-interval '1 day')>=100 then raise exception 'Message limit reached';end if;
 insert into public.marketplace_work_messages(request_id,actor_id,body) values(p_id,caller,btrim(p_body)) returning id into saved;return saved;
end $$;
create function public.work_save_asset(p_kind text,p_target uuid,p_id uuid,p_fields jsonb) returns uuid language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();target jsonb;saved uuid;
begin
 if caller is null or not public.marketplace_complete_member() then raise exception 'Verified owner required';end if;target:=public.work_target(p_kind,p_target);
 if target is null or (target->>'owner')::uuid<>caller then raise exception 'Owning provider required';end if;
 if jsonb_typeof(p_fields) is distinct from 'object' or p_fields-array['label','category','quantity','description','active']<>'{}'::jsonb then raise exception 'Unsupported asset fields';end if;
 perform pg_advisory_xact_lock(hashtextextended('work-assets:'||caller::text,0));
 if p_id is null then
 if (select count(*) from public.marketplace_provider_assets where owner_id=caller)>=200 then raise exception 'Asset limit reached';end if;
 insert into public.marketplace_provider_assets(kind,target_id,owner_id,label,category,quantity,description,active) values(p_kind,p_target,caller,btrim(p_fields->>'label'),coalesce(p_fields->>'category',''),(p_fields->>'quantity')::integer,coalesce(p_fields->>'description',''),coalesce((p_fields->>'active')::boolean,true)) returning id into saved;
 else update public.marketplace_provider_assets set label=btrim(p_fields->>'label'),category=coalesce(p_fields->>'category',''),quantity=(p_fields->>'quantity')::integer,description=coalesce(p_fields->>'description',''),active=coalesce((p_fields->>'active')::boolean,true) where id=p_id and owner_id=caller and kind=p_kind and target_id=p_target returning id into saved;end if;
 if saved is null then raise exception 'Asset unavailable';end if;return saved;
end $$;
create function public.work_progress(p_id uuid,p_revision bigint,p_progress integer) returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();item public.marketplace_work_requests;
begin
 if caller is null or not public.marketplace_complete_member() or p_progress is null or p_progress not between 0 and 100 then raise exception 'Valid learner progress required';end if;
 select * into item from public.marketplace_work_requests where id=p_id and requester_id=caller and kind='learning' and state='enrolled' for update;
 if item.id is null or item.revision is distinct from p_revision then raise exception 'Unavailable or stale enrolment';end if;
 update public.marketplace_work_requests set progress=p_progress,revision=revision+1 where id=p_id;
 insert into public.marketplace_work_events(request_id,revision,actor_id,action,from_state,to_state) values(p_id,item.revision+1,caller,'progress',item.state,item.state);
 return jsonb_build_object('id',p_id,'progress',p_progress,'revision',item.revision+1);
end $$;
revoke all on function public.work_target(text,uuid),public.work_capabilities(text),public.work_submit(text,uuid,jsonb,uuid),public.work_advance(uuid,bigint,text,bigint,timestamptz),public.work_message(uuid,text),public.work_save_asset(text,uuid,uuid,jsonb),public.work_progress(uuid,bigint,integer) from public,anon,authenticated,service_role;
grant execute on function public.work_capabilities(text),public.work_submit(text,uuid,jsonb,uuid),public.work_advance(uuid,bigint,text,bigint,timestamptz),public.work_message(uuid,text),public.work_save_asset(text,uuid,uuid,jsonb),public.work_progress(uuid,bigint,integer) to authenticated;
commit;
