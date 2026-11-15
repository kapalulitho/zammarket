-- READ ONLY. Run only in the separately identified staging project.
-- No row contents, credentials or personal contacts are returned.
SELECT jsonb_build_object(
 'objects',(SELECT jsonb_agg(jsonb_build_object('name',n,'present',to_regclass('public.'||n) IS NOT NULL)) FROM unnest(ARRAY['listings','marketplace_profiles','conversations','messages','business_organisations','business_memberships','business_branches','business_service_entries','stay_room_options','business_service_enquiry_drafts','public_business_profiles','public_business_services','public_stay_rooms']) n),
 'helpers',(SELECT jsonb_agg(jsonb_build_object('name',p.proname,'definition_md5',md5(replace(pg_get_functiondef(p.oid),chr(13),'')),'security_definer',p.prosecdef,'settings',p.proconfig,'anon_execute',has_function_privilege('anon',p.oid,'EXECUTE'),'authenticated_execute',has_function_privilege('authenticated',p.oid,'EXECUTE'))) FROM pg_proc p JOIN pg_namespace ns ON ns.oid=p.pronamespace WHERE ns.nspname='public' AND p.proname IN('marketplace_message_membership_guard','marketplace_complete_member','business_org_guard','business_branch_guard','business_service_entry_guard','stay_room_guard','business_service_draft_guard','business_service_visible')),
 'rls',(SELECT jsonb_agg(jsonb_build_object('table',c.relname,'enabled',c.relrowsecurity,'forced',c.relforcerowsecurity)) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname IN('business_organisations','business_memberships','business_branches','business_service_entries','stay_room_options','business_service_enquiry_drafts','conversations','messages','listings')),
 'policies',(SELECT jsonb_agg(to_jsonb(p)) FROM pg_policies p WHERE (schemaname='public' AND tablename IN('business_organisations','business_memberships','business_branches','business_service_entries','stay_room_options','business_service_enquiry_drafts')) OR (schemaname='storage' AND (policyname LIKE 'business_logo_%' OR policyname LIKE 'business_service_image_%'))),
 'grants',(SELECT jsonb_agg(to_jsonb(g)) FROM information_schema.role_table_grants g WHERE table_schema='public' AND table_name LIKE 'business%'),
 'buckets',(SELECT jsonb_agg(jsonb_build_object('id',id,'public',public,'file_size_limit',file_size_limit,'allowed_mime_types',allowed_mime_types)) FROM storage.buckets WHERE id IN('business-media','business-service-media'))
) AS staging_business_report;
-- After objects exist, inspect the two publication flags in a separate read-only query:
-- SELECT publish_profiles FROM public.business_foundation_settings;
-- SELECT publish_entries FROM public.business_service_settings;
-- Both must remain FALSE. Do not enable them as part of routine setup.
