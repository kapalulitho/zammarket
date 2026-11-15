-- REVIEW ONLY. New modules/storefronts/private enquiries. Requires 009 + 010 + 012.
-- No existing policies, records, listing-image limits or messaging functions change.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
CREATE TABLE public.community_entries (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), owner_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id),
 kind text NOT NULL CHECK(kind IN('event','job','service','learning')),
 title text NOT NULL CHECK(length(trim(title)) BETWEEN 3 AND 200),
 description text NOT NULL CHECK(length(trim(description)) BETWEEN 10 AND 6000),
 location text NOT NULL CHECK(length(trim(location)) BETWEEN 2 AND 200),
 category text NOT NULL DEFAULT '' CHECK(length(category)<=100),
 organisation text NOT NULL DEFAULT '' CHECK(length(organisation)<=120),
 format text NOT NULL DEFAULT '' CHECK(length(format)<=80),
 price numeric CHECK(price>=0), price_unit text NOT NULL DEFAULT 'ZMW' CHECK(length(price_unit)<=40),
 starts_at timestamptz, ends_at timestamptz, deadline date,
 extra text NOT NULL DEFAULT '' CHECK(length(extra)<=3000),
 media_paths text[] NOT NULL DEFAULT '{}' CHECK(cardinality(media_paths)<=5),
 status text NOT NULL DEFAULT 'draft' CHECK(status IN('draft','published','closed')),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 CHECK(ends_at IS NULL OR (starts_at IS NOT NULL AND ends_at>=starts_at)),
 CHECK(kind<>'event' OR starts_at IS NOT NULL)
);
CREATE INDEX stage3_entries_discovery ON public.community_entries(kind,status,created_at DESC);
CREATE INDEX stage3_entries_owner ON public.community_entries(owner_id);
CREATE TABLE public.seller_shops (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),owner_id uuid NOT NULL UNIQUE DEFAULT auth.uid() REFERENCES auth.users(id),
 slug text NOT NULL UNIQUE CHECK(slug ~ '^[a-z0-9][a-z0-9-]{2,59}$'),
 name text NOT NULL CHECK(length(trim(name)) BETWEEN 3 AND 80),
 description text NOT NULL CHECK(length(trim(description)) BETWEEN 10 AND 3000),
 location text NOT NULL CHECK(length(trim(location)) BETWEEN 2 AND 200),
 hours text NOT NULL DEFAULT '' CHECK(length(hours)<=500),policies text NOT NULL DEFAULT '' CHECK(length(policies)<=2000),
 media_paths text[] NOT NULL DEFAULT '{}' CHECK(cardinality(media_paths)<=1),
 status text NOT NULL DEFAULT 'draft' CHECK(status IN('draft','published','closed')),
 created_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE FUNCTION public.stage3_content_guard() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE caller uuid:=auth.uid(); path text;
BEGIN
 IF caller IS NULL OR NOT public.marketplace_complete_member() THEN RAISE EXCEPTION 'Complete your verified profile first'; END IF;
 IF new.owner_id IS DISTINCT FROM caller THEN RAISE EXCEPTION 'Owner mismatch'; END IF;
 IF tg_op='UPDATE' THEN
  IF old.owner_id IS DISTINCT FROM caller OR new.id IS DISTINCT FROM old.id OR new.owner_id IS DISTINCT FROM old.owner_id
    THEN RAISE EXCEPTION 'Ownership is immutable'; END IF;
  new.created_at:=old.created_at;
 END IF;
 FOREACH path IN ARRAY new.media_paths LOOP
  IF path NOT LIKE caller::text||'/%' OR position('..' IN path)>0 OR NOT EXISTS(
    SELECT 1 FROM storage.objects WHERE bucket_id='marketplace-media' AND name=path) THEN RAISE EXCEPTION 'Invalid media ownership'; END IF;
 END LOOP;
 new.updated_at:=now();RETURN new;
END $$;
REVOKE ALL ON FUNCTION public.stage3_content_guard() FROM public,anon,authenticated;
CREATE TRIGGER stage3_entry_guard BEFORE INSERT OR UPDATE ON public.community_entries FOR EACH ROW EXECUTE FUNCTION public.stage3_content_guard();
CREATE TRIGGER stage3_shop_guard BEFORE INSERT OR UPDATE ON public.seller_shops FOR EACH ROW EXECUTE FUNCTION public.stage3_content_guard();
ALTER TABLE public.community_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.seller_shops ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.community_entries,public.seller_shops FROM public,anon,authenticated;
GRANT SELECT ON public.community_entries,public.seller_shops TO anon,authenticated;
GRANT INSERT(owner_id,kind,title,description,location,category,organisation,format,price,price_unit,starts_at,ends_at,deadline,extra,media_paths,status),
 UPDATE(title,description,location,category,organisation,format,price,price_unit,starts_at,ends_at,deadline,extra,media_paths,status)
 ON public.community_entries TO authenticated;
