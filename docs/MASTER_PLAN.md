# ZamMarket master development plan

The existing React/Vite/JavaScript/Supabase project remains the product foundation. One Auth identity and verified marketplace profile are reused across services. Routine local engineering proceeds independently; destructive changes, live migrations/policies, expenses, production deployments and real payments require explicit approval.

## Current milestone

Stage 3 interface/model batch is implemented locally. See STAGE3_REPORT.md for functional versus migration-dependent features. Stage 1 auth/profile/OTP/avatar checks were user-confirmed; the owner chose to skip the real second-email test. Migration 012 was approved/applied by the owner and verified by its CRLF-normalised fingerprint. It must not be rerun.

Stage 3 implementation includes provider/organiser profile navigation and public
service portfolios linked to the existing seller profile/catalogue. The new
module media and publishing backends remain pending, not operational by default.

## Delivery sequence

1. Foundation: preserve auth, profiles, products, availability, private product chat, saved items and owner management. Maintain mobile/light/dark accessibility and on-demand chunks.
2. Multi-service MVP: public discovery plus verified-owner drafts/posting for Events, Jobs, Services and Learning; storefronts, private enquiries and notifications. Proposed 013, not live.
3. Seller commerce foundation: inventory/options, receipt-eligible reviews, private promotion drafts and actual listing counts. Proposed 014, not live. Stock is informational until transactional reservation exists.
4. Trust and operations: moderation, abuse reporting, account retention, verified business onboarding and trusted transaction verification. Do not label email verification as professional/business verification.
5. Growth systems: provider sandbox checkout/webhooks, orders/refunds/payouts, consented analytics and reviewed paid-placement/subscription rules. No live activation in current work.
6. Expansion: food/delivery/bookings/jobs workflows, deeper learning/property/event features and country/currency support. Activate services only when their operations and safeguards exist; no fabricated offers/providers or exchange rates.

## Pending approval/security register

- Read-only 013/014 assessment now recommends HOLD as-is: public draft media in
  013; unfiltered public variant JSON and mutable verified-receipt identities in
  014. Harden through a separately reviewed revision; current SQL files were not
  changed or applied during this review.

- 013/014 need read-only preflight, scope/risks review and backup/recovery confirmation before any live execution.
- Public likes expose user identifiers; no policy changes authorised in this batch.
- Existing listing-images bucket lacks server-side MIME/size limits; unchanged.
- Automatic sold-photo cleanup remains inactive; seven-day recovery duration is agreed but activation requires separate approval.
- Real two-account isolation remains unverified by explicit user choice; local role-based tests do not erase that limitation.
- Review eligibility requires trusted completed receipts. Seller Sold status, payment screenshots and client claims cannot issue them.
- Promotions remain draft/archived only. No payment collection, provider secrets, expenses, subscription activation or active ad serving.

Every batch reports working UI, backend dependencies, validation limits and next steps. Preserve historical SQL and existing data; do not apply old ownership/deletion proposals.


## Latest local batch — 29 October 2026
See [NEXT_BATCH_PROGRESS.md](NEXT_BATCH_PROGRESS.md): corrected 013/014 v2 replacement drafts remain HOLD; private-media integration, stock starters, campaign planning, catalogue analytics, module filters and Property/Delivery/Food local previews implemented. No live migrations or cleanup. Next: staging validation/approval of revised backend, then dedicated property/delivery models.


## Property and Delivery batch — 29 October 2026
See [PROPERTY_DELIVERY_PROGRESS.md](PROPERTY_DELIVERY_PROGRESS.md). Dedicated Property discovery/detail/editor/gallery/saved/enquiry interfaces and Delivery planning/customer/courier/history interfaces replace the prior generic previews. Separate 015/016 drafts and staging validation plan prepared. All new migrations remain HOLD; no live changes or real bookings/payments.


## Latest service discovery batch — 29 October 2026
See [SERVICES_DISCOVERY_PROGRESS.md](SERVICES_DISCOVERY_PROGRESS.md) and [SERVICE_BACKEND_NEXT_CONTRACTS.md](SERVICE_BACKEND_NEXT_CONTRACTS.md). Property URLs/pagination, courier draft wizard/local lifecycle, Food menus/cart planning and Event ticket scenarios implemented locally. 013_v2/014_v2/015/016 remain HOLD. No isolated staging configuration was found; no remote SQL or production changes.


## Latest foundations / Jobs / Learning batch — 29 October 2026
See [FOUNDATIONS_JOBS_LEARNING_PROGRESS.md](FOUNDATIONS_JOBS_LEARNING_PROGRESS.md), [ISOLATED_STAGING_SETUP.md](ISOLATED_STAGING_SETUP.md) and supabase/review/017_019_REVIEW.md. New 017–019 operational drafts remain HOLD with gates FALSE; Jobs/Learning planning dashboards and product cart preview implemented. Existing held SQL and homepage square service-icon boxes preserved. Remote staging unavailable; all database checks were disposable/local and browser checks used the mock backend, not production.


## Detail / discovery / specialist catalogues continuation
See [DETAIL_DISCOVERY_CATALOGUES_PROGRESS.md](DETAIL_DISCOVERY_CATALOGUES_PROGRESS.md) and [DEPENDENCY_AND_STAGING_MATRIX.md](DEPENDENCY_AND_STAGING_MATRIX.md). Shared large/zoom/swipe gallery, honest visit-interest foundations, Agriculture/Digital local catalogues and service-planning workflows added. New 020/021 remain HOLD; previous 013_v2–019 untouched. No production testing or activation.

## Core/business continuation
Current evidence and changed-file inventory: docs/CORE_BUSINESS_FOUNDATION_PROGRESS.md. Business organisations do not silently grant staff access to existing profiles, shops, listings or conversations. Stays remain distinct from Property; logistics businesses remain distinct from parcel Delivery. All new 022/023 and previously held drafts remain HOLD. Follow the dependency/staging matrix before any backend activation.


## Stage 4 handoff
Persistent business preparation is documented in docs/STAGE4_PERSISTENT_BUSINESS_PROGRESS.md. The new repository refuses production. Staging configuration and exact SQL approval remain prerequisites; no operational/publication gates are enabled. Follow docs/STAGE4_STAGING_RUNBOOK.md for native validation rather than using production as a test environment.


## Stage 5 staging handoff
Follow docs/STAGE5_STAGING_SETUP.md. npm run prepare:staging preserves existing environment configuration and generates a manual migration hash manifest; it never executes SQL. Unknown/duplicate variables and production key reuse are rejected. All new backend activation remains gated on separate project configuration, exact migration approval and native evidence.


## 30 October — approved staging baseline installed
See docs/STAGING_APPLIED_2026_10_30.md. Exactly baseline/009/010/012/022/023 applied successfully to verified separate staging only. Production untouched. Publication/operations remain off; signed-in native validation awaits controlled test accounts. Do not blindly reapply Dashboard SQL through CLI.


## Build-first working checkpoint
Current deliverables/evidence and limitations: docs/BUILD_FIRST_2026_10_30.md. Preserve stable homepage icons and existing modules. Public business views remain gated; local preview enhancements must never imply real transactions or publication. Keep the SMTP/template dependency separate from continuing safe development.

