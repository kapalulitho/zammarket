-- HOLD / REVIEW ONLY. Separate operational schema; existing 016 planning tables unchanged.
-- Requires verified-member helper. Gate remains FALSE; no dispatch, payments or GPS service enabled.
BEGIN;
SET LOCAL lock_timeout='5s';SET LOCAL statement_timeout='60s';
CREATE TABLE public.delivery_operation_settings(singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),enabled boolean NOT NULL DEFAULT false);
INSERT INTO public.delivery_operation_settings VALUES(true,false);ALTER TABLE public.delivery_operation_settings ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.delivery_operation_settings FROM public,anon,authenticated,service_role;GRANT SELECT,UPDATE(enabled) ON public.delivery_operation_settings TO service_role;
CREATE TABLE public.delivery_courier_approvals(
 courier_id uuid PRIMARY KEY REFERENCES auth.users(id),approved boolean NOT NULL DEFAULT false,reviewed_at timestamptz,
 reviewed_by uuid REFERENCES auth.users(id),CHECK(NOT approved OR (reviewed_at IS NOT NULL AND reviewed_by IS NOT NULL))
);
CREATE TABLE public.delivery_jobs(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),customer_id uuid NOT NULL REFERENCES auth.users(id),courier_id uuid REFERENCES auth.users(id),
 pickup_area text NOT NULL CHECK(length(trim(pickup_area)) BETWEEN 2 AND 200),destination_area text NOT NULL CHECK(length(trim(destination_area)) BETWEEN 2 AND 200),
 parcel text NOT NULL CHECK(length(trim(parcel)) BETWEEN 3 AND 500),idempotency_key uuid NOT NULL,
 state text NOT NULL DEFAULT 'submitted' CHECK(state IN('submitted','assigned','accepted','picked_up','in_transit','delivered','cancelled')),
 revision bigint NOT NULL DEFAULT 0,created_at timestamptz NOT NULL DEFAULT now(),UNIQUE(customer_id,idempotency_key),CHECK(customer_id IS DISTINCT FROM courier_id)
);
CREATE TABLE public.delivery_job_events(
 job_id uuid NOT NULL REFERENCES public.delivery_jobs(id),revision bigint NOT NULL,
 actor_id uuid REFERENCES auth.users(id),action text NOT NULL,from_state text,to_state text NOT NULL,created_at timestamptz NOT NULL DEFAULT now(),PRIMARY KEY(job_id,revision)
);
CREATE TABLE public.delivery_job_contacts(
 job_id uuid PRIMARY KEY REFERENCES public.delivery_jobs(id),pickup_address text NOT NULL CHECK(length(pickup_address) BETWEEN 2 AND 500),
 destination_address text NOT NULL CHECK(length(destination_address) BETWEEN 2 AND 500),recipient_phone text CHECK(recipient_phone ~ '^\+260[0-9]{9}$')
);
CREATE INDEX delivery_job_customer_idx ON public.delivery_jobs(customer_id,created_at DESC);
CREATE INDEX delivery_job_courier_idx ON public.delivery_jobs(courier_id,created_at DESC);
ALTER TABLE public.delivery_courier_approvals ENABLE ROW LEVEL SECURITY;ALTER TABLE public.delivery_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.delivery_job_events ENABLE ROW LEVEL SECURITY;ALTER TABLE public.delivery_job_contacts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.delivery_courier_approvals,public.delivery_jobs,public.delivery_job_events,public.delivery_job_contacts FROM public,anon,authenticated,service_role;
GRANT SELECT(courier_id,approved,reviewed_at) ON public.delivery_courier_approvals TO authenticated;
GRANT SELECT ON public.delivery_jobs,public.delivery_job_events,public.delivery_job_contacts TO authenticated;
GRANT SELECT,INSERT,UPDATE ON public.delivery_courier_approvals,public.delivery_job_contacts TO service_role;
GRANT SELECT ON public.delivery_jobs,public.delivery_job_events TO service_role;
CREATE POLICY courier_own_approval ON public.delivery_courier_approvals FOR SELECT TO authenticated USING(courier_id=(SELECT auth.uid()));
CREATE POLICY delivery_job_participants ON public.delivery_jobs FOR SELECT TO authenticated USING((SELECT auth.uid()) IN(customer_id,courier_id));
CREATE POLICY delivery_events_participants ON public.delivery_job_events FOR SELECT TO authenticated USING(EXISTS(SELECT 1 FROM public.delivery_jobs j WHERE j.id=job_id AND (SELECT auth.uid()) IN(j.customer_id,j.courier_id)));
CREATE POLICY delivery_contact_access ON public.delivery_job_contacts FOR SELECT TO authenticated USING(EXISTS(SELECT 1 FROM public.delivery_jobs j WHERE j.id=job_id AND (j.customer_id=(SELECT auth.uid()) OR (j.courier_id=(SELECT auth.uid()) AND j.state IN('accepted','picked_up','in_transit') AND EXISTS(SELECT 1 FROM public.delivery_courier_approvals a WHERE a.courier_id=(SELECT auth.uid()) AND a.approved)))));
CREATE FUNCTION public.submit_delivery_job(p_pickup text,p_destination text,p_parcel text,p_key uuid) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE caller uuid:=auth.uid();prior public.delivery_jobs;job_id uuid;
BEGIN
 IF caller IS NULL OR NOT public.marketplace_complete_member() THEN RAISE EXCEPTION 'Verified completed account required'; END IF;
 IF NOT coalesce((SELECT enabled FROM public.delivery_operation_settings WHERE singleton),false) THEN RAISE EXCEPTION 'Delivery operations disabled'; END IF;
 IF p_key IS NULL THEN RAISE EXCEPTION 'Idempotency key required'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('delivery-customer:'||caller::text,0));
 SELECT * INTO prior FROM public.delivery_jobs WHERE customer_id=caller AND idempotency_key=p_key;
 IF prior.id IS NOT NULL THEN IF prior.pickup_area IS DISTINCT FROM trim(p_pickup) OR prior.destination_area IS DISTINCT FROM trim(p_destination) OR prior.parcel IS DISTINCT FROM trim(p_parcel) THEN RAISE EXCEPTION 'Idempotency key reused'; END IF;RETURN prior.id;END IF;
 IF (SELECT count(*) FROM public.delivery_jobs WHERE customer_id=caller AND state NOT IN('delivered','cancelled'))>=10 THEN RAISE EXCEPTION 'Too many open requests'; END IF;
 INSERT INTO public.delivery_jobs(customer_id,pickup_area,destination_area,parcel,idempotency_key) VALUES(caller,trim(p_pickup),trim(p_destination),trim(p_parcel),p_key) RETURNING id INTO job_id;
 INSERT INTO public.delivery_job_events(job_id,revision,actor_id,action,to_state) VALUES(job_id,0,caller,'submit','submitted');RETURN job_id;
