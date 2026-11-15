-- HOLD — REPLACEMENT DRAFT v2. DO NOT APPLY. Alternative to original 014, NOT after it.
-- Requires separate approval and trusted receipt issuance design.
-- REVIEW ONLY. Stock/variants, verified-review eligibility and private advertising drafts.
-- Requires 009 + 010 + 012. No payments, active ads, old data updates or policy replacements.
BEGIN;
SET LOCAL lock_timeout='5s';SET LOCAL statement_timeout='60s';
CREATE TABLE public.listing_stock (
 listing_id uuid PRIMARY KEY REFERENCES public.listings(id),owner_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id),
 quantity integer NOT NULL DEFAULT 0 CHECK(quantity BETWEEN 0 AND 1000000),
 variants jsonb NOT NULL DEFAULT '[]' CHECK(jsonb_typeof(variants)='array' AND jsonb_array_length(variants)<=30),
 updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE FUNCTION public.stage3_stock_guard() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE caller uuid:=auth.uid(); item jsonb; total bigint:=0; labels text[]:='{}'; label text; canonical jsonb:='[]';
BEGIN
 IF caller IS NULL OR NOT public.marketplace_complete_member() OR NOT EXISTS(SELECT 1 FROM public.listings WHERE id=new.listing_id AND user_id=caller AND deleted_at IS NULL)
  OR new.owner_id IS DISTINCT FROM caller THEN RAISE EXCEPTION 'Only the listing owner may manage stock'; END IF;
 IF tg_op='UPDATE' THEN
  IF old.listing_id IS DISTINCT FROM new.listing_id OR old.owner_id IS DISTINCT FROM new.owner_id THEN RAISE EXCEPTION 'Stock ownership is immutable'; END IF;
 END IF;
 IF jsonb_typeof(new.variants)<>'array' OR jsonb_array_length(new.variants)>30 THEN RAISE EXCEPTION 'Invalid variants'; END IF;
 FOR item IN SELECT * FROM jsonb_array_elements(new.variants) LOOP
  label:=trim(coalesce(item->>'label',''));
  IF jsonb_typeof(item)<>'object' OR length(label) NOT BETWEEN 1 AND 100 OR lower(label)=ANY(labels)
    OR coalesce(item->>'quantity','') !~ '^[0-9]{1,7}$' OR (item->>'quantity')::integer>1000000
    OR (item ? 'price' AND item->'price'<>'null'::jsonb AND (jsonb_typeof(item->'price')<>'number' OR (item->>'price')::numeric<0))
    THEN RAISE EXCEPTION 'Each variant needs a unique label, valid quantity and nonnegative optional price'; END IF;
  canonical:=canonical||jsonb_build_array(jsonb_build_object('label',label,'quantity',(item->>'quantity')::integer,'price',item->'price'));
  labels:=array_append(labels,lower(label));total:=total+(item->>'quantity')::integer;
 END LOOP;
 new.variants:=canonical;
 IF total>1000000 THEN RAISE EXCEPTION 'Total stock exceeds limit'; END IF;
 IF jsonb_array_length(new.variants)>0 THEN new.quantity:=total; END IF;
 new.updated_at:=now();RETURN new;
END $$;
REVOKE ALL ON FUNCTION public.stage3_stock_guard() FROM public,anon,authenticated;
CREATE TRIGGER stage3_stock_guard BEFORE INSERT OR UPDATE ON public.listing_stock FOR EACH ROW EXECUTE FUNCTION public.stage3_stock_guard();
ALTER TABLE public.listing_stock ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.listing_stock FROM public,anon,authenticated;
GRANT SELECT,INSERT(owner_id,listing_id,quantity,variants),UPDATE(quantity,variants) ON public.listing_stock TO authenticated;
CREATE POLICY stage3_stock_owner_read ON public.listing_stock FOR SELECT TO authenticated USING(owner_id=(SELECT auth.uid()));
CREATE POLICY stage3_stock_owner_insert ON public.listing_stock FOR INSERT TO authenticated WITH CHECK(owner_id=(SELECT auth.uid()) AND public.marketplace_complete_member());
CREATE POLICY stage3_stock_owner_update ON public.listing_stock FOR UPDATE TO authenticated USING(owner_id=(SELECT auth.uid()) AND public.marketplace_complete_member()) WITH CHECK(owner_id=(SELECT auth.uid()));
-- Explicit public projection, owned by migration administrator; no owner IDs/private data.
CREATE VIEW public.marketplace_stock AS SELECT s.listing_id,s.quantity,(SELECT coalesce(jsonb_agg(jsonb_build_object('label',v->>'label','quantity',v->'quantity','price',v->'price')),'[]'::jsonb) FROM jsonb_array_elements(s.variants) v) AS variants FROM public.listing_stock s JOIN public.listings l ON l.id=s.listing_id WHERE l.deleted_at IS NULL;
REVOKE ALL ON public.marketplace_stock FROM public,anon,authenticated;GRANT SELECT ON public.marketplace_stock TO anon,authenticated;

