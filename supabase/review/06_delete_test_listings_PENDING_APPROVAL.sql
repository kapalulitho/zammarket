-- PENDING APPROVAL: do not execute yet. Deletes exactly four verified test rows.
-- Does not delete Storage objects, users, or change policies or scheduled jobs.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';
DO $$
DECLARE
  expected jsonb := '[
    {"id":"ce820419-6143-4cbe-8c80-f487e7692d52","title":"exercise books"},
    {"id":"79e8ecb3-03a7-442e-8db2-d6cc6098107d","title":"smartphone"},
    {"id":"5dab608c-f239-4ae8-bf77-c7522eca6bb3","title":"hotel"},
    {"id":"30ddb257-2649-46ab-b121-a3ff28698ee0","title":"watch"}
  ]';
  target_ids uuid[];
  changed integer;
BEGIN
  -- Short-lived locks stop concurrent listing/like changes during validation.
  LOCK TABLE public.listings IN SHARE ROW EXCLUSIVE MODE;
  LOCK TABLE public.likes IN SHARE ROW EXCLUSIVE MODE;
  SELECT array_agg((e->>'id')::uuid) INTO target_ids FROM jsonb_array_elements(expected) e;
  IF cardinality(target_ids)<>4 OR (SELECT count(DISTINCT x) FROM unnest(target_ids) x)<>4 THEN
    RAISE EXCEPTION 'Expected exactly four distinct IDs';
  END IF;
  IF EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid IN
    ('public.listings'::regclass,'public.likes'::regclass) AND NOT tgisinternal)
    OR EXISTS(SELECT 1 FROM pg_rules WHERE schemaname='public'
      AND tablename IN ('listings','likes')) THEN
    RAISE EXCEPTION 'Custom triggers/rules found; stop for review';
  END IF;
  -- Reject new incoming foreign keys, including ones that could cascade elsewhere.
  IF EXISTS(SELECT 1 FROM pg_constraint WHERE contype='f' AND confrelid IN
      ('public.listings'::regclass,'public.likes'::regclass)
      AND NOT (confrelid='public.listings'::regclass
        AND conrelid='public.likes'::regclass AND conname='likes_listing_id_fkey'
        AND confdeltype='c'
        AND conkey=ARRAY[(SELECT attnum FROM pg_attribute
          WHERE attrelid='public.likes'::regclass AND attname='listing_id')]::smallint[]
        AND confkey=ARRAY[(SELECT attnum FROM pg_attribute
          WHERE attrelid='public.listings'::regclass AND attname='id')]::smallint[])) THEN
    RAISE EXCEPTION 'Database relationships changed; stop for review';
  END IF;
  IF (SELECT count(*) FROM public.listings WHERE id=ANY(target_ids))<>4
    OR EXISTS(SELECT 1 FROM jsonb_array_elements(expected) e JOIN public.listings l
      ON l.id=(e->>'id')::uuid WHERE lower(trim(l.title))<>e->>'title'
        OR l.user_id IS NOT NULL OR l.seller_id IS NOT NULL OR l.status<>'active') THEN
    RAISE EXCEPTION 'Target listings changed; stop for review';
  END IF;
  IF EXISTS(SELECT 1 FROM public.likes WHERE listing_id=ANY(target_ids)) THEN
    RAISE EXCEPTION 'Likes now exist for these listings; deletion requires further review';
  END IF;

  DELETE FROM public.listings WHERE id=ANY(target_ids);
  GET DIAGNOSTICS changed=ROW_COUNT;
  IF changed<>4 THEN RAISE EXCEPTION 'Expected exactly four deleted listings'; END IF;
  RAISE NOTICE 'Exactly four test listings deleted. Storage photos were not touched.';
END $$;
COMMIT;
