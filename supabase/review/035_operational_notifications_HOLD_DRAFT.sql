-- HOLD 035. Private in-app notifications; no email/push, operation enabling or existing policy replacement.
-- Install AFTER approved operational branches. Re-run registration only through separate review if branches are added later.
begin;
create table public.marketplace_operational_notifications(id uuid primary key default gen_random_uuid(),recipient_id uuid not null references auth.users(id),module text not null check(module in('shopping','food','delivery','stay','event','job','property','logistics','learning','agriculture','service','digital','revenue','safety')),source_type text not null,source_id uuid not null,record_id uuid not null,revision bigint not null,title text not null,read_at timestamptz,created_at timestamptz not null default now(),unique(recipient_id,source_type,source_id,revision));
alter table public.marketplace_operational_notifications enable row level security;
revoke all on public.marketplace_operational_notifications from public,anon,authenticated,service_role;
grant select on public.marketplace_operational_notifications to authenticated;
create policy operational_notification_owner on public.marketplace_operational_notifications for select to authenticated using(recipient_id=(select auth.uid()));
create index operational_notification_recipient on public.marketplace_operational_notifications(recipient_id,created_at desc);
create function public.operational_mark_read(p_ids uuid[],p_read boolean) returns integer language plpgsql security definer set search_path='' as $$
declare changed integer;
begin
 if auth.uid() is null or p_ids is null or cardinality(p_ids) not between 1 and 50 or p_read is null then raise exception 'Signed-in bounded update required';end if;
 update public.marketplace_operational_notifications set read_at=case when p_read then now() else null end where recipient_id=auth.uid() and id=any(p_ids);
 get diagnostics changed=row_count;return changed;
end $$;
create function public.operational_notification_emit() returns trigger language plpgsql security definer set search_path='' as $$
declare item jsonb:=to_jsonb(new);prior jsonb;recipients uuid[];recipient uuid;actor uuid:=auth.uid();mod text;target_record uuid;source_value uuid:=coalesce((item->>'id')::uuid,(item->>'report_id')::uuid);rev bigint:=coalesce((item->>'revision')::bigint,0);state_value text:=coalesce(item->>'state','updated');parent record;
begin
 if tg_op='UPDATE' then prior:=to_jsonb(old);if item->>'state' is not distinct from prior->>'state' and item->>'revision' is not distinct from prior->>'revision' then return new;end if;end if;
 target_record:=source_value;
 case tg_table_name
 when 'shop_order_requests' then mod:='shopping';recipients:=array[(item->>'buyer_id')::uuid,(item->>'seller_id')::uuid];
 when 'food_orders' then mod:='food';recipients:=array[(item->>'customer_id')::uuid,(item->>'merchant_id')::uuid];
 when 'delivery_jobs' then mod:='delivery';recipients:=array[(item->>'customer_id')::uuid,(item->>'courier_id')::uuid];
 when 'marketplace_work_requests' then mod:=item->>'kind';recipients:=array[(item->>'requester_id')::uuid,(item->>'provider_id')::uuid];
 when 'stay_reservation_requests' then mod:='stay';recipients:=array[(item->>'guest_id')::uuid,(item->>'host_id')::uuid];
 when 'event_reservations' then mod:='event';recipients:=array[(item->>'buyer_id')::uuid,(item->>'organiser_id')::uuid];rev:=case when item->>'state'='cancelled' then 1 else 0 end;
 when 'marketplace_subscription_requests' then mod:='revenue';recipients:=array[(item->>'owner_id')::uuid];
 when 'marketplace_promotion_reviews' then mod:='revenue';recipients:=array[(item->>'owner_id')::uuid];
 when 'marketplace_review_events' then
 select owner_id,state into parent from public.marketplace_safety_requests where id=(item->>'report_id')::uuid;
 mod:='safety';recipients:=array[parent.owner_id];actor:=(item->>'actor_id')::uuid;state_value:=parent.state;
 when 'marketplace_commission_entries' then mod:='revenue';recipients:=array[(item->>'seller_id')::uuid];rev:=case when item->>'state'='reversed' then 1 else 0 end;state_value:='test commission '||(item->>'state');
 when 'marketplace_work_messages' then
 select requester_id,provider_id,kind into parent from public.marketplace_work_requests where id=(item->>'request_id')::uuid;
 mod:=parent.kind;recipients:=array[parent.requester_id,parent.provider_id];target_record:=(item->>'request_id')::uuid;actor:=(item->>'actor_id')::uuid;state_value:='new message';
 when 'stay_reservation_messages' then
 select guest_id,host_id into parent from public.stay_reservation_requests where id=(item->>'reservation_id')::uuid;
 mod:='stay';recipients:=array[parent.guest_id,parent.host_id];target_record:=(item->>'reservation_id')::uuid;actor:=(item->>'actor_id')::uuid;state_value:='new message';
 else return new;end case;
 foreach recipient in array recipients loop
 if recipient is not null and recipient is distinct from actor then
 insert into public.marketplace_operational_notifications(recipient_id,module,source_type,source_id,record_id,revision,title) values(recipient,mod,tg_table_name,source_value,target_record,rev,initcap(mod)||' update: '||replace(state_value,'_',' ')) on conflict(recipient_id,source_type,source_id,revision) do nothing;
 end if;end loop;return new;
end $$;
do $$declare source text;begin
 foreach source in array array['shop_order_requests','food_orders','delivery_jobs','marketplace_work_requests','stay_reservation_requests','event_reservations','marketplace_subscription_requests','marketplace_promotion_reviews','marketplace_work_messages','stay_reservation_messages','marketplace_review_events','marketplace_commission_entries'] loop
 if to_regclass('public.'||source) is not null then execute format('create trigger zammarket_operational_notice after insert or update on public.%I for each row execute function public.operational_notification_emit()',source);end if;
 end loop;
end $$;
revoke all on function public.operational_mark_read(uuid[],boolean),public.operational_notification_emit() from public,anon,authenticated,service_role;
grant execute on function public.operational_mark_read(uuid[],boolean) to authenticated;
commit;
