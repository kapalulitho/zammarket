# Stage 1 verification — 29 October 2026

Stage 2 has not started. No live records or policies were changed by the agent. The user is exercising their dedicated test account and entering credentials/codes privately.

## Results so far

| Check | Result | Evidence / limit |
| --- | --- | --- |
| Real signup email | User-confirmed pass | User reported receiving the six-digit email. Inbox was not independently accessed. |
| Account creation | User-confirmed | User reported already creating the test account. Exact OTP submission was not observed by the agent. |
| Session refresh | User-confirmed pass | Refresh opens HomeFeed, still signed in. |
| Saved profile fields | User-confirmed pass | Username, shop name, account type and previously entered optional details all correct after refresh. |
| Live avatar save/display | User-confirmed pass | Save succeeded; avatar remains visible after refresh. |
| Live logout | User-confirmed pass | Logout and refresh show welcome only. |
| Live email-code login/recovery | User-confirmed pass | User reported sign-in email arrival, then confirmed submitting the code restored HomeFeed, saved profile and avatar. No password change was performed. |
| Two real authenticated accounts | Pending | Needs a second dedicated account and targeted test records. No authenticated HTTP write-isolation claim is made yet. |
| Live Auth settings | Pass, GET-only probe | Email enabled, signup enabled, mailer_autoconfirm=false. |
| Anonymous private-table access | Pass, GET-only probes | marketplace_profiles, messages, conversations return HTTP 401 / SQLSTATE 42501. Limit-zero requests prove denied table access, not signed-in row isolation. |
| Anonymous public listings | Pass | marketplace_listings responds HTTP 200; only limit-zero request made. |
| Mobile layout | Pass for checked isolated screens | 320 px profile/edit, messaging empty state and posting form; 360 px feed. No page-wide horizontal overflow; feed has two columns and visible bottom navigation. Uses simulated data, not live writes. |
| Isolated avatar/profile | Pass | Existing non-sensitive app icon selected, previewed and saved through mock client; avatar, location and visibility persisted after refresh. This does not prove actual Storage permissions. |
| Isolated recovery/logout | Pass | Logout returns welcome; email-code fallback accepts synthetic code and opens HomeFeed. No real recovery email/password update was performed here. |
| npm test / lint / build | Pass | 34 unit tests; clean lint; production build succeeds. |

## Backend defect discovered

Expanded disposable-database tests reproduce a failure with the exact original 009+010 scripts. `marketplace_message_membership_guard` uses boolean AND conditions that access NEW.sender_id and NEW.buyer_id across two different table record shapes. PostgreSQL can resolve a nonexistent record field before short-circuiting. A valid start_conversation call fails with SQLSTATE 42703; message inserts are affected by the same shared-trigger pattern.

Earlier checks contained a malformed full-schema message insert that could fail for the wrong reason. The regression harness now uses correct columns/RPC signatures and checks the intended error messages. The earlier simple pass is not sufficient evidence for working chat.

Proposed correction: `supabase/review/012_message_trigger_fix_PENDING_APPROVAL.sql`. It replaces only this function body, using separate IF/ELSIF branches before field access. It preserves verified-profile checks, buyer/sender identity checks, SECURITY INVOKER and empty search_path. CREATE OR REPLACE preserves the existing function identity and ACLs. No table, policy, grant, row, photo, account or cleanup job changes are included. A brief function lock is possible; failure aborts its transaction. Requires approval before live application.

`node scripts/validate-profiles.mjs --full --with-trigger-fix --audit` passes locally with proposed 012: two completed accounts can exchange messages; spoofed senders and a nonparticipant are rejected; private profiles, owner RPC management and avatar isolation remain protected. The original `--full` without the correction now intentionally exposes the discovered regression. The local database is disposable and never connects to Supabase.

## Remaining security review

- Public likes expose user/listing identifiers. Recommend private saved-product records and public aggregate counts only, subject to separate policy/schema approval.
- Last supplied listing-images bucket settings have no MIME/file-size restrictions. Frontend validation is bypassable by custom clients. Review server-side limits separately; do not remove existing images.
- Avatars are intentionally public; public image retrieval is not a privacy failure. The important boundary is owner-only upload paths and blocked overwrite/delete, covered locally but not yet with two real sessions.
- The user supplied the deployed 011 catalog report. RLS is enabled on all six checked tables; profiles have owner-only SELECT and no direct write grants; messaging reads are participant-only and inserts validate sender membership. Direct listing update/delete grants are absent, so the older owner policies do not enable bypassing the owner RPCs. Restrictive Storage guards constrain the retained legacy permissive upload policy. All five expected custom triggers are enabled. Anonymous execution is denied for the checked private/mutating functions; zammarket_features is intentionally public. Listing count remains four. These findings establish deployed configuration, not a substitute for live cross-account behavioural tests.
- The user approved and reported successfully applying 012. The follow-up catalog fingerprint 8f359cb0a0f8ce17ae4f45e7ba32cfed exactly matches the tested correction stored with Windows CRLF line endings. The initial verifier expected LF only and falsely reported matches_tested_fix=false. Local reproduction confirms the difference is solely line endings; the read-only verifier and emergency rollback guard now normalize CRLF to LF, with regression coverage for both. Permissions remain SECURITY INVOKER, empty search_path, no anon/authenticated direct execution and two enabled triggers. The correction is deployed per the supplied catalog report; real two-account messaging remains pending. No second live migration is needed.
- Live reads used only publishable configuration, GET, and limit-zero table requests. No sessions or service credentials were read or printed.

## Safe remaining sequence

1. Completed: user-confirmed test-account email-code login. Keep passwords/codes private. Password change, if tested, must be entered and submitted by the user.
2. Completed: supplied read-only catalog report reviewed against expected RLS/grants/triggers and the defective function fingerprint.
3. Completed: approved 012 applied by user and identified in the supplied catalog report (CRLF fingerprint). Rollback/reapply, metadata and unchanged RLS checks pass locally for LF and CRLF. Do not rerun the migration.
4. Use two dedicated accounts in separate browser sessions, non-sensitive profiles/avatar/listing/chat fixtures only; test owner changes, non-owner denial, and private-contact visibility. A third nonparticipant or anonymous session is required to prove that an unrelated person cannot read the conversation between those two accounts.
5. Preserve existing data/photos and keep automatic cleanup inactive. Report remaining limitations before closing Stage 1.
