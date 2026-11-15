-- HOLD 030. Requires 023 + 010. New private calendars/reservations only. No real bookings enabled.
begin;
create table public.stay_operation_settings(singleton boolean primary key default true check(singleton),enabled boolean not null default false);
insert into public.stay_operation_settings values(true,false);alter table public.stay_operation_settings enable row level security;
revoke all on public.stay_operation_settings from public,anon,authenticated,service_role;grant select,update(enabled) on public.stay_operation_settings to service_role;
create table public.stay_room_calendar(room_id uuid not null references public.stay_room_options(id),day date not null,capacity integer not null check(capacity between 0 and 1000),reserved integer not null default 0 check(reserved>=0 and reserved<=capacity),nightly_minor bigint check(nightly_minor between 0 and 100000000),primary key(room_id,day));
create table public.stay_reservation_requests(id uuid primary key default gen_random_uuid(),room_id uuid not null references public.stay_room_options(id),entry_id uuid not null references public.business_service_entries(id),guest_id uuid not null references auth.users(id),host_id uuid not null references auth.users(id),check_in date not null,check_out date not null,guests integer not null check(guests between 1 and 20),subtotal_minor bigint not null check(subtotal_minor>=0),currency text not null default 'ZMW' check(currency='ZMW'),state text not null default 'requested' check(state in('requested','confirmed','checked_in','checked_out','declined','cancelled')),revision bigint not null default 0,idempotency_key uuid not null,created_at timestamptz not null default now(),check(check_out>check_in and check_out-check_in<=60),check(guest_id<>host_id),unique(guest_id,idempotency_key));
create table public.stay_reservation_events(reservation_id uuid not null references public.stay_reservation_requests(id),revision bigint not null,actor_id uuid not null references auth.users(id),state text not null,created_at timestamptz not null default now(),primary key(reservation_id,revision));
create table public.stay_reservation_messages(id uuid primary key default gen_random_uuid(),reservation_id uuid not null references public.stay_reservation_requests(id),actor_id uuid not null references auth.users(id),body text not null check(length(btrim(body)) between 1 and 2000),created_at timestamptz not null default now());
create index stay_request_guest on public.stay_reservation_requests(guest_id,created_at desc);create index stay_request_host on public.stay_reservation_requests(host_id,created_at desc);
alter table public.stay_room_calendar enable row level security;alter table public.stay_reservation_requests enable row level security;alter table public.stay_reservation_events enable row level security;alter table public.stay_reservation_messages enable row level security;
revoke all on public.stay_room_calendar,public.stay_reservation_requests,public.stay_reservation_events,public.stay_reservation_messages from public,anon,authenticated,service_role;
grant select on public.stay_room_calendar,public.stay_reservation_requests,public.stay_reservation_events,public.stay_reservation_messages to authenticated;
create policy stay_calendar_owner on public.stay_room_calendar for select to authenticated using(exists(select 1 from public.stay_room_options r join public.business_service_entries e on e.id=r.entry_id where r.id=room_id and e.owner_id=(select auth.uid())));
create policy stay_reservation_participants on public.stay_reservation_requests for select to authenticated using((select auth.uid()) in(guest_id,host_id));
create policy stay_reservation_event_participants on public.stay_reservation_events for select to authenticated using(exists(select 1 from public.stay_reservation_requests r where r.id=reservation_id and (select auth.uid()) in(r.guest_id,r.host_id)));
create policy stay_reservation_message_participants on public.stay_reservation_messages for select to authenticated using(exists(select 1 from public.stay_reservation_requests r where r.id=reservation_id and (select auth.uid()) in(r.guest_id,r.host_id)));
create function public.stay_workflow_capabilities() returns jsonb language sql stable security definer set search_path='' as $$select jsonb_build_object('version',1,'enabled',coalesce((select enabled from public.stay_operation_settings where singleton),false));$$;
create function public.stay_set_calendar(p_room uuid,p_from date,p_until date,p_capacity integer,p_nightly_minor bigint default null) returns integer language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();count_days integer;
begin
 if caller is null or not public.marketplace_complete_member() or p_from is null or p_until is null or p_from<(now() at time zone 'Africa/Lusaka')::date or p_until<p_from or p_until-p_from>365 or p_capacity is null or p_capacity not between 0 and 1000 or p_nightly_minor<0 or p_nightly_minor>100000000 then raise exception 'Valid future calendar range required';end if;
 perform r.id from public.stay_room_options r join public.business_service_entries e on e.id=r.entry_id where r.id=p_room and e.owner_id=caller and e.kind='stay' for update of r;
 if not found then raise exception 'Owning host required';end if;
 if exists(select 1 from public.stay_room_calendar where room_id=p_room and day between p_from and p_until and reserved>p_capacity) then raise exception 'Capacity cannot be below confirmed reservations';end if;
 insert into public.stay_room_calendar(room_id,day,capacity,nightly_minor) select p_room,p_from+n,p_capacity,p_nightly_minor from generate_series(0,p_until-p_from) n on conflict(room_id,day) do update set capacity=excluded.capacity,nightly_minor=excluded.nightly_minor;
 get diagnostics count_days=row_count;return count_days;
