-- HOLD / REVIEW ONLY. Agriculture + Digital catalogues; no existing tables/policies replaced.
-- Requires existing membership/profile baseline. Publication disabled, no purchase/issuance RPC.
BEGIN;
SET LOCAL lock_timeout='5s';SET LOCAL statement_timeout='60s';
CREATE TABLE public.specialist_settings(singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),allow_publishing boolean NOT NULL DEFAULT false);
INSERT INTO public.specialist_settings VALUES(true,false);ALTER TABLE public.specialist_settings ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.specialist_settings FROM public,anon,authenticated,service_role;GRANT SELECT,UPDATE(allow_publishing) ON public.specialist_settings TO service_role;
CREATE FUNCTION public.specialist_publication_enabled() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$SELECT coalesce((SELECT allow_publishing FROM public.specialist_settings WHERE singleton),false)$$;
REVOKE ALL ON FUNCTION public.specialist_publication_enabled() FROM public,anon,authenticated,service_role;GRANT EXECUTE ON FUNCTION public.specialist_publication_enabled() TO anon,authenticated;
CREATE TABLE public.specialist_listings(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),owner_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id),
 kind text NOT NULL CHECK(kind IN('agriculture','digital')),title text NOT NULL CHECK(length(trim(title)) BETWEEN 3 AND 160),
 description text NOT NULL CHECK(length(trim(description)) BETWEEN 20 AND 5000),category text NOT NULL CHECK(length(category) BETWEEN 2 AND 100),
 location text NOT NULL CHECK(length(trim(location)) BETWEEN 2 AND 160),organisation text NOT NULL CHECK(length(trim(organisation)) BETWEEN 3 AND 120),
 price numeric NOT NULL CHECK(price BETWEEN 0 AND 1000000000),currency text NOT NULL DEFAULT 'ZMW' CHECK(currency='ZMW'),
 unit text NOT NULL CHECK(length(unit) BETWEEN 2 AND 60),quantity numeric CHECK(quantity>0 AND quantity<=1000000),
 licence text NOT NULL DEFAULT '' CHECK(length(licence)<=1000),media_paths text[] NOT NULL DEFAULT '{}' CHECK(cardinality(media_paths)<=5),
 status text NOT NULL DEFAULT 'draft' CHECK(status IN('draft','published','closed')),created_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now(),
 CHECK(kind<>'digital' OR length(trim(licence))>=10),CHECK(kind<>'agriculture' OR quantity IS NOT NULL)
);
CREATE INDEX specialist_discovery_idx ON public.specialist_listings(kind,status,created_at DESC);CREATE INDEX specialist_owner_idx ON public.specialist_listings(owner_id);
CREATE FUNCTION public.specialist_listing_guard() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE caller uuid:=auth.uid();path text;
BEGIN
 IF caller IS NULL OR new.owner_id IS DISTINCT FROM caller OR NOT public.marketplace_complete_member() THEN RAISE EXCEPTION 'Verified listing owner required';END IF;
 IF tg_op='UPDATE' THEN IF new.id IS DISTINCT FROM old.id OR new.owner_id IS DISTINCT FROM old.owner_id OR new.kind IS DISTINCT FROM old.kind THEN RAISE EXCEPTION 'Listing identity immutable';END IF;new.created_at:=old.created_at;END IF;
 IF new.status='published' AND NOT public.specialist_publication_enabled() THEN RAISE EXCEPTION 'Publication disabled';END IF;
 FOREACH path IN ARRAY new.media_paths LOOP IF path IS NULL OR path NOT LIKE caller::text||'/%' OR path LIKE '%..%' OR NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='specialist-previews' AND name=path) THEN RAISE EXCEPTION 'Invalid preview image';END IF;END LOOP;
 new.updated_at:=now();RETURN new;
