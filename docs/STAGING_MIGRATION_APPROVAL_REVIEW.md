# Staging migration review and native validation readiness

29 October 2026. Review only; no SQL or security policies applied. Exact source hashes are in `.validation/staging-migration-manifest.json`, refreshed with `npm run prepare:staging` (local preparation only). 022/023 remain HOLD for production. Do not treat past approval of 012 on another project as staging approval for this batch.

## Remote evidence

Read-only requests using only the configured staging publishable key reached Auth settings with HTTP 200. Email enabled; confirmation required; anonymous sign-in disabled. This is actual endpoint evidence, not signup/email-delivery evidence. No account or Auth session was created. Nine zero-row REST table probes returned 404/not exposed or missing. No record bodies were retrieved. This is consistent with an uninstalled schema but does not establish an empty database or verify RLS.

The initial network-sandbox attempt failed; the same bounded read-only check succeeded with network access. No TLS bypass was used. The script logs only check names/statuses, writes redacted evidence to `.validation/staging-remote-readiness.json`, and refuses production configuration. It does not send SQL or start sessions. `npm run check:staging:remote` is an opt-in repeat, not polling.

## Exact proposed order, impact and risks

| Order / source | Proposed changes | Main approval considerations |
| --- | --- | --- |
| 1. staging/000_empty_baseline_STAGING_ONLY_HOLD.sql | New listings/likes prerequisite tables with Auth foreign keys, RLS and revoked client grants; listing-images bucket | Brand-new empty staging only; table/bucket collisions must stop. Bucket intentionally matches legacy public/unlimited configuration; native validation must track this known weakness. No production use |
| 2. review/009_backend_setup_PENDING_APPROVAL.sql | Listing availability/revision/soft-delete/photo-metadata columns and view; owner/management/conversation helpers; conversations/messages tables, participant RLS and restricted grants; Storage path guards and likes policies | Contains 001/008/004; do not run those again. Changes staging grants/policies, including public likes visibility. Allows controlled owner deletion of unused images, but no scheduled photo deletion/job is activated. Known public-likes exposure and legacy file limits remain pending separately; synthetic data only |
| 3. review/010_profiles_registration_PENDING_APPROVAL.sql | marketplace_profiles, username uniqueness/profile-save/public-contact helpers, verified/completed membership guards for listings/messages; avatars bucket and scoped policies | New private contact data and controlled public projection; avatar bucket is public by design, so test images must be non-sensitive. No business staff access is implied. Native Auth/Storage evidence required |
| 4. review/012_message_trigger_fix_PENDING_APPROVAL.sql | Replaces only marketplace_message_membership_guard after exact prior-definition guard | Requires 010 and messaging baseline; separates different NEW record shapes. No permissions/rows changed. Stop on guard mismatch; never remove guard. Existing rollback file restores the prior faulty function and must not be run routinely |
| 5. review/022_business_foundation_HOLD_DRAFT.sql | Business settings, organisations, reserved staff metadata, branches; owner guards, public opt-in projections; private 2 MB business-media bucket/scoped policies | Requires verified membership helpers; publication false. No existing account/profile/shop/listing migration or delegation. Native view ownership, cross-account isolation and signature expiry need validation |
| 6. review/023_stays_logistics_HOLD_DRAFT.sql | Business services, room descriptions/prices, private unsent enquiry drafts, public gated views and private 5 MB service-media bucket | Requires 022; publication false and parent-gated. No room availability, real bookings, enquiry submission or dispatch. Drafts require already published offers, so successful draft tests need separate approval for synthetic staging publication |

No 013–021 dependency is needed for this narrow business test baseline. Do not apply original/v2 alternatives or all held migrations automatically. Current sources do not reassign/delete existing application rows; nevertheless this is a NEW staging baseline, not an upgrade plan for an unknown populated database. Some functions permit user-initiated listing management and image deletion when called later; no such actions are authorised/executed by the connectivity probe.

Each file is transactional with timeout limits. Failure before commit rolls that file back; earlier committed files remain installed. Before execution capture project identity and preflight metadata. No automatic destructive rollback: preserve records/buckets, close new UI/publication and prepare a reviewed forward correction. Do not drop schema or restore the broken 012 trigger as a general recovery tactic.

## Next read-only step before approval

In the staging project SQL Editor run `supabase/staging/025_before_setup_READ_ONLY.sql`. It lists public relations/application helpers/buckets/policy names without row data. It changes nothing. Confirm there are no application object collisions before approving the exact ordered files. The 404 API probes cannot replace this privileged metadata inventory. No administrative Supabase connector/database credential is available to run it automatically here.

## Prepared validation sequence after separately approved setup

1. Run 012_verify_READ_ONLY.sql and 024_business_READ_ONLY.sql; verify RLS, exact grants/functions, private business buckets/limits and both false publication flags.
2. Test signup/OTP, resend/error handling, completed profile, refresh, recovery and logout using staging inboxes; do not log passwords/codes or claim delivery from Auth settings alone.
3. A creates a synthetic product and B enquires; verify own/foreign edit and participant messaging. Testing private-message visibility also needs a nonparticipant session/account; B is not an outsider to A/B's own conversation. Verify unauthenticated denial separately.
4. A creates business/logo/branch, stay/room and logistics/service areas; save, reload, edit and reload again. B must not read raw private contacts or alter A's rows, spoof owners or grant itself staff access.
5. Test native file limits/MIME/path ownership, own signing versus foreign/anonymous denial, no overwrite/delete, and actual 60-second signature expiry. Browser signature checks are not trusted server scanning. Preserve uploads; no cleanup is authorised.
6. With gates false, public business/service views should be empty and enquiry creation against unpublished offers rejected. Keep success/public projection/revocation tests pending unless synthetic staging publication is separately approved. No payments, bookings, dispatch or automatic cleanup.

See STAGE4_STAGING_RUNBOOK.md for detailed actions. A second controlled inbox is still needed for real cross-account signup; a third test identity is needed for nonparticipant privacy evidence. No request to create these accounts has been executed. Local automated SQL/adapter tests do not substitute for this native evidence.
