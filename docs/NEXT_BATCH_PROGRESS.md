# Seller tools and expansion — 29 October 2026

## Inspection and scope

Retained existing authentication, profiles, messaging, saved products, compact cards, gallery, storefront editor, inventory and campaign editors, and Events/Jobs/Services/Learning interfaces. Did not rebuild these. Original 013/014 files remain byte-identical and on HOLD. No Supabase SQL, policies, data, buckets, payments or cleanup jobs changed.

## Completed locally

- Inventory: size-option starter, derived total visible in the quantity field, saving waits for stock records to load, public stock requires corrected capability flags and cannot show a previous product's record.
- Storefront/module images: private Storage signed URL component/hook, short-lived 60-second links refreshed every 45 seconds, unavailable fallback, updated publication disclosure. Original avatars and listing-images are unaffected.
- Advertising: campaign duration includes both dates; optional even daily allocation is a planning calculation, not charges/forecasts. Selected product status warns about sold products. Existing duplicate/archive/private draft flows retained.
- Seller analytics: real owner catalogue category/location distributions and missing-photo counts; no invented view/click/revenue data. Reads the existing marketplace_listings view only.
- Homepage: restored category navigation alongside the approved banner and destinations. Search and existing responsive design retained.
- Jobs/Events/Services/Learning: multi-word search, format filter, reset, latest-60-results disclosure and optional past event/deadline filtering using Zambia calendar dates. Existing posting/details/enquiry flows retained and gated.
- Property/Delivery/Food: useful validated local planning forms and review panels, linked through homepage/directory, no fake offers, submissions, payments or storage. Drafts live only in component memory and clear on navigation. These are explicitly previews, not operational services.

## Corrected SQL drafts — still HOLD

013_v2_modules_HOLD_DRAFT.sql and 014_v2_commerce_HOLD_DRAFT.sql are **alternative clean-install replacements**, NOT migrations to run after original 013/014. New object names deliberately collide if originals exist; stop on any preflight conflict. Do not run all four files. Original review recommendations remain valid for original sources.

013 v2 retains the reviewed tables/columns/owner and participant policies, but changes the NEW marketplace-media bucket to private. Owner access or a published entry/storefront reference permits media reads. A restrictive read policy prevents other permissive policies from exposing draft originals. New SECURITY DEFINER boolean visibility helper uses an empty search_path; it exposes only whether a supplied path has a published reference. Already-issued links may remain valid for 60 seconds after closure, and copied images cannot be recalled. No existing bucket/policy is replaced or edited by the draft.

014 v2 canonicalises stock options to label/quantity/price, also explicitly projects only those fields in the public view, rejects case-insensitive duplicate labels and excessive totals. Receipt identity and verification timestamps are immutable; revoked receipts cannot be reinstated. Service-role privileges are explicitly narrowed to read/insert/state update, accounting for default grants. Public verified reviews additionally bind receipt buyer/seller to review author/seller. Adds owner/buyer/seller indexes. Existing tables, policies, 012 messaging and original records remain unchanged.

Frontend now refuses v1 capability responses, requiring v2 plus private_media or safe_variants/immutable_receipts flags. This is compatibility gating, not a replacement for backend RLS. Production service-role secrets are never used by the frontend.

## Checks

- Focused unit coverage: preview validation, real-record insights, multi-word/format/deadline filtering including Zambia midnight, campaign date calculations and existing seller validation.
- Disposable PostgreSQL v2 validation: owner/participant isolation, private/public/closed media transitions, canonical variants, immutable receipt identities and final revocation; existing bucket settings/policies and 012 function preserved. This does not test live Storage HTTP signing or live multi-account sessions.
- Lint and production build run after changes. No repeated email/signup campaign or production-data tests.

## Before any live rollout

1. Review corrected SQL and confirm a current backup/restore plan. Nothing here is approval to execute it.
2. With owner participation, run 013_014_v2_PREFLIGHT_READ_ONLY.sql. Confirm new names absent, UUID listing IDs, required helpers/009+010 baseline and Storage role grants. 012 remains the messaging baseline, not a function replaced by these drafts.
3. Validate in a staging Supabase project, including real Storage signing, private drafts, publication/closure, two-account denial and upload limits. Signed URL API behavior is not covered by the in-memory database fixture.
4. Obtain explicit approval for the exact revised SQL before applying live. Existing data must remain intact. Transaction rollback is available before commit; after records exist prefer a reviewed forward fix or frontend rollback, not destructive DROP scripts.
5. A trusted, idempotent receipt issuance/revocation workflow remains required before verified purchases can be issued. Property/Delivery/Food need separate models and service-specific RLS; no live provider/booking/payment functionality exists yet.

Public-likes privacy, existing listing-image limits and automatic sold-photo cleanup remain pending unchanged. No activation, deletion or policy changes in this batch.

## Files

New: src/lib/expansion.js, src/lib/useCommunityImage.js; components VerticalWorkbench.jsx, SellerInsights.jsx, CommunityImage.jsx; tests/expansion.test.js; scripts/stage3-v2-checks.mjs; corrected 013/014 v2 drafts and read-only preflight.

