-- HOLD / REVIEW ONLY. No existing account, profile, storefront or listing is reassigned.
-- Requires verified/completed membership helpers. Staff permissions/invitations not activated.
BEGIN;
SET LOCAL lock_timeout='5s';SET LOCAL statement_timeout='60s';
CREATE TABLE public.business_foundation_settings(singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),publish_profiles boolean NOT NULL DEFAULT false);
INSERT INTO public.business_foundation_settings VALUES(true,false);ALTER TABLE public.business_foundation_settings ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.business_foundation_settings FROM public,anon,authenticated,service_role;GRANT SELECT,UPDATE(publish_profiles) ON public.business_foundation_settings TO service_role;
CREATE TABLE public.business_organisations(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),owner_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id),
 kind text NOT NULL CHECK(kind IN('personal','small_business','company')),name text NOT NULL CHECK(length(trim(name)) BETWEEN 3 AND 100),
 description text NOT NULL CHECK(length(trim(description)) BETWEEN 10 AND 3000),location text NOT NULL CHECK(length(trim(location)) BETWEEN 2 AND 200),
 phone text NOT NULL DEFAULT '' CHECK(phone='' OR phone ~ '^\+[1-9][0-9]{6,14}$'),whatsapp text NOT NULL DEFAULT '' CHECK(whatsapp='' OR whatsapp ~ '^\+[1-9][0-9]{6,14}$'),
 public_email text NOT NULL DEFAULT '' CHECK(public_email='' OR public_email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'),
 show_phone boolean NOT NULL DEFAULT false,show_whatsapp boolean NOT NULL DEFAULT false,show_public_email boolean NOT NULL DEFAULT false,show_location boolean NOT NULL DEFAULT false,
 logo_path text,status text NOT NULL DEFAULT 'draft' CHECK(status IN('draft','published','closed')),
 created_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.business_memberships(
 organisation_id uuid NOT NULL REFERENCES public.business_organisations(id),user_id uuid NOT NULL REFERENCES auth.users(id),
 role text NOT NULL CHECK(role IN('manager','catalogue_editor','enquiry_responder','analyst')),active boolean NOT NULL DEFAULT false,
 created_at timestamptz NOT NULL DEFAULT now(),PRIMARY KEY(organisation_id,user_id)
);
CREATE TABLE public.business_branches(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),organisation_id uuid NOT NULL REFERENCES public.business_organisations(id),
 name text NOT NULL CHECK(length(trim(name)) BETWEEN 1 AND 100),location text NOT NULL CHECK(length(trim(location)) BETWEEN 2 AND 200),
 status text NOT NULL DEFAULT 'draft' CHECK(status IN('draft','published','closed')),created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX business_owner_idx ON public.business_organisations(owner_id);CREATE INDEX business_member_user_idx ON public.business_memberships(user_id);
CREATE INDEX business_branch_org_idx ON public.business_branches(organisation_id);
CREATE FUNCTION public.business_is_owner(p_org uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$SELECT auth.uid() IS NOT NULL AND EXISTS(SELECT 1 FROM public.business_organisations WHERE id=p_org AND owner_id=auth.uid())$$;
CREATE FUNCTION public.business_publication_enabled() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$SELECT coalesce((SELECT publish_profiles FROM public.business_foundation_settings WHERE singleton),false)$$;
REVOKE ALL ON FUNCTION public.business_is_owner(uuid),public.business_publication_enabled() FROM public,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.business_is_owner(uuid) TO authenticated;GRANT EXECUTE ON FUNCTION public.business_publication_enabled() TO anon,authenticated;
CREATE FUNCTION public.business_org_guard() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL OR new.owner_id IS DISTINCT FROM auth.uid() OR NOT public.marketplace_complete_member() THEN RAISE EXCEPTION 'Verified organisation owner required';END IF;
 IF tg_op='UPDATE' THEN IF new.id IS DISTINCT FROM old.id OR new.owner_id IS DISTINCT FROM old.owner_id THEN RAISE EXCEPTION 'Business identity immutable';END IF;new.created_at:=old.created_at;END IF;
 IF new.status='published' AND NOT public.business_publication_enabled() THEN RAISE EXCEPTION 'Business publication disabled';END IF;
 IF new.public_email<>'' AND EXISTS(SELECT 1 FROM auth.users WHERE id=auth.uid() AND lower(email)=lower(new.public_email)) THEN RAISE EXCEPTION 'Use a public contact email different from login';END IF;
 IF new.logo_path IS NOT NULL AND (new.logo_path NOT LIKE auth.uid()::text||'/%' OR new.logo_path LIKE '%..%' OR NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='business-media' AND name=new.logo_path)) THEN RAISE EXCEPTION 'Invalid logo ownership';END IF;
 new.updated_at:=now();RETURN new;
END $$;
CREATE FUNCTION public.business_branch_guard() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT public.marketplace_complete_member() OR NOT public.business_is_owner(new.organisation_id) THEN RAISE EXCEPTION 'Branch owner required';END IF;
 IF tg_op='UPDATE' THEN IF new.id IS DISTINCT FROM old.id OR new.organisation_id IS DISTINCT FROM old.organisation_id THEN RAISE EXCEPTION 'Branch identity immutable';END IF;new.created_at:=old.created_at;END IF;
 IF new.status='published' AND NOT public.business_publication_enabled() THEN RAISE EXCEPTION 'Branch publication disabled';END IF;RETURN new;
END $$;
REVOKE ALL ON FUNCTION public.business_org_guard(),public.business_branch_guard() FROM public,anon,authenticated,service_role;
CREATE TRIGGER business_org_guard BEFORE INSERT OR UPDATE ON public.business_organisations FOR EACH ROW EXECUTE FUNCTION public.business_org_guard();
CREATE TRIGGER business_branch_guard BEFORE INSERT OR UPDATE ON public.business_branches FOR EACH ROW EXECUTE FUNCTION public.business_branch_guard();
ALTER TABLE public.business_organisations ENABLE ROW LEVEL SECURITY;ALTER TABLE public.business_memberships ENABLE ROW LEVEL SECURITY;ALTER TABLE public.business_branches ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.business_organisations,public.business_memberships,public.business_branches FROM public,anon,authenticated,service_role;
GRANT SELECT,INSERT(owner_id,kind,name,description,location,phone,whatsapp,public_email,show_phone,show_whatsapp,show_public_email,show_location,logo_path,status),UPDATE(kind,name,description,location,phone,whatsapp,public_email,show_phone,show_whatsapp,show_public_email,show_location,logo_path,status) ON public.business_organisations TO authenticated;
GRANT SELECT ON public.business_memberships TO authenticated;GRANT SELECT,INSERT,UPDATE(role,active) ON public.business_memberships TO service_role;
GRANT SELECT,INSERT(organisation_id,name,location,status),UPDATE(name,location,status) ON public.business_branches TO authenticated;
CREATE POLICY business_owner_read ON public.business_organisations FOR SELECT TO authenticated USING(owner_id=(SELECT auth.uid()));
CREATE POLICY business_owner_insert ON public.business_organisations FOR INSERT TO authenticated WITH CHECK(owner_id=(SELECT auth.uid()) AND public.marketplace_complete_member());
CREATE POLICY business_owner_update ON public.business_organisations FOR UPDATE TO authenticated USING(owner_id=(SELECT auth.uid()) AND public.marketplace_complete_member()) WITH CHECK(owner_id=(SELECT auth.uid()));
CREATE POLICY business_membership_read ON public.business_memberships FOR SELECT TO authenticated USING(user_id=(SELECT auth.uid()) OR public.business_is_owner(organisation_id));
CREATE POLICY business_branch_read ON public.business_branches FOR SELECT TO authenticated USING(public.business_is_owner(organisation_id));
CREATE POLICY business_branch_insert ON public.business_branches FOR INSERT TO authenticated WITH CHECK(public.business_is_owner(organisation_id) AND public.marketplace_complete_member());
CREATE POLICY business_branch_update ON public.business_branches FOR UPDATE TO authenticated USING(public.business_is_owner(organisation_id) AND public.marketplace_complete_member()) WITH CHECK(public.business_is_owner(organisation_id));
-- Administrator-owned explicit projection: raw contacts stay owner-only.
CREATE VIEW public.public_business_profiles AS SELECT id,owner_id,kind,name,description,logo_path,CASE WHEN show_location THEN location END location,CASE WHEN show_phone THEN phone END phone,CASE WHEN show_whatsapp THEN whatsapp END whatsapp,CASE WHEN show_public_email THEN public_email END public_email FROM public.business_organisations WHERE status='published' AND public.business_publication_enabled();
CREATE VIEW public.public_business_branches AS SELECT b.id,b.organisation_id,b.name,b.location FROM public.business_branches b JOIN public.business_organisations o ON o.id=b.organisation_id WHERE b.status='published' AND o.status='published' AND public.business_publication_enabled();
REVOKE ALL ON public.public_business_profiles,public.public_business_branches FROM public,anon,authenticated,service_role;GRANT SELECT ON public.public_business_profiles,public.public_business_branches TO anon,authenticated;
CREATE FUNCTION public.business_logo_visible(p_path text) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$SELECT public.business_publication_enabled() AND EXISTS(SELECT 1 FROM public.business_organisations WHERE status='published' AND logo_path=p_path)$$;
REVOKE ALL ON FUNCTION public.business_logo_visible(text) FROM public,anon,authenticated,service_role;GRANT EXECUTE ON FUNCTION public.business_logo_visible(text) TO anon,authenticated;
INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types) VALUES('business-media','business-media',false,2097152,ARRAY['image/jpeg','image/png','image/webp']);
CREATE POLICY business_logo_read ON storage.objects FOR SELECT TO anon,authenticated USING(bucket_id='business-media' AND ((storage.foldername(name))[1]=(SELECT auth.uid())::text OR public.business_logo_visible(name)));
CREATE POLICY business_logo_read_guard ON storage.objects AS RESTRICTIVE FOR SELECT TO anon,authenticated USING(bucket_id<>'business-media' OR ((storage.foldername(name))[1]=(SELECT auth.uid())::text OR public.business_logo_visible(name)));
CREATE POLICY business_logo_upload ON storage.objects FOR INSERT TO authenticated WITH CHECK(bucket_id='business-media' AND (storage.foldername(name))[1]=(SELECT auth.uid())::text AND public.marketplace_complete_member());
CREATE POLICY business_logo_upload_guard ON storage.objects AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK(bucket_id<>'business-media' OR((storage.foldername(name))[1]=(SELECT auth.uid())::text AND name NOT LIKE '%..%' AND public.marketplace_complete_member()));
CREATE POLICY business_logo_no_update ON storage.objects AS RESTRICTIVE FOR UPDATE TO authenticated USING(bucket_id<>'business-media') WITH CHECK(bucket_id<>'business-media');
CREATE POLICY business_logo_no_delete ON storage.objects AS RESTRICTIVE FOR DELETE TO authenticated USING(bucket_id<>'business-media');
COMMIT;