-- Only a future trusted server/admin verification process may issue completed receipts.
CREATE TABLE public.marketplace_trade_receipts (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),listing_id uuid NOT NULL REFERENCES public.listings(id),
 buyer_id uuid NOT NULL REFERENCES auth.users(id),seller_id uuid NOT NULL REFERENCES auth.users(id),
 state text NOT NULL CHECK(state IN('completed','revoked')),verified_at timestamptz NOT NULL DEFAULT now(),
 CHECK(buyer_id<>seller_id)
);
ALTER TABLE public.marketplace_trade_receipts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.marketplace_trade_receipts FROM public,anon,authenticated;
GRANT SELECT ON public.marketplace_trade_receipts TO authenticated;
REVOKE ALL ON public.marketplace_trade_receipts FROM service_role;
GRANT SELECT,INSERT,UPDATE(state) ON public.marketplace_trade_receipts TO service_role;
CREATE POLICY stage3_receipt_read ON public.marketplace_trade_receipts FOR SELECT TO authenticated USING((SELECT auth.uid()) IN(buyer_id,seller_id));
CREATE FUNCTION public.stage3_receipt_integrity() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF tg_op='UPDATE' THEN
  IF new.id IS DISTINCT FROM old.id OR new.listing_id IS DISTINCT FROM old.listing_id OR new.buyer_id IS DISTINCT FROM old.buyer_id OR new.seller_id IS DISTINCT FROM old.seller_id OR new.verified_at IS DISTINCT FROM old.verified_at THEN RAISE EXCEPTION 'Receipt identity is immutable'; END IF;
  IF old.state='revoked' AND new.state<>'revoked' THEN RAISE EXCEPTION 'Receipt revocation is final'; END IF;
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.listings WHERE id=new.listing_id AND user_id=new.seller_id) THEN RAISE EXCEPTION 'Receipt seller must own the listing'; END IF;
 RETURN new;
END $$;
REVOKE ALL ON FUNCTION public.stage3_receipt_integrity() FROM public,anon,authenticated;
CREATE TRIGGER stage3_receipt_integrity BEFORE INSERT OR UPDATE ON public.marketplace_trade_receipts FOR EACH ROW EXECUTE FUNCTION public.stage3_receipt_integrity();
CREATE TABLE public.seller_reviews (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),receipt_id uuid NOT NULL UNIQUE REFERENCES public.marketplace_trade_receipts(id),
 author_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id),seller_id uuid NOT NULL REFERENCES auth.users(id),
 author_display text NOT NULL,rating integer NOT NULL CHECK(rating BETWEEN 1 AND 5),
 body text NOT NULL CHECK(length(trim(body)) BETWEEN 10 AND 1500),created_at timestamptz NOT NULL DEFAULT now()
);
CREATE FUNCTION public.stage3_review_guard() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE receipt public.marketplace_trade_receipts;caller uuid:=auth.uid();
BEGIN
 IF caller IS NULL OR NOT public.marketplace_complete_member() THEN RAISE EXCEPTION 'Complete your verified profile first'; END IF;
 IF new.author_id IS DISTINCT FROM caller THEN RAISE EXCEPTION 'Review author mismatch'; END IF;
 SELECT * INTO receipt FROM public.marketplace_trade_receipts WHERE id=new.receipt_id AND state='completed' AND buyer_id=caller;
 IF receipt.id IS NULL THEN RAISE EXCEPTION 'A verified completed transaction is required'; END IF;
 new.author_id:=caller;new.seller_id:=receipt.seller_id;
 SELECT shop_name INTO new.author_display FROM public.marketplace_profiles WHERE id=caller;
 RETURN new;
