-- HOLD DRAFT 038. DO NOT APPLY TO PRODUCTION.
-- Requires 009,010,013_v2,014_v2,015,017,018,020,022-025,029,032 and 037.
-- Server-enforced public suppression. The enforcement gate is inserted FALSE.
-- No account/content row is changed, no administrator is provisioned and no decision is backfilled.
begin;
set local lock_timeout='5s';
set local statement_timeout='90s';

create table public.marketplace_moderation_settings(
 singleton boolean primary key default true check(singleton),
 enforcement_enabled boolean not null default false
);
insert into public.marketplace_moderation_settings values(true,false);
alter table public.marketplace_moderation_settings enable row level security;
revoke all on public.marketplace_moderation_settings from public,anon,authenticated,service_role;
grant select,update(enforcement_enabled) on public.marketplace_moderation_settings to service_role;

create table public.marketplace_moderation_restrictions(
 id uuid primary key default gen_random_uuid(),
 subject_kind text not null check(subject_kind in(
  'user','listing','business','event','job','learning','community','property',
  'specialist','business_service','shop','restaurant')),
 subject_id uuid not null,
 subject_owner_id uuid not null references auth.users(id),
 report_id uuid not null references public.marketplace_review_cases(report_id),
 imposed_by uuid not null references auth.users(id),
 starts_at timestamptz not null default now(),
 ends_at timestamptz,
 revoked_at timestamptz,
 revoked_by uuid references auth.users(id),
 created_at timestamptz not null default now(),
 check(ends_at is null or ends_at>starts_at),
 check((revoked_at is null)=(revoked_by is null))
);
create unique index moderation_one_open_restriction
 on public.marketplace_moderation_restrictions(subject_kind,subject_id)
 where revoked_at is null;
create index moderation_owner_restrictions
 on public.marketplace_moderation_restrictions(subject_owner_id,created_at desc);

create table public.marketplace_moderation_decisions(
 id uuid primary key default gen_random_uuid(),
 restriction_id uuid not null references public.marketplace_moderation_restrictions(id),
 report_id uuid not null references public.marketplace_review_cases(report_id),
 case_revision bigint not null check(case_revision>0),
 actor_id uuid not null references auth.users(id),
 subject_kind text not null,
 subject_id uuid not null,
 decision text not null check(decision in('enforce','restore')),
 note text not null check(length(btrim(note)) between 10 and 2000),
 created_at timestamptz not null default now(),
 unique(report_id,case_revision)
);

alter table public.marketplace_moderation_restrictions enable row level security;
alter table public.marketplace_moderation_decisions enable row level security;
revoke all on public.marketplace_moderation_restrictions,public.marketplace_moderation_decisions
 from public,anon,authenticated,service_role;
grant select on public.marketplace_moderation_restrictions,public.marketplace_moderation_decisions to authenticated;
grant select,insert,update(revoked_at,revoked_by) on public.marketplace_moderation_restrictions to service_role;
grant select,insert on public.marketplace_moderation_decisions to service_role;
create policy moderation_subject_read on public.marketplace_moderation_restrictions
 for select to authenticated using(subject_owner_id=(select auth.uid()) or public.admin_operations_allowed());
create policy moderation_decision_admin_read on public.marketplace_moderation_decisions
 for select to authenticated using(public.admin_operations_allowed());

create function public.moderation_enforcement_enabled() returns boolean
 language sql stable security definer set search_path='' as $$
 select coalesce((select enforcement_enabled from public.marketplace_moderation_settings where singleton),false)
$$;

create function public.moderation_actor_allowed(p_actor uuid) returns boolean
 language sql stable security definer set search_path='' as $$
 select not public.moderation_enforcement_enabled() or (
  p_actor is not null and not exists(
   select 1 from public.marketplace_moderation_restrictions r
   where r.subject_kind='user' and r.subject_id=p_actor and r.revoked_at is null
     and (r.ends_at is null or r.ends_at>now())
  )
 )
$$;

-- This is the stable contract used by ticket/course/payment fulfilment code.
-- It deliberately has no owner bypass. Owner visibility uses the separate helper below.
create function public.moderation_target_allowed(p_kind text,p_target uuid,p_owner uuid) returns boolean
 language sql stable security definer set search_path='' as $$
 select not public.moderation_enforcement_enabled() or (
  p_kind is not null and p_target is not null and p_owner is not null
  and public.moderation_actor_allowed(p_owner)
  and not exists(
   select 1 from public.marketplace_moderation_restrictions r
   where r.subject_kind=p_kind and r.subject_id=p_target and r.revoked_at is null
     and (r.ends_at is null or r.ends_at>now())
  )
 )
