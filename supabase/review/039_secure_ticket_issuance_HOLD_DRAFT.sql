-- HOLD / REVIEW ONLY. DO NOT APPLY TO PRODUCTION.
-- Requires 013_v2, 018, 031, 032, 036 and 038, in that order.
-- Adds expiring holds and secure ticket credentials. Every new runtime switch defaults OFF.
-- No historical reservation is backfilled, no scheduler is installed and no ticket is issued here.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';

do $$
begin
  if to_regclass('public.event_reservations') is null
     or to_regclass('public.event_attendance') is null
     or to_regclass('public.payment_intents') is null
     or to_regprocedure('public.payment_covers(uuid,text,uuid,uuid,bigint)') is null
     or to_regprocedure('public.moderation_target_allowed(text,uuid,uuid)') is null
     or to_regprocedure('public.moderation_actor_allowed(uuid)') is null then
    raise exception '039 dependencies are missing; install the reviewed predecessors first';
  end if;
end $$;

create table public.event_ticket_security_settings (
  singleton boolean primary key default true check (singleton),
  issuance_enabled boolean not null default false,
  validation_enabled boolean not null default false,
  expiry_processing_enabled boolean not null default false,
  hold_minutes integer not null default 15 check (hold_minutes between 5 and 30)
);
insert into public.event_ticket_security_settings(singleton) values (true);

create table public.event_reservation_holds (
  reservation_id uuid primary key references public.event_reservations(id),
  category_id uuid not null references public.event_ticket_categories(id),
  buyer_id uuid not null references auth.users(id),
  organiser_id uuid not null references auth.users(id),
  state text not null default 'active' check (state in ('active','consumed','released','expired')),
  created_at timestamptz not null default now(),expires_at timestamptz not null,
  closed_at timestamptz,check (expires_at > created_at)
);
create index event_hold_expiry_idx on public.event_reservation_holds(expires_at)
  where state = 'active';

create table public.event_ticket_issuance_batches (
  id uuid primary key default gen_random_uuid(),
  reservation_id uuid not null unique references public.event_reservations(id),
  buyer_id uuid not null references auth.users(id),
  organiser_id uuid not null references auth.users(id),
  payment_intent_id uuid references public.payment_intents(id),
  amount_minor bigint not null check (amount_minor between 0 and 2000000000),
  idempotency_key uuid not null,issued_at timestamptz not null default now(),
  unique (buyer_id,idempotency_key)
);

create table public.event_tickets (
  id uuid primary key default gen_random_uuid(),
  reservation_id uuid not null references public.event_reservations(id),
  event_id uuid not null references public.community_entries(id),
  buyer_id uuid not null references auth.users(id),organiser_id uuid not null references auth.users(id),
  ordinal integer not null check (ordinal between 1 and 20),token_hash bytea not null unique,
  state text not null default 'issued' check (state in ('issued','used','revoked')),
  issued_at timestamptz not null default now(),used_at timestamptz,used_by uuid references auth.users(id),
  revoked_at timestamptz,rotated_at timestamptz,unique (reservation_id,ordinal)
);
create index event_tickets_event_idx on public.event_tickets(event_id,state);
create index event_tickets_buyer_idx on public.event_tickets(buyer_id,issued_at desc);

create table public.event_ticket_audit (
  id bigint generated always as identity primary key,
  ticket_id uuid not null references public.event_tickets(id),
  reservation_id uuid not null references public.event_reservations(id),
  actor_id uuid references auth.users(id),
  action text not null check (action in ('issued','rotated','used','revoked')),
  created_at timestamptz not null default now()
);
create index event_ticket_audit_reservation_idx on public.event_ticket_audit(reservation_id,created_at desc);

alter table public.event_ticket_security_settings enable row level security;
alter table public.event_reservation_holds enable row level security;
alter table public.event_ticket_issuance_batches enable row level security;
alter table public.event_tickets enable row level security;
alter table public.event_ticket_audit enable row level security;
revoke all on public.event_ticket_security_settings,public.event_reservation_holds,
  public.event_ticket_issuance_batches,public.event_tickets,public.event_ticket_audit
  from public,anon,authenticated,service_role;
grant select,update(issuance_enabled,validation_enabled,expiry_processing_enabled,hold_minutes)
  on public.event_ticket_security_settings to service_role;
grant select on public.event_reservation_holds to authenticated;
grant select(id,reservation_id,event_id,buyer_id,organiser_id,ordinal,state,issued_at,used_at,used_by,revoked_at,rotated_at)
  on public.event_tickets to authenticated;
