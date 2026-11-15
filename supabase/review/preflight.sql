-- READ ONLY. Run only this file in the correct project's SQL Editor.
-- One report; no listing contents, emails, tokens, passwords, or photo names.
-- The transaction explicitly rejects writes and is rolled back.
begin read only;
select jsonb_pretty(jsonb_build_object(
  'database', jsonb_build_object('postgres_version',current_setting('server_version'),
    'supports_security_invoker_views',current_setting('server_version_num')::integer>=150000),
  'columns', (select jsonb_agg(to_jsonb(c) order by c.table_name,c.ordinal_position)
    from (select table_name,column_name,data_type,udt_name,column_default,is_nullable,ordinal_position
      from information_schema.columns where table_schema='public'
      and table_name in ('listings','likes','conversations','messages')) c),
  'rls', (select jsonb_agg(jsonb_build_object('table',c.relname,'enabled',c.relrowsecurity,'forced',c.relforcerowsecurity))
    from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relname in ('listings','likes','conversations','messages')),
  'policies', (select jsonb_agg(to_jsonb(p)) from
    (select schemaname,tablename,policyname,permissive,roles,cmd,qual,with_check from pg_policies
     where (schemaname='public' and tablename in ('listings','likes','conversations','messages'))
       or (schemaname='storage' and tablename='objects')) p),
  'constraints', (select jsonb_agg(jsonb_build_object('table',c.conrelid::regclass::text,
    'name',c.conname,'definition',pg_get_constraintdef(c.oid))) from pg_constraint c
    where c.conrelid in (to_regclass('public.listings'),to_regclass('public.likes'))),
  'indexes', (select jsonb_agg(to_jsonb(i)) from
    (select tablename,indexname,indexdef from pg_indexes where schemaname='public'
      and tablename in ('listings','likes')) i),
  'triggers', (select jsonb_agg(jsonb_build_object('name',tgname,'definition',pg_get_triggerdef(oid)))
    from pg_trigger where tgrelid='public.listings'::regclass and not tgisinternal),
  'table_grants', (select jsonb_agg(to_jsonb(g)) from
    (select table_name,grantee,privilege_type from information_schema.table_privileges
      where table_schema='public' and table_name in ('listings','likes','conversations','messages')) g),
  'column_grants', (select jsonb_agg(to_jsonb(g)) from
    (select table_name,column_name,grantee,privilege_type from information_schema.column_privileges
      where table_schema='public' and table_name in ('listings','likes')) g),
  'sequences', (select jsonb_agg(jsonb_build_object('name',c.relname,'acl',c.relacl::text))
    from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='S'),
  'public_functions', (select jsonb_agg(jsonb_build_object('name',p.proname,
    'arguments',pg_get_function_identity_arguments(p.oid),'security_definer',p.prosecdef,
    'owner',pg_get_userbyid(p.proowner),'acl',p.proacl::text))
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'),
  'proposed_relations_already_present', (select jsonb_agg(c.relname) from pg_class c
    join pg_namespace n on n.oid=c.relnamespace where n.nspname='public'
    and c.relname in ('marketplace_listings','conversations','messages','marketplace_cleanup_settings',
      'zammarket_listings_owner','zammarket_cleanup_due')),
  'data_summary', (select jsonb_build_object('listings',count(*),
    'unowned_listings',count(*) filter(where user_id is null),
    'listings_with_unknown_owner',count(*) filter(where user_id is not null and not exists
      (select 1 from auth.users u where u.id=l.user_id)),
    'listings_with_photos',count(*) filter(where image_urls is not null and to_jsonb(image_urls)<>'[]'::jsonb))
    from public.listings l),
  'storage_bucket', (select to_jsonb(b) from
    (select id,public,file_size_limit,allowed_mime_types from storage.buckets where id='listing-images') b),
  'storage_summary', (select jsonb_build_object('objects',count(*),
    'legacy_root_objects',count(*) filter(where position('/' in name)=0))
    from storage.objects where bucket_id='listing-images')
)) as preflight_report;
rollback;
