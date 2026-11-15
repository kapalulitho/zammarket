-- HOLD 036. Server-authoritative sandbox billing. No live provider, charge or scheduler enabled.
-- Requires 010,028,017,030,018,029,034. Source snapshots are immutable.
begin;
create table public.payment_runtime_settings(singleton boolean primary key default true check(singleton),sandbox_enabled boolean not null default false,live_enabled boolean not null default false check(not live_enabled));
insert into public.payment_runtime_settings values(true,false,false);alter table public.payment_runtime_settings enable row level security;revoke all on public.payment_runtime_settings from public,anon,authenticated,service_role;grant select,update(sandbox_enabled) on public.payment_runtime_settings to service_role;
create table public.billing_subscriptions(id uuid primary key default gen_random_uuid(),owner_id uuid not null references auth.users(id),request_id uuid not null unique references public.marketplace_subscription_requests(id),plan_code text not null references public.marketplace_plan_catalogue(code),state text not null default 'pending' check(state in('pending','active','past_due','cancelled')),cancel_at_period_end boolean not null default false,period_end timestamptz,created_at timestamptz not null default now());
create table public.billing_cycles(id uuid primary key default gen_random_uuid(),subscription_id uuid not null references public.billing_subscriptions(id),owner_id uuid not null references auth.users(id),starts_at timestamptz not null,ends_at timestamptz not null,amount_minor bigint not null check(amount_minor between 0 and 100000000000),currency text not null default 'ZMW' check(currency='ZMW'),state text not null default 'due' check(state in('due','paid','void')),unique(subscription_id,starts_at),check(ends_at>starts_at));
create table public.payment_intents(id uuid primary key default gen_random_uuid(),payer_id uuid not null references auth.users(id),payee_id uuid references auth.users(id),source_kind text not null check(source_kind in('shopping','food','stay','event','work','billing')),source_id uuid not null,amount_minor bigint not null check(amount_minor between 1 and 100000000000),currency text not null default 'ZMW' check(currency='ZMW'),state text not null default 'created' check(state in('created','provider_pending','authorized','settled','failed','cancelled','partially_refunded','refunded','reconciliation_required')),refunded_minor bigint not null default 0 check(refunded_minor>=0 and refunded_minor<=amount_minor),idempotency_key uuid not null,quote_expires_at timestamptz not null,created_at timestamptz not null default now(),unique(payer_id,idempotency_key),unique(source_kind,source_id));
create table public.payment_attempts(id uuid primary key default gen_random_uuid(),intent_id uuid not null references public.payment_intents(id),provider text not null,channel text not null check(channel in('mobile_money','card')),merchant_id text not null,provider_reference text,amount_minor bigint not null,currency text not null check(currency='ZMW'),state text not null default 'created',created_at timestamptz not null default now(),unique(provider,provider_reference));
create table public.payment_provider_events(provider text not null,event_id text not null,attempt_id uuid not null references public.payment_attempts(id),event_type text not null,amount_minor bigint not null,currency text not null,verified_at timestamptz not null default now(),primary key(provider,event_id));
create table public.payment_refund_requests(id uuid primary key default gen_random_uuid(),intent_id uuid not null references public.payment_intents(id),payer_id uuid not null references auth.users(id),amount_minor bigint not null check(amount_minor>0),reason text not null check(length(btrim(reason)) between 5 and 1000),idempotency_key uuid not null,state text not null default 'requested' check(state in('requested','approved','processing','succeeded','failed','rejected')),provider_reference text unique,created_at timestamptz not null default now(),unique(payer_id,idempotency_key));
create table public.payment_reconciliation(id uuid primary key default gen_random_uuid(),intent_id uuid not null references public.payment_intents(id),provider text not null,report_reference text not null unique,reported_minor bigint not null,currency text not null,matched boolean not null,created_at timestamptz not null default now());
alter table public.billing_subscriptions enable row level security;alter table public.billing_cycles enable row level security;alter table public.payment_intents enable row level security;alter table public.payment_attempts enable row level security;alter table public.payment_provider_events enable row level security;alter table public.payment_refund_requests enable row level security;alter table public.payment_reconciliation enable row level security;
revoke all on public.billing_subscriptions,public.billing_cycles,public.payment_intents,public.payment_attempts,public.payment_provider_events,public.payment_refund_requests,public.payment_reconciliation from public,anon,authenticated,service_role;
grant select on public.billing_subscriptions,public.billing_cycles,public.payment_intents,public.payment_refund_requests to authenticated;
create policy billing_owner on public.billing_subscriptions for select to authenticated using(owner_id=(select auth.uid()));create policy cycle_owner on public.billing_cycles for select to authenticated using(owner_id=(select auth.uid()));
create policy intent_participants on public.payment_intents for select to authenticated using((select auth.uid()) in(payer_id,payee_id) or public.admin_operations_allowed());create policy refund_owner on public.payment_refund_requests for select to authenticated using(payer_id=(select auth.uid()) or public.admin_operations_allowed());
create index intents_payer_created on public.payment_intents(payer_id,created_at desc);create index refunds_intent on public.payment_refund_requests(intent_id,state);
create function public.payment_source(p_kind text,p_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$declare item jsonb;begin
 case p_kind
 when 'shopping' then select jsonb_build_object('payer',buyer_id,'payee',seller_id,'amount',subtotal_minor,'valid',state not in('cancelled','completed')) into item from public.shop_order_requests where id=p_id;
 when 'food' then select jsonb_build_object('payer',customer_id,'payee',merchant_id,'amount',total_minor,'valid',state not in('cancelled','completed')) into item from public.food_orders where id=p_id;
 when 'stay' then select jsonb_build_object('payer',guest_id,'payee',host_id,'amount',subtotal_minor,'valid',state in('requested','confirmed') and check_in>=(now() at time zone 'Africa/Lusaka')::date) into item from public.stay_reservation_requests where id=p_id;
 when 'event' then select jsonb_build_object('payer',buyer_id,'payee',organiser_id,'amount',quantity*unit_price_minor,'valid',state='held') into item from public.event_reservations where id=p_id;
 when 'work' then select jsonb_build_object('payer',r.requester_id,'payee',r.provider_id,'amount',coalesce(r.quote_minor,round(e.price*100)::bigint),'valid',r.state in('accepted','enrolled','scheduled','awaiting_verification')) into item from public.marketplace_work_requests r left join public.community_entries e on e.id=r.target_id and e.kind='learning' where r.id=p_id;
 when 'billing' then select jsonb_build_object('payer',owner_id,'payee',null,'amount',amount_minor,'valid',state='due') into item from public.billing_cycles where id=p_id;
 else raise exception 'Unsupported payment source';end case;return item;end $$;
create function public.payment_covers(p_intent uuid,p_kind text,p_source uuid,p_payer uuid,p_amount bigint) returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from public.payment_intents where id=p_intent and source_kind=p_kind and source_id=p_source and payer_id=p_payer and amount_minor=p_amount and currency='ZMW' and state='settled' and refunded_minor=0);$$;
create function public.payment_create_intent(p_kind text,p_source uuid,p_key uuid) returns uuid language plpgsql security definer set search_path='' as $$declare caller uuid:=auth.uid();source jsonb;prior public.payment_intents;saved uuid;begin
 if caller is null or not public.marketplace_complete_member() or not coalesce((select sandbox_enabled from public.payment_runtime_settings where singleton),false) then raise exception 'Sandbox payments disabled';end if;
 if p_key is null then raise exception 'Request key required';end if;perform pg_advisory_xact_lock(hashtextextended('payment-payer:'||caller::text,0));
 select * into prior from public.payment_intents where payer_id=caller and idempotency_key=p_key;
 if prior.id is not null then if prior.source_kind is distinct from p_kind or prior.source_id is distinct from p_source then raise exception 'Key reused';end if;return prior.id;end if;
 source:=public.payment_source(p_kind,p_source);if source is null or (source->>'payer')::uuid is distinct from caller or not coalesce((source->>'valid')::boolean,false) or (source->>'amount') is null or (source->>'amount')::bigint not between 1 and 100000000000 then raise exception 'Valid positive server-priced source required';end if;
 select * into prior from public.payment_intents where source_kind=p_kind and source_id=p_source;
 if prior.id is not null then if prior.payer_id<>caller then raise exception 'Source unavailable';end if;return prior.id;end if;
 if (select count(*) from public.payment_intents where payer_id=caller and created_at>now()-interval '1 day')>=50 then raise exception 'Payment intent limit reached';end if;
 insert into public.payment_intents(payer_id,payee_id,source_kind,source_id,amount_minor,idempotency_key,quote_expires_at) values(caller,(source->>'payee')::uuid,p_kind,p_source,(source->>'amount')::bigint,p_key,now()+interval '15 minutes') returning id into saved;return saved;