grant select on public.event_ticket_audit to authenticated;

create policy event_hold_participants on public.event_reservation_holds for select to authenticated
  using ((select auth.uid()) in (buyer_id,organiser_id));
create policy event_ticket_participants on public.event_tickets for select to authenticated
  using ((select auth.uid()) in (buyer_id,organiser_id));
create policy event_ticket_audit_participants on public.event_ticket_audit for select to authenticated
  using (exists (select 1 from public.event_reservations r
    where r.id=reservation_id and (select auth.uid()) in (r.buyer_id,r.organiser_id)));

create function public.event_ticket_new_token() returns text
language sql volatile security definer set search_path = '' as $$
  select encode(pg_catalog.sha256(convert_to(gen_random_uuid()::text||gen_random_uuid()::text,'UTF8')),'hex');
$$;
create function public.event_hold_has_financial_claim(p_reservation uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.payment_intents p
    where p.source_kind='event' and p.source_id=p_reservation
      and p.state in ('provider_pending','authorized','settled','partially_refunded','reconciliation_required')
      and p.refunded_minor<p.amount_minor);
$$;

create function public.event_expire_category_holds(p_category uuid,p_limit integer default 25)
returns integer language plpgsql security definer set search_path = '' as $$
declare candidate record;expired_count integer:=0;
begin
  if not coalesce((select expiry_processing_enabled from public.event_ticket_security_settings where singleton),false) then return 0;end if;
  if p_limit is null or p_limit not between 1 and 100 then raise exception 'Invalid expiry limit';end if;
  perform id from public.event_ticket_categories where id=p_category for update;if not found then return 0;end if;
  for candidate in
    select h.reservation_id,r.quantity from public.event_reservation_holds h
    join public.event_reservations r on r.id=h.reservation_id
    where h.category_id=p_category and h.state='active' and h.expires_at<=now() and r.state='held'
      and not public.event_hold_has_financial_claim(h.reservation_id)
    order by h.expires_at,h.reservation_id limit p_limit for update of h,r
  loop
    update public.event_reservations set state='cancelled',cancelled_at=now(),cancelled_by=null
      where id=candidate.reservation_id and state='held';
    if found then
      update public.event_ticket_categories set allocated=allocated-candidate.quantity
        where id=p_category and allocated>=candidate.quantity;
      if not found then raise exception 'Ticket allocation invariant failed';end if;
      update public.event_reservation_holds set state='expired',closed_at=now()
        where reservation_id=candidate.reservation_id;
      expired_count:=expired_count+1;
    end if;
  end loop;return expired_count;
end $$;

-- Credentials are returned only at initial issuance or explicit buyer rotation.
-- Only their SHA-256 digests are retained in the database.
create function public.rotate_event_ticket(p_ticket uuid) returns text
language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();ticket public.event_tickets;event_row public.community_entries;token_value text;
begin
  if caller is null or not public.marketplace_complete_member()
    or not public.moderation_actor_allowed(caller)
    or not coalesce((select issuance_enabled from public.event_ticket_security_settings where singleton),false)
  then raise exception 'Secure ticket rotation is disabled or unavailable';end if;
  select * into ticket from public.event_tickets where id=p_ticket and buyer_id=caller for update;
  select * into event_row from public.community_entries where id=ticket.event_id for share;
  if ticket.id is null or ticket.state<>'issued' or event_row.id is null
    or event_row.status<>'published' or event_row.starts_at<=now()
    or not public.moderation_target_allowed('event',ticket.event_id,ticket.organiser_id)
  then raise exception 'Unused future ticket required';end if;
  token_value:=public.event_ticket_new_token();
  update public.event_tickets set token_hash=pg_catalog.sha256(convert_to(token_value,'UTF8')),
    rotated_at=now() where id=ticket.id;
  insert into public.event_ticket_audit(ticket_id,reservation_id,actor_id,action)
    values(ticket.id,ticket.reservation_id,caller,'rotated');
  return ticket.id::text||'.'||token_value;
end $$;

