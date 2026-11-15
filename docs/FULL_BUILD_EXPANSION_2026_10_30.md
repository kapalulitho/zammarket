# Full-build marketplace expansion — 30 October 2026

Original project: C:\Users\kapalu\Documents\ZamMarket. Main app: http://127.0.0.1:5173/home. Existing homepage, twelve marketplace sections, original backend selection and separate staging preserved. No live database, role, policy, bucket, account, listing or photo changes. No held migration applied. No real payments, bookings, applications, ticket issuance, publication, dispatch or cleanup activated.

## Features implemented in this batch

### Customer purchase workflow

The Orders route now opens a purchase-discussion planner instead of the previous static coming-soon screen. It uses the existing cart and current listing records, groups lines by seller, excludes missing/unavailable items from its subtotal, preserves ZMW minor-unit calculations, and offers collection/delivery preference, non-sensitive notes, personal checklist and downloadable plan. Links return to the cart, shopping and existing conversations. Starting a new conversation still uses the existing product detail action. No order number, reservation, receipt or successful payment is fabricated. Cart points to the new planner.

### Business and seller tools

- Weekly business operating-hours planner with seven-day editing, explicit closed days, same-day time validation and Africa/Lusaka labeling. Review/download only; no unapproved profile column is written and no opening status is presented as live. Overnight periods are explicitly unsupported by this simple planner.
- Commission/settlement scenarios using integer ZMW minor units, bounded rates, fixed-fee checks and prevention of fees exceeding gross. Assumptions are not a platform fee schedule, payment provider quote or payout.
- Personal/small-business/company package comparison and downloadable requirements. Selection grants no entitlements, active subscription, staff roles or charges. No invented premium prices.
- Validated stock/variant plans can be downloaded using the existing stock validator while persistence remains held. Storefront text can be reviewed and downloaded without activating publishing.
- Custom seller reply templates: up to six non-sensitive 500-character replies during the inbox visit; use fills the message box and never auto-sends. Templates are not cloud-saved.

### Jobs, Events, Services and Learning

These four existing modules now retain up to twelve editable local listing drafts per module visit, rather than losing a preview on returning to discovery. Drafts participate in the correct section's existing search and filters; local cover images receive existing type/size/magic-byte validation, render in cards/details and are released on module exit/replacement. Local records are forced to draft status and cannot accidentally pass into a persisted update path. Persistent save remains separately gated.

Visit-only favourites (up to 100 IDs) and a saved-only filter are available in these modules. Local drafts remain clearly labeled, never represent actual employer posts, live courses, confirmed events or operational service offers. Leaving the module clears local records and favourites.

Published saved records now support section-correct share URLs (/jobs, /events, /services, /learning with an entry UUID). Exact-ID loading still uses Supabase permissions and verifies kind. Private/unsaved/local entries cannot generate public share links. Malformed, unavailable and held-backend links receive clear messages. No bypass of RLS. Actual persisted-link loading awaits approved module backend validation.

### Administration foundation

New authenticated /admin route linked from Business. On the production connection it does not call an administration RPC and explicitly remains inactive. In staging it rechecks identity and calls only a protected overview RPC; missing permission or backend yields denied/unavailable. No frontend role switch, profile-metadata role or self-grant path. Only allowlisted aggregate counts can be displayed after an affirmative server response. No private users, messages, documents or reports are fetched by the UI.

This is a read-only foundation, not completed user management, moderation or business verification. Those operations remain unfinished and unavailable.

## Backend draft and integration architecture

- Prepared 025_admin_foundation_HOLD_DRAFT.sql and 025_ADMIN_REVIEW.md. Requires baseline and held 024 safety requests. Creates a private server-owned membership table and protected aggregate-only definer RPC. No admin is seeded or granted rights. Existing objects/data are unchanged. Empty search_path and server membership check; no client table privileges or policies. Explicit migration and administrator-provisioning approvals remain separate.
- SQL draft is not executed or PostgreSQL-runtime validated. Staging anonymous/non-admin/disabled-admin denial and default/inherited-grant tests are required before approval.
- Existing 024 remains HOLD and unapplied. Previous held migrations stay in their existing states; historical staging approvals are not extended to new drafts.
- PAYMENT_INTEGRATION_BOUNDARY.md specifies server-derived quotes, immutable order snapshots, idempotency, signed webhook validation, private provider credentials, atomic stock transitions and refund/audit requirements. No live adapter, SDK or provider credentials added.

## Current platform status