end $$;
-- Server-only adapter work; no client can choose provider references or report success.
create function public.payment_begin_attempt(p_intent uuid,p_provider text,p_channel text,p_merchant text) returns jsonb language plpgsql security definer set search_path='' as $$declare item public.payment_intents;attempt public.payment_attempts;begin
 if not coalesce((select sandbox_enabled from public.payment_runtime_settings where singleton),false) then raise exception 'Sandbox disabled';end if;
 select * into item from public.payment_intents where id=p_intent for update;
 if item.id is null or item.quote_expires_at<=now() or item.state not in('created','provider_pending','failed') or length(p_provider) not between 2 and 50 or length(p_merchant) not between 2 and 100 or p_channel not in('mobile_money','card') then raise exception 'Payment intent unavailable';end if;
 select * into attempt from public.payment_attempts where intent_id=p_intent and state in('created','pending') order by created_at desc limit 1;
 if attempt.id is not null then if attempt.provider<>p_provider or attempt.channel<>p_channel then raise exception 'Existing attempt must be resolved first';end if;else insert into public.payment_attempts(intent_id,provider,channel,merchant_id,amount_minor,currency) values(p_intent,p_provider,p_channel,p_merchant,item.amount_minor,'ZMW') returning * into attempt;end if;
 update public.payment_intents set state='provider_pending' where id=p_intent;return jsonb_build_object('attempt_id',attempt.id,'amount_minor',item.amount_minor,'currency','ZMW','payer_id',item.payer_id);
