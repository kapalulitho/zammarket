-- HOLD 040: secure course publishing, enrolment and private material delivery.
-- REVIEW ONLY. Requires 010, 013_v2, 029, 036 and 038. Install after 039.
-- Every runtime gate is inserted FALSE. This migration does not publish a course,
-- grant an enrolment, sign a file, schedule work or enable a production feature.
begin;
set local lock_timeout='5s';
set local statement_timeout='90s';

do $$
begin
 if to_regclass('public.community_entries') is null
    or to_regclass('public.marketplace_work_requests') is null
    or to_regclass('public.payment_intents') is null
    or to_regprocedure('public.payment_covers(uuid,text,uuid,uuid,bigint)') is null
    or to_regprocedure('public.moderation_target_allowed(text,uuid,uuid)') is null
    or to_regprocedure('public.moderation_actor_allowed(uuid)') is null then
  raise exception '040 dependencies are missing; install the reviewed 010/013_v2/029/036/038 drafts first';
 end if;
end $$;

create table public.course_runtime_settings(
 singleton boolean primary key default true check(singleton),
 publishing_enabled boolean not null default false,
 enrolment_enabled boolean not null default false,
 delivery_enabled boolean not null default false
);
insert into public.course_runtime_settings values(true,false,false,false);
alter table public.course_runtime_settings enable row level security;
revoke all on public.course_runtime_settings from public,anon,authenticated,service_role;
grant select,update(publishing_enabled,enrolment_enabled,delivery_enabled) on public.course_runtime_settings to service_role;