$$;

create function public.moderation_target_visible(p_kind text,p_target uuid,p_owner uuid) returns boolean
 language sql stable security definer set search_path='' as $$
 select auth.uid()=p_owner or public.moderation_target_allowed(p_kind,p_target,p_owner)
$$;

revoke all on function public.moderation_enforcement_enabled(),public.moderation_actor_allowed(uuid),
 public.moderation_target_allowed(text,uuid,uuid),public.moderation_target_visible(text,uuid,uuid)
 from public,anon,authenticated,service_role;
grant execute on function public.moderation_target_visible(text,uuid,uuid) to anon,authenticated;

create function public.moderation_resolve_owner(p_kind text,p_target uuid) returns uuid
 language plpgsql stable security definer set search_path='' as $$
declare result uuid;
begin
 case p_kind
  when 'user' then select id into result from auth.users where id=p_target;
  when 'listing' then select user_id into result from public.listings where id=p_target;
  when 'business' then select owner_id into result from public.business_organisations where id=p_target;
  when 'event' then select owner_id into result from public.community_entries where id=p_target and kind='event';
  when 'job' then select owner_id into result from public.community_entries where id=p_target and kind='job';
  when 'learning' then select owner_id into result from public.community_entries where id=p_target and kind='learning';
  when 'community' then select owner_id into result from public.community_entries where id=p_target;
  when 'property' then select owner_id into result from public.property_listings where id=p_target;
  when 'specialist' then select owner_id into result from public.specialist_listings where id=p_target;
  when 'business_service' then select owner_id into result from public.business_service_entries where id=p_target;
  when 'shop' then select owner_id into result from public.seller_shops where id=p_target;
  when 'restaurant' then select owner_id into result from public.food_restaurants where id=p_target;
  else raise exception 'Unsupported moderation subject';
 end case;
 return result;
end $$;

