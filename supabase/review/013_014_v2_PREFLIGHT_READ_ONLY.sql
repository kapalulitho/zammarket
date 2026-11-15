-- READ ONLY. Returns schema metadata only. Does not approve or apply either draft.
SELECT jsonb_build_object(
 'complete_member_function',to_regprocedure('public.marketplace_complete_member()'),
 'listings_table',to_regclass('public.listings'),
 'listing_id_type',(SELECT data_type FROM information_schema.columns WHERE table_schema='public' AND table_name='listings' AND column_name='id'),
 'existing_stage3_tables',(SELECT jsonb_agg(c.relname) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname IN('community_entries','seller_shops','module_enquiries','marketplace_notifications','listing_stock','marketplace_trade_receipts','seller_reviews','promotion_drafts')),
 'existing_stage3_functions',(SELECT jsonb_agg(p.proname) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname LIKE 'stage3_%'),
 'existing_media_bucket',(SELECT jsonb_build_object('id',id,'public',public,'limit',file_size_limit) FROM storage.buckets WHERE id='marketplace-media'),
 'storage_select_grants',(SELECT jsonb_agg(jsonb_build_object('role',grantee,'privilege',privilege_type)) FROM information_schema.role_table_grants WHERE table_schema='storage' AND table_name='objects' AND grantee IN('anon','authenticated') AND privilege_type='SELECT')
) AS stage3_v2_preflight;