create function public.validate_event_ticket(p_event uuid,p_credential text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();ticket_id_value uuid;token_value text;ticket public.event_tickets;
  event_row public.community_entries;reservation public.event_reservations;present integer;current_revision bigint;
begin
  if caller is null or not public.marketplace_complete_member()
    or not public.moderation_actor_allowed(caller)
    or not coalesce((select validation_enabled from public.event_ticket_security_settings where singleton),false)
    or p_credential is null
    or p_credential !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}\.[0-9a-fA-F]{64}$'
  then raise exception 'Ticket validation is disabled or invalid';end if;
  ticket_id_value:=split_part(p_credential,'.',1)::uuid;token_value:=split_part(p_credential,'.',2);
  select * into ticket from public.event_tickets where id=ticket_id_value for update;
  select * into reservation from public.event_reservations where id=ticket.reservation_id for update;
  select * into event_row from public.community_entries where id=p_event and owner_id=caller and kind='event' for share;
  if ticket.id is null or reservation.id is null or event_row.id is null or ticket.event_id<>p_event
    or ticket.organiser_id<>caller or ticket.state<>'issued'
    or ticket.token_hash<>pg_catalog.sha256(convert_to(token_value,'UTF8'))
    or event_row.status<>'published'
    or now()<event_row.starts_at-interval '12 hours'
    or now()>coalesce(event_row.ends_at,event_row.starts_at+interval '1 day')
    or not public.moderation_target_allowed('event',event_row.id,caller)
    or (reservation.unit_price_minor>0 and not exists(
      select 1 from public.event_ticket_issuance_batches b where b.reservation_id=reservation.id
        and public.payment_covers(b.payment_intent_id,'event',reservation.id,reservation.buyer_id,
          reservation.quantity::bigint*reservation.unit_price_minor)))
  then raise exception 'Ticket is not valid for entry';end if;
  update public.event_tickets set state='used',used_at=now(),used_by=caller where id=ticket.id;
  insert into public.event_ticket_audit(ticket_id,reservation_id,actor_id,action)
    values(ticket.id,ticket.reservation_id,caller,'used');
  select count(*)::integer into present from public.event_tickets
    where reservation_id=reservation.id and state='used';
  select revision into current_revision from public.event_attendance
    where reservation_id=reservation.id for update;
  current_revision:=coalesce(current_revision,0)+1;
  insert into public.event_attendance(reservation_id,checked_in,revision,updated_at)
    values(reservation.id,present,current_revision,now())
    on conflict(reservation_id) do update set checked_in=excluded.checked_in,
      revision=excluded.revision,updated_at=excluded.updated_at;
  insert into public.event_attendance_events(reservation_id,revision,actor_id,checked_in)
    values(reservation.id,current_revision,caller,present);
  return jsonb_build_object('ticket_id',ticket.id,'reservation_id',reservation.id,
    'ordinal',ticket.ordinal,'checked_in',present,'validated_at',now());
end $$;

-- Once secure tickets exist, attendance is derived from one-use credentials. The
-- legacy attendance RPC remains usable only for historical reservations.
create function public.event_ticket_attendance_guard() returns trigger
language plpgsql security definer set search_path='' as $$
declare used_count integer;
begin
  if exists(select 1 from public.event_tickets where reservation_id=new.reservation_id) then
    select count(*)::integer into used_count from public.event_tickets
      where reservation_id=new.reservation_id and state='used';
    if new.checked_in is distinct from used_count then
      raise exception 'Attendance must match validated secure tickets';end if;
  end if;return new;
end $$;
create trigger a0_secure_ticket_attendance before insert or update on public.event_attendance
  for each row execute function public.event_ticket_attendance_guard();

create function public.event_ticket_cancellation_guard() returns trigger
language plpgsql security definer set search_path='' as $$
declare ticket_row record;
begin
  if new.state='cancelled' and old.state<>'cancelled'
    and exists(select 1 from public.event_tickets where reservation_id=old.id) then
    if exists(select 1 from public.event_tickets where reservation_id=old.id and state='used') then
      raise exception 'A used ticket cannot be cancelled';end if;
    if public.event_hold_has_financial_claim(old.id) then
      raise exception 'Verified full refund or provider resolution required before cancellation';end if;
    for ticket_row in select id from public.event_tickets
      where reservation_id=old.id and state='issued' order by id for update loop
      update public.event_tickets set state='revoked',revoked_at=now() where id=ticket_row.id;
      insert into public.event_ticket_audit(ticket_id,reservation_id,actor_id,action)
        values(ticket_row.id,old.id,auth.uid(),'revoked');
    end loop;
    update public.event_reservation_holds set state='released',closed_at=now()
      where reservation_id=old.id and state in('active','consumed');
  end if;return new;
end $$;
create trigger a0_secure_ticket_cancellation before update of state on public.event_reservations
  for each row execute function public.event_ticket_cancellation_guard();

