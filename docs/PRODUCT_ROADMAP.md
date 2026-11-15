# ZamMarket product foundation — 29 October 2026

Stage 3 update: see STAGE3_REPORT.md and MASTER_PLAN.md. Multi-service forms/models,
storefront/inventory/review foundations and promotion drafts are now implemented
locally, with new publishing gated on unapplied migrations 013/014. The earlier
foundation status below is historical; it does not imply those new backends are live.

This implements the next local foundation for the master product vision, not every future service. Existing React/Vite/Supabase features and data are retained. No live migration, permission change, deployment, expense, payment activation or automatic deletion was performed.

## Delivered in this batch

| Capability | Status and limits |
| --- | --- |
| Design system | Blue/white light appearance, deep navy dark appearance and system preference. Choice persists locally, responds to system changes and synchronises across tabs. Theme applies to welcome, auth, profile setup and marketplace components. |
| Navigation | Desktop: Home, Explore, Categories, Services, Sell, Messages, Saved, Orders, Business, Profile. Mobile: Home, Explore, Post, Messages, Profile. Hamburger directory provides additional pages; mobile header centres branding with profile action on right. |
| Home | Original illustration/promotional area, working product discovery/category filters, generic available-first ordering, visit-only recently viewed products and expandable service directory. No fake sponsored placements, sellers or business metrics. |
| Discovery | Multi-word matching across title/category/location/description, price range, condition from actual existing metadata, availability, location and sorting. Invalid price ranges are rejected. Location matching uses seller text, not GPS/radius or inferred distances. |
| Zambia location entry | All ten provinces plus free town/district entry when posting. Encodes `Town, Province` into existing location text; legacy listings are untouched. Authoritative district lookup and structured server-side region columns remain future work. |
| Product cards | Shared, clickable photo/title cards retain only image, title, ZMW price and location. Legacy photo references and consistent aspect ratio retained. |
| Recently viewed | Up to twelve IDs in React memory; shows up to four recent products on Home. Clear control provided. No persistence, remote tracking or personalised recommendations. Reload/auth-boundary unmount clears it. |
| Comparison | Up to three products, add/remove from details, comparison tray and responsive side-by-side table. Missing condition is labelled Not provided. Visit-only memory; no Supabase writes. |
| Services | Products marked Available; nine other service areas explicitly Planned. Directory entries are configuration, not functioning bookings/food/jobs/event systems. |
| Business | Working shortcuts to existing posting, listing management, enquiries and profile tools. This is not a full storefront/dashboard backend. |
| Orders | Authenticated navigation shell explicitly says checkout/tracking are not active. No fake orders, payment confirmations or delivery quotes. |
| Performance | Messaging, My Listings, account/seller pages, comparison and platform pages load on demand. Initial JS about 496 kB / 142 kB gzip; route chunks load separately. Previous >500 kB warning resolved without raising the warning limit. |

## Product vision still requiring implementation

- Backend-supported subcategories, product condition entry/editing, variants, stock quantities, delivery options/fees and paginated server-side search.
- Real ratings/reviews and verified seller/business designation. Existing rating fields are not sufficient evidence of verification and no badges/review data were invented.
- Curated/trending/sponsored inventory, consented personalisation and homepage modules backed by real service data. No activity analytics is collected for these yet.
- Storefront description/logo/banner/hours/policies, onboarding progress, notifications, moderation/reporting and authorised admin tools.
- Actual order lifecycle, approved payment providers, refunds/payouts, reconciliation, delivery/courier integrations and tracking.
- Jobs, services, food, events, learning, stays/property, agriculture and digital fulfilment modules. They remain planned until their schemas, operations and safety controls are implemented.

## Architecture decisions

