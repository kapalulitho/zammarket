# Approved staging migration application — 30 October 2026

Applied only to the separate configured staging project through its authenticated Dashboard SQL Editor. Dashboard project reference matched VITE_STAGING_PROJECT_REF and differed from production. All six file SHA-256 hashes matched the reviewed manifest before loading; editor content was copied back and compared with each source (normalising CRLF only). No source changes or SQL guard bypasses. Existing production project/configuration/data/policies were untouched.

## Actual execution

In approved order, each file returned **Success. No rows returned** before the next was attempted:

1. `supabase/staging/000_empty_baseline_STAGING_ONLY_HOLD.sql`
2. `supabase/review/009_backend_setup_PENDING_APPROVAL.sql`
3. `supabase/review/010_profiles_registration_PENDING_APPROVAL.sql`
4. `supabase/review/012_message_trigger_fix_PENDING_APPROVAL.sql`
5. `supabase/review/022_business_foundation_HOLD_DRAFT.sql`
6. `supabase/review/023_stays_logistics_HOLD_DRAFT.sql`

No migration failed; no unapproved migration, rollback or cleanup script ran. The baseline creates new empty staging tables, not a data clone. Existing source HOLD filenames remain unchanged: 022/023 are now applied in staging only, still HOLD for production. Dashboard manual SQL is not automatically recorded as a Supabase CLI migration history; do not subsequently db-push/reapply these sources blindly.

## Native read-only verification passed

- 012 fingerprint normalisation matches the tested fix; both messaging triggers enabled.
- All 13 objects listed in 024 exist. All nine inspected tables have RLS enabled. Metadata contains 27 business/service/Storage policies. Stored policy/grant metadata is available in ignored `.validation/staging-installed-metadata.json` for review; metadata inspection is not a cross-account runtime pass.
- `business-media` private, 2 MB, JPEG/PNG/WebP. `business-service-media` private, 5 MB, same formats. Avatars public with 2 MB image limit; listing-images public with legacy null MIME/size limits, as reviewed.
- Business and service publication flags both false. Public business/service views contain zero rows. No scheduler table `cron.job` exists.
- Authenticated clients lack membership insert/update, business delete and enquiry update grants. No unconditional raw-profile read policy found.
- Real staging Auth settings reachable; email/confirmation enabled, anonymous sign-in disabled. Anonymous zero-row product SELECT accepted; private profiles, messages, conversations and business/service tables deny unauthenticated requests. Initial remote script labelled HTTP 401 generically; this was access denial with a working publishable key, not an invalid-key finding. Diagnostic labels corrected locally.
- Real app at `http://127.0.0.1:5180`: staging banner visible, welcome/signup pages load, feed completes with a genuine empty state, guest direct `/business` redirects to Sign In. Existing homepage/service icons remain present.
- 81 local tests, lint and production build passed after the diagnostic update.

## Pending native validation and security issues

No staging test account/password/OTP was entered by the agent. Signup delivery, verified profile persistence, logout/recovery, product ownership writes, real participant messaging, business/branch/room/service save-refresh-edit and native signed media upload/expiry need test-account participation. A/B are needed for ownership; a nonparticipant identity is needed for private conversation denial. SQL metadata and prior disposable role tests do not replace those tests.

Known issues remain pending separately: public likes exposes identity/activity; listing-images lacks bucket MIME/size limits; public avatar/legacy product files are not private just because listings have RLS. Browser signature validation does not establish trusted server scanning. Previously issued media signatures can survive until their short expiry. Staff roles confer no old listing/message rights; invitations/delegation are not activated.

Both publication gates stay false. Private enquiry drafts against unpublished offers must be rejected. Testing successful draft creation/public projection needs separately approved synthetic staging publication; do not open these gates merely to make a test pass. No real bookings, payments, dispatch or automatic cleanup activated. No test data deletion authorised.

## Next user step

The real staging signup page is open. Register a staging test account with an inbox you control and enter password/code privately. Existing production accounts are not copied here. Report only whether the code arrives / profile setup opens, or the exact non-sensitive error. Do not share credentials/codes. Continue the native checklist in STAGE4_STAGING_RUNBOOK.md once signed in; avoid claiming unperformed checks passed.

Evidence: `.validation/staging-application-record.json` (ordered hashes and results), `staging-installed-metadata.json`, `staging-after-setup.json`, remote readiness log and `staging-live-home.png`. No secret values are stored in those evidence reports. New 026_after_setup_READ_ONLY.sql contains only read-only verification, not another migration.
