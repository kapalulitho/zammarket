# Remaining major systems — connected operational implementation

30 October 2026. Original ZamMarket React/Vite/Supabase project preserved at C:\Users\kapalu\Documents\ZamMarket. Main app http://127.0.0.1:5173/home. No replacement application, production changes, applied migrations, deployment, real payments, public bookings, privileged activation, data deletion or automatic cleanup. Existing 026–028 and held 024/025 are unchanged.

## Systems built in this pass

### Jobs and recruitment

Job Operations links existing job posting/owner editor to a new private applicant/employer workflow. Applications carry bounded note/skills/experience text; employer dashboard supports review, shortlist, interview scheduling, offer and rejection, with requester acceptance/withdrawal. Actual participants alone read messages and audit/status history. No CV/identity upload, automated hiring decision or private account-profile/email exposure.

### Property operations

Landlord/agent dashboard connects existing Property editor to viewing/rental enquiries, contacted/viewing-scheduled/viewed/closed states, appointment times and participant messages. Property and Accommodation remain distinct. Scheduled viewings are communications rather than exclusive resource reservations; payment, tenancy agreements and signing are not implemented.

### Logistics operations

Provider dashboard connects business-service listings to freight requests, origin/destination/cargo requirements, ZMW quotations, requester acceptance, schedule/in-transit/delivered states and private communications. Vehicle/facility resources have owner-controlled private catalogue records. Status is provider-recorded, not GPS or dispatcher/courier assignment. No real dispatch or fares are activated.

### Learning

Existing course/tutor creation connects to instructor/requester dashboards, enrolment offers/acceptance, provider enrolment and completion, private messages and learner-owned percentage progress. Course resources have saved private metadata. Progress is self-reported, not an assessment, certificate or automatic access grant. Actual course delivery remains a separate secure-content integration.

### Agriculture

Farmer/supplier catalogue now has a saved staging editor using existing 020 specialist tables, with listed quantity, price/unit, categories and non-destructive closed/draft states. Bulk/agricultural-service requests connect quotations, customer acceptance, preparing/ready/fulfilled and messages. Resource inventory is private and does not reserve stock or decrement against a request. These are operational requests rather than guaranteed paid allocations.

### Professional services

Provider-owned source profiles/listings connect to scoped customer requests, quotations, acceptance, appointments, in-progress/completed states and messages. Existing listing editor is reused. Exclusive provider time-slot allocation, verified credentials and real payment processing are not enabled.

### Accommodation

Host dashboard manages existing room options and nightly calendar capacity/pricing. Guest requests use actual stored calendar data. Host confirmation atomically checks and allocates every night under locks, preserving quoted subtotal and guest capacity. Cancellation is revision-safe and releases confirmed room counts; check-in/check-out transitions and guest/host conversations have stored audit history. Availability returns counts/prices only. One room per request, maximum 60 nights, Zambia calendar dates. Hotel profiles/branches reuse existing business tools; no simulated availability is presented as live.

### Events

Existing event creation connects to organiser category/inventory management and attendee reservations using 018 contracts. New organiser-only attendance counts have revisions and audit events; counts cannot exceed reservation quantity. Capacity below allocated units is rejected. Attendance must be corrected before cancelling a checked-in hold. No QR codes, paid tickets or automated hold-expiry jobs are issued.

### Digital Products

Saved seller catalogue and private file-version management are implemented using existing 020 tables/Storage. Uploads accept bounded PDF/ZIP with type/header checks and remain scan-pending; no seller scan approval or buyer entitlement creation exists. Buyer library lists only eligible approved/non-revoked purchases. New authorization/audit RPC and undeployed staging-only Edge Function validate entitlement and scan status, then issue a 60-second private URL. Frontend validates destination and downloads without retaining the signed URL. True malware scanning, trusted purchase verification and deployment are still external approval/configuration requirements.

### Administration

Protected review queue supports report triage, request-information/escalation, case closure/reopening, independent private business verification decisions and append-only audit notes. Server checks approved membership, verified user, MFA aal2 and explicit disabled-by-default operations flag on every action. No administrator is provisioned. Hide/restore decisions are recommendations only; public visibility enforcement and public verified badges are deliberately not claimed as implemented. Account deletion/suspension and other destructive enforcement remain outside this batch.

## Shared architecture

Seven distinct server-owned transition graphs share participant request/event/message tables and provider assets, avoiding seven duplicate systems. Source ownership is derived from existing community/property/business/specialist records and appropriate publication gates. Quotes, appointments and participant roles are revision-checked. Each operational route remains inside the original app and is private. New clients reject production before network requests and revalidate identity before operations. Source editors and Business/Explore/service navigation are reused. New pages load in separate bundles; the approved homepage and compact category grid are preserved.

## New backend drafts — ALL HOLD

- 029_participant_workflows_HOLD_DRAFT.sql: Jobs/Property/Logistics/Learning/Agriculture/Services/Digital participant operations.
- 030_accommodation_operations_HOLD_DRAFT.sql: calendars, requests, host allocation, audit and communication.
- 031_event_operations_HOLD_DRAFT.sql: inventory owner editing, attendance and cancellation guard.
- 032_admin_review_operations_HOLD_DRAFT.sql: MFA-controlled private case and verification review.
- 033_digital_delivery_HOLD_DRAFT.sql: buyer authorization, private grant audit and eligible library.
- supabase/functions/digital-delivery/index.ts: source only, not deployed or enabled.

Exact dependencies, risks and staging installation steps: supabase/review/029_033_STAGING_REVIEW_AND_INSTALL.md. Separate approval is needed for schema installation, operation enablement, admin provisioning, publication and function deployment. No prior approval is assumed.

## Validation and honest current state

Four focused tests passed: seven workflow role/state graphs and payload allowlisting; production/stale-account denial before RPC; Zambia stay boundaries; signed-download destination and file-header validation. Lint passed. Production build passed after integration. No comprehensive test stage, SQL runtime execution, end-to-end persistence, load/concurrency, live multi-account, Deno execution or digital download test was performed. JavaScript checks do not establish that SQL security or actual hosted operations work.

These are connected frontend/backend implementations awaiting reviewed staging installation, not activated production services. Their new tables/functions are not present merely because the app compiles. Existing Shopping/Food/Delivery operational code and all established live functionality remain preserved. The actual next blocker is approval and isolated backend execution/validation.

## Files

New helpers: src/lib/workSystems.js, workRepository.js, capacityOperations.js, digitalDelivery.js.
New components: src/components/WorkOperations.jsx, CapacityOperations.jsx, DigitalLibrary.jsx, AdminReviewOperations.jsx, SpecialistManager.jsx.
New tests: tests/workSystems.test.js.
New migration/function/review files listed above.
Updated integration: src/App.jsx, src/lib/routes.js, src/business-foundation.css; BusinessWorkspace.jsx, ModuleMarketplace.jsx, PropertyMarketplace.jsx, BusinessServiceDirectory.jsx, LocalVerticalMarketplace.jsx, AdminFoundation.jsx under src/components.
Documentation: this report; NEXT_BATCH_PROGRESS.md.

## Remaining work before real operation

Approve and install only dependency-complete staging branches; test unrelated-user denial and ownership, concurrent allocations/cancellation, stale revisions and interrupted responses. Keep production untouched and every operational flag false until separately approved. Complete quote expiry, exclusive appointment/stock allocation where required, course content access, real digital scanning/purchase verification, authenticated dispatch/GPS, ticket issuance, public moderation enforcement, appeals/privacy/retention and legally reviewed business terms. Payments and real-world integrations remain separate. This report does not claim that every production system is finished or launch-ready.
