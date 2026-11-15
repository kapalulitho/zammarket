# Safe local seller workspace update — 29 October 2026

This batch accompanies the read-only review of 013/014. Neither migration source was changed or applied; source SHA-256 values are recorded in the separate assessment files. No live database query/write, Storage upload, security change or deployment was performed by this batch.

## Built locally

- Inventory: product search, published/unpublished/low/out-of-stock filters, known-stock metrics that distinguish missing records from zero quantity, and an always-available explicitly unsaved editor preview. Variant editing calculates totals live, rejects duplicate labels/invalid quantities/prices, caps total units, and serialises only label/quantity/price. The preview cannot save, even if a backend later exists. Existing owner-bound saves still require commerce capability and checked current account.
- Storefronts: controlled form with automatic handle suggestion (until manually edited), live banner/avatar/name/description/location/hours/policy preview, content readiness checklist, optional banner removal without file deletion, current-account validation and upload consent. Uniqueness is not claimed until Supabase accepts the handle. Draft edits remain in React memory, not browser storage. Existing storefront query errors disable saving to avoid a blind duplicate create.
- Business discovery now has its own search/clear control and distinct loading, unavailable, no-matches and no-published-businesses states.
- Media disclosure: the storefront editor explicitly warns that the proposed bucket exposes uploaded images immediately, including private drafts. A new image requires acknowledgement before upload. This warning is not a substitute for the recommended private-draft media architecture; 013 remains on hold.
- Advertising workspace: reusable controlled draft editor with live budget/type preview, draft search/status/type filters, duplication as a NEW draft and reversible archive/restore. Campaign date pairs and budgets are validated; only draft/archived states are used. Saving never charges, boosts or activates an ad/subscription. Budgets are clearly targets, not billed spend; unknown metrics show a dash rather than fabricated zeroes.
- Homepage: the approved green banner, eight destinations and light/dark design are retained. Local-business section now links directly to stock/options, storefront and campaign workspaces; guests still pass through sign-in.

## Review outcome

See 013_READ_ONLY_ASSESSMENT.md and 014_READ_ONLY_ASSESSMENT.md in supabase/review/ for all tables/columns/functions/policies, data safety, dependencies and rollback details. Recommended next backend work is a hardened separately reviewable revision, not application of the current scripts. Prior role-isolation tests pass, but narrow adversarial probes reproduce unfiltered variant-key publication and trusted receipt mutation retaining an older verified-review badge. Neither finding affects currently live data because these migrations are unapplied.

Migration 012, public-likes privacy and listing-image bucket limits remain tracked unchanged. No automatic cleanup or payments are enabled. A function-only rollback for 012 is not a backup for the new Stage 3 schema.

## Focused checks

Results: all four focused seller-tool tests pass, lint is clean and production build
succeeds. Disposable SQL probes reproduce the two 014 review findings while the
existing owner/privacy checks continue to pass. A short isolated browser check at
360 px confirmed the storefront preview/automatic handle update with no overflow
and the save button disabled while migrations are absent. The original 013/014
SHA-256 digests remain unchanged.

Run node --test tests/sellerTools.test.js, lint and production build. The optional disposable check uses --with-stage3 --review-stage3 to reproduce the review findings with non-sensitive fixtures only. It must not be mistaken for live inspection or approval. No extensive real-email/two-account test campaign was repeated.