END $$;
CREATE FUNCTION public.assign_delivery_job(p_id uuid,p_courier uuid,p_revision bigint) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE job public.delivery_jobs;
BEGIN
 IF NOT coalesce((SELECT enabled FROM public.delivery_operation_settings WHERE singleton),false) THEN RAISE EXCEPTION 'Delivery operations disabled'; END IF;
 SELECT * INTO job FROM public.delivery_jobs WHERE id=p_id FOR UPDATE;
 IF job.id IS NULL OR job.revision IS DISTINCT FROM p_revision OR job.state<>'submitted' OR job.customer_id=p_courier OR NOT EXISTS(SELECT 1 FROM public.delivery_courier_approvals WHERE courier_id=p_courier AND approved) THEN RAISE EXCEPTION 'Assignment not permitted'; END IF;
 UPDATE public.delivery_jobs SET courier_id=p_courier,state='assigned',revision=revision+1 WHERE id=p_id;
 INSERT INTO public.delivery_job_events(job_id,revision,actor_id,action,from_state,to_state) VALUES(p_id,job.revision+1,auth.uid(),'assign','submitted','assigned');
END $$;
CREATE FUNCTION public.advance_delivery_job(p_id uuid,p_revision bigint,p_action text) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE caller uuid:=auth.uid();job public.delivery_jobs;next_state text;
BEGIN
 IF caller IS NULL OR NOT public.marketplace_complete_member() THEN RAISE EXCEPTION 'Verified completed account required'; END IF;
 SELECT * INTO job FROM public.delivery_jobs WHERE id=p_id FOR UPDATE;
 IF job.id IS NULL OR job.revision IS DISTINCT FROM p_revision THEN RAISE EXCEPTION 'Unavailable or stale request'; END IF;
 IF p_action='cancel' AND job.customer_id=caller AND job.state IN('submitted','assigned','accepted') THEN next_state:='cancelled';
 ELSE
  IF NOT coalesce((SELECT enabled FROM public.delivery_operation_settings WHERE singleton),false) THEN RAISE EXCEPTION 'Delivery operations disabled'; END IF;
  IF job.courier_id IS DISTINCT FROM caller OR NOT EXISTS(SELECT 1 FROM public.delivery_courier_approvals WHERE courier_id=caller AND approved) THEN RAISE EXCEPTION 'Assigned approved courier required'; END IF;
  next_state:=CASE WHEN job.state='assigned' AND p_action='accept' THEN 'accepted' WHEN job.state='accepted' AND p_action='collect' THEN 'picked_up' WHEN job.state='picked_up' AND p_action='depart' THEN 'in_transit' WHEN job.state='in_transit' AND p_action='deliver' THEN 'delivered' END;
 END IF;
 IF next_state IS NULL THEN RAISE EXCEPTION 'Invalid delivery transition'; END IF;
 UPDATE public.delivery_jobs SET state=next_state,revision=revision+1 WHERE id=p_id;
 INSERT INTO public.delivery_job_events(job_id,revision,actor_id,action,from_state,to_state) VALUES(p_id,job.revision+1,caller,p_action,job.state,next_state);
END $$;
REVOKE ALL ON FUNCTION public.submit_delivery_job(text,text,text,uuid),public.assign_delivery_job(uuid,uuid,bigint),public.advance_delivery_job(uuid,bigint,text) FROM public,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.submit_delivery_job(text,text,text,uuid),public.advance_delivery_job(uuid,bigint,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.assign_delivery_job(uuid,uuid,bigint) TO service_role;
COMMIT;