Updated: src/App.jsx, src/stage3.css, src/config/platform.js, src/lib/stage3.js; components RevenueHub, CampaignDraftEditor, InventoryDashboard, ModuleMarketplace, PlatformPages, StorefrontEditor, Storefronts, SellerProfile, HomeDiscovery; scripts/stage3-checks.mjs and validate-profiles.mjs; roadmap/master plan and this report. Original 013/014 SQL unchanged.

Next: staging validation and approval review for the corrected backend, followed by dedicated Property discovery/owner draft model and Delivery enquiry/provider model. Food ordering waits for menu availability, opening hours, fulfilment and order-state design. Extend campaign management only after a trusted promotion lifecycle exists; do not infer real ad performance from catalogue counts.


## Property and Delivery batch — 29 October 2026
See [PROPERTY_DELIVERY_PROGRESS.md](PROPERTY_DELIVERY_PROGRESS.md). Dedicated Property discovery/detail/editor/gallery/saved/enquiry interfaces and Delivery planning/customer/courier/history interfaces replace the prior generic previews. Separate 015/016 drafts and staging validation plan prepared. All new migrations remain HOLD; no live changes or real bookings/payments.


## Latest service discovery batch — 29 October 2026
See [SERVICES_DISCOVERY_PROGRESS.md](SERVICES_DISCOVERY_PROGRESS.md) and [SERVICE_BACKEND_NEXT_CONTRACTS.md](SERVICE_BACKEND_NEXT_CONTRACTS.md). Property URLs/pagination, courier draft wizard/local lifecycle, Food menus/cart planning and Event ticket scenarios implemented locally. 013_v2/014_v2/015/016 remain HOLD. No isolated staging configuration was found; no remote SQL or production changes.


## Latest foundations / Jobs / Learning batch — 29 October 2026
See [FOUNDATIONS_JOBS_LEARNING_PROGRESS.md](FOUNDATIONS_JOBS_LEARNING_PROGRESS.md), [ISOLATED_STAGING_SETUP.md](ISOLATED_STAGING_SETUP.md) and supabase/review/017_019_REVIEW.md. New 017–019 operational drafts remain HOLD with gates FALSE; Jobs/Learning planning dashboards and product cart preview implemented. Existing held SQL and homepage square service-icon boxes preserved. Remote staging unavailable; all database checks were disposable/local and browser checks used the mock backend, not production.


## Detail / discovery / specialist catalogues continuation
See [DETAIL_DISCOVERY_CATALOGUES_PROGRESS.md](DETAIL_DISCOVERY_CATALOGUES_PROGRESS.md) and [DEPENDENCY_AND_STAGING_MATRIX.md](DEPENDENCY_AND_STAGING_MATRIX.md). Shared large/zoom/swipe gallery, honest visit-interest foundations, Agriculture/Digital local catalogues and service-planning workflows added. New 020/021 remain HOLD; previous 013_v2–019 untouched. No production testing or activation.

Latest batch: see CORE_CATEGORY_DISCOVERY_2026_10_30.md for twelve-section category correction, scoped search, homepage/mobile updates and promotion proposal preparation. 98 tests, lint and build passed; no live changes.

Latest operations batch: STAGE4_OPERATIONS_2026_10_30.md. Seller operations, local promotion proposals and unsent safety preparation added. 024 safety draft prepared on HOLD; no live changes. 100 tests, lint and build passed.

Full-build expansion: FULL_BUILD_EXPANSION_2026_10_30.md. Purchase planner, business hours, commissions/packages, custom replies, retained multi-service drafts/favourites, published links and gated admin foundation. New 025 remains HOLD; production unchanged. Ten targeted tests, lint and build passed.

Shared-workspace continuation: FULL_BUILD_WORKSPACE_2026_10_30.md. Account-scoped session plans across services, customer activity hub, enquiry management filters/confirmed writes, report handoff and private review preparation. No live changes or new migrations. Focused tests, lint and build passed.

Major operational systems: MAJOR_OPERATIONAL_SYSTEMS_2026_10_30.md. Connected Shopping order requests, Food catalogue/kitchen lifecycle and Delivery customer/courier lifecycle code. New 026–028 HOLD; production/024/025 unchanged. Four essential targeted tests, lint and build passed. No SQL/runtime activation claimed.

Remaining systems implementation: REMAINING_OPERATIONAL_SYSTEMS_2026_10_30.md. Seven participant workflows, host calendars/reservations, event inventory/attendance, digital seller files/private delivery source and MFA admin review. New 029–033 HOLD; no SQL/deployment/activation. Four focused tests, lint and build passed; runtime staging validation pending approval.

Feature completion sprint: FEATURE_COMPLETION_SPRINT_2026_10_30.md. Account/session readiness, unified actual histories, operational notifications, staging report submission, revenue review/test ledger and expiring bounded digital downloads. 034/035 and optional source registration on HOLD; 024–033 unchanged/HOLD. Four targeted checks, lint/build passed; no comprehensive or live backend tests.
