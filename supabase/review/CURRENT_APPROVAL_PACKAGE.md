# Current approval package

> Status update — 17 November 2026: the user ran and confirmed the following live.
> Do not rerun these files.
> - 042_public_seller_profile_anon_PENDING_APPROVAL.sql — applied; anon RPC verified
>   returning 200 (null for unknown ids). Guest seller profiles verified in-browser.
> - 014_stage3_commerce_PENDING_APPROVAL.sql — applied; stage3_commerce_capabilities
>   verified returning inventory/verified_reviews/advertising_drafts = true.
> - 012_message_trigger_fix — already present in the live function definition
>   (separate tg_table_name branches, SECURITY INVOKER). The 012 script's guard
>   correctly refuses reruns; treat as applied.
> Note: no "022b" file exists in this folder; 022_business_foundation_HOLD_DRAFT.sql
> remains unreviewed (HOLD) and references a business-media bucket that must be
> provisioned before any application.

> Deployment update — 29 October 2026: the user approved and reported successfully
> applying 009 and 010, with follow-up catalog checks confirming their main objects.
> Do not rerun these migrations. The sections below are historical review material;
> they do not authorise deleting accounts, listings or photos. The latest master
> instructions require preserving existing data. Automatic cleanup remains inactive.
> See docs/STAGE1_REVIEW.md for current findings and remaining live testing.

> Follow-up: expanded messaging tests found a defect in the 010 shared messaging
> trigger. 012_message_trigger_fix_PENDING_APPROVAL.sql is a separate, unexecuted
> correction. See docs/STAGE1_VERIFICATION.md; do not infer that the earlier
> local pass established working live chat.

Supersedes earlier ownership-repair and photo-deletion proposals. Do not apply those.

## Investigation results

Fresh public read-only Supabase requests confirmed the exact four test listing IDs,
their original titles, active statuses, NULL ownership, and the Hotel photo reference.
Storage listing confirmed exactly two root-level JPEGs, each 1,730,744 bytes. Comparing
their public contents by SHA-256 confirmed identical bytes. This does not establish
their origin or authorize removing either file. BOTH are preserved.

The user's read-only database report found zero target likes, no listing triggers or
rules, and only the likes FK (ON DELETE CASCADE) referencing listings. There is no
administrative Supabase connector in this session. These catalog findings came from
the supplied report, not a claimed new administrative database execution. The final
deletion script rechecks assumptions at execution and aborts if they have changed.

## A. Listing-only deletion: requires final review before execution

Exact file: `06_delete_test_listings_PENDING_APPROVAL.sql`.

| ID | Title |
|---|---|
| ce820419-6143-4cbe-8c80-f487e7692d52 | exercise books |
| 79e8ecb3-03a7-442e-8db2-d6cc6098107d | Smartphone |
| 5dab608c-f239-4ae8-bf77-c7522eca6bb3 | hotel |
| 30ddb257-2649-46ab-b121-a3ff28698ee0 | watch |

The DELETE targets only these IDs after checking all four titles, active/unowned state,
no likes, no custom triggers/rules, and no unexpected incoming relationships. Short
table locks prevent concurrent changes during validation and can briefly delay writes.
Any failed check aborts the transaction. After commit, restoring records needs a backup
or prior export. No user account, Storage object, bucket, or policy is changed.
Offer a read-only export before deletion. Apply BEFORE package B: the new security
triggers would intentionally cause this old-schema deletion guard to stop.

## B. Backend/security setup: requires approval of live permission changes

Exact file: `009_backend_setup_PENDING_APPROVAL.sql`.

One transaction combines core availability/messaging, ownership hardening, and Storage/
like policies. Do not also execute 001, 008, or 004 individually. No cleanup worker,
cleanup functions/settings, scheduler, photo deletion, or ownership repair is included.
Earlier 002/003 automatic-cleanup proposals are not part of the current rollout.

- Public SELECT continues for non-deleted listings; sold/unavailable/coming-soon
  listings remain visible. Owners may also read their own soft-deleted rows.
- New inserts require a signed-in caller. Both user_id and seller_id are assigned and
  validated from auth.uid(); neither can subsequently be reassigned.
