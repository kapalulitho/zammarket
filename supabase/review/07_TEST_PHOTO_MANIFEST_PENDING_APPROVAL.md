# SUPERSEDED: preserve BOTH Storage objects

The latest user instruction prohibits automatic Storage deletion. This historical
manifest is retained for investigation only. Do not execute its photo-deletion steps.
The listing-only deletion proposal remains 06, requiring final review.

# One-time cleanup proposal — not executed

The supplied read-only report found all four target listings, all unowned and active.
No target likes, listing rules/triggers, other photo columns, or ambiguous photo
references were reported. The only incoming relationship reported was likes, with
ON DELETE CASCADE. The deletion script additionally checks likes triggers/rules and
new incoming relationships at execution time; it stops if an unexpected one exists.

## Exact listing deletions proposed

| Listing | UUID |
|---|---|
| Exercise Books | ce820419-6143-4cbe-8c80-f487e7692d52 |
| Smartphone | 79e8ecb3-03a7-442e-8db2-d6cc6098107d |
| Hotel | 5dab608c-f239-4ae8-bf77-c7522eca6bb3 |
| Watch | 30ddb257-2649-46ab-b121-a3ff28698ee0 |

## Exact Storage deletion proposed — separate step after database verification

- Bucket: `listing-images`
- Path: `1792922119631-256u3c3v7vf.jpg`
- Object ID: `8ddf476c-545b-48a2-8613-7cd9d3f5c241`
- Referenced by: Hotel only, through `image_urls`.
- Other listing references in supplied report: none.
- Decision: eligible for deletion after approval, successful listing deletion, and
  a fresh reference/object-ID check immediately before Storage removal.

The bucket contains TWO objects. The other object is not identified as associated
with these listings and MUST be retained. Do not delete the whole bucket, select
all photos, or delete files merely because they appear unused.

## Safe application order, subject to approval

1. Offer/export copies of the four rows and download the one photo if recovery is
   wanted. Do this before removal. No exports or downloads have been performed.
2. Review and separately approve `06_delete_test_listings_PENDING_APPROVAL.sql`.
   It validates exact IDs/titles, unowned/active state, no likes, and relationship/
   trigger/rule assumptions. It locks listings and likes briefly (5-second lock
   timeout), then deletes only the four rows. Any guard failure aborts the transaction.
   New listings are not deletion targets; table locks can briefly delay writes.
3. Verify the four IDs are absent and all non-target data is unchanged. The prior
   report contained four listings total, so zero is expected only if no new listings
   have been added. Do not treat newly added listings as unexpected cleanup targets.
4. Recheck references and Storage object identity. Delete ONLY the approved path
   through the Storage dashboard/API. Never DELETE FROM storage.objects in SQL.
   An external link not stored in the database cannot be discovered by these checks;
   deleting the Hotel photo makes any such link stop working.
5. Verify the other Storage object remains. If the Storage step fails, leave the
   leftover photo and retry after checking references; do not broaden deletion scope.

Database deletion and Storage deletion are not atomic together. Before commit a
database error rolls back row changes; after commit recovery requires the exported
rows or backup. Storage deletion is permanent without an independent photo copy.

No account deletion, ownership repair, RLS migration, bucket setting change, or
automatic seven-day cleanup activation is part of this one-time cleanup approval.
Future authenticated ownership and owner-only writes remain a separate reviewed
backend change after this cleanup, followed by tests with two accounts and anon.
