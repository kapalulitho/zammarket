-- REVIEW ONLY. No live execution authorized. Run the profile preflight first.
-- Requires existing listings(user_id,seller_id,seller_name) and Auth/Storage.
-- Compatible with 009, but does not apply 009 or any cleanup/deletion job.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
CREATE TABLE public.marketplace_profiles (
 id uuid PRIMARY KEY REFERENCES auth.users(id),
 username text NOT NULL CHECK(username ~ '^[a-z0-9_]{3,30}$'),
 shop_name text NOT NULL CHECK(length(trim(shop_name)) BETWEEN 3 AND 60),
 account_type text NOT NULL CHECK(account_type IN ('individual','business')),
 avatar_path text NOT NULL DEFAULT '',
 whatsapp text NOT NULL DEFAULT '', phone text NOT NULL DEFAULT '',
 public_email text NOT NULL DEFAULT '', location text NOT NULL DEFAULT '',address text NOT NULL DEFAULT '',
 show_whatsapp boolean NOT NULL DEFAULT false,show_phone boolean NOT NULL DEFAULT false,
 show_public_email boolean NOT NULL DEFAULT false,show_location boolean NOT NULL DEFAULT false,
 show_address boolean NOT NULL DEFAULT false,
 completed_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now(),
 CHECK(whatsapp='' OR whatsapp ~ '^\+[1-9][0-9]{6,14}$'),
 CHECK(phone='' OR phone ~ '^\+[1-9][0-9]{6,14}$'),
 CHECK(length(public_email)<=254 AND length(location)<=120 AND length(address)<=300)
);
CREATE UNIQUE INDEX marketplace_profiles_username_unique ON public.marketplace_profiles(lower(username));
CREATE UNIQUE INDEX marketplace_profiles_shop_name_unique ON public.marketplace_profiles(lower(trim(shop_name)));
ALTER TABLE public.marketplace_profiles ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.marketplace_profiles FROM public,anon,authenticated;
GRANT SELECT ON public.marketplace_profiles TO authenticated;
CREATE POLICY marketplace_profile_owner_read ON public.marketplace_profiles FOR SELECT TO authenticated
 USING(id=(SELECT auth.uid()));
-- No direct insert/update/delete grants: reviewed saves go through the RPC.

CREATE FUNCTION public.marketplace_verified_user() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT EXISTS(SELECT 1 FROM auth.users WHERE id=auth.uid() AND email_confirmed_at IS NOT NULL)
$$;
CREATE FUNCTION public.marketplace_complete_member() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT public.marketplace_verified_user() AND EXISTS(
   SELECT 1 FROM public.marketplace_profiles WHERE id=auth.uid() AND completed_at IS NOT NULL)
$$;
REVOKE ALL ON FUNCTION public.marketplace_verified_user(),public.marketplace_complete_member() FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.marketplace_verified_user(),public.marketplace_complete_member() TO authenticated;

-- Legacy accounts may have been auto-confirmed. Initial profile completion also
-- requires an OTP-authenticated session, not only an old confirmation timestamp.
CREATE FUNCTION public.marketplace_profile_requires_verification() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT NOT EXISTS(SELECT 1 FROM public.marketplace_profiles WHERE id=auth.uid())
   AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(auth.jwt()->'amr','[]'::jsonb)) method
     WHERE method->>'method'='otp' OR method='"otp"'::jsonb)
$$;
REVOKE ALL ON FUNCTION public.marketplace_profile_requires_verification() FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.marketplace_profile_requires_verification() TO authenticated;

CREATE FUNCTION public.save_marketplace_profile(p_profile jsonb,p_confirm boolean) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
 caller uuid:=auth.uid(); result public.marketplace_profiles;
 handle text:=lower(trim(coalesce(p_profile->>'username','')));
 shop text:=trim(coalesce(p_profile->>'shop_name',''));
 kind text:=p_profile->>'account_type';
 avatar text:=coalesce(p_profile->>'avatar_path','');
 wa text:=regexp_replace(coalesce(p_profile->>'whatsapp',''),'[ ()-]','','g');
 tel text:=regexp_replace(coalesce(p_profile->>'phone',''),'[ ()-]','','g');
 mail text:=trim(coalesce(p_profile->>'public_email',''));
 town text:=trim(coalesce(p_profile->>'location',''));
 street text:=trim(coalesce(p_profile->>'address',''));
