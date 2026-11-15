# Major operational systems implementation — 30 October 2026

Continued the existing ZamMarket application in C:\Users\kapalu\Documents\ZamMarket. Main application remains http://127.0.0.1:5173/home. This batch builds server-connected operational contracts and dashboards, not another temporary-notebook feature. Production remains unchanged. No migration or setting was applied, no data was deleted, and no real order, booking, payment or dispatch was activated. 024/025 remain on HOLD.

## 1. Shopping order-request and seller fulfilment system

New /order-centre integrates the existing shopping cart, product records and corrected stock/variant schema. Customer baskets split by seller; selected variants and quantities are sent to a server request RPC. Server derives ownership and item prices and snapshots line information. Customer history, seller fulfilment queue, details, status timeline and revision-safe transitions are connected to repository methods. Payment is not tracked. Existing Inventory and Messages remain linked rather than duplicated. A request identity is retained after uncertain results; creating a new request intent is explicit.

Important boundary: this is an order-request workflow, not guaranteed inventory allocation or paid checkout. Stock is checked at submission but NOT reserved/decremented. Seller acknowledgement/preparing/ready/completed statuses are seller-recorded fulfilment information, not proof of payment. Full checkout needs separately reviewed inventory reservation, quote expiry, fees/payment and cancellation/refund handling. This limitation is stated in the UI and SQL review.

Backend: new 028_shopping_order_requests_HOLD_DRAFT.sql. Participant headers/immutable line snapshots/events, disabled operational setting, authoritative submission and lifecycle RPCs. Requires corrected 014_v2 plus its dependencies. Not applied.

## 2. Restaurant catalogue, ordering and kitchen fulfilment system

New /food-operations:

- Visible restaurants/menu discovery using existing held 017 table contracts.
- Multiple owner restaurants with name, location, cuisine and operating-hours editing.
- Owner menu/price/allergen/availability/finite-stock editing.
- Customer dish quantities and idempotent, server-priced order submission.
- Customer order history and merchant kitchen/fulfilment queue.
- Order line snapshots, status timeline and optimistic revisions.
- Accept, prepare, ready and complete; customer/merchant cancellation constraints.

New 026 extends existing 017 instead of duplicating its order tables/RPC. Cancellation restores finite stock atomically and writes an audit event. Editing dishes in open orders is blocked. New restaurants remain unapproved drafts; catalogue saving never publishes/approves or enables accepting orders. Delivery, payment, refund processing and restaurant image persistence remain unconnected. Item subtotal is not an all-inclusive quote.

## 3. Delivery request and courier lifecycle system

New /delivery-operations connects to existing held 019:

- Private customer request submission, stable retry keys and participant history.
- Assigned courier dashboard, with server-recorded approval status.
- Accept, collect, depart, deliver and customer cancellation actions according to server lifecycle.
- Stored event history and stale-revision handling.
- No frontend assignment/self-approval, private contact table reads, invented GPS or fare estimates.

027 adds only a read-only capability RPC for the disabled gate/current-account courier approval. Existing 019 retains all mutation authority. No dispatch operations were enabled. Trusted dispatch assignment/onboarding and real tracking remain external work.

## Integration and security

Business links to all three systems. Food and Delivery discovery link to their operational workspaces; purchase planning links to the shopping order centre. These are private routes within the original app, not another project. New operational pages load as separate chunks to avoid adding their UI code to initial homepage loading.

All operational repositories reject production mode BEFORE any database request and revalidate the current authenticated user for every read/write. RLS/server functions remain authoritative; client action lists are usability guards only. Capability calls are read-only; missing backend or disabled flags remain blocked. No privileged key, role grant, payment SDK, external service or new Storage policy is added.

## Current availability — do not confuse implementation with activation

- **Working existing core preserved:** original authentication/profiles/listings, saved products, participant messages, owner listing management and existing safe tools.
- **Implemented new connected code:** the three operational UI/repository/SQL contracts described above. These are not standalone fake records or temporary in-memory operational simulations.
- **Pending staging approval/validation:** 017+026 Food, 019+027 Delivery and corrected 014_v2+028 shopping. They have NOT been installed or run by this batch. No end-to-end persistence or permission pass is claimed for these contracts.
- **Not enabled:** request/order creation, restaurant approval/publication, dispatch, payments, guaranteed stock allocation or real customer operations. All newly drafted operational settings default false; existing settings were not touched.
- **Other major systems remain:** Jobs applications/applicant management, Accommodation inventory/reservations, Event issuance/attendance, Learning enrolment/entitlements, Digital protected downloads and privileged moderation still require their reviewed backends. Existing interfaces remain available in their stated modes; this batch does not claim completion of all ten systems.

## Checks

Four targeted tests passed: production/stale-account repository denial before RPC, role/state transitions, menu minor-unit validation and excluding client prices from Food request payloads. Lint passed. Production build passed after final code-splitting changes. Comprehensive browser, multi-account, SQL runtime, concurrency and regression tests were intentionally not started. These JavaScript checks do not prove SQL correctness or live RLS security.

## Files changed

New UI: src/components/ShopOrderCentre.jsx, FoodOperations.jsx, DeliveryOperations.jsx.
New backend adapters/helpers: src/lib/shopOrders.js, operationalWorkflows.js, deliveryOperations.js.
New targeted test: tests/operationalWorkflows.test.js.
New held SQL: supabase/review/026_food_workflows_HOLD_DRAFT.sql; 027_delivery_capability_HOLD_DRAFT.sql; 028_shopping_order_requests_HOLD_DRAFT.sql.
Review: supabase/review/026_028_OPERATIONAL_REVIEW.md.
Integration updates: src/App.jsx; src/lib/routes.js; BusinessWorkspace.jsx; FoodMarketplace.jsx; DeliveryWorkspace.jsx; PurchasePlanner.jsx. Existing migration files are unchanged.
Documentation: this report and NEXT_BATCH_PROGRESS.md.

## Next recommended milestone

Review exact 026–028 and their existing held dependencies; keep production unchanged and operation flags false. An explicit staging migration approval is required before installation, followed by focused transaction/ownership tests and separate approval for test-operation enabling. This is the actual blocker to exercising the newly connected systems. Continue the next backend batch with private Jobs applications and Accommodation calendar/reservation allocation, without duplicating existing community/business tables. Preserve the separate admin/safety approval track for 024/025.
