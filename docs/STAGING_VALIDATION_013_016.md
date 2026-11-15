# Staging validation and approval gates

Status: prepared only, 29 October 2026. **013_v2, 014_v2, 015 and 016 remain HOLD.** This plan does not authorise creation of a paid staging project, execution of SQL anywhere, production changes or cleanup. No live staging validation has been performed.

## 1. Prepare an isolated environment

- Use a separately approved staging Supabase project and test inboxes. Never point the staging frontend at production or copy production users, messages, photos or credentials.
- Record a current backup/restore plan and an inventory of schema, grants, triggers, policies and bucket settings. Verify prerequisites from the existing 009/010 baseline; retain 012 as the tested product messaging baseline. New drafts do not modify 012.
- Review exact draft files and hashes. Original 013/014 and v2 replacements are alternatives; do not run both. Stop on any existing target object or marketplace-media/property-media bucket. An installed v1 schema needs a separately prepared upgrade, not these clean-install drafts.
- Obtain explicit approval before executing the agreed SQL on staging. No expense or live migration is implicit in this document.

## 2. Static scope and preflight

Use 013_014_v2_PREFLIGHT_READ_ONLY.sql and 015_016_PREFLIGHT_READ_ONLY.sql, only after selecting the correct environment. Confirm UUID keys, membership helpers, Storage SELECT privileges for API roles and target-name absence. Compare pre/post metadata for existing auth, listings, likes, messages, profiles, buckets, functions and policies. No original object definitions or records should change.

013 v2 adds module/storefront/enquiry/notification tables and a PRIVATE marketplace-media bucket. 014 v2 adds stock, trusted receipts, reviews and promotion drafts. 015 adds a separate Property data model/private media bucket. 016 adds PRIVATE plans and courier profile drafts, not an operational delivery system. 015/016 require profile helpers, not application of held 013/014.

## 3. Real Storage signing tests — 013 v2 and 015

Use non-sensitive test images and owner A, verified user B, unrelated C and anonymous clients.

| Test | Required outcome |
| --- | --- |
| Owner uploads valid image in own UUID folder | Allowed; bucket private; size/MIME enforced |
| Foreign UUID folder, traversal, invalid MIME or >5 MB | Rejected |
| Unreferenced or draft-only image | Only owner can obtain a fresh signed URL; B/C/anon denied even knowing path |
| Published entry/shop/property references image | Public audience may obtain a 60-second signed URL |
| Public-bucket endpoint or unsigned private endpoint | No direct public access to private original |
| Close listing/remove last published reference | New signing denied for non-owner; previously issued link can remain usable until expiry |
| Image shared by a draft and another published reference | Remains public while any published reference exists; UI must not imply draft-only privacy |
| Existing signed link after expiry | Denied; UI refreshes permitted links or shows unavailable fallback |
| Overwrite or delete through ordinary user | Denied; photos remain intact |

The SQL fixture tests row policy behavior but not the Storage HTTP server, JWT handling, token TTL or CDN cache. Inspect signed URL calls without logging complete tokens. Copied images cannot be recalled. Validate public-response caching and logout behavior using real staging clients before rollout. Do not promise immediate revocation of already issued links.

## 4. RLS and public exposure

- Test anonymous, unverified, incomplete-profile, owner A, verified B, unrelated C. Use ordinary authenticated JWTs, never service-role credentials, for isolation tests.
- 013: only published module/shop rows are public; drafts/closed owner-only. Enquiries and notifications visible only to intended participants/recipient. Spoofed IDs, sender/recipient updates and cross-account edits fail. Five enquiries/minute rate cap enforced.
- 014: raw stock/promotion rows private; public stock exposes ONLY label/quantity/price and public listing ID/quantity. Extra JSON keys never reach a public response. Case-insensitive duplicate labels, bad quantities/prices and excessive totals fail. Public review projection contains no receipt IDs, buyer IDs or private contacts. Promotion states only draft/archived; no active placement/payment.
- 015: draft/closed properties owner-only; published property fields are deliberately public, including publisher UUID and self-declared agent type. No exact-address/contact fields are added. Saved rows are private to the saving user; enquiries are participant-only and only the publisher can reply. Anonymous users cannot read saves/enquiries. Owner/user identities immutable; agent display name is server-derived from the existing seller profile. Gallery URLs follow publication rules.
- 016: customer plans and courier drafts owner-only; unrelated users/anonymous cannot read them. Cannot spoof owner, mark plan booked/delivered, create verified courier status or delete through client grants. No public courier directory, booking, fare, assignment, tracking or payment tables exist.
- Recheck existing product chat, posting, profile visibility and images. Keep public-likes privacy and listing-image limits on the separate pending list; these drafts do not fix them.

## 5. Receipt integrity — 014 v2

- An ordinary user cannot issue receipts, edit receipt identities or self-verify a sale.
- Through the approved trusted staging process only, issue one non-sensitive completed receipt with the actual listing seller and distinct buyer. Buyer may create one review; other accounts, duplicate reviews and self-reviews fail.
- Attempts to change listing, buyer, seller, receipt ID or verification timestamp fail, including with trusted database role privileges.
- Revoke receipt: public verified review disappears. Revoked receipt cannot be restored to completed. Projection must additionally bind review author/seller to receipt buyer/seller.
- **Still required:** a trusted, audited, idempotent issuance/revocation workflow and business evidence of purchase. No receipt issuer/payment verification service is implemented. Do not issue production verified-purchase claims merely because this schema exists.

## 6. Frontend and release decision

Verify draft-review-confirm flows, reload persistence, private saves/enquiries, multiple-photo signing and errors, property filters/price basis, mobile 360px and desktop, keyboard navigation and reduced motion. Reject original v1 Stage 3 capability responses. Delivery stays planning-only even after 016; the booking button remains disabled.

Record pass/fail, environment, file hashes and unresolved issues without secrets. Current local focused checks are not a substitute for this staging run. Only after resolving failures, reviewing exact SQL scope and confirming backup/restore should production application be requested as a separate explicit approval.

Each draft is transactional with 5s lock timeout and 60s statement timeout. A failed statement before commit rolls back the transaction. If any SQL Editor error leaves a transaction open, explicitly ROLLBACK before retrying. After commit/new data, do not blindly drop tables/buckets or run originals: disable/gate frontend and prepare an approved forward correction. No destructive rollback script or cleanup activation is supplied.