end $$;
create function public.stay_availability(p_room uuid,p_from date,p_until date) returns table(day date,remaining integer,nightly_minor bigint) language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or p_from is null or p_until is null or p_until<p_from or p_until-p_from>60 then raise exception 'Signed-in bounded calendar required';end if;
 if not exists(select 1 from public.stay_room_options r join public.business_service_entries e on e.id=r.entry_id where r.id=p_room and e.kind='stay' and (e.owner_id=auth.uid() or(r.listed and public.business_service_visible(e.id)))) then raise exception 'Room unavailable';end if;
 return query select c.day,c.capacity-c.reserved,coalesce(c.nightly_minor,r.nightly_minor) from public.stay_room_calendar c join public.stay_room_options r on r.id=c.room_id where c.room_id=p_room and c.day between p_from and p_until order by c.day;
end $$;
create function public.stay_request(p_room uuid,p_in date,p_out date,p_guests integer,p_key uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();room public.stay_room_options;host public.business_service_entries;prior public.stay_reservation_requests;total bigint;days integer;saved uuid;
begin
 if caller is null or not public.marketplace_complete_member() or not coalesce((select enabled from public.stay_operation_settings where singleton),false) then raise exception 'Stays requests disabled or membership incomplete';end if;
 if p_key is null or p_in is null or p_out is null or p_in<(now() at time zone 'Africa/Lusaka')::date or p_out<=p_in or p_out-p_in>60 or p_guests is null or p_guests<1 then raise exception 'Valid stay dates and guests required';end if;
 perform pg_advisory_xact_lock(hashtextextended('stay-guest:'||caller::text,0));
 select * into prior from public.stay_reservation_requests where guest_id=caller and idempotency_key=p_key;
 if prior.id is not null then if prior.room_id<>p_room or prior.check_in<>p_in or prior.check_out<>p_out or prior.guests<>p_guests then raise exception 'Key reused for another stay';end if;return prior.id;end if;
 if (select count(*) from public.stay_reservation_requests where guest_id=caller and state in('requested','confirmed','checked_in'))>=10 then raise exception 'Too many open stay requests';end if;
 select * into room from public.stay_room_options where id=p_room for update;
 select * into host from public.business_service_entries where id=room.entry_id and kind='stay';
 if room.id is null or not room.listed or host.owner_id=caller or not public.business_service_visible(host.id) or p_guests>room.guest_capacity then raise exception 'Room unavailable';end if;
 select count(*),sum(coalesce(c.nightly_minor,room.nightly_minor)) into days,total from public.stay_room_calendar c where c.room_id=p_room and c.day>=p_in and c.day<p_out and c.capacity>c.reserved;
 if days<>p_out-p_in then raise exception 'Every night requires availability';end if;
 insert into public.stay_reservation_requests(room_id,entry_id,guest_id,host_id,check_in,check_out,guests,subtotal_minor,idempotency_key) values(p_room,host.id,caller,host.owner_id,p_in,p_out,p_guests,total,p_key) returning id into saved;
 insert into public.stay_reservation_events values(saved,0,caller,'requested',now());return saved;
end $$;
create function public.stay_advance(p_id uuid,p_revision bigint,p_action text) returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();item public.stay_reservation_requests;room public.stay_room_options;target uuid;next_state text;days integer;price bigint;
begin
 if caller is null or not public.marketplace_complete_member() then raise exception 'Verified participant required';end if;
 select room_id into target from public.stay_reservation_requests where id=p_id and caller in(guest_id,host_id);
 if target is null then raise exception 'Stay unavailable';end if;
 select * into room from public.stay_room_options where id=target for update;
 select * into item from public.stay_reservation_requests where id=p_id for update;
 if item.revision is distinct from p_revision then raise exception 'Stale reservation';end if;
 if p_action='cancel' and ((caller=item.guest_id and(item.state='requested' or(item.state='confirmed' and item.check_in>=(now() at time zone 'Africa/Lusaka')::date))) or(caller=item.host_id and item.state in('requested','confirmed'))) then next_state:='cancelled';
 elsif caller=item.host_id and coalesce((select enabled from public.stay_operation_settings where singleton),false) then next_state:=case when item.state='requested' and p_action='confirm' then 'confirmed' when item.state='requested' and p_action='decline' then 'declined' when item.state='confirmed' and p_action='check_in' and item.check_in<=(now() at time zone 'Africa/Lusaka')::date and item.check_out>(now() at time zone 'Africa/Lusaka')::date then 'checked_in' when item.state='checked_in' and p_action='check_out' then 'checked_out' end;end if;
 if next_state is null then raise exception 'Transition not permitted';end if;
 if next_state='confirmed' then
 if item.check_in<(now() at time zone 'Africa/Lusaka')::date then raise exception 'Stay dates have passed';end if;
 perform day from public.stay_room_calendar where room_id=target and day>=item.check_in and day<item.check_out order by day for update;
 select count(*),sum(coalesce(c.nightly_minor,room.nightly_minor)) into days,price from public.stay_room_calendar c where c.room_id=target and c.day>=item.check_in and c.day<item.check_out and c.capacity>c.reserved;
 if days<>item.check_out-item.check_in or price<>item.subtotal_minor or not room.listed or not public.business_service_visible(item.entry_id) or item.guests>room.guest_capacity then raise exception 'Availability or price changed; request new terms';end if;
 update public.stay_room_calendar set reserved=reserved+1 where room_id=target and day>=item.check_in and day<item.check_out;
 elsif next_state='cancelled' and item.state='confirmed' then update public.stay_room_calendar set reserved=reserved-1 where room_id=target and day>=item.check_in and day<item.check_out;end if;
 update public.stay_reservation_requests set state=next_state,revision=revision+1 where id=p_id;
 insert into public.stay_reservation_events values(p_id,item.revision+1,caller,next_state,now());return jsonb_build_object('id',p_id,'state',next_state,'revision',item.revision+1);
end $$;
create function public.stay_message(p_id uuid,p_body text) returns uuid language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();saved uuid;
begin
 if caller is null or not public.marketplace_complete_member() or length(btrim(p_body)) not between 1 and 2000 or not exists(select 1 from public.stay_reservation_requests where id=p_id and caller in(guest_id,host_id)) then raise exception 'Participant message required';end if;
 perform pg_advisory_xact_lock(hashtextextended('stay-messages:'||caller::text,0));if (select count(*) from public.stay_reservation_messages where actor_id=caller and created_at>now()-interval '1 day')>=100 then raise exception 'Message limit reached';end if;
 insert into public.stay_reservation_messages(reservation_id,actor_id,body) values(p_id,caller,btrim(p_body)) returning id into saved;return saved;
end $$;
create function public.stay_room_confirmed_capacity_guard() returns trigger language plpgsql security definer set search_path='' as $begin if new.guest_capacity<old.guest_capacity and exists(select 1 from public.stay_reservation_requests where room_id=old.id and state in('confirmed','checked_in') and guests>new.guest_capacity) then raise exception 'Room capacity must cover confirmed guests';end if;return new;end $;
create trigger stay_confirmed_guest_capacity before update on public.stay_room_options for each row execute function public.stay_room_confirmed_capacity_guard();
revoke all on function public.stay_room_confirmed_capacity_guard() from public,anon,authenticated,service_role;
revoke all on function public.stay_workflow_capabilities(),public.stay_set_calendar(uuid,date,date,integer,bigint),public.stay_availability(uuid,date,date),public.stay_request(uuid,date,date,integer,uuid),public.stay_advance(uuid,bigint,text),public.stay_message(uuid,text) from public,anon,authenticated,service_role;
grant execute on function public.stay_workflow_capabilities(),public.stay_set_calendar(uuid,date,date,integer,bigint),public.stay_availability(uuid,date,date),public.stay_request(uuid,date,date,integer,uuid),public.stay_advance(uuid,bigint,text),public.stay_message(uuid,text) to authenticated;
commit;
