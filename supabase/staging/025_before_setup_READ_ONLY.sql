-- READ ONLY: run in the separate STAGING SQL Editor before migration approval.
-- Lists schema metadata only, never accounts, messages, contacts or photos.
SELECT jsonb_build_object(
 'public_relations',(SELECT coalesce(jsonb_agg(jsonb_build_object('name',c.relname,'kind',c.relkind,'rls_enabled',c.relrowsecurity) ORDER BY c.relname),'[]'::jsonb) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relkind IN('r','p','v','m')),
 'application_helpers',(SELECT coalesce(jsonb_agg(jsonb_build_object('name',p.proname,'arguments',pg_get_function_identity_arguments(p.oid)) ORDER BY p.proname),'[]'::jsonb) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND (p.proname LIKE 'zammarket_%' OR p.proname LIKE 'marketplace_%' OR p.proname LIKE 'business_%' OR p.proname IN('manage_listing','start_conversation','stay_room_guard','save_marketplace_profile','public_seller_profile'))),
 'existing_buckets',(SELECT coalesce(jsonb_agg(jsonb_build_object('id',b.id,'public',b.public,'file_size_limit',b.file_size_limit,'allowed_mime_types',b.allowed_mime_types) ORDER BY b.id),'[]'::jsonb) FROM storage.buckets b),
 'policies',(SELECT coalesce(jsonb_agg(jsonb_build_object('schema',schemaname,'table',tablename,'policy',policyname,'command',cmd,'roles',roles) ORDER BY schemaname,tablename,policyname),'[]'::jsonb) FROM pg_policies WHERE schemaname IN('public','storage'))
) AS staging_before_setup_report;