-- Trusted bounded maintenance entrypoint. No scheduler is installed here.
create function public.expire_ticket_holds(p_limit integer default 50) returns integer
language plpgsql security definer set search_path='' as $$
declare category_row record;expired_count integer:=0;remaining integer;
begin
  if auth.role() is distinct from 'service_role'
    or not coalesce((select expiry_processing_enabled from public.event_ticket_security_settings where singleton),false)
  then raise exception 'Trusted expiry processing is disabled';end if;
  if p_limit is null or p_limit not between 1 and 100 then raise exception 'Invalid expiry limit';end if;
  for category_row in select distinct h.category_id from public.event_reservation_holds h
    where h.state='active' and h.expires_at<=now() order by h.category_id limit p_limit loop
    remaining:=p_limit-expired_count;exit when remaining<=0;
    expired_count:=expired_count+public.event_expire_category_holds(category_row.category_id,remaining);
  end loop;return expired_count;
end $$;

create function public.secure_ticket_capabilities() returns jsonb
language sql stable security definer set search_path='' as $$
  select jsonb_build_object('version',1,
    'issuance_enabled',coalesce(issuance_enabled,false),
    'validation_enabled',coalesce(validation_enabled,false),
    'expiry_processing_enabled',coalesce(expiry_processing_enabled,false),
    'hold_minutes',hold_minutes)
  from public.event_ticket_security_settings where singleton;
$$;

revoke all on function public.event_ticket_new_token(),public.event_hold_has_financial_claim(uuid),
  public.event_expire_category_holds(uuid,integer),public.reserve_event_tickets(uuid,integer,uuid),
  public.rotate_event_ticket(uuid),public.validate_event_ticket(uuid,text),
  public.event_ticket_attendance_guard(),public.event_ticket_cancellation_guard(),
  public.expire_ticket_holds(integer),public.secure_ticket_capabilities()
  from public,anon,authenticated,service_role;
grant execute on function public.reserve_event_tickets(uuid,integer,uuid),
  public.rotate_event_ticket(uuid),
  public.validate_event_ticket(uuid,text),public.secure_ticket_capabilities() to authenticated;
grant execute on function public.expire_ticket_holds(integer) to service_role;

alter function public.reserve_event_tickets(uuid,integer,uuid) rename to reserve_event_tickets_without_expiry;
revoke all on function public.reserve_event_tickets_without_expiry(uuid,integer,uuid)
  from public,anon,authenticated,service_role;
