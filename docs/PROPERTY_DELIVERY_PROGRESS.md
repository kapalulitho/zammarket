# Property and Delivery development batch

29 October 2026. Inspected NEXT_BATCH_PROGRESS.md and existing preview/gallery/backend components first. Continued the latest code; did not rebuild authentication, profiles, products, messages, inventory, storefronts, campaigns, Jobs, Events or Learning.

## Completed frontend

**Property:** dedicated marketplace page, property-type and sale/rental filters, multi-word/location search, price range/bedroom filters, sorting, ZMW and explicit price bases; responsive property cards and detailed views; galleries for up to eight existing/new photos with owner/published signed-image infrastructure; seller/agent information and existing seller-profile navigation; private enquiry/reply interface; saved properties; creation/editing with local review before gated confirmation. Agent type is self-declared, not verified ownership. New editor supports JPG/PNG/WebP signature validation and 5 MB/image; existing photos are retained, not deleted.

With backend absent, users can create and browse clearly labelled previews, save previews for the current module visit and edit them. Photos and drafts stay in memory; object URLs are revoked when leaving the module. They are not production listings, public offers or persistent saved properties. Live publishing, persistence and sending require separately approved 015 and completed verified account. Real content reads/writes are prepared behind the capability gate, not enabled on current production schema. Detail selection is within the Property page; shareable individual property URLs remain a follow-up.

**Delivery:** dedicated homepage; pickup/destination area, parcel size/weight/handling forms; request review; visit-only history; customer dashboard foundation; truthful planning/status steps with booking/assignment/tracking marked unavailable; courier workspace and self-declared profile design preview. No imaginary couriers, fares, tracking, earnings or bookings. With approved 016, private customer plans/history can persist, but booking/payment buttons remain disabled. Courier draft database foundation is prepared; courier draft persistence/onboarding is not connected yet.

**Platform:** lazy-loaded new modules, navigation through existing homepage/directory, consistent hero/cards/forms, phone-friendly filters, single-column detail/workspace on small screens, accessible labels/status/errors and reduced-motion CSS. Existing product gallery and private-image signing logic reused; image hook now accepts a separate bucket and keys cached state by bucket/path. No new tracking, map/geolocation dependency or third-party provider.

## Backend drafts — not applied

- 013_v2 and 014_v2 remain HOLD and unchanged. Original 013/014 also remain unchanged.
- 015_property_MARKETPLACE_HOLD_DRAFT.sql: three new RLS tables, owner/participant/save policies, publication-aware PRIVATE property-media storage, membership/identity/media/enquiry guards and readiness RPC. Published rows contain public property details and seller identity only; saves/enquiries private. No property/photo deletion grants or cleanup.
- 016_delivery_PLANNING_HOLD_DRAFT.sql: owner-private delivery plans and courier profile drafts. Only planning/draft states, no operational dispatch/payment/booking schema. No public courier data.
- Separate review and metadata-only preflight: supabase/review/015_016_REVIEW.md and 015_016_PREFLIGHT_READ_ONLY.sql.
- Staging plan covering private image HTTP signing, token expiry/closure, RLS across account roles, safe projections and immutable receipts: docs/STAGING_VALIDATION_013_016.md.

No SQL has run against production or staging. No existing rows, policies, users, buckets or photos were changed. No backend keys/passwords exposed. Current full production backup remains unverified; obtain backup/restore confirmation and explicit approval before applying any exact draft. No paid staging project has been created.

## Validation

- Three new focused unit tests passed: property validation/identity stripping, combined filters/non-mutating sort, delivery planning-only validation.
- Local disposable PostgreSQL checks passed for 015/016: public/draft/closed property and photo visibility, owner-only editing, private saves/enquiries/delivery/courier drafts, spoofed-owner denial, recipient-only reply, booking-state denial, no property delete grant, existing policy and bucket preservation. One test assertion was corrected to expect RLS-filtered zero updates rather than an exception; no policy was weakened.
- Browser checked local property review, disabled backend confirmation, saved visit preview/card, Delivery review, disabled booking/private saving and visit history. Used only non-sensitive in-memory examples; no submissions or uploads. Phone screenshots at 360px inspected for both modules; no visible horizontal layout overflow. Temporary viewport/tab restored/closed afterward.
- Lint and production build run after final changes. Real signed-image HTTP delivery and live two-account persistence remain staging checks, not claimed as passed. No repeated real-email/signup campaign.

## Files

New components: PropertyMarketplace.jsx, PropertyEditor.jsx, PropertyGallery.jsx, PropertyEnquiries.jsx, DeliveryWorkspace.jsx, ExpansionNotice.jsx.

New libraries/style: src/lib/property.js, delivery.js, useExpansionBackend.js and src/property-delivery.css. Updated src/lib/useCommunityImage.js to accept bucket.

Updated src/App.jsx and src/config/platform.js for module routes/directory descriptions. Added tests/property-delivery.test.js, scripts/property-delivery-checks.mjs and optional --with-property-delivery flag in scripts/validate-profiles.mjs. Added 015/016 SQL drafts, preflight, review and staging plan. Roadmap/master plan/latest progress link to this batch.

## Next priorities

1. Approved isolated staging validation of held drafts, including real Storage signing and account isolation; review exact SQL/backup before any production approval request.
2. Property: cursor pagination, price-basis-specific comparisons, shareable detail URLs, agent verification/moderation process, dedicated private enquiry inbox and retention policy; avoid unverified ownership claims.
3. Delivery: save/edit courier drafts after validation; decide operational provider approval, dispatch, cancellation, proof-of-delivery, private address/contact handling and audited transitions in separate drafts. Do not activate real bookings/payments until those controls exist and are approved.
4. Continue seller workspace navigation and expand service discovery using actual published data after approved backend setup. Existing public-likes privacy, listing-image limits and cleanup remain on their separate pending list, unchanged.


## Latest service discovery batch — 29 October 2026
See [SERVICES_DISCOVERY_PROGRESS.md](SERVICES_DISCOVERY_PROGRESS.md) and [SERVICE_BACKEND_NEXT_CONTRACTS.md](SERVICE_BACKEND_NEXT_CONTRACTS.md). Property URLs/pagination, courier draft wizard/local lifecycle, Food menus/cart planning and Event ticket scenarios implemented locally. 013_v2/014_v2/015/016 remain HOLD. No isolated staging configuration was found; no remote SQL or production changes.