GRANT INSERT(owner_id,slug,name,description,location,hours,policies,media_paths,status),UPDATE(slug,name,description,location,hours,policies,media_paths,status)
 ON public.seller_shops TO authenticated;
CREATE POLICY stage3_entry_read ON public.community_entries FOR SELECT TO anon,authenticated USING(status='published' OR owner_id=(SELECT auth.uid()));
CREATE POLICY stage3_entry_insert ON public.community_entries FOR INSERT TO authenticated WITH CHECK(owner_id=(SELECT auth.uid()) AND public.marketplace_complete_member());
CREATE POLICY stage3_entry_update ON public.community_entries FOR UPDATE TO authenticated USING(owner_id=(SELECT auth.uid()) AND public.marketplace_complete_member()) WITH CHECK(owner_id=(SELECT auth.uid()));
CREATE POLICY stage3_shop_read ON public.seller_shops FOR SELECT TO anon,authenticated USING(status='published' OR owner_id=(SELECT auth.uid()));
CREATE POLICY stage3_shop_insert ON public.seller_shops FOR INSERT TO authenticated WITH CHECK(owner_id=(SELECT auth.uid()) AND public.marketplace_complete_member());
CREATE POLICY stage3_shop_update ON public.seller_shops FOR UPDATE TO authenticated USING(owner_id=(SELECT auth.uid()) AND public.marketplace_complete_member()) WITH CHECK(owner_id=(SELECT auth.uid()));

CREATE TABLE public.module_enquiries (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),entry_id uuid NOT NULL REFERENCES public.community_entries(id),
 sender_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id),recipient_id uuid NOT NULL REFERENCES auth.users(id),
 body text NOT NULL CHECK(length(trim(body)) BETWEEN 1 AND 4000),reply text NOT NULL DEFAULT '' CHECK(length(reply)<=4000),
 created_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now(),CHECK(sender_id<>recipient_id)
);
CREATE INDEX stage3_enquiries_recipient ON public.module_enquiries(recipient_id,created_at DESC);
CREATE INDEX stage3_enquiries_sender ON public.module_enquiries(sender_id,created_at DESC);
CREATE TABLE public.marketplace_notifications (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),recipient_id uuid NOT NULL REFERENCES auth.users(id),
 entry_id uuid REFERENCES public.community_entries(id),title text NOT NULL,read_at timestamptz,created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX stage3_notifications_owner ON public.marketplace_notifications(recipient_id,created_at DESC);
CREATE FUNCTION public.stage3_enquiry_guard() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE caller uuid:=auth.uid(); item public.community_entries;
BEGIN
 IF caller IS NULL OR NOT public.marketplace_complete_member() THEN RAISE EXCEPTION 'Complete your verified profile first'; END IF;
 IF tg_op='INSERT' THEN
  IF new.sender_id IS DISTINCT FROM caller THEN RAISE EXCEPTION 'Sender mismatch'; END IF;
  SELECT * INTO item FROM public.community_entries WHERE id=new.entry_id AND status='published';
  IF item.id IS NULL OR item.owner_id=caller THEN RAISE EXCEPTION 'Enquiry not available'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('stage3-enquiry:'||caller::text,0));
  IF (SELECT count(*) FROM public.module_enquiries WHERE sender_id=caller AND created_at>now()-interval '1 minute')>=5 THEN RAISE EXCEPTION 'Please wait before sending another enquiry'; END IF;
  new.sender_id:=caller;new.recipient_id:=item.owner_id;new.reply:='';
 ELSE
  IF old.recipient_id<>caller OR new.entry_id IS DISTINCT FROM old.entry_id OR new.sender_id IS DISTINCT FROM old.sender_id
    OR new.recipient_id IS DISTINCT FROM old.recipient_id OR new.body IS DISTINCT FROM old.body OR new.id IS DISTINCT FROM old.id THEN RAISE EXCEPTION 'Enquiry identity is immutable'; END IF;
  new.created_at:=old.created_at;
 END IF;
 new.updated_at:=now();RETURN new;
