-- Review before any approval/application. One row; no function execution or data writes.
BEGIN READ ONLY;
SELECT jsonb_build_object(
 'required_profile_helper',to_regprocedure('public.marketplace_complete_member()')::text,
 'listing_id_type',(SELECT data_type FROM information_schema.columns WHERE table_schema='public' AND table_name='listings' AND column_name='id'),
 'existing_new_tables',(SELECT jsonb_agg(table_name) FROM information_schema.tables WHERE table_schema='public' AND table_name IN('community_entries','seller_shops','module_enquiries','marketplace_notifications','listing_stock','marketplace_trade_receipts','seller_reviews','promotion_drafts')),
 'existing_stage3_functions',(SELECT jsonb_agg(p.proname) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname LIKE 'stage3_%'),
 'bucket_settings',(SELECT jsonb_agg(jsonb_build_object('id',id,'public',public,'file_size_limit',file_size_limit,'allowed_mime_types',allowed_mime_types)) FROM storage.buckets WHERE id IN('listing-images','avatars','marketplace-media')),
 'migration_012_fingerprint',(SELECT md5(pg_get_functiondef(p.oid)) FROM pg_proc p WHERE p.oid=to_regprocedure('public.marketplace_message_membership_guard()')),
 'listing_count',(SELECT count(*) FROM public.listings),
 'profiles_count',(SELECT count(*) FROM public.marketplace_profiles),
 'product_messages_count',(SELECT count(*) FROM public.messages)
) AS stage3_preflight;
ROLLBACK;
