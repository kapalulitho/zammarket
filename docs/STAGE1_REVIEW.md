# ZamMarket Stage 1 review — 29 October 2026

> Follow-up verification: see STAGE1_VERIFICATION.md. Expanded messaging tests found
> a shared-trigger record-field bug missed by the original tests. Proposed 012 fixes
> it locally and awaits approval; the original combined SQL is not fully passing
> the expanded regression suite. Real signup email, profile/avatar persistence,
> logout and email-code login have now been confirmed by the user.

Scope: inspect and stabilise the existing React/Vite/JavaScript/Supabase application. Stages 2–5 have not started. No live database changes or data deletions were performed during this review.

## Existing implementation

| Area | Current state / evidence |
| --- | --- |
| Branding and responsive feed | Original SVG bag/Z logo, welcome illustration, blue/white styling, responsive compact 2–5 column cards, consistent photos and accessible forms. No dark theme yet. |
| Authentication | Supabase password registration/login, six-digit signup OTP, resend, email-code login fallback, persisted sessions validated with getUser, logout, route and mandatory profile gates. Local automated and isolated browser tests exist. Real email delivery is not verified. |
| Profile | Required unique username/shop name/account type, optional editable avatar and contact fields, visibility controls, review before completion. Private login email excluded from public projection. Live save still needs user testing. |
| Marketplace | Home, category selection, client-side search/location/status filters, available-first sorting, product details and seller profile; likes on details; upload up to five validated photos. |
| Seller management | My Listings, editing, Sold/Temporarily Unavailable, date-aware availability and soft deletion via owner RPC. No listing automatically expires after its availability date. |
| Messaging | Conversation list, text chat, Zambia timestamps, five-second polling and older-message loading; RLS participant checks in SQL. Real two-account exchange still needs testing. |
| Backend deployment | User reported applying 009 and 010, then supplied catalog results confirming backend objects, profile table/function, avatar bucket and profile RLS. This is not a claim of a full live permission test. |
| Cleanup | Automatic photo deletion remains inactive. Source proposals exist but are not part of this pass. |

## Structure and routes

`src/App.jsx` contains the marketplace shell, feed/search/categories, details and posting. Components include AuthBoundary, ProfileGate, ProfileEditor, AccountProfile, SellerProfile, MyListings, Messages and shared Design. Shared libraries cover sessions, routes, availability, profiles, listing/file validation and OTP handling.

Routes: `/`, `/signin`, `/create-account`, `/home`, `/categories`, `/post`, `/messages`, `/profile`, `/my-listings`. Product details and seller pages are internal state, without permanent deep links. Search is embedded in Home. CSS lives in App.css/index.css; original branding and manifest assets are in public/. SQL proposals and local validation scripts are under supabase/review/ and scripts/.

## Problems found and safely fixed

- Feed Retry passed React's click event into a backend-readiness parameter. It now explicitly calls the loader without an event, preserving the current backend selection.
- Feature polling fetched the full collection every minute. It now refreshes the feed only when feature readiness first becomes available; clock/readiness checks continue.
- Overlapping feed requests could let an older result/error overwrite a newer result, or finish after unmount. Request sequencing and mounted checks now restrict updates to the current request.
- Invalid server time is ignored instead of corrupting availability calculations.
- OTP inputs were empty, but displayed an example numeric code as placeholder. Both now say “Six-digit code”; no credentials or codes are prefilled.

## Missing / unfinished

- Guest browsing is requested by the new master instructions but currently blocked by the earlier auth-only design. Implement public feed/category/detail access separately from private actions after this Stage 1 review; do not bypass verification for posting or messages.
- Deep-navy dark/light themes, hamburger/centred logo/profile header, and theme persistence are absent. Current mobile bottom navigation exists.
- Dedicated password-recovery screen is absent; email-code sign-in followed by password update exists. Dedicated account-deletion request flow is absent.
- Saved-products page, listing pagination, image compression and server-side discovery remain unfinished. Likes exist but no standalone saved view.
- Messaging unread counts, attachments, reporting/blocking and notifications are missing.
- Province/district selectors, subcategories, Reserved status, delivery details, shops/admin tools, reviews and payments are not complete. These belong to later stages; no fake payments/courier data were added.

## Security review and limits

- No service-role credential was found in frontend source. Browser configuration uses a publishable key; service credentials belong only in server environment variables. No secret values are documented here.
- Profile table uses owner-only SELECT and checked save RPCs; contact visibility projection excludes the login email. Messaging participants and immutable listing ownership are enforced in the prepared SQL and disposable-database checks, not merely hidden buttons.
- Existing likes remain publicly readable, including user/listing identifiers. Decide whether to replace this with private saved records plus public aggregate counts before broader rollout. That requires separately reviewed SQL.
- Existing listing-images bucket has no configured MIME/size limits in the user's report. Frontend validation alone cannot enforce these for custom clients. Avatar bucket has its own 2 MB/type restrictions. Review listing bucket restrictions separately without modifying existing photos.
- Upload failures preserve files, so unreferenced files can accumulate; cleanup remains explicitly separate.
- Live cross-account authorisation, avatar upload and verified posting/message writes still need test-account verification. No live RPC probes were performed in this pass.
- No Git repository is available; a timestamped source checkpoint was saved under ignored backups/. No existing files were deleted.

## Files changed

- src/App.jsx — feed retry, request sequencing, clock validation and polling efficiency.
- src/components/AuthBoundary.jsx and src/components/ProfileGate.jsx — nonnumeric OTP placeholders.
- .validation/mock-supabase.js — isolated simulated feed outage; never used by production config.
- docs/STAGE1_REVIEW.md — this review.
- supabase/review/CURRENT_APPROVAL_PACKAGE.md — deployment status notice; historical SQL retained unchanged.

## Safest implementation order

1. Review this Stage 1 result; finish real OTP/profile/refresh/logout smoke testing with the user entering credentials privately.
2. With two approved test accounts, verify private profiles/messages and owner-only listing management. Preserve existing four listings/photos.
3. Complete guest navigation with login gates on mutations, recovery/deletion-request UX, and responsive theme/header changes in small checkpoints. Recheck routes and accessibility.
4. Only after Stage 1 review, begin Stage 2: pagination/saved view, Zambia locations, delivery, and remaining marketplace/chat functionality. Review any live schema/policy changes before applying.
5. Keep shops/admin/payments and future expansion in later stages.

## Validation

- Baseline and final `npm test`: 34 passed, 0 failed.
- Baseline and final `npm run lint`: passed.
- Baseline and final `npm run build`: passed; final JS approximately 496 kB / 141 kB gzip. No missing build dependencies found.
- `node scripts/validate-profiles.mjs --full`: passed combined 009+010 locally for uniqueness, verified/reviewed completion, private fields, visibility projection, ownership, avatar isolation and preserved old data. No live migration was executed by this command.
- Isolated browser at port 5174: forced feed failure displayed its retry state; Retry restored four simulated listing cards. This test did not touch Supabase. Existing real-user browser tab could not be rebound by the browser tool in this pass, so no new real-session browser success is claimed.

Preview the real development site at http://127.0.0.1:5173/. Do not rerun 009 or 010 after the reported successful deployment. Do not run historical ownership/deletion/cleanup scripts.