create function public.admin_moderation_decide(
 p_report uuid,p_revision bigint,p_kind text,p_target uuid,p_enforce boolean,
 p_note text,p_ends_at timestamptz default null
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
 report public.marketplace_safety_requests;
 review public.marketplace_review_cases;
 owner_id uuid;
 restriction public.marketplace_moderation_restrictions;
 next_revision bigint;
 expected_report_kind text;
begin
 if not public.admin_operations_allowed() then
  raise exception 'Approved MFA administrator required' using errcode='42501';
 end if;
 if p_note is null or length(btrim(p_note)) not between 10 and 2000 then raise exception 'Audit note required';end if;
 if p_target is null or p_revision is null then raise exception 'Subject and case revision required';end if;
 if p_ends_at is not null and (p_ends_at<=now() or p_ends_at>now()+interval '365 days') then raise exception 'Restriction end must be within one year';end if;
 owner_id:=public.moderation_resolve_owner(p_kind,p_target);
 if owner_id is null then raise exception 'Moderation subject unavailable';end if;
 if owner_id=auth.uid() then raise exception 'Independent review required';end if;
 expected_report_kind:=case when p_kind='user' then 'user' when p_kind='business' then 'business_verification' else 'listing' end;

 select * into report from public.marketplace_safety_requests where id=p_report for update;
 select * into review from public.marketplace_review_cases where report_id=p_report for update;
 if report.id is null or review.report_id is null or review.state<>'in_review'
   or review.revision is distinct from p_revision then raise exception 'Active matching review required';end if;
 if report.kind<>expected_report_kind or lower(btrim(report.target_reference))<>p_target::text then
  raise exception 'Report target does not match moderation subject';
 end if;

 -- Expired rows cease enforcement immediately, but are explicitly closed before a new row is opened.
 update public.marketplace_moderation_restrictions
 set revoked_at=now(),revoked_by=auth.uid()
 where subject_kind=p_kind and subject_id=p_target and revoked_at is null
   and ends_at is not null and ends_at<=now();
 select * into restriction from public.marketplace_moderation_restrictions
 where subject_kind=p_kind and subject_id=p_target and revoked_at is null for update;

 if p_enforce then
  if restriction.id is not null then raise exception 'Subject already has an open restriction';end if;
  insert into public.marketplace_moderation_restrictions(
   subject_kind,subject_id,subject_owner_id,report_id,imposed_by,ends_at)
  values(p_kind,p_target,owner_id,p_report,auth.uid(),p_ends_at) returning * into restriction;
 else
  if restriction.id is null then raise exception 'No open restriction to restore';end if;
  update public.marketplace_moderation_restrictions
   set revoked_at=now(),revoked_by=auth.uid() where id=restriction.id returning * into restriction;
 end if;

 next_revision:=review.revision+1;
 update public.marketplace_review_cases set revision=next_revision,updated_at=now() where report_id=p_report;
 insert into public.marketplace_review_events(report_id,revision,actor_id,action,note)
 values(p_report,next_revision,auth.uid(),case when p_enforce then 'enforce_' else 'restore_' end||p_kind,btrim(p_note));
 insert into public.marketplace_moderation_decisions(
  restriction_id,report_id,case_revision,actor_id,subject_kind,subject_id,decision,note)
 values(restriction.id,p_report,next_revision,auth.uid(),p_kind,p_target,
  case when p_enforce then 'enforce' else 'restore' end,btrim(p_note));
 return jsonb_build_object('subject_kind',p_kind,'subject_id',p_target,
  'restricted',p_enforce,'case_revision',next_revision,'enforcement_enabled',public.moderation_enforcement_enabled());
end $$;

revoke all on function public.moderation_resolve_owner(text,uuid),
 public.admin_moderation_decide(uuid,bigint,text,uuid,boolean,text,timestamptz)
 from public,anon,authenticated,service_role;
grant execute on function public.admin_moderation_decide(uuid,bigint,text,uuid,boolean,text,timestamptz) to authenticated;

-- A suspended actor cannot create/change public content through direct writes or SECURITY DEFINER RPCs.
-- Financial records, refunds and cancellation ledgers are intentionally not covered by this trigger.
create function public.moderation_actor_write_guard() returns trigger
 language plpgsql security definer set search_path='' as $$
begin
 if coalesce(auth.role(),'')<>'service_role' and auth.uid() is not null
   and not public.moderation_actor_allowed(auth.uid()) then
  raise exception 'Account actions are restricted' using errcode='42501';
 end if;
 return new;
end $$;

create function public.moderation_content_write_guard() returns trigger
 language plpgsql security definer set search_path='' as $$
declare row_data jsonb:=to_jsonb(new);owner_id uuid;target_id uuid;target_kind text;parent_id uuid;
begin
 if coalesce(auth.role(),'')='service_role' or auth.uid() is null then return new;end if;
 if not public.moderation_actor_allowed(auth.uid()) then raise exception 'Account actions are restricted' using errcode='42501';end if;
 owner_id:=nullif(row_data->>tg_argv[0],'')::uuid;
 target_kind:=case when left(tg_argv[1],1)='@' then row_data->>substring(tg_argv[1] from 2) else tg_argv[1] end;
 target_id:=nullif(row_data->>tg_argv[2],'')::uuid;
 if not public.moderation_target_allowed(target_kind,target_id,owner_id) then
  raise exception 'Content is restricted' using errcode='42501';
 end if;
 if tg_nargs=5 then
  parent_id:=nullif(row_data->>tg_argv[4],'')::uuid;
  if not public.moderation_target_allowed(tg_argv[3],parent_id,owner_id) then
   raise exception 'Parent business is restricted' using errcode='42501';
  end if;
 end if;
 return new;
end $$;
revoke all on function public.moderation_actor_write_guard(),public.moderation_content_write_guard()
 from public,anon,authenticated,service_role;

create trigger z0_moderation_listing_write before insert or update on public.listings
 for each row execute function public.moderation_content_write_guard('user_id','listing','id');
create trigger z0_moderation_community_write before insert or update on public.community_entries
 for each row execute function public.moderation_content_write_guard('owner_id','@kind','id');
create trigger z0_moderation_shop_write before insert or update on public.seller_shops
 for each row execute function public.moderation_content_write_guard('owner_id','shop','id');
create trigger z0_moderation_property_write before insert or update on public.property_listings
 for each row execute function public.moderation_content_write_guard('owner_id','property','id');
create trigger z0_moderation_specialist_write before insert or update on public.specialist_listings
 for each row execute function public.moderation_content_write_guard('owner_id','specialist','id');
create trigger z0_moderation_business_write before insert or update on public.business_organisations
 for each row execute function public.moderation_content_write_guard('owner_id','business','id');
create trigger z0_moderation_business_service_write before insert or update on public.business_service_entries
 for each row execute function public.moderation_content_write_guard('owner_id','business_service','id','business','organisation_id');
create trigger z0_moderation_restaurant_write before insert or update on public.food_restaurants
 for each row execute function public.moderation_content_write_guard('owner_id','restaurant','id');

create trigger z0_moderation_message_actor before insert or update on public.messages
 for each row execute function public.moderation_actor_write_guard();
create trigger z0_moderation_module_enquiry_actor before insert or update on public.module_enquiries
 for each row execute function public.moderation_actor_write_guard();
create trigger z0_moderation_property_enquiry_actor before insert or update on public.property_enquiries
 for each row execute function public.moderation_actor_write_guard();
create trigger z0_moderation_business_draft_actor before insert or update on public.business_service_enquiry_drafts
 for each row execute function public.moderation_actor_write_guard();
create trigger z0_moderation_work_message_actor before insert or update on public.marketplace_work_messages
 for each row execute function public.moderation_actor_write_guard();
create trigger z0_moderation_like_actor before insert on public.likes
 for each row execute function public.moderation_actor_write_guard();
create trigger z0_moderation_review_actor before insert on public.seller_reviews
 for each row execute function public.moderation_actor_write_guard();

-- Definer RPCs bypass table RLS, so new public-facing participant records also receive
-- target-aware trigger checks. Existing lifecycle/refund rows remain mutable for safe wind-down.
create function public.moderation_conversation_guard() returns trigger
 language plpgsql security definer set search_path='' as $$
declare item public.listings;
begin
 if coalesce(auth.role(),'')='service_role' or auth.uid() is null then return new;end if;
 if not public.moderation_actor_allowed(auth.uid()) then raise exception 'Account actions are restricted' using errcode='42501';end if;
 if new.listing_id !~ '^[0-9a-fA-F-]{36}$' then raise exception 'Listing unavailable';end if;
 select * into item from public.listings where id=new.listing_id::uuid;
 if item.id is null or not public.moderation_target_allowed('listing',item.id,item.user_id) then
  raise exception 'Listing unavailable' using errcode='42501';
 end if;
 return new;
end $$;
create function public.moderation_module_enquiry_target_guard() returns trigger
 language plpgsql security definer set search_path='' as $$
declare item public.community_entries;
begin
 select * into item from public.community_entries where id=new.entry_id;
 if item.id is null or not public.moderation_target_allowed(item.kind,item.id,item.owner_id) then
  raise exception 'Entry unavailable' using errcode='42501';
 end if;return new;
end $$;
create function public.moderation_property_enquiry_target_guard() returns trigger
 language plpgsql security definer set search_path='' as $$
declare item public.property_listings;
begin
 select * into item from public.property_listings where id=new.property_id;
 if item.id is null or not public.moderation_target_allowed('property',item.id,item.owner_id) then
  raise exception 'Property unavailable' using errcode='42501';
 end if;return new;
end $$;
create function public.moderation_food_order_target_guard() returns trigger
 language plpgsql security definer set search_path='' as $$
declare item public.food_restaurants;
begin
 if not public.moderation_actor_allowed(new.customer_id) then raise exception 'Account actions are restricted' using errcode='42501';end if;
 select * into item from public.food_restaurants where id=new.restaurant_id;
 if item.id is null or item.owner_id<>new.merchant_id
   or not public.moderation_target_allowed('restaurant',item.id,item.owner_id) then
  raise exception 'Restaurant unavailable' using errcode='42501';
 end if;return new;
end $$;
create function public.moderation_work_request_target_guard() returns trigger
 language plpgsql security definer set search_path='' as $$
declare target_kind text;
begin
 if not public.moderation_actor_allowed(new.requester_id) then raise exception 'Account actions are restricted' using errcode='42501';end if;
 target_kind:=case when new.kind in('agriculture','digital') then 'specialist'
  when new.kind='logistics' then 'business_service' else new.kind end;
 if not public.moderation_target_allowed(target_kind,new.target_id,new.provider_id) then
  raise exception 'Request target unavailable' using errcode='42501';
 end if;return new;
end $$;
revoke all on function public.moderation_conversation_guard(),
 public.moderation_module_enquiry_target_guard(),public.moderation_property_enquiry_target_guard(),
 public.moderation_food_order_target_guard(),public.moderation_work_request_target_guard()
 from public,anon,authenticated,service_role;
create trigger z0_moderation_conversation_target before insert or update on public.conversations
 for each row execute function public.moderation_conversation_guard();
create trigger z1_moderation_module_enquiry_target before insert or update on public.module_enquiries
 for each row execute function public.moderation_module_enquiry_target_guard();
create trigger z1_moderation_property_enquiry_target before insert or update on public.property_enquiries
 for each row execute function public.moderation_property_enquiry_target_guard();
create trigger z0_moderation_food_order_target before insert on public.food_orders
 for each row execute function public.moderation_food_order_target_guard();
create trigger z0_moderation_work_request_target before insert on public.marketplace_work_requests
 for each row execute function public.moderation_work_request_target_guard();

-- Restrictive policies keep owners able to inspect an affected record while removing it from public discovery.
create policy moderation_listing_visibility on public.listings as restrictive for select to anon,authenticated
 using(public.moderation_target_visible('listing',id,user_id));
create policy moderation_community_visibility on public.community_entries as restrictive for select to anon,authenticated
 using(public.moderation_target_visible(kind,id,owner_id));
create policy moderation_shop_visibility on public.seller_shops as restrictive for select to anon,authenticated
 using(public.moderation_target_visible('shop',id,owner_id));
create policy moderation_property_visibility on public.property_listings as restrictive for select to anon,authenticated
 using(public.moderation_target_visible('property',id,owner_id));
create policy moderation_specialist_visibility on public.specialist_listings as restrictive for select to anon,authenticated
 using(public.moderation_target_visible('specialist',id,owner_id));
create policy moderation_restaurant_visibility on public.food_restaurants as restrictive for select to anon,authenticated
 using(public.moderation_target_visible('restaurant',id,owner_id));
create policy moderation_menu_visibility on public.food_menu_items as restrictive for select to anon,authenticated
 using(exists(select 1 from public.food_restaurants r where r.id=restaurant_id
  and public.moderation_target_visible('restaurant',r.id,r.owner_id)));
create policy moderation_ticket_category_visibility on public.event_ticket_categories as restrictive for select to anon,authenticated
 using(exists(select 1 from public.community_entries e where e.id=event_id
  and public.moderation_target_visible('event',e.id,e.owner_id)));

-- Preserve existing view/function shapes, adding only server-side suppression predicates.
create or replace view public.marketplace_stock as
 select s.listing_id,
  greatest(0,s.quantity-coalesce((select sum(a.quantity)::integer from public.shop_stock_allocations a
   where a.listing_id=s.listing_id and(a.state='committed' or(a.state='held' and a.expires_at>now()))),0))::integer quantity,
  (select coalesce(jsonb_agg(jsonb_build_object('label',v->>'label','quantity',
   greatest(0,(v->>'quantity')::integer-public.shop_allocation_used(s.listing_id,v->>'label')),'price',v->'price')),'[]'::jsonb)
   from jsonb_array_elements(s.variants) v) variants
 from public.listing_stock s join public.listings l on l.id=s.listing_id
 where l.deleted_at is null and public.moderation_target_allowed('listing',l.id,l.user_id);

create or replace view public.public_seller_reviews as
 select r.id,r.seller_id,r.author_display,r.rating,r.body,r.created_at,true as purchase_verified
 from public.seller_reviews r join public.marketplace_trade_receipts t on t.id=r.receipt_id
 where t.state='completed' and t.buyer_id=r.author_id and t.seller_id=r.seller_id
  and public.moderation_actor_allowed(r.seller_id) and public.moderation_actor_allowed(r.author_id);

create or replace view public.public_business_profiles as
 select id,owner_id,kind,name,description,logo_path,
  case when show_location then location end location,case when show_phone then phone end phone,
  case when show_whatsapp then whatsapp end whatsapp,case when show_public_email then public_email end public_email
 from public.business_organisations
 where status='published' and public.business_publication_enabled()
  and public.moderation_target_allowed('business',id,owner_id);

create or replace view public.public_business_branches as
 select b.id,b.organisation_id,b.name,b.location
 from public.business_branches b join public.business_organisations o on o.id=b.organisation_id
 where b.status='published' and o.status='published' and public.business_publication_enabled()
  and public.moderation_target_allowed('business',o.id,o.owner_id);

create or replace function public.business_service_visible(p_entry uuid) returns boolean
 language sql stable security definer set search_path='' as $$
 select public.business_service_publication_enabled() and public.business_publication_enabled()
  and exists(select 1 from public.business_service_entries e
   join public.business_organisations o on o.id=e.organisation_id
   where e.id=p_entry and e.status='published' and o.status='published'
    and public.moderation_target_allowed('business',o.id,o.owner_id)
    and public.moderation_target_allowed('business_service',e.id,e.owner_id))
$$;

create or replace view public.public_business_services as
 select e.id,e.organisation_id,e.owner_id,e.kind,e.name,e.category,e.location,e.description,
  e.features,e.service_areas,e.media_paths,e.created_at,o.name provider_name
 from public.business_service_entries e join public.business_organisations o on o.id=e.organisation_id
 where public.business_service_visible(e.id);
create or replace view public.public_stay_rooms as
 select r.id,r.entry_id,r.name,r.guest_capacity,r.nightly_minor,r.currency
 from public.stay_room_options r where r.listed and public.business_service_visible(r.entry_id);

create or replace function public.public_seller_profile(p_user_id uuid) returns jsonb
 language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',id,'username',username,'shop_name',shop_name,'account_type',account_type,
  'avatar_path',avatar_path,'whatsapp',case when show_whatsapp then nullif(whatsapp,'') end,
  'phone',case when show_phone then nullif(phone,'') end,
  'public_email',case when show_public_email then nullif(public_email,'') end,
  'location',case when show_location then nullif(location,'') end,
  'address',case when show_address then nullif(address,'') end)
 from public.marketplace_profiles where id=p_user_id and public.marketplace_complete_member()
  and public.moderation_target_allowed('user',p_user_id,p_user_id)