| Section | Current useful workflow | Still held or unfinished |
| --- | --- | --- |
| Shopping | Existing connected products, profiles, saved products, chats, owner management; cart/purchase planning | Secure checkout, stock/variants persistence and commerce activation |
| Food | Local restaurant details, menus/photos, hours, filters, cart/enquiry preparation | Real restaurant/order backend and operations |
| Jobs | Local drafts, discovery/filtering, employer details, application preparation, visit saves | Persistent publishing and applications |
| Events | Local drafts, venue/schedule details, agenda/ticket preparation, visit saves | Publishing, ticket issuance and booking |
| Agriculture | Local produce/equipment/livestock/service catalogue and enquiries | Dedicated persistent catalogue activation |
| Property | Existing guarded discovery/editor/gallery/enquiry interfaces, category separation | Held 015 persistence/validation where unavailable |
| Accommodation | Room/amenity/nightly-price and enquiry planning; existing staging editors | Production persistence/publication and real availability/bookings |
| Delivery | Existing request/lifecycle/courier planning | Dispatch, tracking, operations and held backend |
| Logistics | Providers/service areas/vehicle categories and quotation planning; staging editors | Production persistence and real quotations/operations |
| Services | Local provider/service details, booking preparation, visit saves | Persistent publishing/enquiries and verified reviews |
| Learning | Local listing drafts, course/tutor information, study/enrolment preparation | Publishing, real enrolment/course delivery |
| Digital | Local product/licence/catalogue and secure delivery planning | Approved entitlements, scanning and private paid downloads |

Multiple businesses/branches continue through existing staging-gated tools, not duplicated implementations. Existing authentication and messaging were preserved, not declared newly revalidated by live multi-account tests. This batch does not make the whole platform production-ready.

## Validation performed

- Ten focused tests passed across commercePlanning, operations and marketplaceCategories, zero failures. New coverage: commission arithmetic/invalid rates, weekly hours, published-only section-correct links.
- Lint passed with no warnings after fixes.
- Production build passed after final code changes.
- Main /home HTTP 200; main server left running.
- Focused browser check: create a non-sensitive local job, save for the visit, return to discovery; correct Accounting category, draft card, filter and saved count appeared. No backend write. Production /admin remained inactive with no role grant.
- Screenshot: .validation/full-build-job-draft.png. Temporary test tab closed, clearing the local test draft.
- Full regression, cross-account, live email, real payment/provider and SQL runtime tests intentionally deferred. No claim that they passed.

## Changed files

New components: PurchasePlanner.jsx, CommerceFoundations.jsx, AdminFoundation.jsx, ReplyTemplates.jsx, SubscriptionPlanner.jsx.
New helpers/tests: src/lib/commercePlanning.js, src/lib/communityLinks.js, tests/commercePlanning.test.js.
Updated components: ModuleMarketplace.jsx, Messages.jsx, RevenueHub.jsx, BusinessWorkspace.jsx, ProductCart.jsx, InventoryDashboard.jsx, StorefrontEditor.jsx.
Updated integration/style: src/App.jsx, src/lib/routes.js, src/business-foundation.css.
New backend/review: supabase/review/025_admin_foundation_HOLD_DRAFT.sql; supabase/review/025_ADMIN_REVIEW.md.
Documentation: this report, PAYMENT_INTEGRATION_BOUNDARY.md, NEXT_BATCH_PROGRESS.md.

## Practical final testing and launch checklist

1. Review exact held migration dependencies against a backed-up, isolated staging project; never run original and replacement 013/014 together. Obtain explicit approval per migration before execution.
2. Complete real verified signup/recovery/logout and refresh tests. Resolve the documented staging email-template/sender-access blocker without bypassing confirmation.
3. Use two isolated accounts to test ownership, participant chats, private profiles/enquiries, signed business media and all denied writes. Include account-switch and stale-session cases.
4. Validate image ownership, dimensions/size/MIME, limits, signed-URL expiry and orphan handling. Keep automatic cleanup disabled. Resolve public likes privacy and legacy listing-image limits through separate approval.
5. Validate new 024/025 in staging only after approval; test concurrency/rate limits and denial, server-owned admin provisioning, audit/retention and MFA design before any privileged mutation endpoints.
6. Exercise every module on small Android and desktop, slow/offline connections, invalid forms, refresh/navigation and accessibility. Confirm local-draft lifetimes are understood. Complete full regression at the final activation milestone.
7. Select and configure external payment/delivery/email/document-scanning services only with approval; verify sandbox callbacks, refunds, disputes and costs before activating real operations.
8. Approve production migrations, privacy/consumer policies, administrator operations and deployment separately. Until then keep all unsupported real operations disabled.

Next high-value milestone: approved isolated staging persistence and permission validation for existing modules, followed by audited admin/moderation operations. The main remaining functional blockers are backend approval, security validation and external services, not missing section navigation.
