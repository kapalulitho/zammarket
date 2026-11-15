-- Metadata only. No migrations or row data are changed or returned.
SELECT jsonb_build_object(
 'membership_helper',to_regprocedure('public.marketplace_complete_member()'),
 'profiles',to_regclass('public.marketplace_profiles'),
 'existing_new_tables',(SELECT jsonb_agg(c.relname) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname IN('property_listings','property_saved','property_enquiries','delivery_drafts','courier_profile_drafts')),
 'existing_new_functions',(SELECT jsonb_agg(p.proname) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname IN('property_listing_guard','property_enquiry_guard','property_image_visible','property_capabilities','delivery_plan_guard','courier_profile_draft_guard','delivery_capabilities')),
 'existing_property_bucket',(SELECT jsonb_build_object('id',id,'public',public,'limit',file_size_limit) FROM storage.buckets WHERE id='property-media'),
 'storage_api_select_grants',(SELECT jsonb_agg(jsonb_build_object('role',grantee,'privilege',privilege_type)) FROM information_schema.role_table_grants WHERE table_schema='storage' AND table_name='objects' AND grantee IN('anon','authenticated') AND privilege_type='SELECT')
) AS property_delivery_preflight;
