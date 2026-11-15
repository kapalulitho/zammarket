# Remaining operational migrations 029–033 — staging review and installation

ALL HOLD. None has been applied. This document is not migration or activation approval. Production must remain unchanged. Existing 024/025 and 026–028 are preserved. Do not run every migration indiscriminately; 013/014 originals and v2 replacements are alternatives.

## Dependencies and separate approval units

| Draft | Required baseline and source contracts | Installation behavior |
| --- | --- | --- |
| 029_participant_workflows_HOLD_DRAFT.sql | 010 verified membership. Per-source: corrected 013_v2 for Jobs/Services/Learning; 015 for Property; 022/023 for Logistics; 020 for Agriculture/Digital | Creates shared private requests, events, messages, provider assets and per-kind settings. All seven request gates FALSE. Source tables are not duplicated. Missing source tables remain unavailable. |
| 030_accommodation_operations_HOLD_DRAFT.sql | 010 + 022/023 | Creates room-night capacity, reservation requests, events/messages and RPCs. Gate FALSE. Adds a room guest-capacity guard against lowering capacity below confirmed guests. |
| 031_event_operations_HOLD_DRAFT.sql | 010 + corrected 013_v2 + 018 | Adds attendance/audit tables, organiser category editing and attendance RPCs. Reuses existing holds/capacity. Does NOT change ticket-operation flag. Adds cancellation guard for checked-in reservations. |
| 032_admin_review_operations_HOLD_DRAFT.sql | 010 + 022 + held 024/025 | Creates private review cases/events and business verification decisions. Operations FALSE; no admin seeded. Updates report state only after an authorised explicit review action. |
| 033_digital_delivery_HOLD_DRAFT.sql | 010 + held 020 | Creates owner-private download audit and entitlement/scan/revocation/rate-check RPCs. No entitlements or purchases issued. Edge Function remains undeployed/disabled. |

## Exact staging-only procedure after explicit approval

1. Verify isolated project reference equals VITE_STAGING_PROJECT_REF and differs from production. Do not print keys. Preserve .env/.env.staging.local and original app configuration.
2. Review actual installed schema/functions and original-versus-v2 conflicts against the dependency matrix. Stop on partial source schemas, missing helper grants, old definitions or unexpected names. Take a staging backup/snapshot before approved installation.
3. Have the owner explicitly approve the exact files and dependencies. Do not infer that prior six-file staging approval covers these drafts. Preserve 024/025 HOLD unless separately approved for the admin branch.
4. In staging SQL Editor apply only approved dependency-complete files, one transaction/file at a time. Stop at the first error. Never wrap multiple scripts in an automatic retry or apply anything to production.
5. Inspect created functions, empty search_path, authenticated-only grants, denied direct writes and RLS after each file. Verify all operational settings remain false. No publication, administrator membership, dispatcher approval, scan approval or digital entitlement is implied by schema installation.
6. Use two verified, non-sensitive staging test accounts for essential participant/owner/denial checks. Test a third unrelated account, stale revisions, malformed inputs, lost responses/idempotency and concurrent allocations. These tests have NOT been performed yet.
7. Enabling even staging operations, provisioning an administrator, allowing publication or deploying the private-delivery function requires a separate explicit approval. Real payment, dispatch and production activation remain outside scope.

## Security review points

029 uses fixed, allowlisted source queries in a revoked private helper. Requesters cannot choose provider identity, status, quote or role; provider derives from an available source record. Request payload is bounded string data, never an uploaded CV/document. Keys are requester-scoped and payload-bound; quotas serialize per account. Status edges and actor roles live in a server-owned settings table. Quote acceptance is revision-checked. Appointments are dated communications, not exclusive time-slot reservations. Provider asset quantities are catalogue counts, not reserved inventory. Typed target IDs are polymorphic and validated on submission; source closure/deletion does not erase private history. Source functions/publication gates must be verified in staging, not merely table presence.

030 confirms one room per reservation request. It locks the room and all nights, validates full capacity, dates, guests and current subtotal, then increments every night atomically. Requests alone allocate nothing. Cancellation releases confirmed capacity once under revision lock. Owners cannot set capacity below reservations or lower guest capacity below confirmed occupancy. Public availability contains aggregate counts/prices only, never guest identities. Cancellation policy, early checkout, no-shows, taxes, deposits and hospitality terms remain business-policy work; no payment is handled. Test concurrent confirm/cancel/calendar/room edits. Owner calendar dates are inclusive; guest check-out is exclusive. Africa/Lusaka defines calendar boundaries.

031 reuses 018's allocated capacity and idempotent hold/cancellation logic. Category capacity cannot be below allocated units. Only the actual organiser may record attendance; counts cannot exceed the held reservation quantity. Attendance updates are revision checked and append audit events. A checked-in hold cannot be cancelled until attendance is corrected. This is not QR issuance, a paid ticket or a verified right of entry. No hold-expiry job is activated. Stress-test cancellation/check-in/category-change locking before approval.

032 requires current server membership, verified account, JWT MFA aal2 and the FALSE-by-default operations flag. No frontend role flag, self-grant, public report access or identity upload exists. Independent business review rejects the reviewer's own business and requires a matching verification report. Actions write audit records and requester-visible report state. Hide/restore actions are recommendations ONLY: source visibility-policy integration, public badge exposure and destructive enforcement are NOT implemented/activated. No private user directory or auth.users data is returned. Define retention, appeals, evidence access and incident response before activation.

033 authorizes only verified buyers with a non-revoked entitlement and scan-approved asset. Per-buyer serialization bounds authorizations to 30/hour; grant audit is private. Failed authorization raises and does not expose paths. Buyers have no entitlement issuance path. Private Storage rules from 020 remain owner-only; a server signing client is used only after caller-scoped approval. Malware scanning/approved purchase verification remain trusted external prerequisites, not frontend toggles. A revoked entitlement may leave a previously issued URL usable for up to 60 seconds; downloaded files cannot be recalled. Signed URLs are never logged or persisted by the new UI.

## Digital Edge Function: preparation only

Source: supabase/functions/digital-delivery/index.ts. Do not deploy yet.

After separate approval, deploy ONLY to the verified staging reference using normal JWT verification. Configure server-only secrets through staging dashboard/CLI: ZAMMARKET_ENV=staging, EXPECTED_STAGING_PROJECT_REF, STAGING_APP_ORIGIN (exact staging app origin), and platform server keys. Leave DIGITAL_DELIVERY_ENABLED unset/false until authorization tests pass. Never put service-role keys in VITE variables or chat. The function refuses the original production reference, foreign origins and unapproved enablement; validates caller token and bounded asset-only body, checks authorisation, signs only the fixed private digital-products bucket for 60 seconds and returns no-store responses. No deployment or secrets were configured in this batch. Deno/runtime checks are still required.

## Rollback and data safety

New objects only, except the specifically listed new guards and explicit review-state updates after future authorised actions. No existing migration files or records were rewritten by this batch. None of the new FKs cascades deletion. Retain historical request/attendance/review records. For rollback, keep gates false, revoke new RPC execution in a separately approved migration and preserve data; do not drop populated tables. New guard behavior and source-view/RLS compatibility need staging validation before production consideration.
