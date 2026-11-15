-- Read-only verification after the six approved staging migrations.
SELECT jsonb_build_object(
 'business_publication_disabled',(SELECT NOT publish_profiles FROM public.business_foundation_settings),
 'service_publication_disabled',(SELECT NOT publish_entries FROM public.business_service_settings),
 'public_business_rows',(SELECT count(*) FROM public.public_business_profiles),
 'public_service_rows',(SELECT count(*) FROM public.public_business_services),
 'buckets',(SELECT jsonb_agg(jsonb_build_object('id',id,'public',public,'file_size_limit',file_size_limit,'allowed_mime_types',allowed_mime_types) ORDER BY id) FROM storage.buckets),
 'message_trigger_matches',md5(replace(pg_get_functiondef('public.marketplace_message_membership_guard()'::regprocedure),E'\r\n',E'\n'))='8ca43a0da6c82a813576887f00c3807d',
 'message_trigger_count',(SELECT count(*) FROM pg_trigger WHERE tgfoid='public.marketplace_message_membership_guard()'::regprocedure AND NOT tgisinternal AND tgenabled='O'),
 'unscoped_profile_reads',(SELECT count(*) FROM pg_policies WHERE schemaname='public' AND tablename='marketplace_profiles' AND cmd='SELECT' AND qual='true'),
 'client_membership_insert_grant',has_table_privilege('authenticated','public.business_memberships','INSERT'),
 'client_membership_update_grant',has_any_column_privilege('authenticated','public.business_memberships','UPDATE'),
 'client_business_delete_grant',has_table_privilege('authenticated','public.business_organisations','DELETE'),
 'client_enquiry_update_grant',has_any_column_privilege('authenticated','public.business_service_enquiry_drafts','UPDATE'),
 'cron_jobs',(CASE WHEN to_regclass('cron.job') IS NULL THEN 'cron.job absent' ELSE 'inspect existing scheduler separately; no scheduler installed by these six files' END)
) AS staging_after_setup_report;
