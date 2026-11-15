# Stage 4 — Functional Marketplace & Business Operations

30 October 2026. Existing original React/Vite/Supabase application at C:\Users\kapalu\Documents\ZamMarket; normal app http://127.0.0.1:5173/home. Read MAIN_APP_EXPANSION_2026_10_30.md and CORE_CATEGORY_DISCOVERY_2026_10_30.md before implementation. No replacement project, production mutation, database migration, policy change, media deletion or real operation was performed.

## Implemented and improved

### Seller and business operations

Added a daily operations panel inside the existing Business workspace, using its existing owner-filtered Supabase catalogue query. Search across product title/category/location and filter by Available, Coming Soon, Sold or Temporarily Unavailable. The same Africa/Lusaka availability function used by the marketplace is reused; future dates become available at the start of the chosen Zambia date and stay available thereafter. Another owner's records and deleted rows are excluded defensively in local display as well as by the existing query/permissions.

Buttons connect to existing listing creation/owner management, service enquiries, promotion planning and contact visibility. Customer saved items have a clearly separate entry point. The panel shows up to 20 matching rows and sends users to My Listings for complete management. No duplicate mutation path or new business ownership permissions were introduced. Account-owned products are explicitly not automatically assigned to any of the user's businesses.

Existing persistent business, multiple-organisation, logo, branch, accommodation-room and logistics-service editors remain reused and gated to staging. Production UI accurately states that persistence awaits staging validation.

### Promotion proposals

A validated promotion proposal can now be kept and reopened in the Promotions workspace without the held commerce backend. Up to ten proposals are retained in memory; the same name replaces an earlier local copy. Proposals clear on leaving the workspace, and reviewed proposals can be downloaded to retain a copy. Existing backend draft saving remains separately capability-gated. No paid placement, subscription or payment activation.

### Trust and safety preparation

New authenticated /safety workspace, reachable through Business, supports listing/user report drafts and business verification preparation. It validates reference, reason and description, rejects obvious credential patterns, caps ten local drafts and prevents duplicate reference/reason drafts. Users can download or discard unsent drafts. Credentials screening is advisory, not a guarantee of sensitive-data detection.

All requests are explicitly unsent and unverified. Submit is disabled. No identity files, moderation data or documents are uploaded; no seller is marked verified. Fraud warnings and a business verification checklist explain safe trading and private-document boundaries. No live moderation queue is claimed.

## Backend draft prepared — NOT APPLIED

supabase/review/024_safety_requests_HOLD_DRAFT.sql and 024_SAFETY_REVIEW.md:

- New private safety-request table, owner-only SELECT RLS and no direct client writes.
- Definer RPC derives the owner from auth.uid(), requires existing verified complete membership, serializes per-account submissions, limits five per 24 hours and blocks same-reference/reason duplicates for 24 hours.
- Status is server-controlled; no public report reads, identity bucket, moderator grants or automatic badges.
- Depends on 010's helper, not messaging migration 012. No existing table/policy changes or cascade deletion.
- Not SQL-runtime validated. Separate approval and isolated PostgreSQL/staging tests are required. The UI is intentionally not connected to this draft.

The review identifies privacy/retention/abuse handling requirements and a non-destructive rollback approach: revoke the new RPC capability while retaining received records. Existing held migrations remain held; this batch applies none.

## Functional boundaries

**Existing connected core preserved:** authentication, profiles, shopping, saved products, owner listing management and participant messaging. New seller summary uses existing read access. No fresh live posting/sending/account or cross-account mutation tests were performed.

**Staging-only persistence preserved:** business organisations/logos/branches, accommodation-room and logistics-service data, where existing approved staging setup is available. End-to-end media permission and two-account tests remain pending.

**Local features:** seller display filters, unsent safety preparation and in-memory promotion proposals are working frontend workflows. Food menus/hours/enquiry planning, jobs/application preparation, events/agendas, agriculture, learning, accommodation/logistics planning, property previews and digital delivery planning remain in their existing guarded states. This batch did not activate them or claim that the whole multi-service platform is operational.

**Held:** new safety submissions, moderation, verification, production business persistence/publication and other held module backends. Payments, bookings, applications, ticket issuance, dispatch and automatic cleanup remain disabled.

## Validation

- npm test: 100 passed, zero failures. Added owner isolation/deleted-row tests, Lusaka date-boundary status checks and safety-draft validation/credential checks.
- npm run lint: passed.
- npm run build: passed.
- Main /home HTTP 200.
- Browser: Business displayed the daily operations panel, filter options and correct staging-only persistence notice. Safety navigation opened /safety; a non-sensitive example stayed labeled Unsent/unverified and submission remained disabled. Temporary test tab closed; no test draft transmitted.
- Screenshot: .validation/stage4-safety-draft.png.
- Staging configuration check run separately; configuration validity is not proof of live database/media isolation.
- SQL 024 has not been executed, and no live RLS test result is claimed for it.

## Files

New: src/lib/operations.js; src/components/SellerOperations.jsx; src/components/SafetyWorkspace.jsx; tests/operations.test.js; supabase/review/024_safety_requests_HOLD_DRAFT.sql; supabase/review/024_SAFETY_REVIEW.md; this report.

Updated: src/components/BusinessWorkspace.jsx; src/components/CampaignDraftEditor.jsx; src/components/RevenueHub.jsx; src/App.jsx; src/lib/routes.js; src/business-foundation.css; docs/NEXT_BATCH_PROGRESS.md.

## Remaining requirements and next milestone

1. Complete two-account staging tests of ownership, participant messaging, business persistence and private media before further backend activation. Existing email-template/sender access blocker remains; verification is not bypassed.
2. Review/approve 024 separately before any staging execution, with privacy/retention and staff access requirements first. No production approval implied.
3. Validate held commerce/service migration dependencies before connecting stock, storefronts, campaigns or service submission. Existing private likes exposure and legacy image bucket size/MIME protections remain pending separate security approval.
4. Next implementation batch: durable private draft storage under approved backend capabilities and shared listing/deep-link navigation from the operations panel. Preserve the current homepage and twelve-section category separation.
