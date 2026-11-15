-- READ ONLY. No deletion, ownership assignment, policy change, or job activation.
BEGIN READ ONLY;
WITH
ids(id) AS (SELECT unnest(ARRAY[
 'ce820419-6143-4cbe-8c80-f487e7692d52',
 '79e8ecb3-03a7-442e-8db2-d6cc6098107d',
 '5dab608c-f239-4ae8-bf77-c7522eca6bb3',
 '30ddb257-2649-46ab-b121-a3ff28698ee0']::uuid[])),
refs AS (
 SELECT l.id,l.title,r.source,regexp_replace(r.url,'[?#].*$','') AS url
 FROM public.listings l CROSS JOIN LATERAL (
   SELECT 'image_url' AS source,l.image_url AS url
   UNION ALL SELECT 'image_urls',unnest(l.image_urls)
 ) r WHERE r.url IS NOT NULL AND trim(r.url)<>''
),
paths AS (
 SELECT r.*,CASE
   WHEN starts_with(url,'https://tznbkieczyxwpyhpxeui.supabase.co/storage/v1/object/public/listing-images/')
     THEN substr(url,length('https://tznbkieczyxwpyhpxeui.supabase.co/storage/v1/object/public/listing-images/')+1)
   WHEN starts_with(url,'https://tznbkieczyxwpyhpxeui.supabase.co/storage/v1/render/image/public/listing-images/')
     THEN substr(url,length('https://tznbkieczyxwpyhpxeui.supabase.co/storage/v1/render/image/public/listing-images/')+1)
   ELSE NULL END AS object_path
 FROM refs r
),
objects AS (
 SELECT DISTINCT o.id,o.name FROM storage.objects o JOIN paths p ON p.object_path=o.name
 WHERE o.bucket_id='listing-images' AND p.id IN(SELECT id FROM ids)
),
relationships AS (
 SELECT c.conrelid::regclass::text AS referencing_table,c.conname AS constraint_name,
 pg_get_constraintdef(c.oid) AS definition
 FROM pg_constraint c WHERE c.contype='f' AND c.confrelid='public.listings'::regclass
)
SELECT jsonb_pretty(jsonb_build_object(
 'target_listings',(SELECT jsonb_agg(jsonb_build_object('id',l.id,'title',l.title,
   'user_id',l.user_id,'seller_id',l.seller_id,'status',l.status))
   FROM public.listings l JOIN ids USING(id)),
 'target_photo_references',(SELECT jsonb_agg(to_jsonb(p)) FROM paths p WHERE id IN(SELECT id FROM ids)),
 'matched_storage_objects',(SELECT jsonb_agg(jsonb_build_object('object_id',o.id,'path',o.name,
   'other_listing_references',(SELECT jsonb_agg(jsonb_build_object('id',p.id,'title',p.title,'source',p.source))
     FROM paths p WHERE p.id NOT IN(SELECT id FROM ids) AND p.object_path=o.name))) FROM objects o),
 'references_requiring_manual_review',(SELECT jsonb_agg(to_jsonb(p)) FROM paths p
   WHERE object_path IS NULL OR position('%' IN object_path)>0
   OR NOT EXISTS(SELECT 1 FROM storage.objects o WHERE o.bucket_id='listing-images' AND o.name=p.object_path)),
 'listing_foreign_keys',(SELECT jsonb_agg(to_jsonb(r)) FROM relationships r),
 'other_possible_photo_columns',(SELECT jsonb_agg(jsonb_build_object('table',table_name,'column',column_name))
   FROM information_schema.columns WHERE table_schema='public' AND table_name<>'listings'
   AND column_name ~* '(image|photo|avatar|picture|attachment)'),
 'target_like_count',(SELECT count(*) FROM public.likes WHERE listing_id IN(SELECT id FROM ids)),
 'listing_triggers',(SELECT jsonb_agg(jsonb_build_object('name',tgname,'definition',pg_get_triggerdef(oid)))
   FROM pg_trigger WHERE tgrelid='public.listings'::regclass AND NOT tgisinternal),
 'listing_rules',(SELECT jsonb_agg(jsonb_build_object('name',rulename,'definition',definition))
   FROM pg_rules WHERE schemaname='public' AND tablename='listings'),
 'total_listings',(SELECT count(*) FROM public.listings),
 'total_bucket_objects',(SELECT count(*) FROM storage.objects WHERE bucket_id='listing-images')
)) AS cleanup_preflight_report;
ROLLBACK;