end $$;
create function public.payment_bind_reference(p_attempt uuid,p_reference text) returns void language plpgsql security definer set search_path='' as $$begin
 if length(p_reference) not between 3 and 200 then raise exception 'Provider reference required';end if;
 update public.payment_attempts set provider_reference=p_reference,state='pending' where id=p_attempt and state in('created','pending') and (provider_reference is null or provider_reference=p_reference);if not found then raise exception 'Attempt unavailable';end if;
end $$;
create function public.payment_apply_verified_event(p_attempt uuid,p_provider text,p_merchant text,p_reference text,p_event text,p_type text,p_amount bigint,p_currency text) returns jsonb language plpgsql security definer set search_path='' as $$declare attempt public.payment_attempts;item public.payment_intents;prior public.payment_provider_events;begin
 if not coalesce((select sandbox_enabled from public.payment_runtime_settings where singleton),false) then raise exception 'Sandbox disabled';end if;
 select * into attempt from public.payment_attempts where id=p_attempt for update;if attempt.id is null then raise exception 'Attempt unavailable';end if;
 select * into item from public.payment_intents where id=attempt.intent_id for update;
 select * into prior from public.payment_provider_events where provider=p_provider and event_id=p_event;
 if prior.event_id is not null then if prior.attempt_id<>p_attempt or prior.event_type<>p_type or prior.amount_minor<>p_amount or prior.currency<>p_currency then raise exception 'Event identity conflict';end if;return jsonb_build_object('id',item.id,'state',item.state,'duplicate',true);end if;
 if p_provider is distinct from attempt.provider or p_merchant is distinct from attempt.merchant_id or p_reference is distinct from attempt.provider_reference or length(p_event) not between 1 and 200 or p_type not in('authorized','settled','failed','cancelled') then raise exception 'Event binding failed';end if;
 insert into public.payment_provider_events values(p_provider,p_event,p_attempt,p_type,p_amount,p_currency,now());
 if p_amount is distinct from attempt.amount_minor or p_currency is distinct from 'ZMW' then update public.payment_intents set state='reconciliation_required' where id=item.id;return jsonb_build_object('id',item.id,'state','reconciliation_required');end if;
 if item.state='reconciliation_required' then null;
 elsif attempt.state='settled' and p_type<>'settled' then update public.payment_intents set state='reconciliation_required' where id=item.id;
 elsif item.state in('settled','partially_refunded','refunded') then
 if p_type='settled' and attempt.state<>'settled' then update public.payment_intents set state='reconciliation_required' where id=item.id;end if;
 else update public.payment_intents set state=p_type where id=item.id;end if;
 if attempt.state<>'settled' or p_type='settled' then update public.payment_attempts set state=p_type where id=p_attempt;end if;
 return jsonb_build_object('id',item.id,'state',(select state from public.payment_intents where id=item.id));
