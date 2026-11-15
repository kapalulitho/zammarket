# Backend foundations, Jobs, Learning and commerce

29 October 2026. Reviewed the latest SERVICES_DISCOVERY_PROGRESS.md and existing components first. Preserved authentication, profiles, existing listings/messages/photos, the approved homepage/banner and the existing small square service-icon box markup/styles. Did not repeat completed email/account tests or use production data for testing.

## Implemented this batch

- **Jobs:** category and salary-basis/range filters added to existing multi-word/employment/location/deadline discovery. Salary comparisons require a chosen basis. Job creation now has a usable local detail review while publishing is gated. Employer public-profile summary, application motivation/availability draft review, visit-only applicant dashboard. No CV uploads, private identity/contact collection, real application submission or employer candidate access.
- **Learning:** subject, fee-basis/range and free-only filters on existing Tutor/Course/Workshop discovery. Instructor/public-profile summary, course/tutor detail review, weekly-hour and goal enrolment preview, visit-only learning dashboard with self-tracked planning tasks. No enrolment, payment, course access or certification claim. Unknown fees are not treated as free. Instructor listings and learner dashboard are separately labelled.
- **Commerce:** account-scoped in-memory product cart at /cart, product-detail add/open controls, quantity editing/removal, price refresh, item subtotal in integer minor units and unavailable/missing-price exclusions. Account logout clears the preview; checkout stays disabled. Cart uses listing base prices; variants/stock/fees still need seller confirmation. Seller analytics add actionable missing-location/category/price counts, preserving real catalogue-only statistics and never inventing revenue.
- **Platform:** icon-labelled service wayfinder, consistent planning forms, phone-friendly dashboard cards, clearer owner/learner/applicant tabs. Private module state remounts on account identity changes. Homepage service boxes and green promotional design are unchanged.

## New backend drafts — HOLD

017_food_orders_HOLD_DRAFT.sql: new settings, restaurant/menu catalogue and private order/line tables; server-authoritative prices, atomic bounded stock deduction, strict item fields, participant SELECT policies and idempotent create RPC. Catalogue writes are trusted-service-only for now. Fulfilment/cancellation/refund/audit/fee workflows remain blockers.

018_event_ticketing_HOLD_DRAFT.sql: new settings, active public ticket categories and private reservations; locked capacity, authoritative prices, buyer/key retry handling, per-event hold limit, participant-only idempotent cancellation and cancellation metadata. No payment, confirmation, QR issuance, expiry or cleanup job. Requires corrected 013_v2; no old migration changed.

019_delivery_operations_HOLD_DRAFT.sql: separate approval/job/audit/contact tables and disabled settings; verified customer submission, service-only assignment, approved courier/revision/transition checks, and contact access revoked after terminal states. Late-dispute/reassignment/admin approval/proof-of-delivery/retention processes remain blockers. Existing 016 planning tables are unchanged.

All new operational gates stay FALSE after migration. Missing settings fail closed. Ordinary clients cannot enable gates or directly mutate operational rows. No frontend is wired to these operational RPCs. No production activation, policies, data, payments, orders, bookings, applications, tracking or cleanup was changed. Read supabase/review/017_019_REVIEW.md for separate scope/security/rollback assessments.

013_v2, 014_v2, 015 and 016 remain unchanged and HOLD. All new drafts, including the optional STAGING_ONLY empty baseline, are also HOLD. No database migration was applied remotely.

## Isolated staging preparation

Added .env.staging.example (placeholders only), fail-closed URL/project/mode/publishable-key checks, separate Auth storage key, STAGING banner, guarded dev:staging/build:staging commands and configuration checker. Missing configuration cannot fall back to production in staging mode. Default production connection and existing Auth storage key remain unchanged. No secrets printed or stored in documentation.

ISOLATED_STAGING_SETUP.md gives separate-project, empty-baseline, Auth, migration-order and validation instructions. New empty prerequisite schema is for a brand-new staging project only, never production; no existing object is replaced. No project or expenses were created. check:staging reported no configuration; required-config mode deliberately refused startup. Remote staging signing, concurrency and multi-account validation remain unperformed because no isolated project was supplied.

## Focused results

- Four new unit tests pass: staging isolation/refusal, non-operational opportunity payloads, salary/free-price filtering and shopping-cart pricing/availability.
- New 017–019 disposable PostgreSQL checks pass: gate rejection, immutable request identity on key retry, authoritative prices/stock exhaustion, ticket capacity/single-release cancellation, participant isolation, service-role assignment permission, stale/role transition denial, audit revisions and terminal contact revocation. Old policy definitions were compared and preserved. These are sequential local fixtures, not concurrent/live Supabase tests. A test account was verified only inside the disposable fixture to exercise outsider permissions beyond the membership gate.
- Empty staging baseline DDL checked locally for empty rows/RLS; native Supabase Auth/Storage behavior still needs actual staging validation.
- Lint and production build passed. Browser checks ran through a Vite alias to a local mock Supabase module on port 5174, not the production SDK/project: Jobs draft review → applicant dashboard; Learning preview → study plan/dashboard task; mock product → cart with checkout disabled. Phone layout inspected at 360px, including dark theme. Test tab/viewport/server cleaned up; normal development server preserved.

## Files

New: src/lib/opportunities.js, environment.js; components OpportunityWorkspace.jsx, PublicMemberCard.jsx, ProductCart.jsx; tests/next-foundations.test.js; scripts/check-staging.mjs, check-staging-baseline.mjs, service-foundation-checks.mjs; .env.staging.example; 017–019 review SQL and review report; staging empty baseline; setup and progress docs.

Updated: src/components/ModuleMarketplace.jsx, SellerInsights.jsx, ServiceWayfinder.jsx; src/App.jsx, main.jsx, supabase.js, lib/routes.js, config/platform.js, service-planning.css; package.json commands; optional --with-service-foundations in scripts/validate-profiles.mjs; roadmap/master-plan/latest progress links. Ignored local mock export was updated for the new backendMode import; it is never used by normal/staging production config.

## Next priorities and blockers

1. Owner-approved isolated staging project/configuration, followed by exact SQL review and native Auth/Storage/RLS/concurrent session validation. A current production backup/restore plan remains unverified. No production migration approval should be requested before results and blockers are reviewed.
2. Complete Food fulfilment/cancellation/stock restoration, fees and audit; ticket lifecycle/issuance/expiry policy; Delivery provider approval/disputes/reassignment/proof workflows before any gate activation.
3. Prepare separately reviewed private job application/decision/document and learning enrolment/content-progress schemas. Current dashboards are local planning tools, not real applicant/enrolment systems.
4. Continue seller stock/variant-aware cart planning and server-authoritative product checkout design. Keep payments, new bookings/orders/applications, photo cleanup, public-likes privacy and old image-limit changes on their separate approval tracks.


## Detail / discovery / specialist catalogues continuation
See [DETAIL_DISCOVERY_CATALOGUES_PROGRESS.md](DETAIL_DISCOVERY_CATALOGUES_PROGRESS.md) and [DEPENDENCY_AND_STAGING_MATRIX.md](DEPENDENCY_AND_STAGING_MATRIX.md). Shared large/zoom/swipe gallery, honest visit-interest foundations, Agriculture/Digital local catalogues and service-planning workflows added. New 020/021 remain HOLD; previous 013_v2–019 untouched. No production testing or activation.
