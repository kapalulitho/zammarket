-- HOLD / REVIEW ONLY. Requires 022 business foundation + existing membership helpers.
-- Separate from property sales and parcel delivery. No availability, booking or dispatch schema.
BEGIN;
SET LOCAL lock_timeout='5s';SET LOCAL statement_timeout='60s';
CREATE TABLE public.business_service_settings(singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),publish_entries boolean NOT NULL DEFAULT false);
INSERT INTO public.business_service_settings VALUES(true,false);ALTER TABLE public.business_service_settings ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.business_service_settings FROM public,anon,authenticated,service_role;GRANT SELECT,UPDATE(publish_entries) ON public.business_service_settings TO service_role;
CREATE FUNCTION public.business_service_publication_enabled() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$SELECT coalesce((SELECT publish_entries FROM public.business_service_settings WHERE singleton),false)$$;
REVOKE ALL ON FUNCTION public.business_service_publication_enabled() FROM public,anon,authenticated,service_role;GRANT EXECUTE ON FUNCTION public.business_service_publication_enabled() TO anon,authenticated;
CREATE TABLE public.business_service_entries(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),organisation_id uuid NOT NULL REFERENCES public.business_organisations(id),owner_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id),
 kind text NOT NULL CHECK(kind IN('stay','logistics')),name text NOT NULL CHECK(length(trim(name)) BETWEEN 3 AND 120),
 category text NOT NULL,location text NOT NULL CHECK(length(trim(location)) BETWEEN 2 AND 200),description text NOT NULL CHECK(length(trim(description)) BETWEEN 20 AND 5000),
 features text NOT NULL DEFAULT '' CHECK(length(features)<=1500),service_areas text[] NOT NULL DEFAULT '{}' CHECK(cardinality(service_areas)<=10),
 media_paths text[] NOT NULL DEFAULT '{}' CHECK(cardinality(media_paths)<=8),status text NOT NULL DEFAULT 'draft' CHECK(status IN('draft','published','closed')),
 created_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now(),
 CHECK((kind='stay' AND category IN('Lodge','Hotel','Guesthouse','Resort','Hostel','Furnished apartment / short stay','Campsite')) OR(kind='logistics' AND category IN('Freight & cargo','Truck hire','Moving company','Warehousing','Distribution','Courier business','Import / export logistics'))),
 CHECK(kind<>'logistics' OR cardinality(service_areas)>0)
);
CREATE TABLE public.stay_room_options(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),entry_id uuid NOT NULL REFERENCES public.business_service_entries(id),
 name text NOT NULL CHECK(length(trim(name)) BETWEEN 2 AND 100),guest_capacity integer NOT NULL CHECK(guest_capacity BETWEEN 1 AND 20),
 nightly_minor bigint NOT NULL CHECK(nightly_minor BETWEEN 0 AND 100000000),currency text NOT NULL DEFAULT 'ZMW' CHECK(currency='ZMW'),listed boolean NOT NULL DEFAULT true
);
CREATE TABLE public.business_service_enquiry_drafts(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),author_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id),entry_id uuid NOT NULL REFERENCES public.business_service_entries(id),
 room_option_id uuid REFERENCES public.stay_room_options(id),note text NOT NULL CHECK(length(trim(note)) BETWEEN 5 AND 2000),
 desired_start date,desired_end date,guests integer CHECK(guests BETWEEN 1 AND 20),origin_area text CHECK(length(origin_area)<=200),destination_area text CHECK(length(destination_area)<=200),
 state text NOT NULL DEFAULT 'draft' CHECK(state='draft'),created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX business_service_owner_idx ON public.business_service_entries(owner_id);
