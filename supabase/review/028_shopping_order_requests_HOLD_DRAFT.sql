-- HOLD 028. Staging review required. Depends on 009/010 and corrected 014_v2.
-- Shopping order requests; NO payments, shipping assignment or automatic reservations.
-- Inventory remains seller-managed by 014; requests DO NOT reserve stock.
begin;
create table public.shop_order_settings(singleton boolean primary key default true check(singleton),enabled boolean not null default false);
insert into public.shop_order_settings values(true,false);
alter table public.shop_order_settings enable row level security;
revoke all on public.shop_order_settings from public,anon,authenticated,service_role;
grant select,update(enabled) on public.shop_order_settings to service_role;
create table public.shop_order_requests(
 id uuid primary key default gen_random_uuid(),buyer_id uuid not null references auth.users(id),seller_id uuid not null references auth.users(id),
 idempotency_key uuid not null,request jsonb not null,subtotal_minor bigint not null check(subtotal_minor>=0),currency text not null default 'ZMW' check(currency='ZMW'),
 state text not null default 'requested' check(state in('requested','acknowledged','preparing','ready','completed','cancelled')),
 revision bigint not null default 0,created_at timestamptz not null default now(),unique(buyer_id,idempotency_key),check(buyer_id<>seller_id)
);
create table public.shop_order_request_lines(
 order_id uuid not null references public.shop_order_requests(id),listing_id uuid not null references public.listings(id),title_snapshot text not null,option_label text,
 unit_minor bigint not null check(unit_minor>=0),quantity integer not null check(quantity between 1 and 20),primary key(order_id,listing_id)
);
create table public.shop_order_request_events(
 order_id uuid not null references public.shop_order_requests(id),revision bigint not null,actor_id uuid not null references auth.users(id),state text not null,created_at timestamptz not null default now(),primary key(order_id,revision)
);
create index shop_order_buyer_created on public.shop_order_requests(buyer_id,created_at desc);
create index shop_order_seller_created on public.shop_order_requests(seller_id,created_at desc);
alter table public.shop_order_requests enable row level security;alter table public.shop_order_request_lines enable row level security;alter table public.shop_order_request_events enable row level security;
revoke all on public.shop_order_requests,public.shop_order_request_lines,public.shop_order_request_events from public,anon,authenticated,service_role;
grant select on public.shop_order_requests,public.shop_order_request_lines,public.shop_order_request_events to authenticated;
create policy shop_order_participants on public.shop_order_requests for select to authenticated using((select auth.uid()) in(buyer_id,seller_id));
create policy shop_order_lines_participants on public.shop_order_request_lines for select to authenticated using(exists(select 1 from public.shop_order_requests o where o.id=order_id and (select auth.uid()) in(o.buyer_id,o.seller_id)));
create policy shop_order_events_participants on public.shop_order_request_events for select to authenticated using(exists(select 1 from public.shop_order_requests o where o.id=order_id and (select auth.uid()) in(o.buyer_id,o.seller_id)));
create function public.shop_workflow_capabilities() returns jsonb language sql stable security definer set search_path='' as $$select jsonb_build_object('version',1,'requests_enabled',coalesce((select enabled from public.shop_order_settings where singleton),false),'stock_reserved',false);$$;
create function public.shop_submit_order_request(p_lines jsonb,p_key uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();prior public.shop_order_requests;entry jsonb;product public.listings;stock public.listing_stock;option_value jsonb;seller uuid;qty integer;price numeric;total bigint:=0;new_id uuid;canonical jsonb:='[]';
begin
 if caller is null or not public.marketplace_complete_member() then raise exception 'Verified complete account required';end if;
 if not coalesce((select enabled from public.shop_order_settings where singleton),false) then raise exception 'Shopping order requests disabled';end if;
 if p_key is null or jsonb_typeof(p_lines) is distinct from 'array' or jsonb_array_length(p_lines) not between 1 and 20 then raise exception 'Use 1–20 products';end if;
 perform pg_advisory_xact_lock(hashtextextended('shop-order:'||caller::text,0));
 select * into prior from public.shop_order_requests where buyer_id=caller and idempotency_key=p_key;
 if prior.id is not null then if prior.request<>p_lines then raise exception 'Request key reused with different items';end if;return prior.id;end if;
 if (select count(*) from public.shop_order_requests where buyer_id=caller and state not in('completed','cancelled'))>=20 then raise exception 'Too many open requests';end if;
 if (select count(distinct value->>'listing_id') from jsonb_array_elements(p_lines))<>jsonb_array_length(p_lines) then raise exception 'Duplicate or missing listing';end if;
 -- Stable locks provide consistent price/stock snapshots. No stock is decremented or promised.
 perform id from public.listings where id in(select (value->>'listing_id')::uuid from jsonb_array_elements(p_lines)) order by id for share;
 perform listing_id from public.listing_stock where listing_id in(select (value->>'listing_id')::uuid from jsonb_array_elements(p_lines)) order by listing_id for share;
 for entry in select value from jsonb_array_elements(p_lines) loop
 if jsonb_typeof(entry) is distinct from 'object' or entry-array['listing_id','quantity','option']<>'{}'::jsonb or coalesce(entry->>'quantity','') !~ '^[0-9]{1,2}$' then raise exception 'Invalid line';end if;
 qty:=(entry->>'quantity')::integer;if qty not between 1 and 20 then raise exception 'Invalid quantity';end if;
 select * into product from public.listings where id=(entry->>'listing_id')::uuid;
 if product.id is null or product.deleted_at is not null or product.status is distinct from 'active' or product.user_id is null or product.user_id=caller or product.available_from>(now() at time zone 'Africa/Lusaka')::date then raise exception 'Listing unavailable';end if;
 if seller is null then seller:=product.user_id;elsif seller<>product.user_id then raise exception 'Submit one seller at a time';end if;
 select * into stock from public.listing_stock where listing_id=product.id and owner_id=seller;
 if stock.listing_id is null then raise exception 'Seller stock record required';end if;
 price:=product.price;
 if jsonb_array_length(stock.variants)>0 then
 select value into option_value from jsonb_array_elements(stock.variants) where value->>'label'=entry->>'option';
 if option_value is null or (option_value->>'quantity')::integer<qty then raise exception 'Choose an available variant';end if;
 if option_value->>'price' is not null then price:=(option_value->>'price')::numeric;end if;
 elsif coalesce(entry->>'option','')<>'' then raise exception 'This listing has no selectable variant';
 elsif stock.quantity<qty then raise exception 'Insufficient stated stock';end if;
 if price is null or price::text in('NaN','Infinity','-Infinity') or price<0 or price>1000000000 then raise exception 'Invalid current price';end if;
 total:=total+round(price*100)::bigint*qty;
 canonical:=canonical||jsonb_build_array(jsonb_build_object('listing_id',product.id,'title',product.title,'option',nullif(entry->>'option',''),'unit_minor',round(price*100)::bigint,'quantity',qty));
 end loop;
 insert into public.shop_order_requests(buyer_id,seller_id,idempotency_key,request,subtotal_minor) values(caller,seller,p_key,p_lines,total) returning id into new_id;
 insert into public.shop_order_request_lines select new_id,(value->>'listing_id')::uuid,value->>'title',value->>'option',(value->>'unit_minor')::bigint,(value->>'quantity')::integer from jsonb_array_elements(canonical);
 insert into public.shop_order_request_events values(new_id,0,caller,'requested',now());return new_id;
end $$;
create function public.shop_advance_order_request(p_id uuid,p_revision bigint,p_action text) returns jsonb language plpgsql security definer set search_path='' as $$
declare caller uuid:=auth.uid();item public.shop_order_requests;next_state text;
begin
 if caller is null or not public.marketplace_complete_member() then raise exception 'Verified complete account required';end if;
 select * into item from public.shop_order_requests where id=p_id and caller in(buyer_id,seller_id) for update;
 if item.id is null or item.revision is distinct from p_revision then raise exception 'Unavailable or stale request';end if;
 if p_action='cancel' and ((caller=item.buyer_id and item.state='requested') or (caller=item.seller_id and item.state not in('completed','cancelled'))) then next_state:='cancelled';
 elsif caller=item.seller_id and coalesce((select enabled from public.shop_order_settings where singleton),false) then
 next_state:=case when item.state='requested' and p_action='acknowledge' then 'acknowledged' when item.state='acknowledged' and p_action='prepare' then 'preparing' when item.state='preparing' and p_action='ready' then 'ready' when item.state='ready' and p_action='complete' then 'completed' end;
 end if;
 if next_state is null then raise exception 'Transition not permitted';end if;
 update public.shop_order_requests set state=next_state,revision=revision+1 where id=p_id;
 insert into public.shop_order_request_events values(p_id,item.revision+1,caller,next_state,now());
 return jsonb_build_object('id',p_id,'state',next_state,'revision',item.revision+1);
end $$;
revoke all on function public.shop_workflow_capabilities(),public.shop_submit_order_request(jsonb,uuid),public.shop_advance_order_request(uuid,bigint,text) from public,anon,authenticated,service_role;
grant execute on function public.shop_workflow_capabilities(),public.shop_submit_order_request(jsonb,uuid),public.shop_advance_order_request(uuid,bigint,text) to authenticated;
commit;