END $$;
REVOKE ALL ON FUNCTION public.stage3_enquiry_guard() FROM public,anon,authenticated;
CREATE TRIGGER stage3_enquiry_guard BEFORE INSERT OR UPDATE ON public.module_enquiries FOR EACH ROW EXECUTE FUNCTION public.stage3_enquiry_guard();
CREATE FUNCTION public.stage3_notify_enquiry() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF tg_op='INSERT' THEN
  INSERT INTO public.marketplace_notifications(recipient_id,entry_id,title) VALUES(new.recipient_id,new.entry_id,'New enquiry received');
 ELSIF new.reply IS DISTINCT FROM old.reply AND length(trim(new.reply))>0 THEN
  INSERT INTO public.marketplace_notifications(recipient_id,entry_id,title) VALUES(new.sender_id,new.entry_id,'An organiser or provider replied');
 END IF;
 RETURN new;
END $$;
REVOKE ALL ON FUNCTION public.stage3_notify_enquiry() FROM public,anon,authenticated;
CREATE TRIGGER stage3_notify_enquiry AFTER INSERT OR UPDATE ON public.module_enquiries FOR EACH ROW EXECUTE FUNCTION public.stage3_notify_enquiry();
ALTER TABLE public.module_enquiries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_notifications ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.module_enquiries,public.marketplace_notifications FROM public,anon,authenticated;
GRANT SELECT ON public.module_enquiries,public.marketplace_notifications TO authenticated;
GRANT INSERT(sender_id,entry_id,body),UPDATE(reply) ON public.module_enquiries TO authenticated;
GRANT UPDATE(read_at) ON public.marketplace_notifications TO authenticated;
CREATE POLICY stage3_enquiry_read ON public.module_enquiries FOR SELECT TO authenticated USING((SELECT auth.uid()) IN(sender_id,recipient_id));
CREATE POLICY stage3_enquiry_send ON public.module_enquiries FOR INSERT TO authenticated WITH CHECK(sender_id=(SELECT auth.uid()) AND public.marketplace_complete_member());
CREATE POLICY stage3_enquiry_reply ON public.module_enquiries FOR UPDATE TO authenticated USING(recipient_id=(SELECT auth.uid()) AND public.marketplace_complete_member()) WITH CHECK(recipient_id=(SELECT auth.uid()));
CREATE POLICY stage3_notification_read ON public.marketplace_notifications FOR SELECT TO authenticated USING(recipient_id=(SELECT auth.uid()));
CREATE POLICY stage3_notification_mark ON public.marketplace_notifications FOR UPDATE TO authenticated USING(recipient_id=(SELECT auth.uid())) WITH CHECK(recipient_id=(SELECT auth.uid()));

INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types) VALUES('marketplace-media','marketplace-media',true,5242880,ARRAY['image/jpeg','image/png','image/webp']);
CREATE POLICY stage3_media_read ON storage.objects FOR SELECT TO authenticated USING(bucket_id='marketplace-media' AND (storage.foldername(name))[1]=(SELECT auth.uid())::text);
CREATE POLICY stage3_media_insert ON storage.objects FOR INSERT TO authenticated WITH CHECK(bucket_id='marketplace-media' AND (storage.foldername(name))[1]=(SELECT auth.uid())::text AND public.marketplace_complete_member());
CREATE POLICY stage3_media_insert_guard ON storage.objects AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK(bucket_id<>'marketplace-media' OR ((storage.foldername(name))[1]=(SELECT auth.uid())::text AND name NOT LIKE '%..%' AND public.marketplace_complete_member()));
CREATE POLICY stage3_media_no_overwrite ON storage.objects AS RESTRICTIVE FOR UPDATE TO authenticated USING(bucket_id<>'marketplace-media') WITH CHECK(bucket_id<>'marketplace-media');
CREATE POLICY stage3_media_no_delete ON storage.objects AS RESTRICTIVE FOR DELETE TO authenticated USING(bucket_id<>'marketplace-media');
CREATE FUNCTION public.stage3_capabilities() RETURNS jsonb LANGUAGE sql STABLE SET search_path='' AS $$ SELECT jsonb_build_object('version',1,'modules',true,'storefronts',true) $$;
REVOKE ALL ON FUNCTION public.stage3_capabilities() FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.stage3_capabilities() TO anon,authenticated;
COMMIT;
