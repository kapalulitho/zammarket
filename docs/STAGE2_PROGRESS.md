# Stage 2 — first implementation batch, 29 October 2026

Follow-up: the master product vision foundation adds themes, expanded navigation,
discovery/comparison and province/town entry. See PRODUCT_ROADMAP.md for current
status; this file preserves the first-batch report below.

The user authorised proceeding after the Stage 1 report and chose to skip a second real email/account test. Live two-account messaging/isolation therefore remains explicitly unverified, not passed. The existing 012 correction was previously identified in the supplied live catalog report; it was not rerun here.

## Completed in this batch

- Guest browsing at /home and /categories, reached through Explore the marketplace on welcome. Guests can search, filter, open product details and view public seller listing catalogues. Guest seller pages do not invoke the authenticated contact-profile RPC.
- Sign-in gates on posting, saving, messages, profile and My Listings, including direct private URLs. Unknown URLs fail closed to sign-in. Auth/session loading still shows a loader before mounting any marketplace; authenticated users still complete verified profile setup. Login opens Home; logout returns welcome.
- Saved products at /saved using the existing likes records. Desktop navigation and Profile (including mobile) link to Saved. Product details support Save product and Remove from saved, with a busy guard against duplicate clicks. Shared compact cards retain only photo, title, ZMW price and location.
- Saved loading, retry/error and empty states. Navigation to Saved clears old feed filters. Sold/temporarily unavailable products remain saveable/visible while their listings exist; soft-deleted or missing listings are excluded. Clearing a save removes only the like, not its listing or photos.

## Security boundary

No migration, live policy, bucket setting or existing data was changed. Guest view access uses existing public listing permissions. Authenticated/private actions continue to rely on deployed Supabase checks, not UI buttons alone.

The Saved page filters to the current user's records for presentation, but the existing likes table is publicly readable. This is not a private saved-data backend. That known privacy issue and listing bucket MIME/size limits remain pending separate approval. No automatic cleanup was activated.

## Files

- src/lib/routes.js, src/components/AuthBoundary.jsx: distinguish welcome/auth, public browsing and private routes.
- src/components/Design.jsx: working welcome browse link.
- src/App.jsx: guest action guards and shared Saved feed, save/remove busy/error handling.
- src/lib/saved.js and tests/saved.test.js: own-account saved selection, legacy IDs and deleted/missing listing handling.
- src/components/AccountProfile.jsx: mobile/desktop Saved access.
- src/components/SellerProfile.jsx: avoid authenticated contact RPC for guests.
- src/App.css: guest notice and saved heading styling.
- tests/authSession.test.js: revised public/private route expectations.
- .validation/mock-supabase.js: persistent isolated like fixtures for browser QA, never bundled in production.
- README.md, docs/AUTH.md, docs/REGISTRATION_PROFILES.md: current status clarifications.

A timestamped source checkpoint is saved under ignored backups/. Its copied test file uses .snapshot so Node does not discover it as an active test. Existing code/data were preserved; no Git repository is available.

## Validation

- npm test: 36 passed, 0 failed.
- npm run lint: clean.
- npm run build: passed; JS approximately 499 kB / 141 kB gzip.
- node scripts/validate-profiles.mjs --full --with-trigger-fix --audit: passed disposable-database backend/permission regression suite.
- Isolated browser: save → /saved → refresh preserves item; remove → empty state; logout → welcome; Explore → guest feed; guest details → Message Seller → sign-in; direct /saved while signed out → sign-in; direct categories browse works.
- At 360 px: measured two product columns, visible bottom navigation with Sign In for guests, no page-wide overflow. Desktop navigation also checked. Responsive viewport reset after testing.
- Real development server responds HTTP 200 at http://127.0.0.1:5173/. No real likes or listings were written during the agent's browser tests; the persistence tests used the isolated mock server.

## Still outstanding in Stage 2

Pagination/server-side discovery, complete Zambia province/town selection, subcategories, basic delivery fields/information, sharing URLs, and further messaging improvements remain separate batches. Dark/light themes and requested header layout also remain outstanding design work. Full two-account live behaviour remains a known skipped test. Shops/admin/payments have not started.

Preview: signed in, open /saved or Profile → Saved products. To test guests, use a private window at / and choose Explore the marketplace. Never deploy the ignored QA server/configuration.
