-- HOLD 031. Extends held 018 and corrected 013_v2. No issuance/payments or enabling.
begin;
create table public.event_attendance(reservation_id uuid primary key references public.event_reservations(id),checked_in integer not null check(checked_in between 0 and 20),revision bigint not null default 0,updated_at timestamptz not null default now());
create table public.event_attendance_events(reservation_id uuid not null references public.event_reservations(id),revision bigint not null,actor_id uuid not null references auth.users(id),checked_in integer not null,created_at timestamptz not null default now(),primary key(reservation_id,revision));
alter table public.event_attendance enable row level security;alter table public.event_attendance_events enable row level security;
revoke all on public.event_attendance,public.event_attendance_events from public,anon,authenticated,service_role;
grant select on public.event_attendance,public.event_attendance_events to authenticated;
create policy attendance_participants on public.event_attendance for select to authenticated using(exists(select 1 from public.event_reservations r where r.id=reservation_id and (select auth.uid()) in(r.buyer_id,r.organiser_id)));
create policy attendance_events_participants on public.event_attendance_events for select to authenticated using(exists(select 1 from public.event_reservations r where r.id=reservation_id and (select auth.uid()) in(r.buyer_id,r.organiser_id)));
create function public.event_workflow_capabilities() returns jsonb language sql stable security definer set search_path='' as $$select jsonb_build_object('version',1,'enabled',coalesce((select enabled from public.ticket_operation_settings where singleton),false));$$;
create function public.event_save_category(p_event uuid,p_id uuid,p_label text,p_price_minor bigint,p_capacity integer,p_active boolean) returns uuid language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();saved uuid;
begin
 if caller is null or not public.marketplace_complete_member() then raise exception 'Verified organiser required';end if;
 perform id from public.community_entries where id=p_event and kind='event' and owner_id=caller for update;if not found then raise exception 'Owning organiser required';end if;
 if p_id is null then
 if (select count(*) from public.event_ticket_categories where event_id=p_event)>=20 then raise exception 'Category limit reached';end if;
 insert into public.event_ticket_categories(event_id,label,price_minor,capacity,active) values(p_event,btrim(p_label),p_price_minor,p_capacity,coalesce(p_active,false)) returning id into saved;
 else update public.event_ticket_categories set label=btrim(p_label),price_minor=p_price_minor,capacity=p_capacity,active=coalesce(p_active,false) where id=p_id and event_id=p_event returning id into saved;end if;
 if saved is null then raise exception 'Category unavailable';end if;return saved;
end $$;
create function public.event_mark_attendance(p_reservation uuid,p_revision bigint,p_checked_in integer) returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();item public.event_reservations;current_revision bigint;
begin
 if caller is null or not public.marketplace_complete_member() or not coalesce((select enabled from public.ticket_operation_settings where singleton),false) then raise exception 'Attendance disabled';end if;
 select * into item from public.event_reservations where id=p_reservation and organiser_id=caller and state='held' for update;
 if item.id is null or p_checked_in is null or p_checked_in not between 0 and item.quantity then raise exception 'Owning organiser and valid attendance required';end if;
 select revision into current_revision from public.event_attendance where reservation_id=p_reservation;
 current_revision:=coalesce(current_revision,0);if current_revision is distinct from p_revision then raise exception 'Stale attendance record';end if;
 insert into public.event_attendance(reservation_id,checked_in,revision) values(p_reservation,p_checked_in,current_revision+1) on conflict(reservation_id) do update set checked_in=excluded.checked_in,revision=excluded.revision,updated_at=now();
 insert into public.event_attendance_events values(p_reservation,current_revision+1,caller,p_checked_in,now());return jsonb_build_object('id',p_reservation,'checked_in',p_checked_in,'revision',current_revision+1);
end $$;
create function public.event_cancel_attendance_guard() returns trigger language plpgsql security definer set search_path='' as $$begin if new.state='cancelled' and exists(select 1 from public.event_attendance where reservation_id=old.id and checked_in>0) then raise exception 'Correct recorded attendance before cancellation';end if;return new;end $$;
create trigger event_attendance_cancel_guard before update on public.event_reservations for each row execute function public.event_cancel_attendance_guard();
revoke all on function public.event_workflow_capabilities(),public.event_save_category(uuid,uuid,text,bigint,integer,boolean),public.event_mark_attendance(uuid,bigint,integer),public.event_cancel_attendance_guard() from public,anon,authenticated,service_role;
grant execute on function public.event_workflow_capabilities(),public.event_save_category(uuid,uuid,text,bigint,integer,boolean),public.event_mark_attendance(uuid,bigint,integer) to authenticated;
commit;