END $$;
REVOKE ALL ON FUNCTION public.specialist_listing_guard() FROM public,anon,authenticated,service_role;
CREATE TRIGGER specialist_listing_guard BEFORE INSERT OR UPDATE ON public.specialist_listings FOR EACH ROW EXECUTE FUNCTION public.specialist_listing_guard();
ALTER TABLE public.specialist_listings ENABLE ROW LEVEL SECURITY;REVOKE ALL ON public.specialist_listings FROM public,anon,authenticated,service_role;
GRANT SELECT ON public.specialist_listings TO anon,authenticated;
GRANT INSERT(owner_id,kind,title,description,category,location,organisation,price,unit,quantity,licence,media_paths,status),UPDATE(title,description,category,location,organisation,price,unit,quantity,licence,media_paths,status) ON public.specialist_listings TO authenticated;
CREATE POLICY specialist_read ON public.specialist_listings FOR SELECT TO anon,authenticated USING(owner_id=(SELECT auth.uid()) OR(status='published' AND public.specialist_publication_enabled()));
CREATE POLICY specialist_insert ON public.specialist_listings FOR INSERT TO authenticated WITH CHECK(owner_id=(SELECT auth.uid()) AND public.marketplace_complete_member());
CREATE POLICY specialist_update ON public.specialist_listings FOR UPDATE TO authenticated USING(owner_id=(SELECT auth.uid()) AND public.marketplace_complete_member()) WITH CHECK(owner_id=(SELECT auth.uid()));
CREATE TABLE public.digital_private_assets(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),listing_id uuid NOT NULL REFERENCES public.specialist_listings(id),owner_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id),
 path text NOT NULL UNIQUE,version_label text NOT NULL CHECK(length(version_label) BETWEEN 1 AND 80),scan_status text NOT NULL DEFAULT 'pending' CHECK(scan_status IN('pending','approved','blocked')),created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.digital_entitlements(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),asset_id uuid NOT NULL REFERENCES public.digital_private_assets(id),buyer_id uuid NOT NULL REFERENCES auth.users(id),
 purchase_reference text NOT NULL UNIQUE CHECK(length(purchase_reference) BETWEEN 8 AND 200),created_at timestamptz NOT NULL DEFAULT now(),revoked_at timestamptz,UNIQUE(asset_id,buyer_id)
);
CREATE INDEX digital_asset_owner_idx ON public.digital_private_assets(owner_id);CREATE INDEX digital_entitlement_buyer_idx ON public.digital_entitlements(buyer_id);
CREATE FUNCTION public.digital_asset_guard() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL OR new.owner_id IS DISTINCT FROM auth.uid() OR NOT public.marketplace_complete_member() OR NOT EXISTS(SELECT 1 FROM public.specialist_listings WHERE id=new.listing_id AND kind='digital' AND owner_id=auth.uid()) OR new.path NOT LIKE auth.uid()::text||'/%' OR new.path LIKE '%..%' OR NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='digital-products' AND name=new.path) THEN RAISE EXCEPTION 'Invalid private asset ownership';END IF;RETURN new;
END $$;
REVOKE ALL ON FUNCTION public.digital_asset_guard() FROM public,anon,authenticated,service_role;
CREATE TRIGGER digital_asset_guard BEFORE INSERT ON public.digital_private_assets FOR EACH ROW EXECUTE FUNCTION public.digital_asset_guard();
ALTER TABLE public.digital_private_assets ENABLE ROW LEVEL SECURITY;ALTER TABLE public.digital_entitlements ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.digital_private_assets,public.digital_entitlements FROM public,anon,authenticated,service_role;
GRANT SELECT,INSERT(listing_id,owner_id,path,version_label) ON public.digital_private_assets TO authenticated;
GRANT SELECT ON public.digital_entitlements TO authenticated;
GRANT SELECT,UPDATE(scan_status) ON public.digital_private_assets TO service_role;
GRANT SELECT,INSERT(asset_id,buyer_id,purchase_reference),UPDATE(revoked_at) ON public.digital_entitlements TO service_role;
CREATE POLICY digital_asset_owner_read ON public.digital_private_assets FOR SELECT TO authenticated USING(owner_id=(SELECT auth.uid()));
CREATE POLICY digital_asset_owner_insert ON public.digital_private_assets FOR INSERT TO authenticated WITH CHECK(owner_id=(SELECT auth.uid()) AND public.marketplace_complete_member());
CREATE POLICY digital_entitlement_read ON public.digital_entitlements FOR SELECT TO authenticated USING(buyer_id=(SELECT auth.uid()));
CREATE FUNCTION public.specialist_media_visible(p_path text) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$SELECT public.specialist_publication_enabled() AND EXISTS(SELECT 1 FROM public.specialist_listings WHERE status='published' AND p_path=ANY(media_paths))$$;
-- Buyers cannot directly mint arbitrary-duration Storage signed URLs. Download endpoint remains unimplemented.
CREATE FUNCTION public.digital_asset_access(p_path text) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$SELECT auth.uid() IS NOT NULL AND public.marketplace_verified_user() AND EXISTS(SELECT 1 FROM public.digital_private_assets a WHERE a.path=p_path AND a.owner_id=auth.uid())$$;
CREATE FUNCTION public.digital_download_eligible(p_asset uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$SELECT auth.uid() IS NOT NULL AND public.marketplace_verified_user() AND EXISTS(SELECT 1 FROM public.digital_private_assets a JOIN public.digital_entitlements e ON e.asset_id=a.id WHERE a.id=p_asset AND a.scan_status='approved' AND e.buyer_id=auth.uid() AND e.revoked_at IS NULL)$$;
REVOKE ALL ON FUNCTION public.specialist_media_visible(text),public.digital_asset_access(text) FROM public,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.specialist_media_visible(text) TO anon,authenticated;GRANT EXECUTE ON FUNCTION public.digital_asset_access(text) TO authenticated;
REVOKE ALL ON FUNCTION public.digital_download_eligible(uuid) FROM public,anon,authenticated,service_role;GRANT EXECUTE ON FUNCTION public.digital_download_eligible(uuid) TO authenticated;
INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types) VALUES('specialist-previews','specialist-previews',false,5242880,ARRAY['image/jpeg','image/png','image/webp']),('digital-products','digital-products',false,26214400,ARRAY['application/pdf','application/zip']);
CREATE POLICY specialist_preview_read ON storage.objects FOR SELECT TO anon,authenticated USING(bucket_id='specialist-previews' AND((storage.foldername(name))[1]=(SELECT auth.uid())::text OR public.specialist_media_visible(name)));
CREATE POLICY specialist_preview_read_guard ON storage.objects AS RESTRICTIVE FOR SELECT TO anon,authenticated USING(bucket_id<>'specialist-previews' OR((storage.foldername(name))[1]=(SELECT auth.uid())::text OR public.specialist_media_visible(name)));
CREATE POLICY digital_file_read ON storage.objects FOR SELECT TO authenticated USING(bucket_id='digital-products' AND public.digital_asset_access(name));
CREATE POLICY digital_file_read_guard ON storage.objects AS RESTRICTIVE FOR SELECT TO authenticated USING(bucket_id<>'digital-products' OR public.digital_asset_access(name));
CREATE POLICY digital_no_anon_read ON storage.objects AS RESTRICTIVE FOR SELECT TO anon USING(bucket_id<>'digital-products');
CREATE POLICY specialist_upload ON storage.objects FOR INSERT TO authenticated WITH CHECK(bucket_id IN('specialist-previews','digital-products') AND (storage.foldername(name))[1]=(SELECT auth.uid())::text AND public.marketplace_complete_member());
CREATE POLICY specialist_upload_guard ON storage.objects AS RESTRICTIVE FOR INSERT TO authenticated WITH CHECK(bucket_id NOT IN('specialist-previews','digital-products') OR((storage.foldername(name))[1]=(SELECT auth.uid())::text AND name NOT LIKE '%..%' AND public.marketplace_complete_member()));
CREATE POLICY specialist_no_overwrite ON storage.objects AS RESTRICTIVE FOR UPDATE TO authenticated USING(bucket_id NOT IN('specialist-previews','digital-products')) WITH CHECK(bucket_id NOT IN('specialist-previews','digital-products'));
CREATE POLICY specialist_no_delete ON storage.objects AS RESTRICTIVE FOR DELETE TO authenticated USING(bucket_id NOT IN('specialist-previews','digital-products'));
COMMIT;
