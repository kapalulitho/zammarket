-- READ ONLY: one JSON result, no writes or RPC execution, no user records/secrets.
BEGIN READ ONLY;
SELECT jsonb_build_object(
 'tables', (SELECT jsonb_agg(jsonb_build_object('schema',n.nspname,'table',c.relname,
   'rls_enabled',c.relrowsecurity,'rls_forced',c.relforcerowsecurity))
   FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
   WHERE (n.nspname='public' AND c.relname IN('listings','likes','marketplace_profiles','conversations','messages'))
      OR (n.nspname='storage' AND c.relname='objects')),
 'policies', (SELECT jsonb_agg(to_jsonb(p)) FROM pg_policies p
   WHERE (p.schemaname='public' AND p.tablename IN('listings','likes','marketplace_profiles','conversations','messages'))
      OR (p.schemaname='storage' AND p.tablename='objects')),
 'table_grants', (SELECT jsonb_agg(to_jsonb(g)) FROM information_schema.table_privileges g
   WHERE g.table_schema='public' AND g.table_name IN('listings','likes','marketplace_profiles','conversations','messages')
     AND g.grantee IN('anon','authenticated','PUBLIC')),
 'column_grants', (SELECT jsonb_agg(to_jsonb(g)) FROM information_schema.column_privileges g
   WHERE g.table_schema='public' AND g.table_name IN('listings','likes','marketplace_profiles','conversations','messages')
     AND g.grantee IN('anon','authenticated','PUBLIC')),
 'functions', (SELECT jsonb_agg(jsonb_build_object('name',p.proname,
   'arguments',pg_get_function_identity_arguments(p.oid),'security_definer',p.prosecdef,
   'configuration',p.proconfig,'definition_md5',md5(pg_get_functiondef(p.oid)),
   'anon_execute',has_function_privilege('anon',p.oid,'EXECUTE'),
   'authenticated_execute',has_function_privilege('authenticated',p.oid,'EXECUTE')))
   FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public'
   AND (p.proname LIKE 'marketplace_%' OR p.proname LIKE 'zammarket_%'
     OR p.proname IN('manage_listing','start_conversation','save_marketplace_profile','public_seller_profile'))),
 'triggers', (SELECT jsonb_agg(jsonb_build_object('table',c.relname,'name',t.tgname,
   'enabled',t.tgenabled,'definition',pg_get_triggerdef(t.oid)))
   FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid
   JOIN pg_namespace n ON n.oid=c.relnamespace
   WHERE n.nspname='public' AND c.relname IN('listings','marketplace_profiles','conversations','messages')
     AND NOT t.tgisinternal),
 'buckets', (SELECT jsonb_agg(jsonb_build_object('id',id,'public',public,
   'file_size_limit',file_size_limit,'allowed_mime_types',allowed_mime_types))
   FROM storage.buckets WHERE id IN('listing-images','avatars')),
 'listing_count', (SELECT count(*) FROM public.listings)
) AS stage1_verification_report;
ROLLBACK;
