-- REVIEW ONLY. Apply after 009_backend_setup_PENDING_APPROVAL.sql.
-- This migration separates private saved-item identities from public aggregate counts.
-- It does not delete likes or change listing ownership.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';

ALTER TABLE public.likes ENABLE ROW LEVEL SECURITY;

-- Remove the legacy public read policy and table/column-level public read grants.
DROP POLICY IF EXISTS zammarket_likes_read ON public.likes;
REVOKE SELECT ON public.likes FROM PUBLIC, anon, authenticated;
DO $$
DECLARE column_name text;
BEGIN
  FOR column_name IN
    SELECT attname FROM pg_attribute
    WHERE attrelid = 'public.likes'::regclass AND attnum > 0 AND NOT attisdropped
  LOOP
    EXECUTE format(
      'REVOKE SELECT (%I) ON TABLE public.likes FROM PUBLIC, anon, authenticated',
      column_name
    );
  END LOOP;
END $$;
GRANT SELECT ON public.likes TO authenticated;

-- Users can read only their own saved rows. The restrictive policy also
-- prevents any other permissive SELECT policy from exposing another user's rows.
DROP POLICY IF EXISTS zammarket_likes_read_own ON public.likes;
DROP POLICY IF EXISTS zammarket_likes_read_owner_guard ON public.likes;
CREATE POLICY zammarket_likes_read_own ON public.likes
  FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()));
CREATE POLICY zammarket_likes_read_owner_guard ON public.likes
  AS RESTRICTIVE FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()));

-- Return counts only for existing, non-deleted listings; never expose saver identities.
-- Bound the request size to prevent a caller submitting an excessive ID array.
CREATE OR REPLACE FUNCTION public.public_listing_like_counts(p_listing_ids text[])
RETURNS TABLE(listing_id text, like_count bigint)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT l.listing_id::text, count(*)::bigint
  FROM public.likes AS l
  WHERE (SELECT auth.uid()) IS NOT NULL
    AND cardinality(p_listing_ids) BETWEEN 1 AND 100
    AND l.listing_id::text = ANY(p_listing_ids)
    AND EXISTS (
      SELECT 1
      FROM public.listings AS listing
      WHERE listing.id::text = l.listing_id::text
        AND listing.deleted_at IS NULL
    )
  GROUP BY l.listing_id
$$;
REVOKE ALL ON FUNCTION public.public_listing_like_counts(text[]) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.public_listing_like_counts(text[]) TO authenticated;

COMMIT;
