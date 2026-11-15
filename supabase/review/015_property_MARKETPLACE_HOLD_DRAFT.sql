-- HOLD / REVIEW ONLY. Never applied. Requires existing 009/010 profile/membership helpers.
-- Independent of held 013_v2/014_v2. Creates new objects only; no legacy data updates.
-- Confirm a backup, name conflicts and Storage privileges in staging before approval.
BEGIN;
SET LOCAL lock_timeout='5s'; SET LOCAL statement_timeout='60s';
CREATE TABLE public.property_listings (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),owner_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id),
 title text NOT NULL CHECK(length(trim(title)) BETWEEN 3 AND 150),
 property_type text NOT NULL CHECK(property_type IN('House','Apartment','Land','Commercial')),
 purpose text NOT NULL CHECK(purpose IN('Sale','Rent')),
 location text NOT NULL CHECK(length(trim(location)) BETWEEN 2 AND 200),
 description text NOT NULL CHECK(length(trim(description)) BETWEEN 20 AND 6000),
 price numeric NOT NULL CHECK(price BETWEEN 0 AND 1000000000000),
 price_basis text NOT NULL CHECK(price_basis IN('Total','Per month','Per night')),
 bedrooms integer CHECK(bedrooms BETWEEN 0 AND 100),bathrooms integer CHECK(bathrooms BETWEEN 0 AND 100),
 area_sqm numeric CHECK(area_sqm BETWEEN 0 AND 1000000000000),
 agent_type text NOT NULL DEFAULT 'Owner' CHECK(agent_type IN('Owner','Agent')),
 agent_name text NOT NULL,media_paths text[] NOT NULL DEFAULT '{}' CHECK(cardinality(media_paths)<=8),
 status text NOT NULL DEFAULT 'draft' CHECK(status IN('draft','published','closed')),
 created_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now(),
 CHECK(purpose<>'Sale' OR price_basis='Total')
);
CREATE INDEX property_discovery_idx ON public.property_listings(status,property_type,created_at DESC);
CREATE INDEX property_owner_idx ON public.property_listings(owner_id);
CREATE FUNCTION public.property_listing_guard() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE caller uuid:=auth.uid();path text;
BEGIN
 IF caller IS NULL OR new.owner_id IS DISTINCT FROM caller OR NOT public.marketplace_complete_member() THEN RAISE EXCEPTION 'Verified completed owner required'; END IF;
 IF tg_op='UPDATE' THEN
  IF new.id IS DISTINCT FROM old.id OR new.owner_id IS DISTINCT FROM old.owner_id THEN RAISE EXCEPTION 'Property identity is immutable'; END IF;
  new.created_at:=old.created_at;
 END IF;
 SELECT shop_name INTO new.agent_name FROM public.marketplace_profiles WHERE id=caller;
 IF new.media_paths IS NULL OR cardinality(new.media_paths)>8 THEN RAISE EXCEPTION 'Use at most eight images'; END IF;
 FOREACH path IN ARRAY new.media_paths LOOP
  IF path IS NULL OR path NOT LIKE caller::text||'/%' OR position('..' IN path)>0 OR NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='property-media' AND name=path) THEN RAISE EXCEPTION 'Invalid property image ownership'; END IF;
 END LOOP;
 new.updated_at:=now();RETURN new;
END $$;
REVOKE ALL ON FUNCTION public.property_listing_guard() FROM public,anon,authenticated;
CREATE TRIGGER property_listing_guard BEFORE INSERT OR UPDATE ON public.property_listings FOR EACH ROW EXECUTE FUNCTION public.property_listing_guard();
ALTER TABLE public.property_listings ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.property_listings FROM public,anon,authenticated;
GRANT SELECT ON public.property_listings TO anon,authenticated;
GRANT INSERT(owner_id,title,property_type,purpose,location,description,price,price_basis,bedrooms,bathrooms,area_sqm,agent_type,media_paths,status),UPDATE(title,property_type,purpose,location,description,price,price_basis,bedrooms,bathrooms,area_sqm,agent_type,media_paths,status) ON public.property_listings TO authenticated;
CREATE POLICY property_read ON public.property_listings FOR SELECT TO anon,authenticated USING(status='published' OR owner_id=(SELECT auth.uid()));
CREATE POLICY property_insert ON public.property_listings FOR INSERT TO authenticated WITH CHECK(owner_id=(SELECT auth.uid()) AND public.marketplace_complete_member());
CREATE POLICY property_update ON public.property_listings FOR UPDATE TO authenticated USING(owner_id=(SELECT auth.uid()) AND public.marketplace_complete_member()) WITH CHECK(owner_id=(SELECT auth.uid()));

CREATE TABLE public.property_saved (
 user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id),property_id uuid NOT NULL REFERENCES public.property_listings(id),
 created_at timestamptz NOT NULL DEFAULT now(),PRIMARY KEY(user_id,property_id)
);
ALTER TABLE public.property_saved ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.property_saved FROM public,anon,authenticated;
GRANT SELECT,INSERT(user_id,property_id),DELETE ON public.property_saved TO authenticated;
CREATE POLICY property_saved_read ON public.property_saved FOR SELECT TO authenticated USING(user_id=(SELECT auth.uid()));
CREATE POLICY property_saved_insert ON public.property_saved FOR INSERT TO authenticated WITH CHECK(user_id=(SELECT auth.uid()) AND public.marketplace_complete_member() AND EXISTS(SELECT 1 FROM public.property_listings p WHERE p.id=property_id AND p.status='published'));
CREATE POLICY property_saved_remove ON public.property_saved FOR DELETE TO authenticated USING(user_id=(SELECT auth.uid()));