- Separate column grants AND table grants are reset. Direct listing updates/deletes
  are disabled; authenticated owners use manage_listing for edits/status/soft deletion.
- Availability is computed at read time using Africa/Lusaka calendar dates. It never
  expires a listing. Seller overrides have priority over the date.
- Conversation membership and sender identity are enforced by RLS. User email is not
  exposed in public seller pages or conversation records. No Realtime setup is needed.
- Storage uploads are restricted to the caller's folder; overwrites are blocked.
  Browser deletion of another seller's files or referenced photos is denied. Existing
  public photo reads remain. No existing files are moved or backfilled.
- Existing restrictive policies may still prevent an intended action; no old policies
  are blindly deleted. Old clients that depend on direct listing update/delete will
  need to use the new RPC. Administrative inserts without a user JWT will be rejected.
- New conversation foreign keys can block deleting participating auth accounts. This
  deliberately preserves conversation integrity; a future account-deletion workflow
  needs a separate design. No existing auth account is modified by this setup.
- Status constraints can reject pre-existing unexpected status values. Current four
  reported rows are active. Recheck if new rows are added before applying.

Bucket MIME/size settings are unchanged. Separately approve a 5 MB JPEG/PNG/WebP bucket
limit to enforce the frontend validation at Storage level as well. Service credentials
must remain server-side. No secret values are requested or stored in these scripts.

## Safe local work completed

Posting verifies the current account with getUser before uploading, validates fields,
sets both owner IDs, and saves public image references. Selected files have preview/
remove controls, signature/MIME/size checks, and safe generated extensions. In-flight
posting prevents changing selected photos. Failed posts preserve uploaded files;
there is no automatic frontend Storage removal. Legacy single-photo fields display.

Added location/status filters, newest-first feed, seller listing pages, public display
name editing, and useful no-photo placeholders. Existing login, categories, messaging,
status/date controls, and My Listings remain; new backend-dependent functionality stays
gated until the approved setup exists. Public display names are presentation only,
never an authorization source, and name changes apply to new listing snapshots.

## Testing and remaining validation

Unit tests cover availability midnight/indefinite behavior, file signatures, invalid
files/fields/prices/dates, legacy photos, and the inactive cleanup engine's safeguards.
The disposable PostgreSQL harness applies the EXACT unified setup and tests anon,
seller, buyer, and nonparticipant roles, independent column grants, automatic ownership,
spoofed IDs, immutable ownership, owner management, messaging privacy, and date logic.
It also separately exercises the historical disabled cleanup proposal locally only.

Live authenticated posting, email delivery, real two-account messaging, and actual
Storage permission enforcement need a Supabase staging environment AFTER approval.
No live write tests are claimed. Browser smoke checks cover the real read-only feed,
new filters, empty-state reset, mobile navigation, and signed-out login/post pages.
No Storage deletions or live migrations have been executed.

## Local backup

A fresh read-only export of the four test listing rows was saved under backups/ before
any deletion. It contains no API keys or session credentials and is ignored by Git.
Both Storage objects remain on Supabase; no photo backup was needed to authorize
removal because no photo removal is currently proposed.

Final checks passed: 14 unit tests, clean lint, production build, and four disposable
PostgreSQL combinations (UUID/bigint IDs and text-array/JSONB photo columns). The local
Vite server remained reachable at http://127.0.0.1:5173/. Mobile checks used 390px width;
the temporary viewport was reset afterward. Real signed-in flows were not tested live.

## Additional pending registration/profile migration

010_profiles_registration_PENDING_APPROVAL.sql adds mandatory reviewed profiles,
case-insensitive unique usernames/shop names, owner-only private fields, filtered
public seller contacts, verified/OTP profile completion, and an avatars bucket with
own-folder upload policies. It adds membership triggers but performs no data deletion
or old-user backfill. Review 010_profiles_preflight_READ_ONLY.sql first. Live Auth
settings currently auto-confirm email; enable Confirm email and token templates before
rollout. See docs/REGISTRATION_PROFILES.md for exact findings and required dashboard
steps. No approval is inferred for any live migration from local implementation work.