end $$;
create function public.payment_request_refund(p_intent uuid,p_amount bigint,p_reason text,p_key uuid) returns uuid language plpgsql security definer set search_path='' as $$declare caller uuid:=auth.uid();item public.payment_intents;prior public.payment_refund_requests;saved uuid;reserved bigint;begin
 if caller is null or not public.marketplace_complete_member() then raise exception 'Verified payer required';end if;
 select * into item from public.payment_intents where id=p_intent and payer_id=caller for update;
 if item.id is null or item.state not in('settled','partially_refunded') or p_key is null or p_amount is null or p_amount<1 or p_reason is null or length(btrim(p_reason)) not between 5 and 1000 then raise exception 'Valid refundable payment required';end if;
 select * into prior from public.payment_refund_requests where payer_id=caller and idempotency_key=p_key;if prior.id is not null then if prior.intent_id<>p_intent or prior.amount_minor<>p_amount or prior.reason<>btrim(p_reason) then raise exception 'Refund key reused';end if;return prior.id;end if;
 select coalesce(sum(amount_minor),0) into reserved from public.payment_refund_requests where intent_id=p_intent and state in('requested','approved','processing');
 if item.refunded_minor+reserved+p_amount>item.amount_minor then raise exception 'Refund exceeds remaining amount';end if;
 insert into public.payment_refund_requests(intent_id,payer_id,amount_minor,reason,idempotency_key) values(p_intent,caller,p_amount,btrim(p_reason),p_key) returning id into saved;return saved;
end $$;
create function public.payment_approve_refund(p_id uuid,p_approve boolean) returns void language plpgsql security definer set search_path='' as $$begin
 if not public.admin_operations_allowed() then raise exception 'MFA administrator required';end if;
 update public.payment_refund_requests set state=case when p_approve then 'approved' else 'rejected' end where id=p_id and state='requested' and payer_id<>auth.uid();if not found then raise exception 'Refund review unavailable';end if;
