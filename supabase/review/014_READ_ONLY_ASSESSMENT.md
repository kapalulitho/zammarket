# Migration 014 — read-only assessment

Date: 29 October 2026. **Recommendation: HOLD live application until the variant JSON/public projection and receipt-identity integrity findings are corrected in a separately reviewed revision.** No SQL in this migration was changed or applied during this review.

Reviewed source: [014_stage3_commerce_PENDING_APPROVAL.sql](014_stage3_commerce_PENDING_APPROVAL.sql). SHA-256: `5C1599028D55DDE9CEEC3A48C395CB0F35248B2330BAF62305E6354B3D22B6AB`.

## New tables and every column

| New table | Columns | Rules |
| --- | --- | --- |
| public.listing_stock | listing_id, owner_id, quantity, variants, updated_at | UUID listing/Auth FKs; one stock record per listing; quantity 0–1,000,000; up to 30 variants. |
| public.marketplace_trade_receipts | id, listing_id, buyer_id, seller_id, state, verified_at | Distinct buyer/seller; existing listing; completed/revoked state; only trusted server/admin may issue records. |
| public.seller_reviews | id, receipt_id, author_id, seller_id, author_display, rating, body, created_at | One review per receipt; rating 1–5; text length 10–1,500; caller must be the completed receipt's buyer. |
| public.promotion_drafts | id, owner_id, name, kind, listing_id, budget, starts_on, ends_on, notes, state, created_at, updated_at | Checked name/kind/budget/dates/notes; optional owned product; state ONLY draft/archived. No active/paid state. |

No existing columns are changed. Supporting indexes beyond primary/unique keys are absent; owner, receipt-participant and seller-review lookup indexes should be added before growth, after confirming query plans.

## New functions and triggers (5 functions, 4 triggers)

- `stage3_stock_guard()` / `stage3_stock_guard` — checked owner membership and live listing ownership; immutable stock identity; validate variant labels/quantities/prices, compute total quantity, stamp updated_at.
- `stage3_receipt_integrity()` / `stage3_receipt_integrity` — seller must own referenced listing. **Does not freeze listing/buyer/seller identity after insertion.**
- `stage3_review_guard()` / `stage3_review_guard` — verified completed caller profile, author check, eligible receipt, server-derived seller and public display name.
- `stage3_promotion_guard()` / `stage3_promotion_guard` — checked caller ownership and linked product ownership; immutable identity; preserve created_at/stamp updated_at.
- `stage3_commerce_capabilities()` — public read-only availability declaration.

The four trigger functions are SECURITY DEFINER with empty search_path and no PUBLIC/anon/authenticated direct EXECUTE grant. Capability EXECUTE is public. No existing function is replaced.

## Policies and grants (9 policies)

| Table | Policies | Access |
| --- | --- | --- |
| listing_stock | stage3_stock_owner_read, stage3_stock_owner_insert, stage3_stock_owner_update | Raw records owner-readable; completed verified owners insert; only quantity/variants are updateable. Owner reassignment cannot pass the grants/guard. |
| marketplace_trade_receipts | stage3_receipt_read | Buyer/seller can read their records; no normal client creation/edit/delete. service_role is explicitly granted ALL on this new table and bypasses RLS by design; this is a trusted credential boundary. |
| seller_reviews | stage3_review_private_read, stage3_review_insert | Raw records visible to author/seller; only an eligible buyer inserts. No client update/delete. Receipt/seller/display identities are derived/checked. |
| promotion_drafts | stage3_promotion_owner_read, stage3_promotion_owner_insert, stage3_promotion_owner_update | Owner-only private drafts; linked listing ownership checked; no deletes or activation. |

RLS is enabled on all four new tables; blanket client grants are revoked. Existing policies and data are untouched. Normal client cross-account checks pass locally. RLS does not protect data from a trusted service credential or the privileged owner of a public view.

## New public views and findings

1. `marketplace_stock`: listing_id, quantity, **entire variants JSON**, joined to non-deleted listings. Raw table owner_id is excluded. The stock guard validates expected fields but accepts arbitrary additional JSON keys. A local owner update containing fixture internal_cost/private_note was returned by the anonymous public view. This is unintended publication risk for extra owner-supplied metadata, not evidence of reading another user's private table. Fix by canonicalising/allowlisting variant keys in the database and building an explicit safe JSON projection. The improved local editor strips extra fields, but custom clients can bypass that and therefore SQL remains on hold.
2. `public_seller_reviews`: review ID, seller ID, author_display, rating, body, created_at, purchase_verified=true, joined to completed receipts. Receipt/author IDs are excluded. Revocation hides the review as intended. However, a trusted server can currently change a receipt's buyer/listing/seller; an existing review can remain publicly marked verified despite the changed relationship. A disposable probe confirmed this for buyer mutation. Freeze receipt identities, allow only audited state transitions/corrections, and bind public review eligibility to the same identities. Add idempotent trusted transaction references before real review issuance.

Both are administrator-owned views, not security_invoker views. They intentionally bypass underlying raw-table RLS to expose selected public data. Their projections/ownership therefore require direct review; raw-table policies alone do not prove view privacy. See Supabase's [views and RLS guidance](https://supabase.com/docs/guides/database/postgres/row-level-security#views-and-rls). Simply switching to invoker mode would break current public access without a complementary design.

No automated trusted transaction-verification process exists. Marking a product Sold, submitting a payment screenshot or saving a promotion does not issue a receipt. Ordinary sellers cannot mint eligibility. Reduce service-role permissions to the smallest required set and add audit/verification operations before enabling receipt issuance. Paid advertising, subscriptions and payment processing are not activated by this migration.

## Existing data and migration dependencies

No existing users/listings/messages/photos are updated, reassigned or deleted. No existing Storage bucket or policy is modified. New FKs referencing auth.users and listings can block future hard deletion once these new rows exist. Current soft-deletion/status behaviour remains intact; stock=0 does not change listing status automatically.

009/010 are real technical dependencies: UUID listings.id, deleted_at/user_id and verified profile helper. 014 has no SQL dependency on 013 and does not call/replace 012's messaging function. Keep the approved 012 installed for existing product chat; it is not part of this rollout and must not be rerun.

## Deployment and rollback

Requires UUID listing IDs, trusted migration/view/function ownership and unused object names. New FK/DDL locks may briefly delay requests. Each script is transactional; lock_timeout is five seconds and statement_timeout is 60 seconds per statement. Name conflicts fail rather than overwrite objects. No irreversible operation executes against existing records.

Before COMMIT, an error/ROLLBACK reverses the new schema operations. After COMMIT and use, dropping these tables would lose inventory/history/reviews/private campaign plans. No safe blanket down script or current full database backup is confirmed. Preserve records, gate/revert affected UI and use an approved forward correction; verify an independent backup/recovery point before deployment.

Recommended order: harden the two confirmed findings; separate trusted review issuance from stock/promotion rollout if needed; review preflight and exact revised SQL; stage-test minimal owner/nonowner/public paths; seek explicit approval. Current 014 is **not ready to approve as-is**.
