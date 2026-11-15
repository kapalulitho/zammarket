# Test listing cleanup proposal — no execution authorized

The user cancelled the ownership repair. Do not execute any ownership repair script.

## Verify before proposing deletion SQL

Run only `05_test_cleanup_preflight.sql` in SQL Editor. It is read-only and uses the
four user-supplied listing UUIDs. Compare titles and current ownership. Review both
legacy image_url and image_urls, exact Storage object matches, other listing references,
ambiguous/unmatched/encoded URLs, incoming foreign keys, likes counts, triggers/rules,
and other possible photo columns. Any ambiguous path or other photo column requires
manual verification before approving the final file list. No bucket-wide cleanup.
Previous report: likes.listing_id cascades on listing deletion; two root-level Storage
objects exist, but this does not prove either is unused. A current check is required.

## Approval package to prepare after results

1. List the exact four UUID/title pairs and all dependent rows that deletion affects.
   If likes exist, disclose their count: ON DELETE CASCADE removes those likes. If the
   user requires preserving them, propose hiding listings instead of physical deletion.
   Review any other incoming foreign keys and transitive cascades before proceeding.
2. Produce an exact photo manifest: bucket, object UUID/path, target references,
   non-target references, and retain/delete decision. Keep all shared/ambiguous files.
   References from other tables must also be checked; a listing-only scan is insufficient
   if other photo consumers are discovered. Do not infer deletion from object counts.
3. Offer a local export of the four listing rows and copies of exclusively associated
   photos before deletion. Database backups alone do not back up Storage bytes.
4. Prepare a guarded database transaction: exact-ID locks, title/ownership checks,
   expected affected-row/dependency counts, and abort on changed state. Delete only
   these four records and explicitly approved dependent likes. Check remaining rows.
5. Delete photos only after successful database removal, a fresh shared-reference check,
   and approval of the exact Storage manifest. Use the Storage API/dashboard, never
   DELETE FROM storage.objects. Storage and database changes are not one atomic
   transaction: failed photo deletion leaves recoverable leftover files, not broken
   active listings. Storage deletion itself is permanent. Never delete the bucket.
6. Verify all other listings, users, likes, and photos remain intact.

## Future listing ownership proposal — separate schema approval

The frontend already includes user_id from the current signed-in user. Before upload,
verify the user with Supabase Auth getUser(); submit the verified user_id and seller_id.
The database assigns/checks both fields from auth.uid() at insert, blocks signed-out
and spoofed inserts, and prevents ownership reassignment on updates. user_id remains
the canonical owner used by messaging and My Listings.

Preserve public SELECT of products for signed-out and signed-in visitors. Require
owner-only status/edit/delete operations through the approved management RPC. Audit
and revoke any separate column UPDATE grants as well as table UPDATE/DELETE grants;
retain restrictive ownership policies as defense in depth. Existing permissive
policies alone must not grant another write path. Test with two accounts and anon:
public reads succeed; owner writes succeed; another user's writes and owner transfers
fail. Do not apply the earlier core migration blindly: integrate the ownership trigger
and sequence/column grant findings into the exact approval package first.

No migrations/policies, live records/photos, or automatic cleanup schedules have been
changed. Automatic seven-day deletion remains a separate approval step.