end $$;
create function public.payment_refund_work(p_id uuid,p_reference text,p_succeeded boolean default null) returns jsonb language plpgsql security definer set search_path='' as $$declare refund public.payment_refund_requests;item public.payment_intents;begin
 if not coalesce((select sandbox_enabled from public.payment_runtime_settings where singleton),false) then raise exception 'Sandbox disabled';end if;
 select intent_id into item.id from public.payment_refund_requests where id=p_id;
 select * into item from public.payment_intents where id=item.id for update;
 select * into refund from public.payment_refund_requests where id=p_id for update;
 if refund.id is null or length(p_reference) not between 3 and 200 then raise exception 'Refund unavailable';end if;
 if refund.state='succeeded' then if refund.provider_reference<>p_reference then raise exception 'Refund binding mismatch';end if;return jsonb_build_object('id',p_id,'state','succeeded');end if;
 if p_succeeded is null then
 if refund.state not in('approved','processing') or (refund.provider_reference is not null and refund.provider_reference<>p_reference) then raise exception 'Refund not approved';end if;
 update public.payment_refund_requests set state='processing',provider_reference=p_reference where id=p_id;
 else
 if refund.state<>'processing' or refund.provider_reference is distinct from p_reference then raise exception 'Refund callback binding mismatch';end if;
 if p_succeeded then update public.payment_intents set refunded_minor=refunded_minor+refund.amount_minor,state=case when refunded_minor+refund.amount_minor=amount_minor then 'refunded' else 'partially_refunded' end where id=item.id;end if;
 update public.payment_refund_requests set state=case when p_succeeded then 'succeeded' else 'failed' end where id=p_id;
 end if;return jsonb_build_object('id',p_id,'intent_id',item.id,'provider',(select provider from public.payment_attempts where intent_id=item.id and state='settled' order by created_at desc limit 1),'merchant_id',(select merchant_id from public.payment_attempts where intent_id=item.id and state='settled' order by created_at desc limit 1),'channel',(select channel from public.payment_attempts where intent_id=item.id and state='settled' order by created_at desc limit 1),'payment_reference',(select provider_reference from public.payment_attempts where intent_id=item.id and state='settled' order by created_at desc limit 1),'amount_minor',refund.amount_minor,'state',(select state from public.payment_refund_requests where id=p_id));
end $$;
create function public.payment_reconcile(p_intent uuid,p_provider text,p_report text,p_amount bigint,p_currency text) returns boolean language plpgsql security definer set search_path='' as $$declare item public.payment_intents;matched boolean;prior public.payment_reconciliation;begin
 select * into item from public.payment_intents where id=p_intent for update;if item.id is null then raise exception 'Intent unavailable';end if;
 select * into prior from public.payment_reconciliation where report_reference=p_report;if prior.id is not null then if prior.intent_id<>p_intent or prior.provider<>p_provider or prior.reported_minor<>p_amount or prior.currency<>p_currency then raise exception 'Reconciliation identity conflict';end if;return prior.matched;end if;
 matched:=exists(select 1 from public.payment_attempts where intent_id=p_intent and provider=p_provider and state='settled') and p_currency='ZMW' and p_amount=item.amount_minor-item.refunded_minor and item.state in('settled','partially_refunded','refunded');
 insert into public.payment_reconciliation(intent_id,provider,report_reference,reported_minor,currency,matched) values(p_intent,p_provider,p_report,p_amount,p_currency,coalesce(matched,false)) on conflict(report_reference) do nothing;
 if not coalesce(matched,false) then update public.payment_intents set state='reconciliation_required' where id=p_intent;end if;return coalesce(matched,false);
