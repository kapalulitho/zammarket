BEGIN READ ONLY;
SELECT table_name,column_name,data_type FROM information_schema.columns
 WHERE table_schema='public' AND table_name IN('marketplace_profiles','profiles','listings','conversations','messages')
 ORDER BY table_name,ordinal_position;
SELECT * FROM pg_policies WHERE (schemaname='public' AND tablename IN('marketplace_profiles','listings','messages','conversations'))
 OR (schemaname='storage' AND tablename='objects');
SELECT id,public,file_size_limit,allowed_mime_types FROM storage.buckets WHERE id IN('avatars','listing-images');
SELECT tgname,pg_get_triggerdef(oid) FROM pg_trigger WHERE tgrelid='public.listings'::regclass AND NOT tgisinternal;
SELECT p.proname,pg_get_function_identity_arguments(p.oid) AS arguments,p.prosecdef AS security_definer
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public'
 AND (p.proname LIKE 'marketplace_%' OR p.proname IN('save_marketplace_profile','public_seller_profile'));
ROLLBACK;
