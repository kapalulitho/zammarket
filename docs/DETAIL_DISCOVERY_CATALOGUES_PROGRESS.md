# Detail experience, honest discovery and specialist catalogues

29 October 2026 local continuation. Inspected current code and FOUNDATIONS_JOBS_LEARNING_PROGRESS.md first. Existing modules retained; no replacement project or broad retest campaign.

## Completed locally

- Shared ImageGallery for product, Property, specialist and existing module-detail photos: large photo-first presentation, bounded previous/next, thumbnail strip, full-viewport native dialog, zoom slider/reset/double-click, scroll/pan when zoomed, horizontal swipe at 100%, Escape/close, native focus containment/return and body-scroll lock. Existing private-image signing hook reused; compact cards do not gain full viewer controls.
- Product desktop detail width increased to 1180px, balanced photo/details columns, top-aligned information and no former height cap. Phone photos are above readable details. Property/module galleries reuse the same viewer. Currency wrapping corrected and dark-theme price contrast improved. Existing compact product cards unchanged.
- Trending Now contains no invented visitor counts/ranks. It explicitly says community data is unavailable. Optional visit-interest recording is memory-only, not transmitted, with one signal/action/entity/hour, 8/minute and 200/visit caps, decay over time, exact town filtering and clear/off controls. Common personal search patterns are rejected. Only consented product clicks, successful saves, submitted searches and service/event opens are considered. Homepage icon order is still the original fixed eight destinations.
- Agriculture: crop/produce, seeds/inputs, equipment and feed categories; town/multi-word search, supplier name, price unit/quantity, image preview/gallery, create/edit/detail and unsent buying-enquiry workflow. Local drafts only, not real public listings.
- Digital Products: software/templates/educational/design categories, creator/licence details, local image preview/gallery, create/edit/detail, unsent questions and secure purchase/private delivery explanation. No paid file upload or purchase/download activation.
- Professional Services: provider profile summary, category/fee/location/format filters, local detail review, preferred date/scope/format service request preview and review-verification explanation. Real enquiries retain existing approved infrastructure/gates; bookings/reviews remain unavailable until the completion/verification backend exists.
- Food, Event organisers, employers, instructors, Property sellers and couriers gained collapsed local outline/readiness notebooks for planning responsibilities and operating notes. These are manual checklists, not actual order/booking transitions or verification. Existing inventory, storefront, cart and campaign flows retained.
- Navigation includes Agriculture/Digital via directory/service wayfinder. The approved green homepage and small square service-icon boxes remain unchanged in source/style. No icons are reordered by ranking.

## Backend and staging

013_v2–019 sources and all existing HOLD decisions preserved. New 020 specialist catalogues/private digital assets and 021 private activity/thresholded trends drafts are HOLD; publication settings default FALSE. Detailed separate assessments: supabase/review/020_021_REVIEW.md. No frontend reads/writes new schema or sends analytics.

Reviewed dependency readiness in DEPENDENCY_AND_STAGING_MATRIX.md, reusing prior assessments rather than repeating them. ISOLATED_STAGING_SETUP.md remains the exact separate-project/config/Auth/baseline/migration/validation guide. No isolated project/configuration is currently available; no remote staging validation or production test was performed. No production database, security policy, user data, photo, payment, order, booking, ticket, application, dispatch, cleanup or deployment changed.

## Focused results

- Four focused tests: gesture direction/bounds/safe sources; opt-in/dedup/rate/decay/location/clear; personal-search rejection; type-specific catalogue validation/identity stripping.
- Disposable 020/021 SQL checks: gated publication, owner/private/scanning/entitlement boundaries, revocation, buyer cannot mint Storage signed URLs, private deduplicated activity, threshold and publication gate; existing policy preservation. Native Storage/signing/scanning and fraud-proof ingestion remain unverified.
- Browser on isolated mock server 5174: large two-photo product, full-screen open, next, 200% zoom, Escape and tap re-open; pointer-captured swipe switches photo without opening dialog. An initial gesture bug was fixed and verified. Agriculture local create/detail/supplier preview with send/purchase disabled. Phone photo-first layout/dark contrast inspected at 360px. Test tab, viewport and mock server cleaned up.
- Lint and production build run after final edits. No test against the production SDK/project and no real email/account creation or payments. Physical touch-device/pinch accessibility, large real-photo assets and native private signing still require staging/device validation; pointer swipe was tested, not a claim of device coverage.

## Files

New: components ImageGallery, TrendingNow, WorkflowNotebook, LocalVerticalMarketplace and ServiceBookingPlanner; libraries gallery.js, discoverySignals.js, verticalCatalogues.js; detail-discovery.css; tests/detail-discovery.test.js; scripts/discovery-catalogue-checks.mjs; held 020/021 SQL and review; dependency/staging matrix and this report.

Updated: ProductGallery, PropertyGallery, PublicMemberCard, ModuleMarketplace, FoodMarketplace, PropertyMarketplace, DeliveryWorkspace, ServiceWayfinder; App.jsx, lib/property.js, lib/routes.js, config/platform.js; optional --with-discovery-catalogues fixture flag; roadmap/master plan/latest report links. The ignored mock has two local branding-image fixtures to test gallery controls; no real listing photo was changed.

## Remaining priorities

1. Configure a separately approved staging project and validate native Auth/Storage, roles, file access, signing expiry, private projections and concurrency before any SQL approval/application.
2. Implement genuine, consent-aware trusted analytics collector/rollup pipeline; fraud/privacy validation before public trends. Current per-visit guards cannot prevent cross-account public fraud because no public ingestion exists.
3. Complete audited digital purchase entitlements, scanning and mediated short-TTL download service; service completion/review eligibility; supplier moderation. Keep purchasing/bookings/reviews disabled until validated.
4. Finish Food fulfilment/refund, Event issuance/expiry, Delivery approval/dispute/proof, Jobs private applications and Learning enrolment/content backends from earlier reports. Notebook checkboxes do not implement these operations.
5. Stock/variant-aware carts, campaign lifecycle and larger server-filtered discovery after staging validation. Real recommendation quality/engagement analytics require legitimate data; none is claimed now.

Final verification: lint clean, four focused tests pass, production build succeeds. The isolated Home consent flow was also checked: consent remains enabled across product-detail navigation and one real mock click appears as a visit interest; community rankings remain unavailable. Render-time clock warnings and startup fetch declaration ordering were corrected without changing backend settings.
