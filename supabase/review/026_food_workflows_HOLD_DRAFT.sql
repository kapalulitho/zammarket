-- HOLD 026: NEW Food lifecycle/catalogue extension. Requires approved 017 + 010.
-- Not applied. No production changes. Existing food operational gate stays false.
begin;
set local lock_timeout='5s';
create table public.food_order_events(
 order_id uuid not null references public.food_orders(id),revision bigint not null,
 actor_id uuid not null references auth.users(id),from_state text not null,to_state text not null,
 created_at timestamptz not null default now(),primary key(order_id,revision)
);
alter table public.food_order_events enable row level security;
revoke all on public.food_order_events from public,anon,authenticated,service_role;
grant select on public.food_order_events to authenticated;
create policy food_event_participants on public.food_order_events for select to authenticated using(exists(select 1 from public.food_orders o where o.id=order_id and (select auth.uid()) in(o.customer_id,o.merchant_id)));
create function public.food_workflow_capabilities() returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('version',1,'catalogue',true,'orders_enabled',coalesce((select enabled from public.food_operation_settings where singleton),false));
$$;
create function public.food_save_restaurant(p_id uuid,p_fields jsonb) returns uuid language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();saved uuid;
begin
 if caller is null or not public.marketplace_complete_member() then raise exception 'Verified complete account required';end if;
 if jsonb_typeof(p_fields) is distinct from 'object' or p_fields-array['name','location','cuisine','hours']<>'{}'::jsonb then raise exception 'Unsupported restaurant fields';end if;
 perform pg_advisory_xact_lock(hashtextextended('food-restaurant-owner:'||caller::text,0));
 if p_id is null then
 if (select count(*) from public.food_restaurants where owner_id=caller)>=20 then raise exception 'Restaurant limit reached';end if;
 insert into public.food_restaurants(owner_id,name,location,cuisine,hours) values(caller,btrim(p_fields->>'name'),btrim(p_fields->>'location'),btrim(p_fields->>'cuisine'),coalesce(p_fields->>'hours','')) returning id into saved;
 else
 update public.food_restaurants set name=btrim(p_fields->>'name'),location=btrim(p_fields->>'location'),cuisine=btrim(p_fields->>'cuisine'),hours=coalesce(p_fields->>'hours','') where id=p_id and owner_id=caller returning id into saved;
 end if;
 if saved is null then raise exception 'Restaurant unavailable';end if;return saved;
end $$;
create function public.food_save_menu_item(p_restaurant uuid,p_id uuid,p_fields jsonb) returns uuid language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();saved uuid;
begin
 if caller is null or not public.marketplace_complete_member() then raise exception 'Verified complete account required';end if;
 perform id from public.food_restaurants where id=p_restaurant and owner_id=caller for update;
 if not found then raise exception 'Owner required';end if;
 if jsonb_typeof(p_fields) is distinct from 'object' or p_fields-array['name','description','category','allergens','price_minor','available','units']<>'{}'::jsonb then raise exception 'Unsupported menu fields';end if;
 if p_id is not null and exists(select 1 from public.food_order_lines l join public.food_orders o on o.id=l.order_id where l.item_id=p_id and o.state not in('completed','cancelled')) then raise exception 'Finish or cancel open orders before editing this dish';end if;
 if p_id is null then
 if (select count(*) from public.food_menu_items where restaurant_id=p_restaurant)>=200 then raise exception 'Menu limit reached';end if;
 insert into public.food_menu_items(restaurant_id,name,description,category,allergens,price_minor,available,units) values(p_restaurant,btrim(p_fields->>'name'),coalesce(p_fields->>'description',''),coalesce(p_fields->>'category',''),btrim(p_fields->>'allergens'),(p_fields->>'price_minor')::bigint,coalesce((p_fields->>'available')::boolean,false),(p_fields->>'units')::integer) returning id into saved;
 else
 update public.food_menu_items set name=btrim(p_fields->>'name'),description=coalesce(p_fields->>'description',''),category=coalesce(p_fields->>'category',''),allergens=btrim(p_fields->>'allergens'),price_minor=(p_fields->>'price_minor')::bigint,available=coalesce((p_fields->>'available')::boolean,false),units=(p_fields->>'units')::integer where id=p_id and restaurant_id=p_restaurant returning id into saved;
 end if;
 if saved is null then raise exception 'Dish unavailable';end if;return saved;
end $$;
create function public.food_advance_order(p_id uuid,p_revision bigint,p_action text) returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();item public.food_orders;target uuid;next_state text;
begin
 if caller is null or not public.marketplace_complete_member() then raise exception 'Verified complete account required';end if;
 select restaurant_id into target from public.food_orders where id=p_id and caller in(customer_id,merchant_id);
 if target is null then raise exception 'Order unavailable';end if;
 -- Same restaurant-first lock order as 017 order creation and menu editing.
 perform id from public.food_restaurants where id=target for update;
 select * into item from public.food_orders where id=p_id for update;
 if item.revision is distinct from p_revision then raise exception 'Order changed; refresh before retrying';end if;
 if p_action='cancel' and ((caller=item.customer_id and item.state='submitted') or (caller=item.merchant_id and item.state not in('completed','cancelled'))) then next_state:='cancelled';
 elsif caller=item.merchant_id and coalesce((select enabled from public.food_operation_settings where singleton),false) then
 next_state:=case when item.state='submitted' and p_action='accept' then 'accepted' when item.state='accepted' and p_action='prepare' then 'preparing' when item.state='preparing' and p_action='ready' then 'ready' when item.state='ready' and p_action='complete' then 'completed' end;
 end if;
 if next_state is null then raise exception 'Transition not permitted';end if;
 if next_state='cancelled' then
 perform m.id from public.food_menu_items m join public.food_order_lines l on l.item_id=m.id where l.order_id=p_id order by m.id for update of m;
 update public.food_menu_items m set units=m.units+l.quantity from public.food_order_lines l where l.order_id=p_id and l.item_id=m.id and m.units is not null;
 end if;
 update public.food_orders set state=next_state,revision=revision+1 where id=p_id;
 insert into public.food_order_events(order_id,revision,actor_id,from_state,to_state) values(p_id,item.revision+1,caller,item.state,next_state);
 return jsonb_build_object('id',p_id,'state',next_state,'revision',item.revision+1);
end $$;
revoke all on function public.food_workflow_capabilities(),public.food_save_restaurant(uuid,jsonb),public.food_save_menu_item(uuid,uuid,jsonb),public.food_advance_order(uuid,bigint,text) from public,anon,authenticated,service_role;
grant execute on function public.food_workflow_capabilities(),public.food_save_restaurant(uuid,jsonb),public.food_save_menu_item(uuid,uuid,jsonb),public.food_advance_order(uuid,bigint,text) to authenticated;
commit;
