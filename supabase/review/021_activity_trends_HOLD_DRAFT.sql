-- HOLD / REVIEW ONLY. No frontend telemetry ingestion, no raw search text and no fake aggregates.
-- Trusted collector, consent, HMAC actor tokens and abuse controls must be validated before connection.
BEGIN;
SET LOCAL lock_timeout='5s';SET LOCAL statement_timeout='60s';
CREATE TABLE public.discovery_settings(singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),publish_trends boolean NOT NULL DEFAULT false);
INSERT INTO public.discovery_settings VALUES(true,false);ALTER TABLE public.discovery_settings ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.discovery_settings FROM public,anon,authenticated,service_role;GRANT SELECT,UPDATE(publish_trends) ON public.discovery_settings TO service_role;
CREATE TABLE public.discovery_topics(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),kind text NOT NULL CHECK(kind IN('product','service','event','search')),label text NOT NULL CHECK(length(trim(label)) BETWEEN 2 AND 100),location text NOT NULL DEFAULT '' CHECK(length(location)<=100),active boolean NOT NULL DEFAULT false);
CREATE TABLE public.discovery_activity(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),topic_id uuid NOT NULL REFERENCES public.discovery_topics(id),actor_token_hash text NOT NULL CHECK(actor_token_hash ~ '^[a-f0-9]{64}$'),action text NOT NULL CHECK(action IN('click','save','search')),bucket_start timestamptz NOT NULL,created_at timestamptz NOT NULL DEFAULT now(),UNIQUE(topic_id,actor_token_hash,action,bucket_start));
CREATE INDEX discovery_actor_time_idx ON public.discovery_activity(actor_token_hash,created_at DESC);
CREATE TABLE public.discovery_rollups(topic_id uuid NOT NULL REFERENCES public.discovery_topics(id),window_start timestamptz NOT NULL,window_hours integer NOT NULL CHECK(window_hours IN(6,24,168)),unique_actors integer NOT NULL CHECK(unique_actors>=5),score numeric NOT NULL CHECK(score BETWEEN 0 AND 1000000000000),published boolean NOT NULL DEFAULT false,PRIMARY KEY(topic_id,window_start,window_hours));
CREATE FUNCTION public.discovery_activity_guard() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('discovery-actor:'||new.actor_token_hash,0));
 IF (SELECT count(*) FROM public.discovery_activity WHERE actor_token_hash=new.actor_token_hash AND created_at>now()-interval '1 minute')>=8 THEN RAISE EXCEPTION 'Activity rate limit';END IF;
 new.bucket_start:=date_trunc('hour',now());new.created_at:=now();RETURN new;
END $$;
REVOKE ALL ON FUNCTION public.discovery_activity_guard() FROM public,anon,authenticated,service_role;
CREATE TRIGGER discovery_activity_guard BEFORE INSERT ON public.discovery_activity FOR EACH ROW EXECUTE FUNCTION public.discovery_activity_guard();
ALTER TABLE public.discovery_topics ENABLE ROW LEVEL SECURITY;ALTER TABLE public.discovery_activity ENABLE ROW LEVEL SECURITY;ALTER TABLE public.discovery_rollups ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.discovery_topics,public.discovery_activity,public.discovery_rollups FROM public,anon,authenticated,service_role;
GRANT SELECT ON public.discovery_topics,public.discovery_rollups TO anon,authenticated;
GRANT SELECT,INSERT,UPDATE ON public.discovery_topics,public.discovery_rollups TO service_role;
GRANT SELECT,INSERT(topic_id,actor_token_hash,action,bucket_start) ON public.discovery_activity TO service_role;
CREATE FUNCTION public.discovery_trends_enabled() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$SELECT coalesce((SELECT publish_trends FROM public.discovery_settings WHERE singleton),false)$$;
REVOKE ALL ON FUNCTION public.discovery_trends_enabled() FROM public,anon,authenticated,service_role;GRANT EXECUTE ON FUNCTION public.discovery_trends_enabled() TO anon,authenticated;
CREATE POLICY discovery_topic_public ON public.discovery_topics FOR SELECT TO anon,authenticated USING(active AND public.discovery_trends_enabled());
CREATE POLICY discovery_rollup_public ON public.discovery_rollups FOR SELECT TO anon,authenticated USING(published AND unique_actors>=5 AND public.discovery_trends_enabled() AND EXISTS(SELECT 1 FROM public.discovery_topics t WHERE t.id=topic_id AND t.active));
CREATE VIEW public.discovery_trends WITH(security_invoker=true) AS SELECT t.id,t.kind,t.label,t.location,r.window_start,r.window_hours,r.score FROM public.discovery_topics t JOIN public.discovery_rollups r ON r.topic_id=t.id WHERE t.active AND r.published AND r.unique_actors>=5 AND r.window_start<=now() AND r.window_start+make_interval(hours=>r.window_hours)>now();
REVOKE ALL ON public.discovery_trends FROM public,anon,authenticated,service_role;GRANT SELECT ON public.discovery_trends TO anon,authenticated;
COMMIT;
