-- 022b — LISTING ↔ BUSINESS ORGANISATION LINK (HOLD / REVIEW ONLY)
--
-- Draft for review with the CURRENT_APPROVAL_PACKAGE process. Do not apply
-- before 022_business_foundation_HOLD_DRAFT.sql has been approved and applied.
-- No existing listing, account or organisation row is modified beyond the new
-- nullable column. Listings without a business keep their current behaviour,
-- and the personal-profile identity keeps working everywhere it does today.
--
-- What this adds:
--   1. listings.business_organisation_id — nullable reference to the business
--      a listing is published under (NULL = personal listing, unchanged).
--   2. assign_listing_organisation RPC — the only write path for the new
--      column. Owner-guarded on both sides: the caller must own the listing
--      AND own the organisation, and both must be undeleted/active.
--   3. Refresh of the marketplace_listings view so the new column is exposed
--      to the existing read paths (the view expands l.* at creation time).
--
-- Out of scope (separate drafts): publishing listings under a business inside
-- the posting flow UI, storefront pages built on public_business_profiles,
-- and staff membership activation.

BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '60s';

-- 1. Column ---------------------------------------------------------------

ALTER TABLE public.listings
  ADD COLUMN IF NOT EXISTS business_organisation_id uuid
  REFERENCES public.business_organisations(id);

-- Partial index: business storefront feeds look up their listings by owner.
CREATE INDEX IF NOT EXISTS zammarket_listings_organisation
  ON public.listings(business_organisation_id)
  WHERE business_organisation_id IS NOT NULL;

-- 2. Refresh the read view so the new column is visible --------------------
-- (Views expand l.* when created, so a new base column needs a rebuild.
-- The definition is identical to 001_marketplace.sql.)

DROP VIEW IF EXISTS public.marketplace_listings;

CREATE VIEW public.marketplace_listings WITH (security_invoker = true) AS
SELECT l.*, CASE
  WHEN status = 'sold' THEN 'Sold'
  WHEN status = 'temporarily_unavailable' THEN 'Temporarily Unavailable'
  WHEN available_from > (now() AT TIME ZONE 'Africa/Lusaka')::date THEN 'Coming Soon'
  ELSE 'Available' END AS effective_status
FROM public.listings l;

REVOKE ALL ON public.marketplace_listings FROM public, anon, authenticated, service_role;
GRANT SELECT ON public.marketplace_listings TO anon, authenticated;

-- 3. Owner-guarded RPC (single write path, mirrors manage_listing style) ----

CREATE OR REPLACE FUNCTION public.assign_listing_organisation(
  p_listing_id text,
  p_organisation_id uuid DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  item public.listings;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Sign-in required';
  END IF;

  -- Lock the listing the same way manage_listing does.
  SELECT * INTO item FROM public.listings WHERE id::text = p_listing_id FOR UPDATE;

  IF item.user_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'Listing not found or not owned by you';
  END IF;
  IF item.deleted_at IS NOT NULL THEN
    RAISE EXCEPTION 'Listing has been deleted';
  END IF;

  -- Connecting: the caller must own the organisation and it must be live.
  IF p_organisation_id IS NOT NULL THEN
    IF NOT public.business_is_owner(p_organisation_id) THEN
      RAISE EXCEPTION 'Only the business owner can connect listings';
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM public.business_organisations
      WHERE id = p_organisation_id AND status <> 'closed'
    ) THEN
      RAISE EXCEPTION 'That business is closed';
    END IF;
  END IF;

  UPDATE public.listings
  SET business_organisation_id = p_organisation_id,
      revision = revision + 1
  WHERE id::text = p_listing_id;
END $$;

REVOKE ALL ON FUNCTION public.assign_listing_organisation(text, uuid)
  FROM public, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.assign_listing_organisation(text, uuid)
  TO authenticated;

COMMIT;

-- Review notes for the approval package:
-- * The RPC bumps revision so a concurrent My Listings edit fails safely and
--   refreshes instead of silently overwriting.
-- * manage_listing intentionally does not touch the new column: assignment is
--   a separate, explicit action ("publish under a business").
-- * Detaching is the same RPC with p_organisation_id NULL (default).
-- * No RLS policy changes are needed: the column lives on public.listings,
--   whose existing restrictive guards already gate every other path, and the
--   only granted write path is the RPC above.