CREATE INDEX business_service_org_idx ON public.business_service_entries(organisation_id);
CREATE INDEX business_service_discovery_idx ON public.business_service_entries(kind,status,created_at DESC);
CREATE INDEX stay_room_entry_idx ON public.stay_room_options(entry_id);CREATE INDEX business_service_draft_author_idx ON public.business_service_enquiry_drafts(author_id,created_at DESC);
CREATE FUNCTION public.business_service_owner(p_entry uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$SELECT auth.uid() IS NOT NULL AND EXISTS(SELECT 1 FROM public.business_service_entries WHERE id=p_entry AND owner_id=auth.uid())$$;
CREATE FUNCTION public.business_service_visible(p_entry uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$SELECT public.business_service_publication_enabled() AND public.business_publication_enabled() AND EXISTS(SELECT 1 FROM public.business_service_entries e JOIN public.business_organisations o ON o.id=e.organisation_id WHERE e.id=p_entry AND e.status='published' AND o.status='published')$$;
REVOKE ALL ON FUNCTION public.business_service_owner(uuid),public.business_service_visible(uuid) FROM public,anon,authenticated,service_role;GRANT EXECUTE ON FUNCTION public.business_service_owner(uuid) TO authenticated;GRANT EXECUTE ON FUNCTION public.business_service_visible(uuid) TO anon,authenticated;
CREATE FUNCTION public.business_service_entry_guard() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE path text;area text;
BEGIN
 IF auth.uid() IS NULL OR new.owner_id IS DISTINCT FROM auth.uid() OR NOT public.marketplace_complete_member() OR NOT public.business_is_owner(new.organisation_id) THEN RAISE EXCEPTION 'Verified owning business required';END IF;
 IF tg_op='UPDATE' THEN IF new.id IS DISTINCT FROM old.id OR new.owner_id IS DISTINCT FROM old.owner_id OR new.organisation_id IS DISTINCT FROM old.organisation_id OR new.kind IS DISTINCT FROM old.kind THEN RAISE EXCEPTION 'Service identity immutable';END IF;new.created_at:=old.created_at;END IF;
 IF new.status='published' AND NOT public.business_service_publication_enabled() THEN RAISE EXCEPTION 'Service publication disabled';END IF;
 FOREACH area IN ARRAY new.service_areas LOOP IF area IS NULL OR length(trim(area)) NOT BETWEEN 1 AND 120 THEN RAISE EXCEPTION 'Invalid service area';END IF;END LOOP;
 FOREACH path IN ARRAY new.media_paths LOOP IF path IS NULL OR path NOT LIKE auth.uid()::text||'/%' OR path LIKE '%..%' OR NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='business-service-media' AND name=path) THEN RAISE EXCEPTION 'Invalid service image';END IF;END LOOP;
 new.updated_at:=now();RETURN new;
END $$;
CREATE FUNCTION public.stay_room_guard() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT public.marketplace_complete_member() OR NOT public.business_service_owner(new.entry_id) OR NOT EXISTS(SELECT 1 FROM public.business_service_entries WHERE id=new.entry_id AND kind='stay') THEN RAISE EXCEPTION 'Owning accommodation required';END IF;
 IF tg_op='UPDATE' THEN IF new.id IS DISTINCT FROM old.id OR new.entry_id IS DISTINCT FROM old.entry_id THEN RAISE EXCEPTION 'Room identity immutable';END IF;END IF;RETURN new;
END $$;
CREATE FUNCTION public.business_service_draft_guard() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE entry public.business_service_entries;room public.stay_room_options;
BEGIN
 IF auth.uid() IS NULL OR new.author_id IS DISTINCT FROM auth.uid() OR NOT public.marketplace_complete_member() OR NOT public.business_service_visible(new.entry_id) THEN RAISE EXCEPTION 'Verified author and published service required';END IF;
 SELECT * INTO entry FROM public.business_service_entries WHERE id=new.entry_id;
 IF entry.kind='stay' THEN
  SELECT * INTO room FROM public.stay_room_options WHERE id=new.room_option_id AND entry_id=entry.id AND listed;
  IF room.id IS NULL OR new.desired_start IS NULL OR new.desired_end IS NULL OR new.desired_start<(now() AT TIME ZONE 'Africa/Lusaka')::date OR new.desired_end-new.desired_start NOT BETWEEN 1 AND 90 OR new.guests IS NULL OR new.guests>room.guest_capacity THEN RAISE EXCEPTION 'Invalid stay enquiry plan';END IF;
 ELSE
  IF new.room_option_id IS NOT NULL OR new.origin_area IS NULL OR length(trim(new.origin_area))<2 OR new.destination_area IS NULL OR length(trim(new.destination_area))<2 THEN RAISE EXCEPTION 'Invalid logistics enquiry plan';END IF;
 END IF;RETURN new;
END $$;
REVOKE ALL ON FUNCTION public.business_service_entry_guard(),public.stay_room_guard(),public.business_service_draft_guard() FROM public,anon,authenticated,service_role;
CREATE TRIGGER business_service_entry_guard BEFORE INSERT OR UPDATE ON public.business_service_entries FOR EACH ROW EXECUTE FUNCTION public.business_service_entry_guard();
CREATE TRIGGER stay_room_guard BEFORE INSERT OR UPDATE ON public.stay_room_options FOR EACH ROW EXECUTE FUNCTION public.stay_room_guard();
CREATE TRIGGER business_service_draft_guard BEFORE INSERT ON public.business_service_enquiry_drafts FOR EACH ROW EXECUTE FUNCTION public.business_service_draft_guard();
ALTER TABLE public.business_service_entries ENABLE ROW LEVEL SECURITY;ALTER TABLE public.stay_room_options ENABLE ROW LEVEL SECURITY;ALTER TABLE public.business_service_enquiry_drafts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.business_service_entries,public.stay_room_options,public.business_service_enquiry_drafts FROM public,anon,authenticated,service_role;
GRANT SELECT,INSERT(organisation_id,owner_id,kind,name,category,location,description,features,service_areas,media_paths,status),UPDATE(name,category,location,description,features,service_areas,media_paths,status) ON public.business_service_entries TO authenticated;
GRANT SELECT,INSERT(entry_id,name,guest_capacity,nightly_minor,listed),UPDATE(name,guest_capacity,nightly_minor,listed) ON public.stay_room_options TO authenticated;
GRANT SELECT,INSERT(author_id,entry_id,room_option_id,note,desired_start,desired_end,guests,origin_area,destination_area) ON public.business_service_enquiry_drafts TO authenticated;
CREATE POLICY business_service_owner_read ON public.business_service_entries FOR SELECT TO authenticated USING(owner_id=(SELECT auth.uid()));
CREATE POLICY business_service_owner_insert ON public.business_service_entries FOR INSERT TO authenticated WITH CHECK(owner_id=(SELECT auth.uid()) AND public.business_is_owner(organisation_id));
CREATE POLICY business_service_owner_update ON public.business_service_entries FOR UPDATE TO authenticated USING(owner_id=(SELECT auth.uid()) AND public.marketplace_complete_member()) WITH CHECK(owner_id=(SELECT auth.uid()));
CREATE POLICY stay_room_owner_read ON public.stay_room_options FOR SELECT TO authenticated USING(public.business_service_owner(entry_id));
CREATE POLICY stay_room_owner_insert ON public.stay_room_options FOR INSERT TO authenticated WITH CHECK(public.business_service_owner(entry_id));
CREATE POLICY stay_room_owner_update ON public.stay_room_options FOR UPDATE TO authenticated USING(public.business_service_owner(entry_id)) WITH CHECK(public.business_service_owner(entry_id));
CREATE POLICY business_service_draft_read ON public.business_service_enquiry_drafts FOR SELECT TO authenticated USING(author_id=(SELECT auth.uid()));
CREATE POLICY business_service_draft_insert ON public.business_service_enquiry_drafts FOR INSERT TO authenticated WITH CHECK(author_id=(SELECT auth.uid()) AND public.marketplace_complete_member());
CREATE VIEW public.public_business_services AS SELECT e.id,e.organisation_id,e.owner_id,e.kind,e.name,e.category,e.location,e.description,e.features,e.service_areas,e.media_paths,e.created_at,o.name provider_name FROM public.business_service_entries e JOIN public.business_organisations o ON o.id=e.organisation_id WHERE public.business_service_visible(e.id);
CREATE VIEW public.public_stay_rooms AS SELECT r.id,r.entry_id,r.name,r.guest_capacity,r.nightly_minor,r.currency FROM public.stay_room_options r WHERE r.listed AND public.business_service_visible(r.entry_id);
REVOKE ALL ON public.public_business_services,public.public_stay_rooms FROM public,anon,authenticated,service_role;GRANT SELECT ON public.public_business_services,public.public_stay_rooms TO anon,authenticated;
CREATE FUNCTION public.business_service_image_visible(p_path text) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$SELECT EXISTS(SELECT 1 FROM public.business_service_entries WHERE p_path=ANY(media_paths) AND public.business_service_visible(id))$$;
REVOKE ALL ON FUNCTION public.business_service_image_visible(text) FROM public,anon,authenticated,service_role;GRANT EXECUTE ON FUNCTION public.business_service_image_visible(text) TO anon,authenticated;
INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types) VALUES('business-service-media','business-service-media',false,5242880,ARRAY['image/jpeg','image/png','image/webp']);
CREATE POLICY business_service_image_read ON storage.objects FOR SELECT TO anon,authenticated USING(bucket_id='business-service-media' AND ((storage.foldername(name))[1]=(SELECT auth.uid())::text OR public.business_service_image_visible(name)));
CREATE POLICY business_service_image_read_guard ON storage.objects AS RESTRICTIVE FOR SELECT TO anon,authenticated USING(bucket_id<>'business-service-media' OR ((storage.foldername(name))[1]=(SELECT auth.uid())::text OR public.business_service_image_visible(name)));
CREATE POLICY business_service_image_upload ON storage.objects FOR INSERT TO authenticated WITH CHECK(bucket_id='business-service-media' AND (storage.foldername(name))[1]=(SELECT auth.uid())::text AND public.marketplace_complete_member());
CREATE POLICY business_service_image_upload_guard ON storage.objects AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK(bucket_id<>'business-service-media' OR((storage.foldername(name))[1]=(SELECT auth.uid())::text AND name NOT LIKE '%..%' AND public.marketplace_complete_member()));
CREATE POLICY business_service_image_no_update ON storage.objects AS RESTRICTIVE FOR UPDATE TO authenticated USING(bucket_id<>'business-service-media') WITH CHECK(bucket_id<>'business-service-media');
CREATE POLICY business_service_image_no_delete ON storage.objects AS RESTRICTIVE FOR DELETE TO authenticated USING(bucket_id<>'business-service-media');
COMMIT;
