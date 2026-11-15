# 034/035 completion review — HOLD, no execution

## 034 revenue

Depends on baseline 010, corrected 014_v2 promotion_drafts (not original 014 followed by v2), 022 business organisations and held 032 MFA administrator helper. Adds plan catalogue, package requests, immutable campaign review snapshots, audit events and a test-only commission ledger. No existing migration, policy, source record or business ownership is overwritten.

Clients read their own requests/events/ledger; only server-approved MFA administrators may read review queues. No direct client mutation grants. RPCs derive ownership, check business/draft owner, serialize requester quotas, bind idempotency keys and require revisions. Admins cannot approve their own requests. Approval records a review outcome only; no active subscription, paid entitlement, placement, charge or payout exists. Premium prices are NULL until approved; only existing free account tools are represented at zero. Trusted service-role ledger inserts have unique source references, bounded integer amounts and generated net values; rows are constrained test_only=true. UI never creates ledger entries.

Risks requiring staging tests: source ownership/closure changes, concurrent cancel/review, stale revisions, key reuse after campaign edit, attempted owner/amount forgery, administrator role/MFA revocation and inherited/default grants. Source foreign keys preserve history and can prevent hard deletion; no cascades or cleanup. Privacy, commercial pricing, entitlements, settlement/refund/reversal governance and provider signatures remain prerequisites for any future real revenue system.

## 035 notifications

Independent private table/function schema requires Auth. Source registration is limited to the installed, approved operational tables. Functions have empty search_path; source trigger helper is not client executable. Notification recipients are derived from the source records, not request parameters. Initiating actor is excluded. Unique source/recipient/revision prevents repeated trigger delivery; titles carry generic module/status metadata without private message bodies, addresses or financial values. Ordinary clients can SELECT own rows and call a max-50-ID own-read-status RPC only.

No email, push, publication or operation flags are enabled. Notifications are in-app metadata and not proof of payment or delivery. Trigger failures roll back the source transaction; validate every registered source and concurrent update before activation. No historical backfill is performed. A source installed after 035 needs separately approved registration through 035_registration_HOLD.sql; do not rerun the whole schema migration. Registration stops on an unexpected existing helper binding and does not override it. Inspect disabled trigger state separately rather than silently enabling it. Source-level spam/rate limits and notification retention need validation before production.

## Safe staging sequence — only after explicit approval

1. Verify connected reference equals the separate staging reference and differs from production. Do not print credentials. Snapshot staging and inspect actual source/function definitions/grants.
2. Obtain approval for exact dependency-complete files. Keep 024–033 HOLD unless individually approved. Never install original and replacement 013/014 together.
3. Apply 034 only after its dependencies; apply 035 after the approved operational branches. One transaction/file; stop at any error. Keep allow_requests=false and all operational flags false. No administrator membership, pricing or ledger rows seeded automatically.
4. Inspect all new RLS, grants, source trigger bindings and default/inherited privileges. Use two/three non-sensitive staging accounts for targeted ownership/denial/idempotency checks. Check rollback on notification failure and revision races.
5. Do not deploy the digital function. Its source now returns expires_at as well as expires_in. Validate Deno/runtime and matching client/server contract only after a separately approved deployment step, with DIGITAL_DELIVERY_ENABLED unset until security checks pass. Existing private Storage comes from held 020; no bucket/policy change is included here.

Rollback: keep gates false; revoke new RPC execution through reviewed changes, and disable new notification triggers only through explicit approved action. Retain requests, audits, reports and commission records. Do not drop populated objects or delete production data. No migrations, policies, deployment or live operations were executed in this sprint.
