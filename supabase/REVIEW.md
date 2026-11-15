# Supabase approval package — nothing applied

## Approval boundaries

These scripts are deliberately stored in `review/`, not `migrations/`, so a normal
`supabase db push` cannot accidentally apply them. Review the actual project schema,
make a database backup, and validate in a separate Supabase staging project before
applying approved scripts. No live credentials, settings, policies, records, objects,
Edge Functions, or scheduled jobs have been changed by this implementation.

1. Run `review/preflight.sql` in the dashboard. It is read-only. Check column types,
   defaults, existing constraints/triggers/policies, unowned rows, and bucket settings.
   The draft expects `user_id uuid`, `image_urls text[]` or `jsonb`, ordinary text
   listing fields, numeric price, and an ID castable to text (UUID/bigint work).
   Ensure no new column, view, function, table, constraint, or policy names collide.
   Existing unowned listings are preserved and cannot be claimed from the browser.
2. Approve and apply `review/001_marketplace.sql`: additive listing fields, a
   security-invoker status view, private messaging tables, owner-management RPC,
   RLS guards, and least-privilege grants. Existing listings become active with
   no availability date. Nothing expires or is removed by the availability date.
   Direct listing update/delete grants are revoked in favor of the owner-checked
   RPC. Existing policies stay in place but new restrictive guards limit them.
   Review old SECURITY DEFINER functions separately: their privilege bypass could
   otherwise undermine table policies. Existing restrictive policies can still
   deny intended actions and must be reviewed, not blindly removed.
3. Approve and apply `review/002_photo_cleanup.sql`: service-only cleanup RPCs and
   configuration. Cleanup defaults to **disabled**, with a fixed **7-day** recovery.
4. Approve and apply `review/004_storage_and_likes_policies.sql`: owner/folder
   upload policies, no overwrites, unreferenced-owner-only browser photo deletion,
   and owner-only like writes. Existing public image reads are preserved. Verify
   `listing-images` is public and has the correct read policy. Set bucket limits
   to 5 MB and JPEG/PNG/WebP only after separately approving those setting changes.
   Verify existing likes uniqueness/defaults and sequence privileges from preflight.
5. Deploy the function and schedule only after the separate destructive approval below.

## Availability semantics

`status` is active, sold, or temporarily_unavailable. `available_from` is a calendar
date or null (Available Now). The security-invoker view computes Coming Soon only
when the date is later than `(now() at time zone 'Africa/Lusaka')::date`; otherwise
it computes Available. Seller-set Sold/Temporarily Unavailable override that result.
There is no expiry timestamp or availability job. A listing stays Available for
all subsequent days/months/years. The frontend synchronizes its clock from the
server every minute and recalculates visible labels every second, including after
focus returns. No seller login or visit is required for database status correctness.

## Messaging and My Listings

The server chooses the seller from the listing; a buyer cannot supply another seller.
Only the buyer and seller can read the conversation or send a message. Senders
cannot impersonate another user. Conversations and messages cannot be edited or
deleted by browser clients. Listings are soft-deleted by the seller, preserving
message history. Text messages poll every 5 seconds while the screen is open;
Realtime configuration is not needed. Latest 100 messages load first, with Load
older messages available. No email/push notification service is configured.

My Listings supports metadata/date edits, Sold, Temporarily Unavailable, restoration,
and soft deletion. Revision checks prevent silent overwrites from stale tabs.
Restoring a sold listing before cleanup begins cancels its pending photo cleanup.
Marking it sold again starts a fresh seven-day period. Editing an already-sold
listing does not reset the recovery timer. Photos already removed are not recoverable.

## Destructive operation requiring separate approval

The worker permanently removes **only tracked Storage photos**, using the Storage
API, once Sold has lasted at least 7 x 24 hours. Soft-deleted listings have the same
7-day grace period. It does not remove listing records, messages, likes, or accounts.
The selected availability date never triggers photo deletion.

Before deletion, the database claims the listing and blocks seller changes. This
prevents a restore/delete race. The worker validates paths under the listing owner's
folder, deletes at most five files per listing, then clears image references and
records completion. Claims retry after ten minutes using the same token; operations
and worker execution are time-bounded below that lease. Partial failure keeps the
claim locked to prevent restoring partially deleted photos; check function logs and
retry rather than manually unlocking it. After successful cleanup the seller can edit
the listing again. Running cleanup twice is safe. Shared paths between listings are
rejected. Legacy photos have no tracked `image_paths` and are **excluded**: do not infer
paths from arbitrary URLs or delete legacy root-folder files. A verified owner/object
mapping and separate approved backfill are required to include older photos.

Deployment/configuration steps (not performed):

- Deploy `functions/cleanup-sold-photos` with JWT gateway verification disabled for
  this function only. The handler checks a dedicated long random `PHOTO_CLEANUP_SECRET`
  on every request; never use a public/publishable key for that secret.
- Configure `PHOTO_CLEANUP_SECRET` server-side. The Supabase URL and service-role key
  must exist in the function environment only, never Vite/browser variables.
- Store the project URL and the same scheduler secret in Vault under `project_url`
  and `photo_cleanup_secret`. Enter secrets directly in Supabase, not in this repo/chat.
- Approve `review/003_schedule_cleanup.sql` separately. It creates a job running every
  15 minutes and enables cleanup. Files are deleted at the first successful run after
  the 7-day boundary, not before it. Confirm there is no existing job with this name.
- Monitor job results and Edge Function logs. Pausing future cleanup:
  `update public.marketplace_cleanup_settings set enabled=false where singleton;`
  Also unschedule the job through the dashboard. Already-running deletions cannot
  be reversed. Disabling cleanup is not a way to recover deleted photos.

Supabase requires deleting object bytes through its Storage API rather than SQL:
[Delete objects](https://supabase.com/docs/guides/storage/management/delete-objects).
The scheduler follows [Scheduling Edge Functions](https://supabase.com/docs/guides/functions/schedule-functions).
The view and policies follow [Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security).

## Validation

`npm test` covers the midnight boundary in Zambia, future dates, indefinite
availability, seller overrides, cleanup disabled, unsafe paths, deletion failure,
and finalization failure. `npm run lint` and `npm run build` validate the frontend.

The optional local PostgreSQL harness never connects to Supabase:

```powershell
npm install --prefix .validation --no-save --package-lock=false @electric-sql/pglite
node scripts/validate-database.mjs
```

It applies the drafts to disposable in-memory databases, tests both text-array and
JSONB photo columns, and tests roles, ownership, privacy, spoofing, date-aware status,
retention, restoration, retry tokens, cleanup locks, and soft deletion. This is not
a substitute for staging tests against the actual Supabase Auth/Storage services.

After approval, use two test accounts and a third nonparticipant to test messages
and unauthorized access; confirm signed-out reads; post both availability choices;
test date/status editing; test restored and sold listings with staging-only aged
timestamps; run cleanup twice; simulate a failed Storage request; verify actual bytes
were removed and active/legacy photos were preserved. Verify real email-code delivery
and mobile layouts. No live data should be aged or deleted for these tests.
