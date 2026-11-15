# 022 and 023 — separate review, HOLD

29 October 2026. Neither draft executed remotely. Local fixture tests are evidence of intended SQL behaviour, not a native Supabase deployment approval.

## 022 business foundation

Creates business_foundation_settings (publication false), business_organisations (immutable owner; personal/small_business/company, identity, opt-in contacts, logo/status), business_memberships (reserved staff-role metadata) and business_branches. Creates owner/publication helpers, identity/contact/media validation triggers, explicit public profiles/branches projections and private business-media bucket (2 MB JPEG/PNG/WebP).

Raw organisation rows are owner-only. Membership records may be seen by their subject or owner, but clients cannot grant roles. Even an active manager does not acquire listing, messaging, private contact or organisation mutation rights. Owner insertion/update requires completed verified membership. Login email is rejected as a public contact. Public views expose only selected contact fields and require publication gates; publishing a branch explicitly exposes its town. No existing account type/profile is rewritten.

Storage reads require ownership or a currently published reference. Restrictive guards prevent permissive policies from opening this new bucket; overwrite/delete are disallowed to clients. Native signing, signed URL lifetime/revocation, actual MIME validation and image decoding must still be tested in staging. Database path checks and bucket MIME metadata do not replace trusted server file inspection.

Recommendation: retain HOLD. Validate natively and approve exact SQL before applying. Depends on 009/010 helpers, not directly on 012 messaging DDL. Existing seller_shops from 013_v2 is a separate one-owner storefront model: do not duplicate/backfill shops automatically or treat reserved staff roles as ownership. A reviewed linking contract is needed.

## 023 accommodation and logistics

Depends on 022 plus membership helpers. Creates business_service_settings (publication false), business_service_entries (owned organisation, stay/logistics kind, categories, town, features, service areas/media), stay_room_options (capacity, nightly integer minor units, ZMW) and business_service_enquiry_drafts (author-only, immutable unsent drafts). Adds owner/visibility helpers, validated identity/room/enquiry triggers, public service/room projections and private business-service-media bucket (5 MB JPEG/PNG/WebP).

Raw provider/service/room records are owner-only; enquiry drafts remain private to their author, including from the provider. They cannot be submitted/assigned through these grants. Public entries require both published parent and service and both publication gates. Room capacity is descriptive, not inventory or available dates. No booking, room reservation, transport dispatch, quote sending or payment schema is created. Existing property and parcel Delivery tables remain separate.

Recommendation: retain HOLD. Native Storage and role tests, publication/contact revocation, provider moderation and the reviewed enquiry-submission workflow are prerequisites to real publishing. No direct 012 DDL dependency; existing product conversations continue through their existing schema.

## Safety, conflicts and rollback

Both files are transactional with bounded lock/statement timeouts. They create new named objects and Storage policies only for their own buckets; local checks confirm old policy definitions unchanged. Existing users, listings, messages and photos are not rewritten, reassigned or deleted. Name collisions must stop deployment; these are not idempotent rerun scripts. Preflight must inspect existing names, roles, helper definitions and bucket policies before approval.

Before commit a SQL error rolls the transaction back. After commit use a forward corrective migration, close the new publication flags and disconnect the new UI if needed. Do not DROP populated tables/buckets as an automatic rollback. Capture current schema/policy definitions and an approved backup before any live deployment. No destructive rollback SQL supplied.

The public views intentionally project administrator-owned data rather than inheriting owner-only raw-table policies. Exact projection and view ownership are security-sensitive: confirm definitions/ownership/grants and both flags in native staging, including anonymous API requests. Cached signed URLs may survive until expiry; use short lifetimes and document this limit before publishing.

All original 013/014 and 013_v2–021 remain HOLD. The historically applied 012 fix is not reapplied here; preserve fingerprint/trigger verification in the staging baseline. Pending public-likes privacy and legacy image-limit changes are outside this approval scope.
