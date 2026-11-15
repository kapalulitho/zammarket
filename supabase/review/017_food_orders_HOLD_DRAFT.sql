-- HOLD / REVIEW ONLY. New Food foundations; no existing objects/data changed.
-- Requires existing verified-member helper. Operational gate stays FALSE after commit.
-- No frontend wiring, payment integration, tax/delivery quote or cleanup activation.
BEGIN;
SET LOCAL lock_timeout='5s';SET LOCAL statement_timeout='60s';
CREATE TABLE public.food_operation_settings(singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),enabled boolean NOT NULL DEFAULT false);
INSERT INTO public.food_operation_settings VALUES(true,false);
ALTER TABLE public.food_operation_settings ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.food_operation_settings FROM public,anon,authenticated,service_role;
GRANT SELECT,UPDATE(enabled) ON public.food_operation_settings TO service_role;
CREATE TABLE public.food_restaurants(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),owner_id uuid NOT NULL REFERENCES auth.users(id),
 name text NOT NULL CHECK(length(trim(name)) BETWEEN 3 AND 100),location text NOT NULL CHECK(length(trim(location)) BETWEEN 2 AND 200),
 cuisine text NOT NULL CHECK(length(cuisine)<=80),hours text NOT NULL DEFAULT '' CHECK(length(hours)<=300),
 status text NOT NULL DEFAULT 'draft' CHECK(status IN('draft','published','closed')),
 approved boolean NOT NULL DEFAULT false,accepting_orders boolean NOT NULL DEFAULT false,created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.food_menu_items(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),restaurant_id uuid NOT NULL REFERENCES public.food_restaurants(id),
 name text NOT NULL CHECK(length(trim(name)) BETWEEN 2 AND 120),description text NOT NULL DEFAULT '' CHECK(length(description)<=1000),
 allergens text NOT NULL CHECK(length(trim(allergens)) BETWEEN 2 AND 500),category text NOT NULL DEFAULT '' CHECK(length(category)<=80),
 price_minor bigint NOT NULL CHECK(price_minor BETWEEN 0 AND 100000000),currency text NOT NULL DEFAULT 'ZMW' CHECK(currency='ZMW'),
 available boolean NOT NULL DEFAULT false,units integer CHECK(units BETWEEN 0 AND 1000000)
);
CREATE TABLE public.food_orders(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),restaurant_id uuid NOT NULL REFERENCES public.food_restaurants(id),
 customer_id uuid NOT NULL REFERENCES auth.users(id),merchant_id uuid NOT NULL REFERENCES auth.users(id),
 idempotency_key uuid NOT NULL,request jsonb NOT NULL,total_minor bigint NOT NULL CHECK(total_minor>=0),
 currency text NOT NULL DEFAULT 'ZMW' CHECK(currency='ZMW'),state text NOT NULL DEFAULT 'submitted' CHECK(state IN('submitted','accepted','preparing','ready','completed','cancelled')),
 revision bigint NOT NULL DEFAULT 0,created_at timestamptz NOT NULL DEFAULT now(),UNIQUE(customer_id,idempotency_key)
);
CREATE TABLE public.food_order_lines(
 order_id uuid NOT NULL REFERENCES public.food_orders(id),item_id uuid NOT NULL REFERENCES public.food_menu_items(id),
 name_snapshot text NOT NULL,price_minor bigint NOT NULL CHECK(price_minor>=0),quantity integer NOT NULL CHECK(quantity BETWEEN 1 AND 20),PRIMARY KEY(order_id,item_id)
);
CREATE INDEX food_restaurant_owner_idx ON public.food_restaurants(owner_id);
CREATE INDEX food_menu_restaurant_idx ON public.food_menu_items(restaurant_id);
CREATE INDEX food_order_customer_idx ON public.food_orders(customer_id,created_at DESC);
CREATE INDEX food_order_merchant_idx ON public.food_orders(merchant_id,created_at DESC);
ALTER TABLE public.food_restaurants ENABLE ROW LEVEL SECURITY;ALTER TABLE public.food_menu_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.food_orders ENABLE ROW LEVEL SECURITY;ALTER TABLE public.food_order_lines ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.food_restaurants,public.food_menu_items,public.food_orders,public.food_order_lines FROM public,anon,authenticated,service_role;
GRANT SELECT ON public.food_restaurants,public.food_menu_items TO anon,authenticated;
GRANT SELECT ON public.food_orders,public.food_order_lines TO authenticated;
GRANT SELECT,INSERT,UPDATE ON public.food_restaurants,public.food_menu_items TO service_role;
-- Order mutation is RPC-only for ordinary clients; trusted service workflow still requires separate review.
CREATE POLICY food_restaurant_read ON public.food_restaurants FOR SELECT TO anon,authenticated USING((status='published' AND approved) OR owner_id=(SELECT auth.uid()));
CREATE POLICY food_menu_read ON public.food_menu_items FOR SELECT TO anon,authenticated USING(EXISTS(SELECT 1 FROM public.food_restaurants r WHERE r.id=restaurant_id AND ((r.status='published' AND r.approved) OR r.owner_id=(SELECT auth.uid()))));
CREATE POLICY food_order_participants ON public.food_orders FOR SELECT TO authenticated USING((SELECT auth.uid()) IN(customer_id,merchant_id));
CREATE POLICY food_line_participants ON public.food_order_lines FOR SELECT TO authenticated USING(EXISTS(SELECT 1 FROM public.food_orders o WHERE o.id=order_id AND (SELECT auth.uid()) IN(o.customer_id,o.merchant_id)));
CREATE FUNCTION public.food_create_order(p_restaurant uuid,p_items jsonb,p_key uuid) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE caller uuid:=auth.uid();restaurant public.food_restaurants;prior public.food_orders;item jsonb;menu public.food_menu_items;qty integer;total bigint:=0;order_id uuid;request_value jsonb;
BEGIN
 IF caller IS NULL OR NOT public.marketplace_complete_member() THEN RAISE EXCEPTION 'Verified completed account required'; END IF;
 IF NOT coalesce((SELECT enabled FROM public.food_operation_settings WHERE singleton),false) THEN RAISE EXCEPTION 'Food orders are disabled'; END IF;
 IF p_key IS NULL OR jsonb_typeof(p_items) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Invalid order request'; END IF;
 IF jsonb_array_length(p_items) NOT BETWEEN 1 AND 20 THEN RAISE EXCEPTION 'Use 1 to 20 dishes'; END IF;
 request_value:=jsonb_build_object('restaurant',p_restaurant,'items',p_items);
 PERFORM pg_advisory_xact_lock(hashtextextended('food-customer:'||caller::text,0));
 PERFORM pg_advisory_xact_lock(hashtextextended('food-order:'||caller::text||p_key::text,0));
 SELECT * INTO prior FROM public.food_orders WHERE customer_id=caller AND idempotency_key=p_key;
 IF prior.id IS NOT NULL THEN IF prior.request<>request_value THEN RAISE EXCEPTION 'Idempotency key already used for another request'; END IF;RETURN prior.id;END IF;
 IF (SELECT count(*) FROM public.food_orders WHERE customer_id=caller AND state NOT IN('completed','cancelled'))>=10 THEN RAISE EXCEPTION 'Too many open food orders'; END IF;
 SELECT * INTO restaurant FROM public.food_restaurants WHERE id=p_restaurant FOR UPDATE;
 IF restaurant.id IS NULL OR restaurant.status<>'published' OR NOT restaurant.approved OR NOT restaurant.accepting_orders OR restaurant.owner_id=caller THEN RAISE EXCEPTION 'Restaurant cannot accept this order'; END IF;
 IF (SELECT count(DISTINCT value->>'item_id') FROM jsonb_array_elements(p_items))<>jsonb_array_length(p_items) THEN RAISE EXCEPTION 'Duplicate or missing dish ID'; END IF;
 -- Stable lock order serialises price/availability/stock changes and prevents over-allocation.
 PERFORM id FROM public.food_menu_items WHERE id IN(SELECT (value->>'item_id')::uuid FROM jsonb_array_elements(p_items)) ORDER BY id FOR UPDATE;
 FOR item IN SELECT value FROM jsonb_array_elements(p_items) LOOP
  IF jsonb_typeof(item)<>'object' OR item-ARRAY['item_id','quantity']<>'{}'::jsonb OR coalesce(item->>'quantity','') !~ '^[0-9]{1,2}$' THEN RAISE EXCEPTION 'Invalid dish fields'; END IF;
  qty:=(item->>'quantity')::integer;IF qty NOT BETWEEN 1 AND 20 THEN RAISE EXCEPTION 'Invalid quantity'; END IF;
  SELECT * INTO menu FROM public.food_menu_items WHERE id=(item->>'item_id')::uuid AND restaurant_id=p_restaurant;
  IF menu.id IS NULL OR NOT menu.available OR (menu.units IS NOT NULL AND menu.units<qty) THEN RAISE EXCEPTION 'Dish unavailable'; END IF;
  total:=total+menu.price_minor*qty;
 END LOOP;
 INSERT INTO public.food_orders(restaurant_id,customer_id,merchant_id,idempotency_key,request,total_minor) VALUES(p_restaurant,caller,restaurant.owner_id,p_key,request_value,total) RETURNING id INTO order_id;
 FOR item IN SELECT value FROM jsonb_array_elements(p_items) LOOP
  qty:=(item->>'quantity')::integer;SELECT * INTO menu FROM public.food_menu_items WHERE id=(item->>'item_id')::uuid;
  INSERT INTO public.food_order_lines VALUES(order_id,menu.id,menu.name,menu.price_minor,qty);
  UPDATE public.food_menu_items SET units=units-qty WHERE id=menu.id AND units IS NOT NULL;
 END LOOP;
 RETURN order_id;
END $$;
REVOKE ALL ON FUNCTION public.food_create_order(uuid,jsonb,uuid) FROM public,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.food_create_order(uuid,jsonb,uuid) TO authenticated;
COMMIT;