CREATE TABLE public.property_enquiries (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),property_id uuid NOT NULL REFERENCES public.property_listings(id),
 sender_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id),recipient_id uuid NOT NULL REFERENCES auth.users(id),
 body text NOT NULL CHECK(length(trim(body)) BETWEEN 1 AND 2000),reply text NOT NULL DEFAULT '' CHECK(length(reply)<=2000),
 created_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now(),CHECK(sender_id<>recipient_id)
);
CREATE INDEX property_enquiry_sender_idx ON public.property_enquiries(sender_id,created_at DESC);
CREATE INDEX property_enquiry_recipient_idx ON public.property_enquiries(recipient_id,created_at DESC);
CREATE FUNCTION public.property_enquiry_guard() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE caller uuid:=auth.uid();seller uuid;
BEGIN
 IF caller IS NULL OR NOT public.marketplace_complete_member() THEN RAISE EXCEPTION 'Verified completed member required'; END IF;
 IF tg_op='INSERT' THEN
  SELECT owner_id INTO seller FROM public.property_listings WHERE id=new.property_id AND status='published';
  IF seller IS NULL OR seller=caller OR new.sender_id IS DISTINCT FROM caller THEN RAISE EXCEPTION 'Property enquiry not permitted'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('property-enquiry:'||caller::text,0));
  IF (SELECT count(*) FROM public.property_enquiries WHERE sender_id=caller AND created_at>now()-interval '1 minute')>=5 THEN RAISE EXCEPTION 'Please wait before another enquiry'; END IF;
  new.recipient_id:=seller;new.reply:='';
 ELSE
  IF old.recipient_id IS DISTINCT FROM caller OR new.id IS DISTINCT FROM old.id OR new.property_id IS DISTINCT FROM old.property_id OR new.sender_id IS DISTINCT FROM old.sender_id OR new.recipient_id IS DISTINCT FROM old.recipient_id OR new.body IS DISTINCT FROM old.body THEN RAISE EXCEPTION 'Enquiry identity is immutable'; END IF;
  new.created_at:=old.created_at;
 END IF;
 new.updated_at:=now();RETURN new;
END $$;
REVOKE ALL ON FUNCTION public.property_enquiry_guard() FROM public,anon,authenticated;
CREATE TRIGGER property_enquiry_guard BEFORE INSERT OR UPDATE ON public.property_enquiries FOR EACH ROW EXECUTE FUNCTION public.property_enquiry_guard();
ALTER TABLE public.property_enquiries ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.property_enquiries FROM public,anon,authenticated;
GRANT SELECT,INSERT(property_id,sender_id,body),UPDATE(reply) ON public.property_enquiries TO authenticated;
CREATE POLICY property_enquiry_read ON public.property_enquiries FOR SELECT TO authenticated USING((SELECT auth.uid()) IN(sender_id,recipient_id));
CREATE POLICY property_enquiry_send ON public.property_enquiries FOR INSERT TO authenticated WITH CHECK(sender_id=(SELECT auth.uid()) AND public.marketplace_complete_member());
CREATE POLICY property_enquiry_reply ON public.property_enquiries FOR UPDATE TO authenticated USING(recipient_id=(SELECT auth.uid()) AND public.marketplace_complete_member()) WITH CHECK(recipient_id=(SELECT auth.uid()));

INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types) VALUES('property-media','property-media',false,5242880,ARRAY['image/jpeg','image/png','image/webp']);
CREATE FUNCTION public.property_image_visible(p_path text) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$SELECT EXISTS(SELECT 1 FROM public.property_listings WHERE status='published' AND p_path=ANY(media_paths))$$;
REVOKE ALL ON FUNCTION public.property_image_visible(text) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.property_image_visible(text) TO anon,authenticated;
CREATE POLICY property_image_read ON storage.objects FOR SELECT TO anon,authenticated USING(bucket_id='property-media' AND ((storage.foldername(name))[1]=(SELECT auth.uid())::text OR public.property_image_visible(name)));
CREATE POLICY property_image_read_guard ON storage.objects AS RESTRICTIVE FOR SELECT TO anon,authenticated USING(bucket_id<>'property-media' OR ((storage.foldername(name))[1]=(SELECT auth.uid())::text OR public.property_image_visible(name)));
CREATE POLICY property_image_upload ON storage.objects FOR INSERT TO authenticated WITH CHECK(bucket_id='property-media' AND (storage.foldername(name))[1]=(SELECT auth.uid())::text AND public.marketplace_complete_member());
CREATE POLICY property_image_upload_guard ON storage.objects AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK(bucket_id<>'property-media' OR ((storage.foldername(name))[1]=(SELECT auth.uid())::text AND name NOT LIKE '%..%' AND public.marketplace_complete_member()));
CREATE POLICY property_image_no_update ON storage.objects AS RESTRICTIVE FOR UPDATE TO authenticated USING(bucket_id<>'property-media') WITH CHECK(bucket_id<>'property-media');
CREATE POLICY property_image_no_delete ON storage.objects AS RESTRICTIVE FOR DELETE TO authenticated USING(bucket_id<>'property-media');
CREATE FUNCTION public.property_capabilities() RETURNS jsonb LANGUAGE sql STABLE SET search_path='' AS $$SELECT jsonb_build_object('version',1,'private_data',true,'private_images',true,'saved_private',true)$$;
REVOKE ALL ON FUNCTION public.property_capabilities() FROM public,anon,authenticated;GRANT EXECUTE ON FUNCTION public.property_capabilities() TO anon,authenticated;
COMMIT;