1. Keep one Supabase Auth identity and marketplace_profiles record. Reuse that identity for future buyer/seller/business capabilities; never derive admin privileges from client metadata.
2. Keep shared design, theme, cards, currency presentation and navigation. `src/config/platform.js` holds the current navigation/module directory and Zambia province choices; each future service gets its own implementation rather than a parallel account system.
3. Isolate discovery/selection/location transformations in tested pure libraries. Separate optional page components and load them lazily. Keep authenticated routes behind the verified-profile gate, with Supabase enforcement for writes and private data.
4. Add backend capabilities through additive, reviewed migrations and read-only preflights. Preserve legacy fields while introducing typed region, stock/variant and delivery structures. Never fake persistence with frontend-only fields that current grants cannot save.
5. Inventory/reservations will need atomic server operations; reviews should require eligible completed transactions, uniqueness and moderation; verified businesses need an explicit staff-controlled process. None of these is enabled by displaying a badge.
6. Order/payment state must be verified server-side with provider callbacks and idempotency. Frontend success screens, screenshots and user claims must not confirm payment. Integrations require sandbox testing and separate production approval.

## Safe next milestones

1. Paginated discovery and backward-compatible product metadata/delivery schema proposals; review exact SQL before live application.
2. Approval-dependent privacy hardening: public likes expose account identifiers; listing-image bucket still lacks server MIME/size limits. These issues were deliberately not changed in this batch.
3. Finish core posting/editing metadata and location discovery against the approved schema, then seller onboarding/storefronts and moderation. Stabilise these before activating additional service businesses.
4. Transaction-backed orders/reviews and sandbox integrations, then gradual additional services. International expansion starts with explicit country/currency capabilities, never invented exchange rates or unsupported cross-border promises.

## Validation and operational status

Final results: npm test 41 passed, 0 failed; npm run lint clean; npm run build
successful without the previous chunk-size warning. Final initial JS is 495.91 kB
(142.22 kB gzip), with secondary page chunks separate.

- Source checkpoint saved under ignored backups/; no Git repository is available.
- Unit tests cover route protection, discovery/price combinations, visit-history deduplication, comparison limits, province choices, location encoding and theme resolution, alongside existing auth/OTP/profile/availability/photo tests.
- Isolated browser checked desktop dark Home, 360 px dark comparison/menu, light preference persistence after reload, transient comparison clearing after reload, combined search/price filtering, directory status labels and actual simulated posting of `Chongwe, Lusaka` without touching Supabase.
- Existing disposable backend suite still passes for ownership, private profiles, avatar boundaries and the approved messaging correction. Two-real-account live tests remain skipped at the owner's request; no new claim of live verification is made.
- Automatic photo cleanup remains inactive. Real development server remains http://127.0.0.1:5173/.

## Main files

App.jsx, platform.css, main.jsx and routes.js integrate the foundation. New ThemeControl, ProductCard, CompareProducts, PlatformPages and ZambiaLocationFields components reuse the existing backend. theme.js, discovery.js and locations.js contain shared behaviour; platform.js contains navigation/service/province configuration. Existing auth/profile headers gained theme controls. No SQL file was changed for this product batch.


## Latest local batch — 29 October 2026
See [NEXT_BATCH_PROGRESS.md](NEXT_BATCH_PROGRESS.md): corrected 013/014 v2 replacement drafts remain HOLD; private-media integration, stock starters, campaign planning, catalogue analytics, module filters and Property/Delivery/Food local previews implemented. No live migrations or cleanup. Next: staging validation/approval of revised backend, then dedicated property/delivery models.


## Property and Delivery batch — 29 October 2026
See [PROPERTY_DELIVERY_PROGRESS.md](PROPERTY_DELIVERY_PROGRESS.md). Dedicated Property discovery/detail/editor/gallery/saved/enquiry interfaces and Delivery planning/customer/courier/history interfaces replace the prior generic previews. Separate 015/016 drafts and staging validation plan prepared. All new migrations remain HOLD; no live changes or real bookings/payments.


## Latest service discovery batch — 29 October 2026
See [SERVICES_DISCOVERY_PROGRESS.md](SERVICES_DISCOVERY_PROGRESS.md) and [SERVICE_BACKEND_NEXT_CONTRACTS.md](SERVICE_BACKEND_NEXT_CONTRACTS.md). Property URLs/pagination, courier draft wizard/local lifecycle, Food menus/cart planning and Event ticket scenarios implemented locally. 013_v2/014_v2/015/016 remain HOLD. No isolated staging configuration was found; no remote SQL or production changes.