end $$;
create function public.billing_prepare_cycle(p_request uuid,p_start timestamptz,p_end timestamptz) returns uuid language plpgsql security definer set search_path='' as $$declare request public.marketplace_subscription_requests;sub public.billing_subscriptions;price bigint;saved uuid;begin
 if not coalesce((select sandbox_enabled from public.payment_runtime_settings where singleton),false) or p_start is null or p_end is null or p_end<=p_start or p_end is distinct from p_start+interval '1 month' then raise exception 'Valid sandbox billing period required';end if;
 select * into request from public.marketplace_subscription_requests where id=p_request and state='approved' for update;if request.id is null then raise exception 'Approved package request required';end if;
 select monthly_minor into price from public.marketplace_plan_catalogue where code=request.plan_code;if price is null or price<=0 then raise exception 'Approved positive catalogue price required';end if;
 insert into public.billing_subscriptions(owner_id,request_id,plan_code) values(request.owner_id,p_request,request.plan_code) on conflict(request_id) do nothing;
 select * into sub from public.billing_subscriptions where request_id=p_request for update;
 if sub.state='cancelled' or sub.cancel_at_period_end then raise exception 'Subscription cancelled';end if;
 if exists(select 1 from public.billing_cycles where subscription_id=sub.id and starts_at<p_end and ends_at>p_start and starts_at<>p_start and state<>'void') then raise exception 'Billing periods overlap';end if;
 insert into public.billing_cycles(subscription_id,owner_id,starts_at,ends_at,amount_minor) values(sub.id,sub.owner_id,p_start,p_end,price) on conflict(subscription_id,starts_at) do nothing;
 select id into saved from public.billing_cycles where subscription_id=sub.id and starts_at=p_start and ends_at=p_end and amount_minor=price;if saved is null then raise exception 'Billing period terms changed';end if;return saved;
end $$;
create function public.billing_apply_settlement(p_cycle uuid,p_intent uuid) returns void language plpgsql security definer set search_path='' as $$declare item public.billing_cycles;begin
 select * into item from public.billing_cycles where id=p_cycle for update;
 if item.id is null or item.state='void' or not public.payment_covers(p_intent,'billing',p_cycle,item.owner_id,item.amount_minor) then raise exception 'Verified cycle settlement required';end if;
 update public.billing_cycles set state='paid' where id=p_cycle;update public.billing_subscriptions set state='active',period_end=greatest(coalesce(period_end,item.ends_at),item.ends_at) where id=item.subscription_id;
end $$;
create function public.billing_cancel_subscription(p_id uuid) returns void language plpgsql security definer set search_path='' as $$begin update public.billing_subscriptions set cancel_at_period_end=true,state=case when period_end is null or period_end<=now() then 'cancelled' else state end where id=p_id and owner_id=auth.uid();if not found then raise exception 'Owned subscription required';end if;end $$;
-- Signed refund callbacks are bound to the original settled attempt, amount and
-- server-created refund reference. Contradictory terminal events are retained
-- for reconciliation rather than silently rewriting financial history.
create function public.payment_apply_refund_event(p_refund uuid,p_provider text,p_merchant text,p_event text,p_reference text,p_amount bigint,p_currency text,p_succeeded boolean) returns jsonb language plpgsql security definer set search_path='' as $$declare refund public.payment_refund_requests;item public.payment_intents;attempt public.payment_attempts;prior public.payment_provider_events;begin
 if not coalesce((select sandbox_enabled from public.payment_runtime_settings where singleton),false) then raise exception 'Sandbox disabled';end if;
 select intent_id into item.id from public.payment_refund_requests where id=p_refund;
 select * into item from public.payment_intents where id=item.id for update;
 select * into refund from public.payment_refund_requests where id=p_refund for update;
 select * into attempt from public.payment_attempts where intent_id=item.id and state='settled' order by created_at desc limit 1 for update;
 if refund.id is null or item.id is null or attempt.id is null or p_provider is distinct from attempt.provider or p_merchant is distinct from attempt.merchant_id or p_reference is distinct from refund.provider_reference or p_amount is distinct from refund.amount_minor or p_currency is distinct from 'ZMW' or length(p_event) not between 1 and 200 then raise exception 'Refund event binding failed';end if;
 select * into prior from public.payment_provider_events where provider=p_provider and event_id=p_event;
 if prior.event_id is not null then if prior.attempt_id<>attempt.id or prior.event_type<>case when p_succeeded then 'refund_succeeded' else 'refund_failed' end or prior.amount_minor<>p_amount or prior.currency<>p_currency then raise exception 'Refund event identity conflict';end if;return jsonb_build_object('id',refund.id,'state',refund.state,'duplicate',true);end if;
 insert into public.payment_provider_events(provider,event_id,attempt_id,event_type,amount_minor,currency) values(p_provider,p_event,attempt.id,case when p_succeeded then 'refund_succeeded' else 'refund_failed' end,p_amount,p_currency);
 if refund.state='processing' then
  if p_succeeded then update public.payment_intents set refunded_minor=refunded_minor+refund.amount_minor,state=case when refunded_minor+refund.amount_minor=amount_minor then 'refunded' else 'partially_refunded' end where id=item.id and refunded_minor+refund.amount_minor<=amount_minor; if not found then raise exception 'Refund total invalid';end if;end if;
  update public.payment_refund_requests set state=case when p_succeeded then 'succeeded' else 'failed' end where id=refund.id;
 elsif (refund.state='succeeded' and not p_succeeded) or (refund.state='failed' and p_succeeded) then
  update public.payment_intents set state='reconciliation_required' where id=item.id;
 elsif refund.state<>case when p_succeeded then 'succeeded' else 'failed' end then raise exception 'Refund is not processing';end if;
 return jsonb_build_object('id',refund.id,'intent_id',item.id,'state',(select state from public.payment_refund_requests where id=refund.id));
