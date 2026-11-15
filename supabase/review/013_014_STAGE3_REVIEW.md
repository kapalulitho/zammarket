# Stage 3 migration review — NOT APPLIED

**Latest decision: HOLD both current scripts.** See the separate
[013 read-only assessment](013_READ_ONLY_ASSESSMENT.md) and
[014 read-only assessment](014_READ_ONLY_ASSESSMENT.md). The source SQL is unchanged.
Draft-image privacy, public variant JSON and mutable trusted receipt identities
need hardening before live approval. Earlier passing role tests below do not
resolve these newly examined boundaries.

Exact scripts: 013_stage3_modules_PENDING_APPROVAL.sql, then 014_stage3_commerce_PENDING_APPROVAL.sql. Run 013_014_preflight_READ_ONLY.sql and review its result before any approval. These scripts are not part of the already-approved 012 change and have not been authorised for live execution.

## 013: public content and private communication

- community_entries: Events, Jobs, Services and Learning share common discovery fields plus module-specific times, deadline, category/format and public descriptive details. Published content is public; drafts/closed content are visible only to the owner. Only completed verified members may create/edit their content; owner and record identity are immutable.
- seller_shops: one storefront per owner, unique handle, banner, description, hours, location and policies. Same published/draft ownership boundary; no verified-business badge is issued.
- module_enquiries: private sender/recipient reads. Sender identity is checked and recipient is derived from the published entry; recipients may change only the reply field. A per-sender advisory lock serialises the five-per-minute send limit. This is a new enquiry feature; existing product conversations/messages are unchanged.
- marketplace_notifications: private recipient-only reads and read markers; only trusted enquiry triggers create notifications. No push/email delivery provider or product-chat notification hook is activated.
- marketplace-media: NEW public image bucket, 5 MB JPEG/PNG/WebP, verified member uploads in their own folder. Protected against overwrite/deletion; old files are retained if publishing fails. This does not alter listing-images or avatars settings. Public media is explicitly public and must not contain private documents.
- stage3_capabilities: public read-only feature declaration. UI publishing remains disabled until this setup is present.

## 014: commerce foundations without payments

- listing_stock: owner-managed quantities and up to 30 uniquely labelled size/colour/options with optional prices. Server computes total quantity for variants; no buyer reservation/order/decrement mechanism is claimed. Stock=0 does not automatically change existing listing status.
- marketplace_stock: explicit public projection of listing ID, quantity and variants for non-deleted listings; no private owner fields. The raw table is owner-readable only.
- marketplace_trade_receipts: participants can read their own records, but ordinary users cannot issue or change them. Only a trusted service/admin process may issue completed receipts, and the seller must own the product. **No real transaction-verification process is connected yet.** Marking a listing Sold does not manufacture review eligibility.
- seller_reviews: one review per eligible receipt, buyer-only creation, server-derived seller/author display; sellers cannot self-review. Public view exposes only rating/text/display name and verified status, excluding receipt/buyer IDs; revoked receipts disappear from the public projection. Ordinary clients cannot edit/delete reviews.
- promotion_drafts: private owner-only planning for sponsored listings, boosts, subscriptions and advertising. State can only be draft/archived; linked products must belong to the owner. There is no paid/active state, payment endpoint, ad auction, subscription activation or sponsored-feed placement.
- stage3_commerce_capabilities: public read-only feature declaration.

## Preserved and pending

No existing account, listing, profile, message or photo is updated/deleted by either migration. Existing RLS policies/grants and the corrected 012 messaging function are not replaced. The likes privacy issue and listing-image bucket limits remain pending. No scheduler or cleanup is activated. Additive foreign keys preserve history but can block later account/listing hard deletion until a separate account-retention design exists.

New views use deliberate administrator-owned safe projections, not blanket raw-table public access. Review ownership/search_path/function EXECUTE privileges as part of deployment. Tests ensure existing policies/bucket settings and 012 definition stay unchanged.

## Deployment risk and approval sequence

Both scripts run in separate transactions with five-second lock timeout and 60-second statement timeout. Names/bucket collisions abort rather than overwrite. 014 currently requires UUID listings.id, matching the supplied ZamMarket schema. No automatic rollback may drop tables after users create content: that could destroy data. Obtain a current database backup/snapshot and review a deployment-specific recovery plan before applying; do not run old deletion/ownership scripts.

Approve/apply one script at a time only after preflight review; verify catalog/RLS and use dedicated test data. If a network error occurs, inspect capability/catalog state before retrying. Media uploads use additional storage only when users explicitly upload after approval; no uploads or live setup were performed in this development batch.

## Essential local verification

`node scripts/validate-profiles.mjs --full --with-trigger-fix --with-stage3` applies the proposed SQL only in disposable PostgreSQL. Checks include public/draft isolation, forged owner/sender denial, cross-account update denial, enquiry/notification privacy, media-folder protection, stock projection, verified-only/nonduplicate reviews, receipt revocation, private promotion drafts and rejection of active campaign state. It verifies existing policies, old bucket settings and 012 remain unchanged. This is not a live two-account test.