## Latest foundations / Jobs / Learning batch — 29 October 2026
See [FOUNDATIONS_JOBS_LEARNING_PROGRESS.md](FOUNDATIONS_JOBS_LEARNING_PROGRESS.md), [ISOLATED_STAGING_SETUP.md](ISOLATED_STAGING_SETUP.md) and supabase/review/017_019_REVIEW.md. New 017–019 operational drafts remain HOLD with gates FALSE; Jobs/Learning planning dashboards and product cart preview implemented. Existing held SQL and homepage square service-icon boxes preserved. Remote staging unavailable; all database checks were disposable/local and browser checks used the mock backend, not production.


## Detail / discovery / specialist catalogues continuation
See [DETAIL_DISCOVERY_CATALOGUES_PROGRESS.md](DETAIL_DISCOVERY_CATALOGUES_PROGRESS.md) and [DEPENDENCY_AND_STAGING_MATRIX.md](DEPENDENCY_AND_STAGING_MATRIX.md). Shared large/zoom/swipe gallery, honest visit-interest foundations, Agriculture/Digital local catalogues and service-planning workflows added. New 020/021 remain HOLD; previous 013_v2–019 untouched. No production testing or activation.

## Core marketplace / business foundation — 29 October 2026
See CORE_BUSINESS_FOUNDATION_PROGRESS.md and BUSINESS_STAYS_LOGISTICS_REVIEW.md. Owner listing validation/filtering, connected business summaries and local company/Stays/Logistics workflows added. New 022/023 remain HOLD; no publishing, booking, staff delegation or production changes. Next: isolated staging baseline and core ownership/messaging/media evidence before persistence.


## Stage 4 — persistent business preparation
See STAGE4_PERSISTENT_BUSINESS_PROGRESS.md and STAGE4_STAGING_RUNBOOK.md. Staging-only saved business/branches/media/service/rooms and private enquiry draft interfaces prepared. Production saving stays disabled. 022/023 unchanged/HOLD; native isolated staging remains unconfigured. Next: approved baseline and native ownership/messaging/media evidence.


## Stage 5 — isolated staging readiness
See STAGE5_STAGING_SETUP.md for exact Dashboard steps and current blockers. Local preparation/redacted checks/manual SHA-256 manifest implemented; 81 tests, lint/build passed. Three staging values remain placeholders. No remote setup/migrations/policy changes. Next: owner-provided isolated project configuration, then exact staging SQL approval and native validation.


## Native staging installation — 30 October 2026
Six approved files applied in order and schema/RLS/buckets/disabled flags checked. See STAGING_APPLIED_2026_10_30.md. Next milestone: staging signup and real owner/participant/business-media persistence tests. 022/023 remain HOLD for production.


## Staging OTP blocker investigation — 30 October
Dashboard confirms locked email templates with default sender and OTP length8. No cloud settings changed. Safe resend cooldown, verify labels and staging help implemented; 82 tests/lint/build passed. See STAGING_OTP_BLOCKERS_2026_10_30.md. Hosted validation awaits approved sender/template access and six-digit security-setting approval.


## Build-first continuation — 30 October
See BUILD_FIRST_2026_10_30.md. Three local batches delivered: shareable products/seller catalogues/messaging tools; staged public business/service discovery; portable service planning and campaign scenarios. 86 tests/lint/build passed. Six-digit sender-template delivery remains blocked; safe confirmation-link return/sign-in guidance added. No live policies/migrations/operations changed.


## Main app restoration and expansion — 30 October
See MAIN_APP_EXPANSION_2026_10_30.md. Main original app restored on5173; same-source staging stays5180. Saved searches/recommendations, local Food photos/enquiries, career prep, agenda planner, agriculture categories and room/vehicle labels added. 93 tests, lint/build pass. No production changes or held SQL execution.