end $$;
create function public.payment_reconciliation_work(p_intent uuid) returns jsonb language plpgsql security definer set search_path='' as $$declare item public.payment_intents;attempt public.payment_attempts;begin
 if not coalesce((select sandbox_enabled from public.payment_runtime_settings where singleton),false) then raise exception 'Sandbox disabled';end if;
 select * into item from public.payment_intents where id=p_intent;if item.id is null then raise exception 'Intent unavailable';end if;
 select * into attempt from public.payment_attempts where intent_id=p_intent and state='settled' order by created_at desc limit 1;if attempt.id is null or attempt.provider_reference is null then raise exception 'Settled attempt required';end if;
 return jsonb_build_object('intent_id',item.id,'provider',attempt.provider,'channel',attempt.channel,'merchant_id',attempt.merchant_id,'reference',attempt.provider_reference,'amount_minor',item.amount_minor-item.refunded_minor,'currency','ZMW');
end $$;
revoke all on function public.payment_source(text,uuid),public.payment_covers(uuid,text,uuid,uuid,bigint),public.payment_create_intent(text,uuid,uuid),public.payment_begin_attempt(uuid,text,text,text),public.payment_bind_reference(uuid,text),public.payment_apply_verified_event(uuid,text,text,text,text,text,bigint,text),public.payment_request_refund(uuid,bigint,text,uuid),public.payment_approve_refund(uuid,boolean),public.payment_refund_work(uuid,text,boolean),public.payment_reconcile(uuid,text,text,bigint,text),public.billing_prepare_cycle(uuid,timestamptz,timestamptz),public.billing_apply_settlement(uuid,uuid),public.billing_cancel_subscription(uuid),public.payment_apply_refund_event(uuid,text,text,text,text,bigint,text,boolean),public.payment_reconciliation_work(uuid) from public,anon,authenticated,service_role;
grant execute on function public.payment_create_intent(text,uuid,uuid),public.payment_request_refund(uuid,bigint,text,uuid),public.payment_approve_refund(uuid,boolean),public.billing_cancel_subscription(uuid) to authenticated;
grant execute on function public.payment_begin_attempt(uuid,text,text,text),public.payment_bind_reference(uuid,text),public.payment_apply_verified_event(uuid,text,text,text,text,text,bigint,text),public.payment_refund_work(uuid,text,boolean),public.payment_reconcile(uuid,text,text,bigint,text),public.billing_prepare_cycle(uuid,timestamptz,timestamptz),public.billing_apply_settlement(uuid,uuid),public.payment_apply_refund_event(uuid,text,text,text,text,bigint,text,boolean),public.payment_reconciliation_work(uuid) to service_role;
commit;
