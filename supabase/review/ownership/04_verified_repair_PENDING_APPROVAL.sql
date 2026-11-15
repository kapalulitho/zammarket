-- CANCELLED BY USER: do not execute this ownership repair. Retained for history only.
-- PENDING APPROVAL. Do not execute yet. Changes ownership only.
BEGIN;
DO $$
DECLARE
  account_id uuid := '388abe0b-0864-4bc0-b970-f97b680bfc60';
  listing_ids uuid[] := ARRAY[
    'ce820419-6143-4cbe-8c80-f487e7692d52',
    '79e8ecb3-03a7-442e-8db2-d6cc6098107d',
    '5dab608c-f239-4ae8-bf77-c7522eca6bb3',
    '30ddb257-2649-46ab-b121-a3ff28698ee0'
  ]::uuid[];
  before_rows jsonb;
  changed integer;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM auth.users
    WHERE id = account_id AND email_confirmed_at IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'The supplied account does not exist or is not confirmed';
  END IF;
  IF cardinality(listing_ids) <> 4 OR
    (SELECT count(DISTINCT x) FROM unnest(listing_ids) x) <> 4 THEN
    RAISE EXCEPTION 'Exactly four distinct listing IDs are required';
  END IF;

  PERFORM 1 FROM public.listings
    WHERE id = ANY(listing_ids) ORDER BY id FOR UPDATE;

  IF (SELECT count(*) FROM public.listings WHERE id = ANY(listing_ids)) <> 4
    OR (SELECT array_agg(lower(trim(title)) ORDER BY lower(trim(title)))
        FROM public.listings WHERE id = ANY(listing_ids))
        IS DISTINCT FROM ARRAY['exercise books','hotel','smartphone','watch']::text[]
    OR EXISTS (SELECT 1 FROM public.listings WHERE id = ANY(listing_ids)
        AND (user_id IS NOT NULL OR seller_id IS NOT NULL)) THEN
    RAISE EXCEPTION 'Listing IDs, titles, or unassigned ownership do not match; stopped';
  END IF;

  SELECT jsonb_agg(to_jsonb(l) ORDER BY l.id) INTO before_rows
    FROM public.listings l WHERE id = ANY(listing_ids);

  UPDATE public.listings SET user_id = account_id, seller_id = account_id
    WHERE id = ANY(listing_ids) AND user_id IS NULL AND seller_id IS NULL;
  GET DIAGNOSTICS changed = ROW_COUNT;
  IF changed <> 4 THEN
    RAISE EXCEPTION 'Expected exactly four ownership updates';
  END IF;

  IF EXISTS (
    SELECT 1 FROM jsonb_array_elements(before_rows) b
    LEFT JOIN public.listings l ON l.id = (b->>'id')::uuid
    WHERE l.id IS NULL
      OR (to_jsonb(l)-'user_id'-'seller_id') IS DISTINCT FROM (b-'user_id'-'seller_id')
      OR l.user_id IS DISTINCT FROM account_id
      OR l.seller_id IS DISTINCT FROM account_id
  ) THEN
    RAISE EXCEPTION 'Unexpected changes detected; transaction aborted';
  END IF;
  RAISE NOTICE 'Exactly four listings linked; all other listing fields preserved';
END $$;
COMMIT;