create function public.reserve_event_tickets(p_category uuid,p_quantity integer,p_key uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare caller uuid:=auth.uid();prior_id uuid;reservation_id uuid;hold_minutes_value integer;
begin
  select id into prior_id from public.event_reservations where buyer_id=caller and idempotency_key=p_key;
  if coalesce((select expiry_processing_enabled from public.event_ticket_security_settings where singleton),false) then
    perform public.event_expire_category_holds(p_category,25);
  end if;
  reservation_id:=public.reserve_event_tickets_without_expiry(p_category,p_quantity,p_key);
  -- Pre-039 reservations remain historical; this is intentionally not a backfill.
  if prior_id is null then
    select hold_minutes into hold_minutes_value from public.event_ticket_security_settings where singleton;
    insert into public.event_reservation_holds(reservation_id,category_id,buyer_id,organiser_id,expires_at)
      select r.id,r.category_id,r.buyer_id,r.organiser_id,
        least(now()+make_interval(mins=>hold_minutes_value),e.starts_at)
      from public.event_reservations r join public.community_entries e on e.id=r.event_id where r.id=reservation_id
      on conflict(reservation_id) do nothing;
  end if;return reservation_id;
end $$;

create function public.event_payment_hold_guard() returns trigger
language plpgsql security definer set search_path = '' as $$
declare hold_row public.event_reservation_holds;
begin
  if new.source_kind<>'event' then return new;end if;
  select * into hold_row from public.event_reservation_holds where reservation_id=new.source_id for update;
  if hold_row.reservation_id is null or hold_row.state<>'active' or hold_row.expires_at<=now() then
    raise exception 'Active unexpired ticket hold required';end if;
  new.quote_expires_at:=least(new.quote_expires_at,hold_row.expires_at);return new;
end $$;
create trigger event_payment_hold_guard before insert on public.payment_intents
  for each row execute function public.event_payment_hold_guard();

create function public.issue_event_tickets(p_reservation uuid,p_payment_intent uuid,p_key uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  caller uuid:=auth.uid();category_id_value uuid;reservation public.event_reservations;
  event_row public.community_entries;hold_row public.event_reservation_holds;
  batch public.event_ticket_issuance_batches;key_batch public.event_ticket_issuance_batches;
  amount_value bigint;ordinal_value integer;token_value text;ticket_id_value uuid;
  issued jsonb:='[]'::jsonb;
begin
  if caller is null or p_key is null or not public.marketplace_complete_member()
    or not public.moderation_actor_allowed(caller)
    or not coalesce((select issuance_enabled from public.event_ticket_security_settings where singleton),false)
  then raise exception 'Secure ticket issuance is disabled or unavailable';end if;
  select category_id into category_id_value from public.event_reservations where id=p_reservation;
  if category_id_value is null then raise exception 'Reservation unavailable';end if;
  perform id from public.event_ticket_categories where id=category_id_value for update;
  select * into reservation from public.event_reservations where id=p_reservation and buyer_id=caller for update;
  select e.* into event_row from public.community_entries e where e.id=reservation.event_id for share;
  select * into hold_row from public.event_reservation_holds where reservation_id=p_reservation for update;
  if reservation.id is null or reservation.state<>'held' or event_row.id is null or event_row.kind<>'event'
    or event_row.status<>'published' or event_row.starts_at<=now() or hold_row.reservation_id is null
    or hold_row.state not in ('active','consumed')
    or not public.moderation_target_allowed('event',event_row.id,reservation.organiser_id)
    or not public.moderation_actor_allowed(reservation.organiser_id)
  then raise exception 'Reservation is not eligible for issuance';end if;
  amount_value:=reservation.quantity::bigint*reservation.unit_price_minor;
  if amount_value=0 then
    if p_payment_intent is not null then raise exception 'Free reservation must not bind a payment';end if;
    if hold_row.expires_at<=now() and hold_row.state='active' then raise exception 'Free ticket hold expired';end if;
  elsif p_payment_intent is null or not public.payment_covers(
    p_payment_intent,'event',reservation.id,caller,amount_value)
  then raise exception 'Verified exact payment required';end if;
  select * into key_batch from public.event_ticket_issuance_batches
    where buyer_id=caller and idempotency_key=p_key for update;
  if key_batch.id is not null and key_batch.reservation_id<>reservation.id then
    raise exception 'Issuance idempotency key reused';end if;
  select * into batch from public.event_ticket_issuance_batches where reservation_id=reservation.id for update;
  if batch.id is not null then
    if batch.buyer_id<>caller or batch.amount_minor<>amount_value
      or batch.payment_intent_id is distinct from p_payment_intent
    then raise exception 'Existing issuance binding mismatch';end if;
    return jsonb_build_object('reservation_id',reservation.id,'already_issued',true,
      'requires_rotation',true,'tickets',(select coalesce(jsonb_agg(jsonb_build_object(
        'id',t.id,'ordinal',t.ordinal,'state',t.state) order by t.ordinal),'[]'::jsonb)
        from public.event_tickets t where t.reservation_id=reservation.id));
  end if;
  insert into public.event_ticket_issuance_batches(
    reservation_id,buyer_id,organiser_id,payment_intent_id,amount_minor,idempotency_key
  ) values(reservation.id,caller,reservation.organiser_id,p_payment_intent,amount_value,p_key)
    returning * into batch;
  for ordinal_value in 1..reservation.quantity loop
    loop
      token_value:=public.event_ticket_new_token();
      begin
        insert into public.event_tickets(reservation_id,event_id,buyer_id,organiser_id,ordinal,token_hash)
          values(reservation.id,reservation.event_id,caller,reservation.organiser_id,ordinal_value,
            pg_catalog.sha256(convert_to(token_value,'UTF8'))) returning id into ticket_id_value;
        exit;
      exception when unique_violation then null;end;
    end loop;
    insert into public.event_ticket_audit(ticket_id,reservation_id,actor_id,action)
      values(ticket_id_value,reservation.id,caller,'issued');
    issued:=issued||jsonb_build_array(jsonb_build_object('id',ticket_id_value,'ordinal',ordinal_value,
      'credential',ticket_id_value::text||'.'||token_value));
  end loop;
  update public.event_reservation_holds set state='consumed',closed_at=now()
    where reservation_id=reservation.id;
  return jsonb_build_object('reservation_id',reservation.id,'already_issued',false,
    'requires_rotation',false,'tickets',issued);
end $$;

revoke all on function public.reserve_event_tickets(uuid,integer,uuid),
  public.event_payment_hold_guard(),public.issue_event_tickets(uuid,uuid,uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.reserve_event_tickets(uuid,integer,uuid),
  public.issue_event_tickets(uuid,uuid,uuid) to authenticated;

commit;
