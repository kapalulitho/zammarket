# Property, Delivery, Food and Events — latest batch

29 October 2026. Read PROPERTY_DELIVERY_PROGRESS.md and the existing components first. Retained working auth/profile/product/messaging functionality, new service shells and held migrations. No old feature was rebuilt from scratch.

## Implemented

- **Property:** persisted-UUID share links via query string, direct detail loading and browser history support; copy-link control; 12-row server-filtered/count-based pagination prepared behind 015; local preview pagination; multi-word REST-safe search; price-basis filter; favourites queried before server pagination; public seller/agent profile summary with avatar and opt-in public phone/WhatsApp/email. Login email is never displayed. Local previews cannot be shared. Agent type remains self-declared, not verified ownership. Live link loading/pagination/favourite persistence still need approved backend/staging tests.
- **Delivery:** three-step courier registration draft wizard (basics, coverage/vehicle, review), field allowlist, Auth recheck, existing-draft load protection and private persistence prepared against 016; activation and sensitive-document collection disabled. Local status simulator with customer/courier role transitions, terminal states and visible simulated history. Existing customer plans/history retained; reviewing a prior plan now prefills the form. Private workspace caches reset on account identity change.
- **Food:** replaced generic preview with restaurant draft creation, menu categories/items, allergen information, availability controls, location/cuisine/dish discovery, restaurant menu views, single-restaurant cart, quantity changes/removal, integer-money subtotal and fulfilment/order planning. No fabricated live restaurants. All data clears on module exit; no backend, kitchen confirmation, real delivery, payment or order submission.
- **Events:** category and start-date ordering added to existing discovery; local event detail review is usable while publishing remains blocked. Ticket-category/capacity scenarios, selection limits, subtotal and booking-preview review. Prices/capacities are clearly user assumptions; no real ticket inventory/reservations. Event times retain Africa/Lusaka interpretation. Local event cover files are not uploaded by preview.
- **Platform:** service wayfinder across all new modules; Property/Food added to Explore search scopes; shared planning helpers, responsive mobile controls, consistent forms/buttons, clearer loading/error/empty states and account-bound private cache resets. Existing product feed and approved homepage banner retained.

## Safety and backend status

013_v2, 014_v2, 015 and 016 SQL sources remain unchanged and on HOLD. No migrations, policy changes, publishing, booking, payment, dispatch, tracking or cleanup activation occurred. Existing users/data/photos were preserved. Only local preview records were created during browser tests; they disappeared with the temporary tab/module. Current production backup remains unverified.

No verified isolated staging configuration exists in project files or the checked staging environment variables. Remote staging validation was therefore not run; the existing app project was not used as a substitute. Staging plan remains STAGING_VALIDATION_013_016.md. Updated contracts in SERVICE_BACKEND_NEXT_CONTRACTS.md cover Property pagination/favourites/profile privacy, courier permissions, authoritative Food totals and ticket allocation privacy. Food/order and Event ticket schemas still need separate reviewable drafts.

## Focused verification

- Seven focused tests passed in tests/services-discovery.test.js: UUID links, query grammar/order/range, price-basis filtering, courier field allowlist, role/terminal lifecycle, food minor-unit totals/invalid carts and ticket capacity/totals.
- Lint passed and production build passed after final edits. No new libraries installed.
- Browser: local restaurant/menu → cart quantity 3 × ZMW 10.10 = ZMW 30.30 → unsubmitted order plan, with checkout disabled; local Event detail → Standard scenario 2 × ZMW 25.50 = ZMW 51.00 → unsubmitted visit plan, ticket purchase disabled; courier review with private saving/activation disabled; local status transition with other-role action disabled; cross-service navigation.
- Food cart inspected at 360px; spacing and field/button layout corrected. Browser viewport restored and temporary tab closed. Real Supabase persistence, live linked-property reload and image signing are not claimed as tested in this batch. No real email/account/security tests were repeated.

## Files

New libraries: src/lib/propertyDiscovery.js, usePropertyLink.js, servicePlanning.js.

New components: ServiceWayfinder.jsx, PropertyPublisher.jsx, CourierRegistration.jsx, DeliveryLifecycle.jsx, FoodMarketplace.jsx, EventTicketPlanner.jsx. New src/service-planning.css and tests/services-discovery.test.js.

Updated: src/components/PropertyMarketplace.jsx, DeliveryWorkspace.jsx, ModuleMarketplace.jsx, ModuleEnquiries.jsx; src/lib/property.js; src/App.jsx; src/config/platform.js; roadmap/master plan/latest progress links. Added this report and backend contracts; original generic VerticalWorkbench is retained as unused source, not deleted.

## Recommended next batch

1. Validate exact held drafts in an approved isolated staging project: real image signing/expiry, private profile/contact behavior, direct Property links and server pagination across accounts, courier-draft persistence, receipt integrity. Request explicit production approval only after reporting results and backup readiness.
2. Prepare versioned Food restaurant/menu/private order and Event ticket/reservation drafts with RLS, server pricing and capacity locking. Keep reservations/payments inactive.
3. Prepare operational Delivery assignment/transition/audit schema and secure provider approval separately. The simulator is design validation, not an implemented logistics backend.
4. Property cursor pagination, dedicated enquiry inbox and moderation/agent-verification workflows after staging validation. Public-likes privacy and legacy image upload limits remain separate pending fixes; automatic cleanup remains disabled.

Final targeted run: 10 tests passed (seven new service/discovery checks plus three relevant Property/Delivery regression checks), lint clean, production build successful. Browser also verified invalid shared-link recovery to Property browsing. Temporary mobile viewport and test tab were restored/closed.


## Latest foundations / Jobs / Learning batch — 29 October 2026
See [FOUNDATIONS_JOBS_LEARNING_PROGRESS.md](FOUNDATIONS_JOBS_LEARNING_PROGRESS.md), [ISOLATED_STAGING_SETUP.md](ISOLATED_STAGING_SETUP.md) and supabase/review/017_019_REVIEW.md. New 017–019 operational drafts remain HOLD with gates FALSE; Jobs/Learning planning dashboards and product cart preview implemented. Existing held SQL and homepage square service-icon boxes preserved. Remote staging unavailable; all database checks were disposable/local and browser checks used the mock backend, not production.
