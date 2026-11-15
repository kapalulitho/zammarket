# Feature-completion sprint — 30 October 2026

Original project and Supabase configuration preserved. Main app: http://127.0.0.1:5173/home. Production data/settings unchanged; 024–033 remain HOLD. No migrations applied, digital function deployed, real payment/booking/placement activated or moderation enforcement enabled.

## Implemented in this sprint

- **Account completion and security:** Supabase email/profile readiness, private account settings, seller/business entry points, operational history links and explicit sign-out-other-refresh-sessions control. Password changes now recheck current account identity. Profile account type never grants admin rights.
- **Unified histories:** customer/provider order, application, reservation and request metadata across Shopping, Food, Delivery, Accommodation, Events and seven participant workflows. Own participants only, search/status/role/system filters, correct dashboard navigation and separate unavailable-source reporting. Operational history stays staging-only; existing production Messages/Saved links remain usable.
- **Notifications:** combines legacy enquiries with private operational notifications, correct dashboard destinations, read/unread controls and accurate loading/filter/error states. New held triggers cover requests/statuses/messages, report review, package/campaign review and trusted test-ledger updates. No email/push activated; latest 50 per source, not global totals.
- **Reporting:** reviewed reports can use the existing held 024 submission RPC in staging, with current identity checks, confirmed-record feedback and own report-state history. Stored reports leave the unsent-preparation list. Production submission stays disabled; no moderation outcome or verified badge is fabricated.
- **Revenue:** connected package-change requests, campaign snapshots/review histories, owner cancellation, MFA/server-authorized review queue and trusted test commission ledger. Plans with unknown prices remain unpriced. Approval never activates billing, entitlements or sponsored placements. Client scenarios/marked-sold listings cannot become ledger revenue.
- **Digital completion:** conservative server expiry timestamp, client expiry validation, foreign-host rejection, bounded streaming, progress/cancellation and explicit fresh-link recovery after expiry/access denial. Authorization, scan approval and revocation are rechecked by the existing function source. Deployment remains disabled.
- **Consolidation/usability:** reused existing profile, business, campaign, participant and admin components. Removed unused static OrdersPage/BusinessPage exports, preserving their working replacements. Connected histories/revenue to Profile and workspaces, improved mobile wrapping and lazy-loaded new pages.

## Reviewable backend additions

034_revenue_management_HOLD_DRAFT.sql: request/review/event/test-ledger tables, owner/admin RLS and RPCs. Requires 010, corrected 014_v2, 022 and 032. New request gate defaults false; no pricing approval, admin grant or activation.

035_operational_notifications_HOLD_DRAFT.sql: private notification table, recipient-only SELECT, bounded mark-read RPC and source-bound triggers for installed approved branches. No message bodies or personal contact details in notification titles. Optional 035_registration_HOLD.sql registers later approved source tables without rerunning schema creation. Both remain unapplied.

Review/install notes: supabase/review/034_035_COMPLETION_REVIEW.md. No Storage policy/bucket change required; digital relies on held 020/033 private configuration.

## All 12 sections: what remains genuinely unfinished

| Section | Operational code retained | Remaining real-operation gap |
| --- | --- | --- |
| Shopping | Cart, variants/request snapshots, seller fulfilment/history | Guaranteed stock allocation, full quotes, payment/order settlement |
| Food | Restaurant/menu management, kitchen states, cancellation | Hospitality/food policies, tax/delivery quotes, real ordering activation |
| Jobs | Posting, employer/applicant workflow and history | Approved persistent backend, employment/privacy policies; no CV-document intake |
| Events | Category inventory, reservation holds, attendance | Paid ticket/QR issuance, expiry rules and activation |
| Agriculture | Saved seller catalogue, listed inventory, bulk quotations | Inventory reservation/fulfilment allocation; source activation |
| Property | Owner management, viewing requests, enquiry tracking | Exclusive viewing slots, tenancy/contracts and activation |
| Accommodation | Night calendars, atomic confirmation, guest messages | Approved booking terms, deposits/no-show/early-checkout/refund policies |
| Delivery | Private requests, assigned-courier actions, stored tracking | Trusted dispatch onboarding, real GPS/provider integration |
| Logistics | Fleet/resources, freight quotations and status | Carrier execution/integration, transport terms, live dispatch |
| Services | Provider requests, quotes, appointments | Exclusive appointment capacity and credentials/payment integration |
| Learning | Courses, enrolment/progress foundations | Secure lesson delivery, entitlement/assessment/certification workflow |
| Digital | Private versions, entitlement authorisation, signed-delivery source | Approved scanner/purchase issuer, server configuration/deployment |

Admin case/review tools exist, but public hide/restore enforcement, public verification badges and destructive account operations remain unimplemented/unactivated. Paid subscription entitlements, real provider webhooks, billing and sponsored placement serving also remain unfinished. Authentication email-template/sender configuration remains the previously recorded external blocker; no verification bypass was added.

## Validation and activation boundary

Four focused tests passed for history isolation, notification routing, ledger arithmetic/production denial and expiry/bounded downloads. Lint and production build passed. Static scan: all 12 sections registered; 84 literal navigation targets checked with zero unknown targets. Main app HTTP 200. One notification-sort edge case was caught and corrected.

No comprehensive regression, multi-account, PostgreSQL runtime/concurrency, Deno runtime, real email or live financial/digital-download tests were performed. Builds do not prove hosted backends are operational. The next required milestone is explicit approval and dependency-correct isolated staging installation, followed by essential permission/transaction checks; production approval stays separate.

## Files

New components: AccountCompletion.jsx, AccountHistory.jsx, RevenueOperations.jsx, ReportOperations.jsx.
New helpers: accountHistory.js, revenueOperations.js, notificationTools.js. New tests: featureCompletion.test.js.
Updated components/integration: App.jsx, routes.js, AccountProfile.jsx, CustomerWorkspace.jsx, RevenueHub.jsx, AdminFoundation.jsx, PlatformPages.jsx, NotificationInbox.jsx, SafetyWorkspace.jsx, DigitalLibrary.jsx, digitalDelivery.js, business-foundation.css. Edge source: supabase/functions/digital-delivery/index.ts. New held SQL/review files above. All component paths are under src/components, helpers under src/lib, tests under tests.
