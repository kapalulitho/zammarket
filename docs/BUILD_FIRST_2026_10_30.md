# Build-first batches — 30 October 2026

Existing project continued. No production deployment/configuration change, migration, RLS change, payment, booking, dispatch or cleanup activation in this batch. Homepage/compact service icons and current verticals preserved.

## Batch 1 — marketplace journeys

- Shareable product URLs (`/home?product=...`), direct detail loading through existing RLS, copy-link action and unavailable/invalid-link handling. Existing large galleries retained; details are not restricted to the first feed response. Browser history and seller navigation clear the detail link appropriately.
- Seller catalogues now use compact product cards, explicit ZMW prices, title/category filters, availability-first/price/newest sorting and incremental display.
- Conversation title search, optional seller quick replies (fill only; never auto-send), character count and fresh Auth identity check before sending. Participant query filters supplement existing RLS. Polling skips hidden documents. These are code improvements; a new live two-account send test was not performed.
- Broken listing images fall back to existing artwork. Dark-mode availability/seller controls have stronger contrast.

## Batch 2 — business discovery

- New staging-only business/accommodation/logistics discovery uses only 022/023 public projections, not private raw contact tables. Search, location/type filters, details, selected contacts, room prices/capacity and signed media reuse available foundations.
- Private and public business galleries now share one component. Publication gates were NOT enabled: real staging browser check shows a truthful empty public directory.
- Business/service editor persistence prepared in previous batches is retained. Real owner save-refresh-edit and native media-signature tests still require verified staging sessions; do not describe them as passed by this batch.

## Batch 3 — usable planning workflows

- Accommodation/logistics local previews gain visit-only favourites, incremental browsing and downloadable unsent enquiry plans. Edits to plan inputs clear stale calculated previews.
- Existing Food, Events, Jobs, Learning, Property, Delivery and Services workflow notebooks gain downloadable text notes/checklists. No notes are uploaded or persisted automatically.
- Promotions gains an assumption-driven campaign budget/CPM/click-rate scenario and download. No actual rates, measured trends, conversions, revenue or paid exposure are claimed.
- Agriculture/Digital and other existing modules remain intact with their previous capability gates. This batch does not claim those held backends are complete.

## Staging registration

Staging six-digit OTP length was previously saved with explicit approval. Template editing remains locked behind approved SMTP/plan/hook setup, so **six-digit email delivery is not fixed or verified**. No repeated sender changes or new email sends were attempted. Local staging code-entry guidance now supports the existing confirmation-link journey: confirm the email using its newest link, then return and sign in with the same email/password. Supabase still verifies the identity; no confirmation/profile bypass or artificial session is introduced. This fallback may let the existing test account proceed without changing the locked template. Automatic return depends on staging Auth redirect configuration; manual return/sign-in remains available after confirmation. Production Auth settings unchanged.

## Checks and evidence

- Full test run: **86 passed, zero failed**. New tests cover URL validation/ambiguity, message limits/search, unsent-plan exports and campaign assumptions. Existing auth/ownership tests retained.
- Lint and production build passed after meaningful changes. Later targeted link/auth/planning tests also passed.
- Isolated fixture browser: direct product link rendered real fixture details/gallery; seller navigation and catalogue search passed. Fixture server stopped and temporary tabs closed.
- Actual staging browser: approved public business views load empty with gates off. No production browsing requests used for tests.
- Requested mobile viewport override did not apply to the fixture tab (measured 1265px), so this batch does NOT claim a fresh 360px visual pass. Existing responsive CSS remains; the captured product evidence is desktop.
- Real OTP delivery, native signed-in data writes and cross-account messaging/media remain pending. No user password, email code or API key was recorded.

## Changed files

App.jsx; AuthBoundary, Messages, SellerProfile, ProductCard, ExploreServices, PersistentBusinessTools, BusinessServiceDirectory, WorkflowNotebook and RevenueHub components; new BusinessDiscovery, BusinessImageGallery and CampaignScenario components; new productLinks/useProductLink/messageTools/planningExport helpers; business-foundation.css; tests/buildFirst.test.js; isolated mock query support; this report/roadmap pointers. Existing held SQL unchanged.

Next useful work: complete hosted email-provider setup when an approved sender is available, then verify the existing account and run native ownership/messages/business/media workflows. Continue local module development independently; do not use fake public offers, disable confirmation, publish drafts or activate payments to hide backend dependencies.