$$;

create or replace function public.stage3_media_visible(p_path text) returns boolean
 language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.community_entries e where p_path=any(e.media_paths) and e.status='published'
  and public.moderation_target_allowed(e.kind,e.id,e.owner_id))
 or exists(select 1 from public.seller_shops s where p_path=any(s.media_paths) and s.status='published'
  and public.moderation_target_allowed('shop',s.id,s.owner_id))
$$;
create or replace function public.property_image_visible(p_path text) returns boolean
 language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.property_listings p where p.status='published' and p_path=any(p.media_paths)
  and public.moderation_target_allowed('property',p.id,p.owner_id))
$$;
create or replace function public.specialist_media_visible(p_path text) returns boolean
 language sql stable security definer set search_path='' as $$
 select public.specialist_publication_enabled() and exists(select 1 from public.specialist_listings s
  where s.status='published' and p_path=any(s.media_paths)
   and public.moderation_target_allowed('specialist',s.id,s.owner_id))
$$;
create or replace function public.business_logo_visible(p_path text) returns boolean
 language sql stable security definer set search_path='' as $$
 select public.business_publication_enabled() and exists(select 1 from public.business_organisations o
  where o.status='published' and o.logo_path=p_path
   and public.moderation_target_allowed('business',o.id,o.owner_id))