BEGIN
 IF NOT public.marketplace_verified_user() THEN RAISE EXCEPTION 'Verified email required'; END IF;
 IF public.marketplace_profile_requires_verification() THEN RAISE EXCEPTION 'Email code verification required before first profile setup'; END IF;
 IF p_confirm IS DISTINCT FROM true THEN RAISE EXCEPTION 'Profile review must be confirmed'; END IF;
 IF handle !~ '^[a-z0-9_]{3,30}$' OR length(shop) NOT BETWEEN 3 AND 60
   OR kind IS NULL OR kind NOT IN ('individual','business') THEN RAISE EXCEPTION 'Invalid profile names or account type'; END IF;
 IF (wa<>'' AND wa !~ '^\+[1-9][0-9]{6,14}$') OR (tel<>'' AND tel !~ '^\+[1-9][0-9]{6,14}$')
   OR length(mail)>254 OR length(town)>120 OR length(street)>300 THEN RAISE EXCEPTION 'Invalid contact details'; END IF;
 IF mail<>'' AND (mail !~* '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
   OR EXISTS(SELECT 1 FROM auth.users WHERE id=caller AND lower(email)=lower(mail))) THEN
   RAISE EXCEPTION 'Public contact email must be valid and different from private login email'; END IF;
 IF avatar<>'' AND (avatar NOT LIKE caller::text||'/%' OR position('..' IN avatar)>0
   OR NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='avatars' AND name=avatar)) THEN
   RAISE EXCEPTION 'Avatar must be an existing file in your own folder'; END IF;
 INSERT INTO public.marketplace_profiles(id,username,shop_name,account_type,avatar_path,
   whatsapp,phone,public_email,location,address,show_whatsapp,show_phone,show_public_email,show_location,show_address)
 VALUES(caller,handle,shop,kind,avatar,wa,tel,mail,town,street,
   coalesce((p_profile->>'show_whatsapp')::boolean,false),coalesce((p_profile->>'show_phone')::boolean,false),
   coalesce((p_profile->>'show_public_email')::boolean,false),coalesce((p_profile->>'show_location')::boolean,false),
   coalesce((p_profile->>'show_address')::boolean,false))
 ON CONFLICT(id) DO UPDATE SET username=excluded.username,shop_name=excluded.shop_name,
   account_type=excluded.account_type,avatar_path=excluded.avatar_path,whatsapp=excluded.whatsapp,
   phone=excluded.phone,public_email=excluded.public_email,location=excluded.location,address=excluded.address,
   show_whatsapp=excluded.show_whatsapp,show_phone=excluded.show_phone,show_public_email=excluded.show_public_email,
   show_location=excluded.show_location,show_address=excluded.show_address,updated_at=now()
 RETURNING * INTO result;
 RETURN to_jsonb(result);
END $$;
REVOKE ALL ON FUNCTION public.save_marketplace_profile(jsonb,boolean) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.save_marketplace_profile(jsonb,boolean) TO authenticated;

CREATE FUNCTION public.public_seller_profile(p_user_id uuid) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT jsonb_build_object('id',id,'username',username,'shop_name',shop_name,'account_type',account_type,
 'avatar_path',avatar_path,
 'whatsapp',CASE WHEN show_whatsapp THEN nullif(whatsapp,'') END,
 'phone',CASE WHEN show_phone THEN nullif(phone,'') END,
 'public_email',CASE WHEN show_public_email THEN nullif(public_email,'') END,
 'location',CASE WHEN show_location THEN nullif(location,'') END,
 'address',CASE WHEN show_address THEN nullif(address,'') END)
 FROM public.marketplace_profiles WHERE id=p_user_id AND public.marketplace_complete_member()
$$;
REVOKE ALL ON FUNCTION public.public_seller_profile(uuid) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.public_seller_profile(uuid) TO authenticated;

-- New avatar bucket only. If already present, abort and review its existing setup.
INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
 VALUES('avatars','avatars',true,2097152,ARRAY['image/jpeg','image/png','image/webp']);
CREATE POLICY marketplace_avatar_upload ON storage.objects FOR INSERT TO authenticated
 WITH CHECK(bucket_id='avatars' AND (storage.foldername(name))[1]=(SELECT auth.uid())::text
   AND public.marketplace_verified_user());
CREATE POLICY marketplace_avatar_upload_guard ON storage.objects AS RESTRICTIVE FOR INSERT TO authenticated
 WITH CHECK(bucket_id<>'avatars' OR ((storage.foldername(name))[1]=(SELECT auth.uid())::text
   AND public.marketplace_verified_user()));
