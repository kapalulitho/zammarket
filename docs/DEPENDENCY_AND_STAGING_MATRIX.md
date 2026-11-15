# Held migration dependencies and staging connection checklist

Stage 4 continuation: see `STAGE4_STAGING_RUNBOOK.md` and `STAGE4_PERSISTENT_BUSINESS_PROGRESS.md`. The staging-only business adapter is implemented, but no separate Supabase configuration or native evidence is available. 022/023 remain unchanged and HOLD; 024_business_READ_ONLY.sql is metadata inspection, not a migration.

29 October 2026 local development continuation. All files remain HOLD. No production database connection was used for tests, no migration was applied remotely, and no staging project was provisioned. This matrix updates dependency readiness without repeating prior full reviews.

| Draft | Technical prerequisites | Main boundary / remaining validation |
| --- | --- | --- |
| 013_v2 modules | Empty marketplace baseline, 009 and 010 helpers/Auth/Storage | Owner drafts, participant enquiries, private marketplace-media signing; native HTTP signing/expiry remains staging work |
| 014_v2 commerce | 009/010, UUID listings and membership helpers | Canonical public variants; immutable/revocable trusted receipts; purchase proof issuer still missing |
| 015 Property | 009/010 helpers and native Storage | Owner-only drafts, private saves/enquiries, property-media signing and >12-row pagination checks |
| 016 Delivery planning | 010 membership helper | Private customer/courier drafts only, not dispatch or verified providers |
| 017 Food | Existing member helper; no 013–016 DDL dependency | Server item prices, stock locks and idempotency; fulfilment/cancellation/refunds/fee workflow incomplete |
| 018 tickets | Corrected 013_v2 community_entries plus membership | Capacity locks/private reservations; issuance, expiry/refunds and concurrent stress tests incomplete |
| 019 Delivery operations | Existing member helper; independent of 016 planning schema | Service-only assignment, revision/role checks, private contacts; admin/dispute/proof workflows incomplete |
| 020 specialist catalogues | 009/010 profile/membership helpers, native Storage | Private previews/assets, publication gate FALSE; moderation, scanning, proof-based entitlements and mediated download endpoint not implemented |
| 021 discovery activity | Native Auth roles/PostgreSQL; no module table dependency | Private pseudonymous ledger and thresholded public aggregate projection; trusted consent-aware collector/rollup job not connected, publication FALSE |
| 022 business foundation | 009/010 membership helpers and native Storage | Owner-only organisations, reserved staff metadata, public opt-ins; publication FALSE. No implicit permissions over existing seller_shops/listings/messages |
| 023 Stays / Logistics | 022 plus membership helpers | Parent-gated service/room projections, author-only unsent enquiries, private media; both publication flags FALSE; no bookings or dispatch |

012 remains the existing messaging baseline; these drafts do not replace its function. Its operational prerequisite in earlier file headers should not be mistaken for a direct DDL dependency where no messaging object is referenced. Original 013/014 and v2 replacements are alternatives; never run both. Existing 013_v2–019 source files were not edited in this batch.

## Exactly what is needed to connect a separate staging project

1. A separately approved, empty/non-production Supabase project with a different 20-character project reference. No production data clone. If creation incurs expense, owner approval is required first.
2. Its project URL and **publishable** key entered privately in ignored `.env.staging.local`, copied from `.env.staging.example`. Do not provide secrets in chat or put service-role/database credentials into VITE variables.
3. Explicit staging mode/isolation acknowledgement; `npm run check:staging` must pass. The guard checks matching project reference/host, a different production origin and publishable-key format. It does not prove project ownership or remote key correspondence; confirm both in the staging Dashboard.
4. `npm run dev:staging` on port 5180. Missing configuration refuses startup, staging cannot fall back to production, sessions use a separate storage key and the STAGING banner must be visible.
5. Owner approval for exact staging SQL. Review `supabase/staging/000_empty_baseline_STAGING_ONLY_HOLD.sql` only for a brand-new project, then approved 009 → 010 → 012, followed by the applicable reviewed drafts. No automatic SQL runner is supplied. Stop on any object collision; do not drop/overwrite tables or buckets.
6. Separate test inboxes/accounts and non-sensitive fixture images/files. Configure Auth email confirmation/OTP template and redirect URLs only in staging. No production accounts/passwords/photos/messages may be imported.
7. Native validation described in ISOLATED_STAGING_SETUP.md and STAGING_VALIDATION_013_016.md: Auth/RLS across roles, Storage signing and expiry, file MIME/size, public projections, receipt identity, capacity/stock concurrency, idempotency and contact revocation. New gates remain FALSE unless separately approved for synthetic staging scenarios. No real operations are authorised.

No isolated configuration is currently available; `check:staging` reports NOT CONFIGURED. Local tests use in-memory PostgreSQL and a Vite mock on 5174, never the production SDK. Local passes are not a live staging pass. Update the staging evidence report with exact source hashes/results before any production approval request. Keep backups/rollback readiness and all operational blockers on the approval checklist.

## Core/business batch validation order

Keep 012–021 reviews and holds intact; 012 is the historical messaging baseline, not a prerequisite to every new table. Never apply original 013/014 together with replacements. 018 depends on corrected 013_v2; 019 operations does not automatically migrate 016 planning records. No cross-module backfills are authorised. 020 paid assets need mediated entitlement-bound downloads; 021 needs a trusted collector before rankings can claim real popularity. Existing 017–019 workflow completeness blockers remain.

After an approved empty staging baseline and 009/010/012, validate Auth refresh/recovery, two-account listing ownership and messaging first. Then test 022/023 with gates false: owner/other/anonymous reads, manager non-escalation, private contacts, tampered paths, oversized/disguised files, signing expiry, public view allowlists, room/enquiry constraints. Test gates only with synthetic fixtures and separate approval; disabling parent publication must hide services and stop issuing new media signatures. Keep future public publishing and staff permissions disabled until evidence is reviewed. Link 013 storefronts to organisations by an explicit future contract; do not create duplicate shops.