$$;
create or replace function public.business_service_image_visible(p_path text) returns boolean
 language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.business_service_entries e
  where p_path=any(e.media_paths) and public.business_service_visible(e.id))
$$;

-- Reassert original grants after CREATE OR REPLACE.
revoke all on public.marketplace_stock,public.public_seller_reviews,public.public_business_profiles,
 public.public_business_branches,public.public_business_services,public.public_stay_rooms
 from public,anon,authenticated,service_role;
grant select on public.marketplace_stock,public.public_seller_reviews,public.public_business_profiles,
 public.public_business_branches,public.public_business_services,public.public_stay_rooms to anon,authenticated;
revoke all on function public.business_service_visible(uuid),public.public_seller_profile(uuid),
 public.stage3_media_visible(text),public.property_image_visible(text),public.specialist_media_visible(text),
 public.business_logo_visible(text),public.business_service_image_visible(text)
 from public,anon,authenticated,service_role;
grant execute on function public.business_service_visible(uuid),public.stage3_media_visible(text),
 public.property_image_visible(text),public.specialist_media_visible(text),public.business_logo_visible(text),
 public.business_service_image_visible(text) to anon,authenticated;
grant execute on function public.public_seller_profile(uuid) to authenticated;

create function public.moderation_capabilities() returns jsonb
 language sql stable security definer set search_path='' as $$
 select jsonb_build_object('version',1,'server_enforcement',public.moderation_enforcement_enabled(),
  'admin_authorized',case when auth.uid() is null then false else public.admin_operations_allowed() end)
$$;
revoke all on function public.moderation_capabilities() from public,anon,authenticated,service_role;
grant execute on function public.moderation_capabilities() to authenticated;

commit;

-- Known limitation for review: listing-images and avatars are older PUBLIC buckets. Database
-- suppression removes blocked records from queries, but cannot recall a public URL already copied elsewhere.
-- A separate, explicitly approved private-media migration is required to close that legacy gap.
