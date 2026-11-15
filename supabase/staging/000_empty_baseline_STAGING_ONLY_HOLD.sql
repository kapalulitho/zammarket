-- STAGING ONLY / HOLD / REVIEW ONLY. Never execute on the production project.
-- Empty prerequisite schema for a brand-new isolated Supabase project before 009/010.
-- No auth/storage internals are recreated and no existing tables are replaced.
-- Confirm the project reference and explicit approval in Dashboard before execution.
BEGIN;
SET LOCAL lock_timeout='5s';SET LOCAL statement_timeout='60s';
CREATE TABLE public.listings(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),seller_id uuid REFERENCES auth.users(id),title text NOT NULL,
 description text,price numeric,category text,location text,image_url text,status text NOT NULL DEFAULT 'active',
 created_at timestamptz NOT NULL DEFAULT now(),seller_name text,seller_rating numeric,seller_review_count bigint,
 condition text,joined_at timestamp,image_urls text[],user_id uuid REFERENCES auth.users(id)
);
CREATE TABLE public.likes(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),listing_id uuid NOT NULL REFERENCES public.listings(id),user_id uuid NOT NULL REFERENCES auth.users(id),created_at timestamptz NOT NULL DEFAULT now(),UNIQUE(listing_id,user_id));
ALTER TABLE public.listings ENABLE ROW LEVEL SECURITY;ALTER TABLE public.likes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.listings,public.likes FROM public,anon,authenticated;
-- Legacy bucket shape intentionally reproduced; existing upload-limit weakness stays tracked.
INSERT INTO storage.buckets(id,name,public) VALUES('listing-images','listing-images',true);
COMMIT;