CREATE POLICY marketplace_avatar_read ON storage.objects FOR SELECT TO authenticated USING(bucket_id='avatars');
CREATE POLICY marketplace_avatar_no_overwrite ON storage.objects AS RESTRICTIVE FOR UPDATE TO authenticated
 USING(bucket_id<>'avatars') WITH CHECK(bucket_id<>'avatars');
CREATE POLICY marketplace_avatar_no_delete ON storage.objects AS RESTRICTIVE FOR DELETE TO authenticated
 USING(bucket_id<>'avatars');

-- Also protects definer RPC writes: the caller's JWT identity still passes through triggers.
CREATE FUNCTION public.marketplace_listing_membership_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
DECLARE caller uuid:=auth.uid();
BEGIN
 IF caller IS NULL THEN
   IF current_user NOT IN ('postgres','service_role') THEN RAISE EXCEPTION 'Sign in required'; END IF;
 ELSE
   IF NOT public.marketplace_complete_member() THEN RAISE EXCEPTION 'Complete your verified profile first'; END IF;
   IF tg_op='INSERT' THEN
     IF (new.user_id IS NOT NULL AND new.user_id<>caller) OR (new.seller_id IS NOT NULL AND new.seller_id<>caller)
       THEN RAISE EXCEPTION 'Owner mismatch'; END IF;
     new.user_id:=caller;new.seller_id:=caller;
     SELECT shop_name INTO new.seller_name FROM public.marketplace_profiles WHERE id=caller;
   ELSE
     IF old.user_id IS DISTINCT FROM caller THEN RAISE EXCEPTION 'Only the listing owner may change it'; END IF;
     IF tg_op='UPDATE' AND (new.user_id IS DISTINCT FROM old.user_id OR new.seller_id IS DISTINCT FROM old.seller_id)
       THEN RAISE EXCEPTION 'Ownership cannot be changed'; END IF;
   END IF;
 END IF;
 IF tg_op='DELETE' THEN RETURN old; ELSE RETURN new; END IF;
END $$;
REVOKE ALL ON FUNCTION public.marketplace_listing_membership_guard() FROM public,anon,authenticated;
CREATE TRIGGER a0_marketplace_listing_membership BEFORE INSERT OR UPDATE OR DELETE ON public.listings
 FOR EACH ROW EXECUTE FUNCTION public.marketplace_listing_membership_guard();
CREATE POLICY marketplace_member_listing_insert ON public.listings AS RESTRICTIVE FOR INSERT TO authenticated
 WITH CHECK(public.marketplace_complete_member() AND user_id=(SELECT auth.uid()));
CREATE POLICY marketplace_member_listing_update ON public.listings AS RESTRICTIVE FOR UPDATE TO authenticated
 USING(public.marketplace_complete_member() AND user_id=(SELECT auth.uid()))
 WITH CHECK(public.marketplace_complete_member() AND user_id=(SELECT auth.uid()));
CREATE POLICY marketplace_member_listing_delete ON public.listings AS RESTRICTIVE FOR DELETE TO authenticated
 USING(public.marketplace_complete_member() AND user_id=(SELECT auth.uid()));
CREATE FUNCTION public.marketplace_message_membership_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL THEN
   IF current_user NOT IN ('postgres','service_role') THEN RAISE EXCEPTION 'Sign in required'; END IF;
 ELSE
   IF NOT public.marketplace_complete_member() THEN RAISE EXCEPTION 'Complete your verified profile first'; END IF;
   IF tg_table_name='messages' AND new.sender_id IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'Sender mismatch'; END IF;
   IF tg_table_name='conversations' AND new.buyer_id IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'Buyer mismatch'; END IF;
 END IF;
 RETURN new;
END $$;
REVOKE ALL ON FUNCTION public.marketplace_message_membership_guard() FROM public,anon,authenticated;
DO $$ BEGIN
 IF to_regclass('public.messages') IS NOT NULL THEN
  EXECUTE 'CREATE TRIGGER a0_marketplace_message_membership BEFORE INSERT ON public.messages FOR EACH ROW EXECUTE FUNCTION public.marketplace_message_membership_guard()';
 END IF;
 IF to_regclass('public.conversations') IS NOT NULL THEN
  EXECUTE 'CREATE TRIGGER a0_marketplace_conversation_membership BEFORE INSERT ON public.conversations FOR EACH ROW EXECUTE FUNCTION public.marketplace_message_membership_guard()';
 END IF;
END $$;
COMMIT;
