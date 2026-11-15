# Stage 3 — Core marketplace and business foundation

29 October 2026. Existing project continued; no remote database operations. Homepage layout, fixed eight service icons, mixed feed, Shop navigation and large galleries preserved.

## Connected functionality

- Existing Supabase Auth/profile, posting, saved products, participant messaging and owner listing RPC are retained. This batch did not repeat live signup/email tests or claim a fresh production pass.
- My Listings now has title/status filters, ownership checks and a fresh authenticated-user check before mutations. Full edits reuse posting validation; availability still uses Africa/Lusaka dates and never expires. Status-only actions preserve existing price/date values. Backend RPC/RLS remain authoritative.
- Business workspace reads only the current user's catalogue and participant conversations through existing backend capabilities. Counts represent listings/statuses, never orders/revenue. Individual failures display errors rather than invented metrics.
- Explore adds related service navigation and conditionally reads published community content only when the corrected module capability is available. Results are labelled recent, not trending. Unavailable backends do not show fake offers.

## Local previews

- Business planning: personal/small-business/company identity, optional validated logo, description, contact opt-ins and public projection; branch/team planning. No saved company account or staff access is created. Existing saved account profile remains available separately.
- Accommodation at `/stays`: seven accommodation categories, text/town/category filters, create/edit, shared large gallery, host profile, room options, capacity and nightly ZMW estimates; validated 1–90 calendar-night enquiry planning. No real room inventory, availability, bookings or enquiries sent.
- Logistics at `/logistics`: seven business categories, provider/service areas, create/edit/gallery and unsent quotation planning. Separate from parcel Delivery; no route tracking, fare, dispatch or carrier verification.
- These plans live in component memory and disappear when leaving/reloading the module. Use non-sensitive sample details. Nothing is uploaded or published.
- Existing stock/variants, storefronts, vertical workflows and advertising remain subject to their existing capability gates. Payments, tickets, orders, applications, digital downloads and operations are not enabled by this batch.

## Files changed in this batch

Application: `src/App.jsx`, `src/config/platform.js`, `src/lib/routes.js`, `src/components/MyListings.jsx`, `src/components/ModuleMarketplace.jsx`.

Added UI: `src/components/BusinessWorkspace.jsx`, `BusinessServiceDirectory.jsx`, `CoreJourneyGuide.jsx`, `ExploreServices.jsx`, `src/business-foundation.css`.

Added validation helpers: `src/lib/businessFoundation.js`, `businessServices.js`, `listingManagement.js`.

Backend review only: `supabase/review/022_business_foundation_HOLD_DRAFT.sql`, `023_stays_logistics_HOLD_DRAFT.sql`; review and matrix updates listed below. Existing 012–021 SQL untouched.

Checks: `tests/business-stays-logistics.test.js`, corrected stale menu-length assertion in `tests/discovery.test.js`, `scripts/business-service-checks.mjs`, optional flag in `scripts/validate-profiles.mjs`, isolated mock query support in `.validation/mock-supabase.js`.

## Verification

- `npm test`: 73 passed, zero failed. New checks cover contact privacy, injected permissions, ownership, edit/post validation consistency, invalid calendar dates, room capacity, integer currency and unsent quotation boundaries.
- `npm run lint` and production build passed.
- In-memory PGlite: baseline 009/010 plus proposed 012, then 022/023. Existing policies unchanged; owner/manager/nonparticipant isolation, no membership self-escalation, hidden login email, opt-in public contacts, publication defaults false, parent-gated services/media, room type/capacity and private unsent drafts passed. No Supabase connection used.
- Isolated browser at 5174: accommodation creation/detail and two-night estimate (250 × 2 = ZMW 500), disabled publishing/booking, business summary and logistics directory checked. Small-screen stays and business layouts showed no horizontal overflow at the 360px viewport. Mock results are not production or native Storage validation.
- `npm run check:staging`: NOT CONFIGURED, no remote validation. Real two-account RLS/signing/concurrency checks remain pending in a separate approved staging project.

## Backend requirements and approvals

All held drafts remain HOLD. New 022/023 are reviewable foundations, not production-ready operational systems. See `BUSINESS_STAYS_LOGISTICS_REVIEW.md` and `DEPENDENCY_AND_STAGING_MATRIX.md`. Provisioning any paid staging project, applying exact staging/production SQL, changing policies, public publication, staff permissions or enabling real operations requires approval. No cleanup or deletion was activated. Public likes privacy and legacy listing image limits remain pending separately.

Recommended next milestone: isolated staging baseline, then authentication/ownership/listing management/messaging verification, followed by business profile/media validation and explicit organisation-to-storefront mapping. Only after this evidence should frontend business persistence and public stays/logistics discovery be connected. Staff access and enquiry submission need separate audited workflows.