create table public.course_programs(
 id uuid primary key default gen_random_uuid(),
 source_entry_id uuid not null unique references public.community_entries(id),
 instructor_id uuid not null references auth.users(id),
 title_snapshot text not null check(length(btrim(title_snapshot)) between 3 and 200),
 summary text not null check(length(btrim(summary)) between 10 and 3000),
 access_days integer not null default 30 check(access_days between 1 and 365),
 published_price_minor bigint check(published_price_minor between 0 and 100000000000),
 currency text not null default 'ZMW' check(currency='ZMW'),
 status text not null default 'draft' check(status in('draft','published','retired')),
 revision bigint not null default 0,
 published_at timestamptz,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index course_program_owner on public.course_programs(instructor_id,updated_at desc);
create index course_program_discovery on public.course_programs(status,published_at desc);

create table public.course_modules(
 id uuid primary key default gen_random_uuid(),
 course_id uuid not null references public.course_programs(id),
 position integer not null check(position between 1 and 500),
 title text not null check(length(btrim(title)) between 2 and 160),
 created_at timestamptz not null default now(),
 unique(course_id,position)
);
create table public.course_lessons(
 id uuid primary key default gen_random_uuid(),
 course_id uuid not null references public.course_programs(id),
 module_id uuid not null references public.course_modules(id),
 position integer not null check(position between 1 and 500),
 title text not null check(length(btrim(title)) between 2 and 160),
 summary text not null default '' check(length(summary)<=2000),
 preview boolean not null default false,
 created_at timestamptz not null default now(),
 unique(module_id,position)
);
create index course_lesson_course on public.course_lessons(course_id,module_id,position);

create table public.course_materials(
 id uuid primary key default gen_random_uuid(),
 course_id uuid not null references public.course_programs(id),
 lesson_id uuid not null references public.course_lessons(id),
 instructor_id uuid not null references auth.users(id),
 path text not null unique check(length(path) between 40 and 500 and path not like '%..%'),
 title text not null check(length(btrim(title)) between 2 and 160),
 media_type text not null check(media_type in('pdf','video')),
 mime_type text not null check(mime_type in('application/pdf','video/mp4','video/webm')),
 byte_size bigint not null check(byte_size between 1 and 52428800),
 duration_seconds integer check(duration_seconds between 1 and 86400),
 scan_status text not null default 'pending' check(scan_status in('pending','approved','blocked')),
 scan_observed_at timestamptz,
 created_at timestamptz not null default now()
);
create index course_material_lesson on public.course_materials(course_id,lesson_id,created_at);
create index course_material_scan on public.course_materials(scan_status,created_at);

create table public.course_access_grants(
 id uuid primary key default gen_random_uuid(),
 course_id uuid not null references public.course_programs(id),
 work_request_id uuid not null unique references public.marketplace_work_requests(id),
 learner_id uuid not null references auth.users(id),
 instructor_id uuid not null references auth.users(id),
 payment_intent_id uuid references public.payment_intents(id),
 price_snapshot_minor bigint not null check(price_snapshot_minor between 0 and 100000000000),
 currency text not null default 'ZMW' check(currency='ZMW'),
 idempotency_key uuid not null,
 state text not null default 'active' check(state in('active','revoked')),
 begins_at timestamptz not null default now(),
 expires_at timestamptz not null,
 revoked_at timestamptz,
 created_at timestamptz not null default now(),
 unique(instructor_id,idempotency_key),
 check(learner_id<>instructor_id and expires_at>begins_at),
 check((price_snapshot_minor=0 and payment_intent_id is null) or (price_snapshot_minor>0 and payment_intent_id is not null)),
 check((state='active' and revoked_at is null) or (state='revoked' and revoked_at is not null))
);
create index course_access_learner on public.course_access_grants(learner_id,expires_at desc);
create index course_access_instructor on public.course_access_grants(instructor_id,created_at desc);

create table public.course_lesson_progress(
 grant_id uuid not null references public.course_access_grants(id),
 lesson_id uuid not null references public.course_lessons(id),
 learner_id uuid not null references auth.users(id),
 state text not null default 'not_started' check(state in('not_started','in_progress','completed')),
 position_seconds integer not null default 0 check(position_seconds between 0 and 86400),
 completed_at timestamptz,
 updated_at timestamptz not null default now(),
 primary key(grant_id,lesson_id),
 check((state='completed' and completed_at is not null) or (state<>'completed' and completed_at is null))
);
create index course_progress_learner on public.course_lesson_progress(learner_id,updated_at desc);

create table public.course_delivery_audit(
 id uuid primary key default gen_random_uuid(),
 learner_id uuid not null references auth.users(id),
 grant_id uuid not null references public.course_access_grants(id),
 material_id uuid not null references public.course_materials(id),
 created_at timestamptz not null default now()
);
create index course_delivery_learner_time on public.course_delivery_audit(learner_id,created_at desc);

alter table public.course_programs enable row level security;
alter table public.course_modules enable row level security;
alter table public.course_lessons enable row level security;
alter table public.course_materials enable row level security;
alter table public.course_access_grants enable row level security;
alter table public.course_lesson_progress enable row level security;
alter table public.course_delivery_audit enable row level security;
revoke all on public.course_programs,public.course_modules,public.course_lessons,public.course_materials,public.course_access_grants,public.course_lesson_progress,public.course_delivery_audit from public,anon,authenticated,service_role;
grant select on public.course_programs,public.course_modules,public.course_lessons to anon,authenticated;
grant select(id,course_id,lesson_id,instructor_id,title,media_type,mime_type,byte_size,duration_seconds,scan_status,scan_observed_at,created_at) on public.course_materials to authenticated;
grant select on public.course_access_grants,public.course_lesson_progress,public.course_delivery_audit to authenticated;

create function public.course_source_snapshot(p_source uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('owner',owner_id,'title',title,'price_minor',round(coalesce(price,0)*100)::bigint,'currency',upper(split_part(btrim(price_unit),' ',1)),'published',status='published')
 from public.community_entries where id=p_source and kind='learning'
$$;
create function public.course_owner_or_student(p_course uuid,p_user uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.course_programs c where c.id=p_course and c.instructor_id=p_user)
 or exists(select 1 from public.course_access_grants g join public.course_programs c on c.id=g.course_id
   join public.community_entries e on e.id=c.source_entry_id
   where g.course_id=p_course and g.learner_id=p_user and g.state='active'
    and g.begins_at<=now() and g.expires_at>now() and c.status='published'
    and e.status='published' and e.kind='learning'
    and exists(select 1 from auth.users u join public.marketplace_profiles p on p.id=u.id
      where u.id=p_user and u.email_confirmed_at is not null and p.completed_at is not null)
    and public.moderation_actor_allowed(p_user)
    and public.moderation_target_allowed('community',e.id,c.instructor_id)
    and (g.price_snapshot_minor=0 or public.payment_covers(g.payment_intent_id,'work',g.work_request_id,p_user,g.price_snapshot_minor)))
$$;
create function public.course_publicly_visible(p_course uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.course_programs c join public.community_entries e on e.id=c.source_entry_id
  where c.id=p_course and c.status='published' and e.status='published' and e.kind='learning'
  and public.moderation_target_allowed('community',e.id,e.owner_id))
$$;
create function public.course_verified_member(p_user uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from auth.users u join public.marketplace_profiles p on p.id=u.id
  where u.id=p_user and u.email_confirmed_at is not null and p.completed_at is not null)
$$;

create policy course_program_read on public.course_programs for select to anon,authenticated using(
 instructor_id=(select auth.uid()) or public.course_publicly_visible(id)
 or exists(select 1 from public.course_access_grants g where g.course_id=id and g.learner_id=(select auth.uid()))
);
create policy course_module_read on public.course_modules for select to anon,authenticated using(
 public.course_publicly_visible(course_id) or public.course_owner_or_student(course_id,(select auth.uid()))
);
create policy course_lesson_read on public.course_lessons for select to anon,authenticated using(
  (preview and public.course_publicly_visible(course_id)) or public.course_owner_or_student(course_id,(select auth.uid()))
);
create policy course_material_metadata_read on public.course_materials for select to authenticated using(
 instructor_id=(select auth.uid()) or exists(select 1 from public.course_access_grants g where g.course_id=course_id and g.learner_id=(select auth.uid()) and g.state='active' and g.begins_at<=now() and g.expires_at>now())
);
create policy course_access_participants on public.course_access_grants for select to authenticated using((select auth.uid()) in(learner_id,instructor_id));
create policy course_progress_participants on public.course_lesson_progress for select to authenticated using(
 learner_id=(select auth.uid()) or exists(select 1 from public.course_access_grants g where g.id=grant_id and g.instructor_id=(select auth.uid()))
);
create policy course_delivery_owner on public.course_delivery_audit for select to authenticated using(learner_id=(select auth.uid()));

create function public.course_save_program(p_source uuid,p_course uuid,p_revision bigint,p_summary text,p_access_days integer) returns uuid language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();source jsonb;item public.course_programs;saved uuid;
begin
 if caller is null or not public.marketplace_complete_member() or not public.moderation_actor_allowed(caller) then raise exception 'Eligible instructor required';end if;
 source:=public.course_source_snapshot(p_source);
 if source is null or (source->>'owner')::uuid<>caller or length(btrim(coalesce(p_summary,''))) not between 10 and 3000 or p_access_days not between 1 and 365 then raise exception 'Owned learning source and valid course details required';end if;
 perform pg_advisory_xact_lock(hashtextextended('course-owner:'||caller::text,0));
 if p_course is null then
  if p_revision is not null or (select count(*) from public.course_programs where instructor_id=caller)>=100 then raise exception 'Course creation unavailable';end if;
  insert into public.course_programs(source_entry_id,instructor_id,title_snapshot,summary,access_days)
  values(p_source,caller,source->>'title',btrim(p_summary),p_access_days) returning id into saved;
 else
  select * into item from public.course_programs where id=p_course and source_entry_id=p_source and instructor_id=caller for update;
  if item.id is null or item.revision is distinct from p_revision or item.status<>'draft' then raise exception 'Draft course unavailable or stale';end if;
  update public.course_programs set title_snapshot=source->>'title',summary=btrim(p_summary),access_days=p_access_days,revision=revision+1,updated_at=now() where id=p_course returning id into saved;
 end if;
 return saved;
end $$;

create function public.course_save_module(p_course uuid,p_module uuid,p_position integer,p_title text) returns uuid language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();saved uuid;
begin
 if caller is null or not public.marketplace_complete_member() or p_position not between 1 and 500 or length(btrim(coalesce(p_title,''))) not between 2 and 160 then raise exception 'Valid instructor module required';end if;
 perform id from public.course_programs where id=p_course and instructor_id=caller and status='draft' for update;if not found then raise exception 'Owned draft course required';end if;
 if p_module is null then insert into public.course_modules(course_id,position,title) values(p_course,p_position,btrim(p_title)) returning id into saved;
 else update public.course_modules set position=p_position,title=btrim(p_title) where id=p_module and course_id=p_course returning id into saved;end if;
 if saved is null then raise exception 'Module unavailable';end if;update public.course_programs set revision=revision+1,updated_at=now() where id=p_course;return saved;
end $$;

create function public.course_save_lesson(p_course uuid,p_module uuid,p_lesson uuid,p_position integer,p_title text,p_summary text,p_preview boolean) returns uuid language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();saved uuid;
begin
 if caller is null or not public.marketplace_complete_member() or p_position not between 1 and 500 or length(btrim(coalesce(p_title,''))) not between 2 and 160 or length(coalesce(p_summary,''))>2000 then raise exception 'Valid instructor lesson required';end if;
 perform c.id from public.course_programs c join public.course_modules m on m.course_id=c.id where c.id=p_course and c.instructor_id=caller and c.status='draft' and m.id=p_module for update of c;if not found then raise exception 'Owned draft module required';end if;
 if p_lesson is null then insert into public.course_lessons(course_id,module_id,position,title,summary,preview) values(p_course,p_module,p_position,btrim(p_title),coalesce(p_summary,''),coalesce(p_preview,false)) returning id into saved;
 else update public.course_lessons set module_id=p_module,position=p_position,title=btrim(p_title),summary=coalesce(p_summary,''),preview=coalesce(p_preview,false) where id=p_lesson and course_id=p_course returning id into saved;end if;
 if saved is null then raise exception 'Lesson unavailable';end if;update public.course_programs set revision=revision+1,updated_at=now() where id=p_course;return saved;
end $$;

create function public.course_register_material(p_course uuid,p_lesson uuid,p_path text,p_title text,p_duration integer default null) returns uuid language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();object_size bigint;object_mime text;saved uuid;
begin
 if caller is null or not public.marketplace_complete_member() or length(btrim(coalesce(p_title,''))) not between 2 and 160 or p_duration is not null and p_duration not between 1 and 86400 then raise exception 'Valid instructor material required';end if;
 perform c.id from public.course_programs c join public.course_lessons l on l.course_id=c.id where c.id=p_course and c.instructor_id=caller and c.status='draft' and l.id=p_lesson for update of c;if not found then raise exception 'Owned draft lesson required';end if;
 if p_path is null or p_path not like caller::text||'/'||p_course::text||'/%' or p_path like '%..%' or length(p_path)>500 then raise exception 'Invalid private material path';end if;
 select nullif(metadata->>'size','')::bigint,coalesce(metadata->>'mimetype','') into object_size,object_mime from storage.objects where bucket_id='course-materials' and name=p_path for share;
 if object_size is null or object_size not between 1 and 52428800 or object_mime not in('application/pdf','video/mp4','video/webm') then raise exception 'Uploaded material type or size is unavailable';end if;
 perform pg_advisory_xact_lock(hashtextextended('course-material:'||caller::text,0));
 if (select count(*) from public.course_materials where instructor_id=caller)>=2000 then raise exception 'Material limit reached';end if;
 insert into public.course_materials(course_id,lesson_id,instructor_id,path,title,media_type,mime_type,byte_size,duration_seconds)
 values(p_course,p_lesson,caller,p_path,btrim(p_title),case when object_mime='application/pdf' then 'pdf' else 'video' end,object_mime,object_size,p_duration) returning id into saved;
 update public.course_programs set revision=revision+1,updated_at=now() where id=p_course;return saved;
end $$;

create function public.course_material_scan_review(p_material uuid,p_status text,p_observed_size bigint,p_mime text) returns void language plpgsql security definer set search_path='' as $$
declare item public.course_materials;
begin
 if auth.role() is distinct from 'service_role' or p_status not in('approved','blocked') then raise exception 'Trusted material scanner required';end if;
 select * into item from public.course_materials where id=p_material for update;
 if item.id is null or p_observed_size is distinct from item.byte_size or p_mime is distinct from item.mime_type or (p_status='approved' and item.scan_status<>'pending') then raise exception 'Material scan binding failed';end if;
 if item.scan_status=p_status then return;end if;
 update public.course_materials set scan_status=p_status,scan_observed_at=now() where id=p_material;
end $$;

create function public.course_publish(p_course uuid,p_revision bigint) returns void language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();item public.course_programs;source jsonb;price bigint;
begin
 if caller is null or not public.marketplace_complete_member() or not public.moderation_actor_allowed(caller) or not coalesce((select publishing_enabled from public.course_runtime_settings where singleton),false) then raise exception 'Course publishing disabled or instructor ineligible';end if;
 select * into item from public.course_programs where id=p_course and instructor_id=caller for update;
 if item.id is null or item.status<>'draft' or item.revision is distinct from p_revision then raise exception 'Draft course unavailable or stale';end if;
 perform id from public.community_entries where id=item.source_entry_id for share;
 source:=public.course_source_snapshot(item.source_entry_id);price:=(source->>'price_minor')::bigint;
 if source is null or not coalesce((source->>'published')::boolean,false) or source->>'currency'<>'ZMW' or not public.moderation_target_allowed('community',item.source_entry_id,caller) then raise exception 'Published moderated ZMW learning source required';end if;
 if not exists(select 1 from public.course_modules where course_id=p_course) or not exists(select 1 from public.course_lessons where course_id=p_course) then raise exception 'Course outline is incomplete';end if;
 if exists(select 1 from public.course_materials where course_id=p_course and scan_status<>'approved') then raise exception 'Every material must pass scanning';end if;
 update public.course_programs set title_snapshot=source->>'title',published_price_minor=price,status='published',published_at=now(),revision=revision+1,updated_at=now() where id=p_course;
end $$;

create function public.course_unpublish(p_course uuid,p_revision bigint) returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Instructor required';end if;
 update public.course_programs set status='draft',published_at=null,revision=revision+1,updated_at=now() where id=p_course and instructor_id=auth.uid() and status='published' and revision=p_revision;
 if not found then raise exception 'Published course unavailable or stale';end if;
end $$;

create function public.course_activate_enrolment(p_request uuid,p_payment_intent uuid,p_key uuid,p_expires_at timestamptz default null) returns uuid language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();request public.marketplace_work_requests;course public.course_programs;prior public.course_access_grants;source jsonb;expiry timestamptz;saved uuid;
begin
 if caller is null or p_key is null or not public.marketplace_complete_member() or not public.moderation_actor_allowed(caller) or not coalesce((select enrolment_enabled from public.course_runtime_settings where singleton),false) then raise exception 'Course enrolment disabled or instructor ineligible';end if;
 perform pg_advisory_xact_lock(hashtextextended('course-enrolment:'||p_request::text,0));
 select * into prior from public.course_access_grants where work_request_id=p_request for update;
 if prior.id is not null then if prior.instructor_id<>caller or prior.idempotency_key<>p_key or prior.payment_intent_id is distinct from p_payment_intent then raise exception 'Enrolment identity conflict';end if;return prior.id;end if;
 select * into request from public.marketplace_work_requests where id=p_request and kind='learning' and provider_id=caller for update;
 select * into course from public.course_programs where source_entry_id=request.target_id and instructor_id=caller for update;
 if request.id is null or request.state<>'enrolled' or course.id is null or course.status<>'published' or not public.moderation_actor_allowed(request.requester_id) or not public.moderation_target_allowed('community',course.source_entry_id,caller) then raise exception 'Eligible enrolled learner and published course required';end if;
 perform id from public.community_entries where id=course.source_entry_id for share;
 source:=public.course_source_snapshot(course.source_entry_id);
 if source is null or not coalesce((source->>'published')::boolean,false) or (source->>'price_minor')::bigint is distinct from course.published_price_minor or source->>'currency'<>'ZMW' then raise exception 'Republish course after source terms change';end if;
 if course.published_price_minor=0 then if p_payment_intent is not null then raise exception 'Free course does not accept a payment proof';end if;
 elsif p_payment_intent is null or not public.payment_covers(p_payment_intent,'work',p_request,request.requester_id,course.published_price_minor) then raise exception 'Verified settled course payment required';end if;
 expiry:=coalesce(p_expires_at,now()+make_interval(days=>course.access_days));
 if expiry<now()+interval '1 day' or expiry>now()+interval '1 year' then raise exception 'Access expiry must be within one year';end if;
 insert into public.course_access_grants(course_id,work_request_id,learner_id,instructor_id,payment_intent_id,price_snapshot_minor,idempotency_key,expires_at)
 values(course.id,p_request,request.requester_id,caller,p_payment_intent,course.published_price_minor,p_key,expiry) returning id into saved;return saved;
end $$;

create function public.course_access_eligible(p_grant uuid,p_learner uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.course_access_grants g join public.course_programs c on c.id=g.course_id join public.community_entries e on e.id=c.source_entry_id
  where g.id=p_grant and g.learner_id=p_learner and g.state='active' and g.begins_at<=now() and g.expires_at>now()
  and c.status='published' and e.status='published' and e.kind='learning'
  and public.course_verified_member(p_learner) and public.moderation_actor_allowed(p_learner)
  and public.moderation_target_allowed('community',e.id,c.instructor_id)
  and (g.price_snapshot_minor=0 or public.payment_covers(g.payment_intent_id,'work',g.work_request_id,p_learner,g.price_snapshot_minor)))
$$;

drop policy course_material_metadata_read on public.course_materials;
create policy course_material_metadata_read on public.course_materials for select to authenticated using(
 instructor_id=(select auth.uid()) or public.course_owner_or_student(course_id,(select auth.uid()))
);

create function public.course_my_library() returns table(grant_id uuid,course_id uuid,title text,expires_at timestamptz,completed_lessons bigint,total_lessons bigint) language sql stable security definer set search_path='' as $$
 select g.id,c.id,c.title_snapshot,g.expires_at,
  (select count(*) from public.course_lesson_progress p where p.grant_id=g.id and p.state='completed'),
  (select count(*) from public.course_lessons l where l.course_id=c.id)
 from public.course_access_grants g join public.course_programs c on c.id=g.course_id
 where g.learner_id=auth.uid() and public.course_access_eligible(g.id,auth.uid()) order by g.created_at desc limit 100
$$;

create function public.course_save_progress(p_grant uuid,p_lesson uuid,p_state text,p_position_seconds integer) returns void language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();item public.course_access_grants;
begin
 if caller is null or p_state not in('not_started','in_progress','completed') or p_position_seconds not between 0 and 86400 or not public.course_access_eligible(p_grant,caller) then raise exception 'Active course access required';end if;
 select * into item from public.course_access_grants where id=p_grant and learner_id=caller for share;
 if item.id is null or not exists(select 1 from public.course_lessons where id=p_lesson and course_id=item.course_id) then raise exception 'Course lesson unavailable';end if;
 insert into public.course_lesson_progress(grant_id,lesson_id,learner_id,state,position_seconds,completed_at,updated_at)
 values(p_grant,p_lesson,caller,p_state,p_position_seconds,case when p_state='completed' then now() end,now())
 on conflict(grant_id,lesson_id) do update set state=excluded.state,position_seconds=excluded.position_seconds,completed_at=excluded.completed_at,updated_at=now()
 where public.course_lesson_progress.learner_id=caller;
end $$;

create function public.course_authorize_delivery(p_material uuid,p_learner uuid) returns text language plpgsql security definer set search_path='' as $$
declare material public.course_materials;grant_item public.course_access_grants;
begin
 if auth.role() is distinct from 'service_role' or not coalesce((select delivery_enabled from public.course_runtime_settings where singleton),false) then raise exception 'Trusted course delivery is disabled';end if;
 select * into material from public.course_materials where id=p_material and scan_status='approved' for share;
 select * into grant_item from public.course_access_grants where course_id=material.course_id and learner_id=p_learner and public.course_access_eligible(id,p_learner) order by expires_at desc limit 1 for share;
 if material.id is null or grant_item.id is null then raise exception 'Course material access denied';end if;
 perform pg_advisory_xact_lock(hashtextextended('course-delivery:'||p_learner::text,0));
 if (select count(*) from public.course_delivery_audit where learner_id=p_learner and created_at>now()-interval '1 hour')>=60 then raise exception 'Course delivery limit reached';end if;
 insert into public.course_delivery_audit(learner_id,grant_id,material_id) values(p_learner,grant_item.id,p_material);return material.path;
end $$;

create function public.course_owner_materials(p_course uuid) returns table(id uuid,lesson_id uuid,path text,title text,mime_type text,byte_size bigint,scan_status text) language sql stable security definer set search_path='' as $$
 select m.id,m.lesson_id,m.path,m.title,m.mime_type,m.byte_size,m.scan_status from public.course_materials m join public.course_programs c on c.id=m.course_id
 where c.id=p_course and c.instructor_id=auth.uid() order by m.created_at
$$;

create function public.course_request_state_guard() returns trigger language plpgsql security definer set search_path='' as $$
declare grant_item public.course_access_grants;
begin
 if old.kind='learning' and new.state is distinct from old.state and new.state in('withdrawn','cancelled','rejected','closed') then
  select * into grant_item from public.course_access_grants where work_request_id=old.id and state='active' for update;
  if grant_item.id is not null then
   if grant_item.price_snapshot_minor>0 and public.payment_covers(grant_item.payment_intent_id,'work',old.id,old.requester_id,grant_item.price_snapshot_minor) then raise exception 'Refund the paid course before cancelling access';end if;
   update public.course_access_grants set state='revoked',revoked_at=now() where id=grant_item.id;
  end if;
 end if;return new;
end $$;
create trigger a1_course_request_state before update of state on public.marketplace_work_requests for each row execute function public.course_request_state_guard();

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('course-materials','course-materials',false,52428800,array['application/pdf','video/mp4','video/webm']);
create function public.course_material_upload_allowed(p_path text) returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and p_path not like '%..%' and exists(
  select 1 from public.course_programs c where c.id=(storage.foldername(p_path))[2]::uuid
  and c.instructor_id=auth.uid() and c.status='draft' and (storage.foldername(p_path))[1]=auth.uid()::text)
$$;
create policy course_material_owner_read on storage.objects for select to authenticated using(bucket_id='course-materials' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy course_material_read_guard on storage.objects as restrictive for select to authenticated using(bucket_id<>'course-materials' or (storage.foldername(name))[1]=(select auth.uid())::text);
create policy course_material_no_anon on storage.objects as restrictive for select to anon using(bucket_id<>'course-materials');
create policy course_material_upload on storage.objects for insert to authenticated with check(bucket_id='course-materials' and public.course_material_upload_allowed(name));
create policy course_material_upload_guard on storage.objects as restrictive for insert to authenticated with check(bucket_id<>'course-materials' or public.course_material_upload_allowed(name));
create policy course_material_no_overwrite on storage.objects as restrictive for update to authenticated using(bucket_id<>'course-materials') with check(bucket_id<>'course-materials');
create policy course_material_no_delete on storage.objects as restrictive for delete to authenticated using(bucket_id<>'course-materials');

create function public.completion_capabilities() returns jsonb language plpgsql stable security definer set search_path='' as $$
declare payments boolean:=false;stock boolean:=false;appointments boolean:=false;moderation boolean:=false;tickets boolean:=false;ticket_validation boolean:=false;expiry boolean:=false;publishing boolean:=false;delivery boolean:=false;
begin
 if auth.uid() is null then raise exception 'Authentication required';end if;
 if to_regclass('public.payment_runtime_settings') is not null then execute 'select coalesce(sandbox_enabled,false) from public.payment_runtime_settings where singleton' into payments;end if;
 if to_regclass('public.marketplace_allocation_settings') is not null then execute 'select coalesce(stock_enabled,false),coalesce(appointments_enabled,false) from public.marketplace_allocation_settings where singleton' into stock,appointments;end if;
 if to_regclass('public.marketplace_moderation_settings') is not null then execute 'select coalesce(enforcement_enabled,false) from public.marketplace_moderation_settings where singleton' into moderation;end if;
 if to_regclass('public.event_ticket_security_settings') is not null then execute 'select coalesce(issuance_enabled,false),coalesce(validation_enabled,false),coalesce(expiry_processing_enabled,false) from public.event_ticket_security_settings where singleton' into tickets,ticket_validation,expiry;end if;
 select publishing_enabled,delivery_enabled into publishing,delivery from public.course_runtime_settings where singleton;
 return jsonb_build_object('version',1,'payments',coalesce(payments,false),'stock',coalesce(stock,false),'appointments',coalesce(appointments,false),'moderation',coalesce(moderation,false),'ticket_issuance',coalesce(tickets,false),'ticket_validation',coalesce(ticket_validation,false),'ticket_expiry',coalesce(expiry,false),'course_publishing',coalesce(publishing,false),'course_delivery',coalesce(delivery,false));
end $$;

revoke all on function public.course_source_snapshot(uuid),public.course_owner_or_student(uuid,uuid),public.course_publicly_visible(uuid),public.course_verified_member(uuid),public.course_save_program(uuid,uuid,bigint,text,integer),public.course_save_module(uuid,uuid,integer,text),public.course_save_lesson(uuid,uuid,uuid,integer,text,text,boolean),public.course_register_material(uuid,uuid,text,text,integer),public.course_material_scan_review(uuid,text,bigint,text),public.course_publish(uuid,bigint),public.course_unpublish(uuid,bigint),public.course_activate_enrolment(uuid,uuid,uuid,timestamptz),public.course_access_eligible(uuid,uuid),public.course_my_library(),public.course_save_progress(uuid,uuid,text,integer),public.course_authorize_delivery(uuid,uuid),public.course_owner_materials(uuid),public.course_request_state_guard(),public.course_material_upload_allowed(text),public.completion_capabilities() from public,anon,authenticated,service_role;
grant execute on function public.course_save_program(uuid,uuid,bigint,text,integer),public.course_save_module(uuid,uuid,integer,text),public.course_save_lesson(uuid,uuid,uuid,integer,text,text,boolean),public.course_register_material(uuid,uuid,text,text,integer),public.course_publish(uuid,bigint),public.course_unpublish(uuid,bigint),public.course_activate_enrolment(uuid,uuid,uuid,timestamptz),public.course_my_library(),public.course_save_progress(uuid,uuid,text,integer),public.course_owner_materials(uuid),public.completion_capabilities() to authenticated;
grant execute on function public.course_material_scan_review(uuid,text,bigint,text),public.course_authorize_delivery(uuid,uuid) to service_role;
grant execute on function public.course_publicly_visible(uuid),public.course_owner_or_student(uuid,uuid),public.course_material_upload_allowed(text) to anon,authenticated;

commit;
