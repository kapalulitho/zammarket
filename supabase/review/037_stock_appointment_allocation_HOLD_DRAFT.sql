-- HOLD 037. Allocation ledger around existing owner-only stock and capacity systems.
-- Requires 014_v2,028,029,030,036. No scheduler or operation gate enabled.
begin;
create table public.marketplace_allocation_settings(singleton boolean primary key default true check(singleton),stock_enabled boolean not null default false,appointments_enabled boolean not null default false);
insert into public.marketplace_allocation_settings values(true,false,false);alter table public.marketplace_allocation_settings enable row level security;revoke all on public.marketplace_allocation_settings from public,anon,authenticated,service_role;grant select,update(stock_enabled,appointments_enabled) on public.marketplace_allocation_settings to service_role;
create table public.shop_allocation_batches(id uuid primary key default gen_random_uuid(),order_id uuid not null references public.shop_order_requests(id),buyer_id uuid not null references auth.users(id),seller_id uuid not null references auth.users(id),idempotency_key uuid not null,expires_at timestamptz not null,state text not null default 'held' check(state in('held','committed','released')),created_at timestamptz not null default now(),unique(buyer_id,idempotency_key));
create table public.shop_stock_allocations(batch_id uuid not null references public.shop_allocation_batches(id),listing_id uuid not null references public.listing_stock(listing_id),option_label text not null default '',quantity integer not null check(quantity between 1 and 20),state text not null default 'held' check(state in('held','committed','released','reconciled')),expires_at timestamptz not null,primary key(batch_id,listing_id));
create index shop_allocation_resource on public.shop_stock_allocations(listing_id,option_label,state);create index shop_allocation_order on public.shop_allocation_batches(order_id,state);
alter table public.shop_allocation_batches enable row level security;alter table public.shop_stock_allocations enable row level security;
revoke all on public.shop_allocation_batches,public.shop_stock_allocations from public,anon,authenticated,service_role;grant select on public.shop_allocation_batches,public.shop_stock_allocations to authenticated;
create policy allocation_batch_participant on public.shop_allocation_batches for select to authenticated using((select auth.uid()) in(buyer_id,seller_id));
create policy allocation_line_participant on public.shop_stock_allocations for select to authenticated using(exists(select 1 from public.shop_allocation_batches b where b.id=batch_id and (select auth.uid()) in(b.buyer_id,b.seller_id)));
create function public.shop_allocation_used(p_listing uuid,p_option text) returns integer language sql stable security definer set search_path='' as $$select coalesce(sum(quantity),0)::integer from public.shop_stock_allocations where listing_id=p_listing and option_label=p_option and(state='committed' or(state='held' and expires_at>now()));$$;
create function public.reserve_shop_allocation(p_order uuid,p_key uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();item public.shop_order_requests;prior public.shop_allocation_batches;line public.shop_order_request_lines;stock public.listing_stock;product public.listings;option_value jsonb;capacity integer;current_price numeric;saved uuid;
begin
 if caller is null or not public.marketplace_complete_member() or not coalesce((select stock_enabled from public.marketplace_allocation_settings where singleton),false) or p_key is null then raise exception 'Stock allocation disabled';end if;
 select * into item from public.shop_order_requests where id=p_order and buyer_id=caller for update;
 if item.id is null or item.state not in('requested','acknowledged') then raise exception 'Owned open request required';end if;
 perform pg_advisory_xact_lock(hashtextextended('stock-buyer:'||caller::text,0));
 select * into prior from public.shop_allocation_batches where buyer_id=caller and idempotency_key=p_key;if prior.id is not null then if prior.order_id<>p_order then raise exception 'Allocation key reused';end if;return prior.id;end if;
 select * into prior from public.shop_allocation_batches where order_id=p_order and (state='committed' or(state='held' and expires_at>now())) order by created_at desc limit 1;if prior.id is not null then return prior.id;end if;
 if (select count(*) from public.shop_allocation_batches where buyer_id=caller and state='held' and expires_at>now())>=10 then raise exception 'Too many active holds';end if;
 perform l.id from public.listings l join public.shop_order_request_lines r on r.listing_id=l.id where r.order_id=p_order order by l.id for share of l;
 perform s.listing_id from public.listing_stock s join public.shop_order_request_lines l on l.listing_id=s.listing_id where l.order_id=p_order order by s.listing_id for update of s;
 for line in select * from public.shop_order_request_lines where order_id=p_order order by listing_id loop
 select * into stock from public.listing_stock where listing_id=line.listing_id and owner_id=item.seller_id;
 select * into product from public.listings where id=line.listing_id and user_id=item.seller_id and deleted_at is null and status='active' and (available_from is null or available_from<=(now() at time zone 'Africa/Lusaka')::date);
 if stock.listing_id is null or product.id is null then raise exception 'Product unavailable';end if;current_price:=product.price;
 if jsonb_array_length(stock.variants)>0 then select value into option_value from jsonb_array_elements(stock.variants) where value->>'label'=line.option_label;if option_value is null then raise exception 'Variant unavailable';end if;capacity:=(option_value->>'quantity')::integer;current_price:=coalesce((option_value->>'price')::numeric,product.price);
 else if coalesce(line.option_label,'')<>'' then raise exception 'Variant changed';end if;capacity:=stock.quantity;end if;
 if current_price is null or current_price::text in('NaN','Infinity','-Infinity') or round(current_price*100)::bigint<>line.unit_minor or capacity-public.shop_allocation_used(line.listing_id,coalesce(line.option_label,''))<line.quantity then raise exception 'Price or available stock changed';end if;
 end loop;
 insert into public.shop_allocation_batches(order_id,buyer_id,seller_id,idempotency_key,expires_at) values(p_order,caller,item.seller_id,p_key,now()+interval '15 minutes') returning id into saved;
 insert into public.shop_stock_allocations(batch_id,listing_id,option_label,quantity,expires_at) select saved,listing_id,coalesce(option_label,''),quantity,now()+interval '15 minutes' from public.shop_order_request_lines where order_id=p_order;
 return saved;
end $$;
create function public.commit_shop_allocation(p_batch uuid,p_intent uuid default null) returns void language plpgsql security definer set search_path='' as $$declare batch public.shop_allocation_batches;item public.shop_order_requests;begin
 select order_id into item.id from public.shop_allocation_batches where id=p_batch;select * into item from public.shop_order_requests where id=item.id for update;select * into batch from public.shop_allocation_batches where id=p_batch for update;
 if item.id is null or (auth.uid() is distinct from item.buyer_id and auth.role() is distinct from 'service_role') or not coalesce((select stock_enabled from public.marketplace_allocation_settings where singleton),false) then raise exception 'Owned sandbox allocation required';end if;
 if batch.state='committed' then return;end if;
 if batch.state<>'held' or batch.expires_at<=now() or item.state='cancelled' then raise exception 'Hold expired or unavailable';end if;
 if item.subtotal_minor>0 and not public.payment_covers(p_intent,'shopping',item.id,item.buyer_id,item.subtotal_minor) then raise exception 'Verified payment required';end if;
 perform s.listing_id from public.listing_stock s join public.shop_stock_allocations a on a.listing_id=s.listing_id where a.batch_id=p_batch order by s.listing_id for update of s;
 update public.shop_stock_allocations set state='committed' where batch_id=p_batch and state='held';update public.shop_allocation_batches set state='committed' where id=p_batch;
end $$;
create function public.allocation_stock_guard() returns trigger language plpgsql security definer set search_path='' as $$declare amount integer;entry record;matched jsonb;begin
 if jsonb_typeof(new.variants) is distinct from 'array' then raise exception 'Invalid variants';end if;
 for entry in select option_label,sum(quantity)::integer units from public.shop_stock_allocations where listing_id=old.listing_id and(state='committed' or(state='held' and expires_at>now())) group by option_label loop
 if entry.option_label='' then if jsonb_array_length(new.variants)>0 or new.quantity<entry.units then raise exception 'Inventory below allocated units';end if;
 else select value into matched from jsonb_array_elements(new.variants) where value->>'label'=entry.option_label;if matched is null or (matched->>'quantity')::integer<entry.units then raise exception 'Allocated option cannot be removed or reduced';end if;end if;
 end loop;return new;
end $$;
create trigger allocation_stock_floor before update on public.listing_stock for each row execute function public.allocation_stock_guard();
create function public.allocation_reconcile_inventory(p_listing uuid,p_quantity integer,p_variants jsonb) returns void language plpgsql security definer set search_path='' as $$begin
 if auth.uid() is null or not public.marketplace_complete_member() then raise exception 'Verified owner required';end if;
 perform listing_id from public.listing_stock where listing_id=p_listing and owner_id=auth.uid() for update;if not found then raise exception 'Stock owner required';end if;
 update public.shop_stock_allocations set state='reconciled' where listing_id=p_listing and state='committed';
 update public.listing_stock set quantity=p_quantity,variants=p_variants where listing_id=p_listing and owner_id=auth.uid();
end $$;
create function public.shop_allocation_order_guard() returns trigger language plpgsql security definer set search_path='' as $$begin
 if new.state='cancelled' and old.state<>'cancelled' then
 if exists(select 1 from public.shop_allocation_batches where order_id=new.id and state='committed') and exists(select 1 from public.payment_intents where source_kind='shopping' and source_id=new.id and state<>'refunded' and refunded_minor<amount_minor and state in('settled','partially_refunded','reconciliation_required')) then raise exception 'Verified full refund required before releasing paid stock';end if;
 perform s.listing_id from public.listing_stock s join public.shop_stock_allocations a on a.listing_id=s.listing_id join public.shop_allocation_batches b on b.id=a.batch_id where b.order_id=new.id order by s.listing_id for update of s;
 update public.shop_stock_allocations set state='released' where batch_id in(select id from public.shop_allocation_batches where order_id=new.id) and state in('held','committed');update public.shop_allocation_batches set state='released' where order_id=new.id;
 elsif new.state='completed' and exists(select 1 from public.shop_allocation_batches where order_id=new.id and state='held') and not exists(select 1 from public.shop_allocation_batches where order_id=new.id and state='committed') then raise exception 'Commit the funded allocation before completion';end if;return new;
end $$;
create trigger shop_allocation_order_state before update on public.shop_order_requests for each row execute function public.shop_allocation_order_guard();
-- Same public shape, now remaining stock. Owner inventory keeps gross counts until explicit reconciliation.
create or replace view public.marketplace_stock as select s.listing_id,greatest(0,s.quantity-coalesce((select sum(a.quantity)::integer from public.shop_stock_allocations a where a.listing_id=s.listing_id and(a.state='committed' or(a.state='held' and a.expires_at>now()))),0))::integer quantity,(select coalesce(jsonb_agg(jsonb_build_object('label',v->>'label','quantity',greatest(0,(v->>'quantity')::integer-public.shop_allocation_used(s.listing_id,v->>'label')),'price',v->'price')),'[]'::jsonb) from jsonb_array_elements(s.variants) v) variants from public.listing_stock s join public.listings l on l.id=s.listing_id where l.deleted_at is null;
create table public.provider_appointment_slots(id uuid primary key default gen_random_uuid(),provider_id uuid not null references auth.users(id),kind text not null,target_id uuid not null,starts_at timestamptz not null,ends_at timestamptz not null,capacity integer not null check(capacity between 1 and 50),active boolean not null default true,check(ends_at>starts_at and ends_at<=starts_at+interval '8 hours'));
create table public.appointment_allocations(id uuid primary key default gen_random_uuid(),request_id uuid not null references public.marketplace_work_requests(id),slot_id uuid not null references public.provider_appointment_slots(id),requester_id uuid not null references auth.users(id),provider_id uuid not null references auth.users(id),idempotency_key uuid not null,state text not null default 'held' check(state in('held','confirmed','released','expired')),expires_at timestamptz not null,created_at timestamptz not null default now(),unique(requester_id,idempotency_key));
create index appointment_slot_holds on public.appointment_allocations(slot_id,state,expires_at);
alter table public.provider_appointment_slots enable row level security;alter table public.appointment_allocations enable row level security;revoke all on public.provider_appointment_slots,public.appointment_allocations from public,anon,authenticated,service_role;grant select on public.provider_appointment_slots,public.appointment_allocations to authenticated;
create policy appointment_provider_read on public.provider_appointment_slots for select to authenticated using(provider_id=(select auth.uid()));create policy appointment_participant_read on public.appointment_allocations for select to authenticated using((select auth.uid()) in(requester_id,provider_id));
create function public.appointment_create_slot(p_kind text,p_target uuid,p_start timestamptz,p_end timestamptz,p_capacity integer) returns uuid language plpgsql security definer set search_path='' as $$declare caller uuid:=auth.uid();target jsonb;saved uuid;begin
 if caller is null or not public.marketplace_complete_member() or p_kind not in('service','property','job','learning') or p_start is null or p_end is null or p_start<=now() or p_start>now()+interval '1 year' or p_end<=p_start or p_end>p_start+interval '8 hours' then raise exception 'Valid verified provider slot required';end if;
 target:=public.work_target(p_kind,p_target);if target is null or (target->>'owner')::uuid<>caller then raise exception 'Provider ownership required';end if;
 perform pg_advisory_xact_lock(hashtextextended('appointment-provider:'||caller::text,0));if (select count(*) from public.provider_appointment_slots where provider_id=caller)>=1000 then raise exception 'Slot limit reached';end if;if exists(select 1 from public.provider_appointment_slots where provider_id=caller and active and starts_at<p_end and ends_at>p_start) then raise exception 'Provider slots overlap';end if;
 insert into public.provider_appointment_slots(provider_id,kind,target_id,starts_at,ends_at,capacity) values(caller,p_kind,p_target,p_start,p_end,p_capacity) returning id into saved;return saved;
end $$;
create function public.appointment_availability(p_request uuid) returns table(id uuid,starts_at timestamptz,ends_at timestamptz,remaining integer) language plpgsql security definer set search_path='' as $$declare item public.marketplace_work_requests;begin
 select * into item from public.marketplace_work_requests where id=p_request and auth.uid() in(requester_id,provider_id);if item.id is null then raise exception 'Participant required';end if;
 return query select s.id,s.starts_at,s.ends_at,s.capacity-(select count(*)::integer from public.appointment_allocations a where a.slot_id=s.id and(a.state='confirmed' or(a.state='held' and a.expires_at>now()))) from public.provider_appointment_slots s where s.provider_id=item.provider_id and s.target_id=item.target_id and s.kind=item.kind and s.active and s.starts_at>now() order by s.starts_at limit 100;
end $$;
create function public.appointment_reserve(p_request uuid,p_slot uuid,p_key uuid) returns uuid language plpgsql security definer set search_path='' as $$declare caller uuid:=auth.uid();item public.marketplace_work_requests;slot public.provider_appointment_slots;prior public.appointment_allocations;saved uuid;provider uuid;begin
 if caller is null or not public.marketplace_complete_member() or not coalesce((select appointments_enabled from public.marketplace_allocation_settings where singleton),false) or p_key is null then raise exception 'Appointments disabled';end if;
 select provider_id into provider from public.marketplace_work_requests where id=p_request and requester_id=caller;if provider is null then raise exception 'Owned accepted request required';end if;
 perform pg_advisory_xact_lock(hashtextextended('appointment-provider:'||provider::text,0));select * into item from public.marketplace_work_requests where id=p_request for update;
 if item.state not in('accepted','contacted','shortlisted','enrolled') then raise exception 'Request not ready for appointment';end if;
 select * into prior from public.appointment_allocations where requester_id=caller and idempotency_key=p_key;if prior.id is not null then if prior.request_id<>p_request or prior.slot_id<>p_slot then raise exception 'Appointment key reused';end if;return prior.id;end if;
 if exists(select 1 from public.appointment_allocations where request_id=p_request and(state='confirmed' or(state='held' and expires_at>now()))) then raise exception 'Request already has an active allocation';end if;
 select * into slot from public.provider_appointment_slots where id=p_slot and provider_id=provider and target_id=item.target_id and kind=item.kind and active and starts_at>now() for update;
 if slot.id is null or (select count(*) from public.appointment_allocations where slot_id=p_slot and(state='confirmed' or(state='held' and expires_at>now())))>=slot.capacity then raise exception 'Slot unavailable';end if;
 insert into public.appointment_allocations(request_id,slot_id,requester_id,provider_id,idempotency_key,expires_at) values(p_request,p_slot,caller,provider,p_key,least(slot.starts_at,now()+interval '15 minutes')) returning id into saved;return saved;
end $$;
create function public.appointment_confirm(p_id uuid,p_intent uuid default null) returns void language plpgsql security definer set search_path='' as $$declare allocation public.appointment_allocations;item public.marketplace_work_requests;slot public.provider_appointment_slots;action text;begin
 select * into allocation from public.appointment_allocations where id=p_id and provider_id=auth.uid();if allocation.id is null or not public.marketplace_complete_member() or not coalesce((select appointments_enabled from public.marketplace_allocation_settings where singleton),false) then raise exception 'Enabled verified provider required';end if;
 perform pg_advisory_xact_lock(hashtextextended('appointment-provider:'||auth.uid()::text,0));select * into item from public.marketplace_work_requests where id=allocation.request_id for update;select * into allocation from public.appointment_allocations where id=p_id for update;select * into slot from public.provider_appointment_slots where id=allocation.slot_id for update;
 if allocation.state='confirmed' then return;end if;if allocation.state<>'held' or allocation.expires_at<=now() or not slot.active or slot.starts_at<=now() then raise exception 'Allocation expired';end if;
 if coalesce(item.quote_minor,0)>0 and not public.payment_covers(p_intent,'work',item.id,item.requester_id,item.quote_minor) then raise exception 'Verified appointment payment required';end if;
 update public.appointment_allocations set state='confirmed' where id=p_id;
 action:=case when item.kind='job' then 'interview' when item.kind in('property','service') then 'schedule' else null end;
 if action is not null then perform public.work_advance(item.id,item.revision,action,null,slot.starts_at);end if;
end $$;
create function public.appointment_request_guard() returns trigger language plpgsql security definer set search_path='' as $$begin
 if new.state in('scheduled','viewing_scheduled','interview_scheduled') and old.state is distinct from new.state and new.kind in('service','property','job') and coalesce((select appointments_enabled from public.marketplace_allocation_settings where singleton),false) and not exists(select 1 from public.appointment_allocations a join public.provider_appointment_slots s on s.id=a.slot_id where a.request_id=new.id and a.state='confirmed' and s.starts_at=new.appointment_at) then raise exception 'Confirmed allocated slot required';end if;
 if new.state in('withdrawn','cancelled') and old.state is distinct from new.state then
 if exists(select 1 from public.appointment_allocations where request_id=new.id and state='confirmed') and exists(select 1 from public.payment_intents where source_kind='work' and source_id=new.id and state in('settled','partially_refunded','reconciliation_required') and refunded_minor<amount_minor) then raise exception 'Verified refund required before paid appointment release';end if;
 update public.appointment_allocations set state='released' where request_id=new.id and state in('held','confirmed');end if;return new;
end $$;
create trigger appointment_request_allocation before update on public.marketplace_work_requests for each row execute function public.appointment_request_guard();
-- Food's 017/026 restaurant/menu locks already allocate finite stock; protect paid cancellation.
create function public.food_paid_cancellation_guard() returns trigger language plpgsql security definer set search_path='' as $$begin if new.state='cancelled' and old.state<>'cancelled' and exists(select 1 from public.payment_intents where source_kind='food' and source_id=new.id and state in('settled','partially_refunded','reconciliation_required') and refunded_minor<amount_minor) then raise exception 'Verified refund required before restoring paid food stock';end if;return new;end $$;
create trigger food_paid_allocation_guard before update on public.food_orders for each row execute function public.food_paid_cancellation_guard();
revoke all on function public.shop_allocation_used(uuid,text),public.reserve_shop_allocation(uuid,uuid),public.commit_shop_allocation(uuid,uuid),public.allocation_stock_guard(),public.allocation_reconcile_inventory(uuid,integer,jsonb),public.shop_allocation_order_guard(),public.appointment_create_slot(text,uuid,timestamptz,timestamptz,integer),public.appointment_availability(uuid),public.appointment_reserve(uuid,uuid,uuid),public.appointment_confirm(uuid,uuid),public.appointment_request_guard(),public.food_paid_cancellation_guard() from public,anon,authenticated,service_role;
grant execute on function public.reserve_shop_allocation(uuid,uuid),public.commit_shop_allocation(uuid,uuid),public.allocation_reconcile_inventory(uuid,integer,jsonb),public.appointment_create_slot(text,uuid,timestamptz,timestamptz,integer),public.appointment_availability(uuid),public.appointment_reserve(uuid,uuid,uuid),public.appointment_confirm(uuid,uuid) to authenticated;
grant execute on function public.commit_shop_allocation(uuid,uuid) to service_role;
commit;
