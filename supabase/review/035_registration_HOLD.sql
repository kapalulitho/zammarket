-- HOLD. Optional registration ONLY after approved 035 exists. No schema/operation enabling.
do $$declare source text;expected oid:=to_regprocedure('public.operational_notification_emit()');actual oid;begin
 if expected is null or to_regclass('public.marketplace_operational_notifications') is null then raise exception 'Approved 035 prerequisite missing';end if;
 foreach source in array array['shop_order_requests','food_orders','delivery_jobs','marketplace_work_requests','stay_reservation_requests','event_reservations','marketplace_subscription_requests','marketplace_promotion_reviews','marketplace_work_messages','stay_reservation_messages','marketplace_review_events','marketplace_commission_entries'] loop
 if to_regclass('public.'||source) is not null then
 select tgfoid into actual from pg_trigger where tgrelid=to_regclass('public.'||source) and tgname='zammarket_operational_notice' and not tgisinternal;
 if actual is null then execute format('create trigger zammarket_operational_notice after insert or update on public.%I for each row execute function public.operational_notification_emit()',source);
 elsif actual<>expected then raise exception 'Unexpected notification trigger on %',source;end if;
 end if;end loop;
end $$;
