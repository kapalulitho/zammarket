-- HOLD / REVIEW ONLY. Private planning foundations only. Never applied.
-- Requires existing 010 membership helper. Independent of held 013/014 and 015.
-- No bookings, drivers, dispatch, verification claims, fares, tracking or payments.
BEGIN;
SET LOCAL lock_timeout='5s';SET LOCAL statement_timeout='60s';
CREATE TABLE public.delivery_drafts (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),customer_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id),
 pickup text NOT NULL CHECK(length(trim(pickup)) BETWEEN 2 AND 200),destination text NOT NULL CHECK(length(trim(destination)) BETWEEN 2 AND 200),
 description text NOT NULL CHECK(length(trim(description)) BETWEEN 3 AND 500),
 parcel_size text NOT NULL CHECK(parcel_size IN('Document','Small parcel','Medium parcel','Large parcel')),
 weight_kg numeric CHECK(weight_kg>0 AND weight_kg<=1000),notes text NOT NULL DEFAULT '' CHECK(length(notes)<=1000),
 state text NOT NULL DEFAULT 'planning' CHECK(state='planning'),created_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX delivery_customer_idx ON public.delivery_drafts(customer_id,created_at DESC);
CREATE FUNCTION public.delivery_plan_guard() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL OR new.customer_id IS DISTINCT FROM auth.uid() OR NOT public.marketplace_complete_member() THEN RAISE EXCEPTION 'Verified plan owner required'; END IF;
 IF tg_op='UPDATE' THEN
  IF new.id IS DISTINCT FROM old.id OR new.customer_id IS DISTINCT FROM old.customer_id THEN RAISE EXCEPTION 'Plan identity is immutable'; END IF;
  new.created_at:=old.created_at;
 END IF;
 new.updated_at:=now();RETURN new;
END $$;
REVOKE ALL ON FUNCTION public.delivery_plan_guard() FROM public,anon,authenticated;
CREATE TRIGGER delivery_plan_guard BEFORE INSERT OR UPDATE ON public.delivery_drafts FOR EACH ROW EXECUTE FUNCTION public.delivery_plan_guard();
ALTER TABLE public.delivery_drafts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.delivery_drafts FROM public,anon,authenticated;
GRANT SELECT,INSERT(customer_id,pickup,destination,description,parcel_size,weight_kg,notes),UPDATE(pickup,destination,description,parcel_size,weight_kg,notes) ON public.delivery_drafts TO authenticated;
CREATE POLICY delivery_plan_read ON public.delivery_drafts FOR SELECT TO authenticated USING(customer_id=(SELECT auth.uid()));
CREATE POLICY delivery_plan_insert ON public.delivery_drafts FOR INSERT TO authenticated WITH CHECK(customer_id=(SELECT auth.uid()) AND public.marketplace_complete_member());
CREATE POLICY delivery_plan_update ON public.delivery_drafts FOR UPDATE TO authenticated USING(customer_id=(SELECT auth.uid()) AND public.marketplace_complete_member()) WITH CHECK(customer_id=(SELECT auth.uid()));

CREATE TABLE public.courier_profile_drafts (
 owner_id uuid PRIMARY KEY DEFAULT auth.uid() REFERENCES auth.users(id),display_name text NOT NULL CHECK(length(trim(display_name)) BETWEEN 3 AND 100),
 vehicle text NOT NULL CHECK(vehicle IN('Bicycle','Motorbike','Car','Van','Truck')),service_area text NOT NULL CHECK(length(trim(service_area)) BETWEEN 2 AND 200),
 about text NOT NULL DEFAULT '' CHECK(length(about)<=1000),state text NOT NULL DEFAULT 'draft' CHECK(state='draft'),updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE FUNCTION public.courier_profile_draft_guard() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL OR new.owner_id IS DISTINCT FROM auth.uid() OR NOT public.marketplace_complete_member() THEN RAISE EXCEPTION 'Verified profile owner required'; END IF;
 IF tg_op='UPDATE' THEN IF new.owner_id IS DISTINCT FROM old.owner_id THEN RAISE EXCEPTION 'Owner is immutable'; END IF;END IF;
 new.updated_at:=now();RETURN new;
END $$;
REVOKE ALL ON FUNCTION public.courier_profile_draft_guard() FROM public,anon,authenticated;
CREATE TRIGGER courier_profile_draft_guard BEFORE INSERT OR UPDATE ON public.courier_profile_drafts FOR EACH ROW EXECUTE FUNCTION public.courier_profile_draft_guard();
ALTER TABLE public.courier_profile_drafts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.courier_profile_drafts FROM public,anon,authenticated;
GRANT SELECT,INSERT(owner_id,display_name,vehicle,service_area,about),UPDATE(display_name,vehicle,service_area,about) ON public.courier_profile_drafts TO authenticated;
CREATE POLICY courier_draft_read ON public.courier_profile_drafts FOR SELECT TO authenticated USING(owner_id=(SELECT auth.uid()));
CREATE POLICY courier_draft_insert ON public.courier_profile_drafts FOR INSERT TO authenticated WITH CHECK(owner_id=(SELECT auth.uid()) AND public.marketplace_complete_member());
CREATE POLICY courier_draft_update ON public.courier_profile_drafts FOR UPDATE TO authenticated USING(owner_id=(SELECT auth.uid()) AND public.marketplace_complete_member()) WITH CHECK(owner_id=(SELECT auth.uid()));
CREATE FUNCTION public.delivery_capabilities() RETURNS jsonb LANGUAGE sql STABLE SET search_path='' AS $$SELECT jsonb_build_object('version',1,'private_data',true,'planning_only',true,'bookings',false,'payments',false)$$;
REVOKE ALL ON FUNCTION public.delivery_capabilities() FROM public,anon,authenticated;GRANT EXECUTE ON FUNCTION public.delivery_capabilities() TO anon,authenticated;
COMMIT;
