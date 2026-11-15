# Migration 013 — read-only assessment

Date: 29 October 2026. **Recommendation: HOLD live application pending draft-media privacy hardening, then preflight/backup review and explicit approval.** No SQL in this migration was changed or applied during this review.

Reviewed source: [013_stage3_modules_PENDING_APPROVAL.sql](013_stage3_modules_PENDING_APPROVAL.sql). SHA-256: `7A403FD4515E644EAEF5A8F2670663145A7533A0B407767EC2D349A2D8D93955`.

## New tables and every column

| New table | Columns | Rules |
| --- | --- | --- |
| public.community_entries | id, owner_id, kind, title, description, location, category, organisation, format, price, price_unit, starts_at, ends_at, deadline, extra, media_paths, status, created_at, updated_at | UUID identity; owner Auth FK; event/job/service/learning; checked text lengths; optional nonnegative price; events require start; end cannot precede start; up to five image paths; draft/published/closed. |
| public.seller_shops | id, owner_id, slug, name, description, location, hours, policies, media_paths, status, created_at, updated_at | One shop per owner; unique lowercase handle; checked text lengths; up to one banner; draft/published/closed. |
| public.module_enquiries | id, entry_id, sender_id, recipient_id, body, reply, created_at, updated_at | Entry/Auth FKs; sender differs from recipient; bounded message/reply; sender/recipient identity checked/derived server-side. |
| public.marketplace_notifications | id, recipient_id, entry_id, title, read_at, created_at | Private recipient records created by enquiry triggers; bounded access rather than public notifications. |

Five secondary indexes: entries(kind,status,created_at), entries(owner_id), enquiries(recipient_id,created_at), enquiries(sender_id,created_at), notifications(recipient_id,created_at). Primary/unique constraints add their own indexes.

## New functions, triggers and grants

- `stage3_content_guard()` — SECURITY DEFINER with empty search_path. Requires completed verified membership; checks caller/owner, immutable record/owner identity, owned existing media paths, preserves creation time and stamps update time. Attached through `stage3_entry_guard` and `stage3_shop_guard`.
- `stage3_enquiry_guard()` — same controlled definer context; validates sender, derives recipient from a published entry, prevents self-enquiries/identity/body edits, limits sends to five/minute with an advisory lock. `stage3_enquiry_guard` trigger runs before insert/update.
- `stage3_notify_enquiry()` — creates recipient notification on enquiry and sender notification on a changed nonblank reply. `stage3_notify_enquiry` runs after insert/update. Only new tables receive these effects.
- `stage3_capabilities()` — public, read-only SQL function returning version/module/storefront availability; not a secret/configuration endpoint.

Direct execution of trigger functions is revoked from PUBLIC/anon/authenticated. Only the capability function is granted to client roles. New tables revoke blanket client grants and restore SELECT plus selected INSERT/UPDATE columns. No client DELETE is granted. Authenticated users cannot update ownership, message body/identity, notification recipient/title or creation metadata through those column grants.

## Every policy created (16)

| Table | Policies | Access |
| --- | --- | --- |
| community_entries | stage3_entry_read, stage3_entry_insert, stage3_entry_update | Published rows public; drafts/closed rows owner-only. Verified completed owner inserts/updates only. |
| seller_shops | stage3_shop_read, stage3_shop_insert, stage3_shop_update | Same public/owner split; checked owner-only writes. |
| module_enquiries | stage3_enquiry_read, stage3_enquiry_send, stage3_enquiry_reply | Only sender/recipient read; caller sends as self; only recipient can update reply. |
| marketplace_notifications | stage3_notification_read, stage3_notification_mark | Recipient-only reads and read_at updates. No client insert/delete. |
| storage.objects | stage3_media_read, stage3_media_insert, stage3_media_insert_guard, stage3_media_no_overwrite, stage3_media_no_delete | Owner-folder metadata/upload access; restrictive guards deny overwrite/delete for the new bucket and prevent a broader permissive upload policy bypass. |

RLS is enabled on all four new application tables. Existing Storage RLS remains in use. The five Storage policies are **new policies on an existing table**, even though no old policy is replaced. Existing buckets pass the bucket-specific restrictive guards unchanged.

## Storage change and privacy finding

The script inserts a NEW `storage.buckets` row: marketplace-media, public=true, 5 MB, JPEG/PNG/WebP. It neither moves nor deletes files and does not alter listing-images/avatars settings.

**Private draft rows do not make draft images private.** Anyone with an image URL can retrieve it immediately, including after closing/unpublishing the record. Metadata SELECT policies do not change that public-file access. Supabase documents this [public bucket behaviour](https://supabase.com/docs/guides/storage/buckets/fundamentals).

Recommendation: use private draft media with authorised signed access and a controlled publication flow before promising private drafts. Local upload warnings/acknowledgements added during development make the current proposal explicit but do not fix this SQL privacy boundary. Until hardened, treat these images as public artwork only; do not approve a broad private-draft rollout.

## Existing users/data and migration 012

There are no ALTER/UPDATE/DELETE operations targeting existing users, listings, product messages or profile rows. No ownership backfill, photo cleanup, scheduler, active ads or payments. Existing product-chat triggers/functions, grants and policies are retained; local checks confirm old policies, old bucket settings and the 012 function are unchanged.

New Auth/entry foreign keys can block future hard deletion of referenced users/content. That preserves history; it requires a separate retention workflow rather than silently cascading deletion.

Technical dependencies: 009 listing/messaging baseline and 010's marketplace_complete_member/Auth/Storage setup. It does not call or replace the function fixed by 012. Keeping 012 applied is the rollout baseline for working existing product Chats, not a DDL dependency of these new tables. Do not rerun 012.

## Deployment and rollback

Requires a trusted administrator role and unused table/function/policy/bucket names. CREATE rather than CREATE OR REPLACE means collisions fail instead of overwriting existing objects. DDL/FKs/Storage metadata can briefly contend with live requests; five-second lock_timeout limits waiting and 60-second statement_timeout applies to each statement, not the whole script.

Before COMMIT, failure/ROLLBACK reverses the transaction, including the bucket metadata insert; this SQL does not upload physical files. After COMMIT, there is no blanket data-preserving down migration: dropping newly used tables or a bucket could destroy new user data. Preferred recovery is to disable/revert affected UI, preserve records/files, and apply an approved forward fix. Restore from an independently verified backup only with a specific recovery plan; no current full backup was verified here.

Run the existing read-only preflight, inspect deployment ownership/default grants/collisions, confirm a backup/recovery point, and stage-test the hardened media flow before seeking live approval. This assessment is source review plus disposable-database permission checks, not a new inspection of live database state.