END $$;
REVOKE ALL ON FUNCTION public.stage3_review_guard() FROM public,anon,authenticated;
CREATE TRIGGER stage3_review_guard BEFORE INSERT ON public.seller_reviews FOR EACH ROW EXECUTE FUNCTION public.stage3_review_guard();
ALTER TABLE public.seller_reviews ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.seller_reviews FROM public,anon,authenticated;
GRANT SELECT,INSERT(author_id,receipt_id,rating,body) ON public.seller_reviews TO authenticated;
CREATE POLICY stage3_review_private_read ON public.seller_reviews FOR SELECT TO authenticated USING((SELECT auth.uid()) IN(author_id,seller_id));
CREATE POLICY stage3_review_insert ON public.seller_reviews FOR INSERT TO authenticated WITH CHECK(author_id=(SELECT auth.uid()) AND public.marketplace_complete_member());
CREATE VIEW public.public_seller_reviews AS SELECT r.id,r.seller_id,r.author_display,r.rating,r.body,r.created_at,true AS purchase_verified
 FROM public.seller_reviews r JOIN public.marketplace_trade_receipts t ON t.id=r.receipt_id WHERE t.state='completed' AND t.buyer_id=r.author_id AND t.seller_id=r.seller_id;
REVOKE ALL ON public.public_seller_reviews FROM public,anon,authenticated;GRANT SELECT ON public.public_seller_reviews TO anon,authenticated;

CREATE TABLE public.promotion_drafts (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),owner_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id),
 name text NOT NULL CHECK(length(trim(name)) BETWEEN 3 AND 100),
 kind text NOT NULL CHECK(kind IN('sponsored_listing','boost','business_subscription','advertising')),
 listing_id uuid REFERENCES public.listings(id),budget numeric CHECK(budget>=0),
 starts_on date,ends_on date,notes text NOT NULL DEFAULT '' CHECK(length(notes)<=2000),
 state text NOT NULL DEFAULT 'draft' CHECK(state IN('draft','archived')),
 created_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now(),CHECK(ends_on IS NULL OR starts_on IS NULL OR ends_on>=starts_on)
);
CREATE FUNCTION public.stage3_promotion_guard() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE caller uuid:=auth.uid();
BEGIN
 IF caller IS NULL OR new.owner_id IS DISTINCT FROM caller OR NOT public.marketplace_complete_member() THEN RAISE EXCEPTION 'Owner required'; END IF;
 IF new.listing_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.listings WHERE id=new.listing_id AND user_id=caller AND deleted_at IS NULL) THEN RAISE EXCEPTION 'Choose your own listing'; END IF;
 IF tg_op='UPDATE' THEN IF new.owner_id IS DISTINCT FROM old.owner_id OR new.id IS DISTINCT FROM old.id THEN RAISE EXCEPTION 'Owner is immutable'; END IF;new.created_at:=old.created_at;END IF;
 new.updated_at:=now();RETURN new;
END $$;
REVOKE ALL ON FUNCTION public.stage3_promotion_guard() FROM public,anon,authenticated;
CREATE TRIGGER stage3_promotion_guard BEFORE INSERT OR UPDATE ON public.promotion_drafts FOR EACH ROW EXECUTE FUNCTION public.stage3_promotion_guard();
ALTER TABLE public.promotion_drafts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.promotion_drafts FROM public,anon,authenticated;
GRANT SELECT,INSERT(owner_id,name,kind,listing_id,budget,starts_on,ends_on,notes,state),UPDATE(name,kind,listing_id,budget,starts_on,ends_on,notes,state) ON public.promotion_drafts TO authenticated;
CREATE POLICY stage3_promotion_owner_read ON public.promotion_drafts FOR SELECT TO authenticated USING(owner_id=(SELECT auth.uid()));
CREATE POLICY stage3_promotion_owner_insert ON public.promotion_drafts FOR INSERT TO authenticated WITH CHECK(owner_id=(SELECT auth.uid()) AND public.marketplace_complete_member());
CREATE POLICY stage3_promotion_owner_update ON public.promotion_drafts FOR UPDATE TO authenticated USING(owner_id=(SELECT auth.uid()) AND public.marketplace_complete_member()) WITH CHECK(owner_id=(SELECT auth.uid()));
CREATE FUNCTION public.stage3_commerce_capabilities() RETURNS jsonb LANGUAGE sql STABLE SET search_path='' AS $$SELECT jsonb_build_object('version',2,'safe_variants',true,'immutable_receipts',true,'inventory',true,'verified_reviews',true,'advertising_drafts',true)$$;
REVOKE ALL ON FUNCTION public.stage3_commerce_capabilities() FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.stage3_commerce_capabilities() TO anon,authenticated;
CREATE INDEX stage3_stock_owner_idx ON public.listing_stock(owner_id);
CREATE INDEX stage3_receipt_buyer_idx ON public.marketplace_trade_receipts(buyer_id);
CREATE INDEX stage3_receipt_seller_idx ON public.marketplace_trade_receipts(seller_id);
CREATE INDEX stage3_review_seller_idx ON public.seller_reviews(seller_id,created_at DESC);
CREATE INDEX stage3_promotion_owner_idx ON public.promotion_drafts(owner_id,created_at DESC);
COMMIT;
