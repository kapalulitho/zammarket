# Next service backend contracts — design only

29 October 2026. No SQL applied or new production endpoints enabled. Existing 013_v2, 014_v2, 015 and 016 remain HOLD. Food and Event ticket planning are client-only scenarios; courier draft persistence is gated by approved 016 capability. This document is not migration approval.

## Staging availability

No isolated staging URL, publishable key or database URL was configured in the inspected project/environment. The app's existing project connection is not a staging target. No staging project was created, no expense incurred and no remote SQL was run. Follow STAGING_VALIDATION_013_016.md when a separately approved isolated environment is available. Do not repoint production or use production users/photos as fixtures.

The focused tests in this batch cover new local logic and query construction, not real Storage signing, two-account RPC behavior, production pagination or secure receipt issuance. Prior disposable SQL checks remain documented in the prior report; they were not needlessly repeated because these SQL sources were unchanged.

## Property integration contract

015 capability must advertise private images and private saves. Public discovery queries apply filters before a 12-row range, request RLS-filtered counts and use deterministic secondary ID ordering. Search words are restricted to Unicode letters/numbers before inclusion in PostgREST OR grammar; location LIKE wildcards are escaped. Price basis is selectable so monthly/nightly/total quotes can be separated. Offset pages can shift if content changes concurrently; stable cursor pagination remains a scale improvement.

Persisted UUID links use /property?property=<uuid>. Local preview IDs cannot be shared. Linked rows load directly through property_listings RLS; owner drafts remain owner-only, closed/unavailable properties give a neutral unavailable message. Saved-property IDs remain private through property_saved and the catalogue query restricts favourites before pagination. Seller details use public_seller_profile and its existing contact-visibility projection, never the private profile table or login email. Verify direct URL refresh, Back navigation, pagination across >12 staging records, favourite removal on final page, anonymous/owner/outsider access and profile field visibility in staging.

## Courier registration and delivery lifecycle

016 permits a PRIVATE non-operational courier profile draft (name, area, vehicle, description); it cannot register a verified courier or allow assignments. UI validates and explicitly reconstructs permitted fields, rechecks current Auth user, loads an existing draft before enabling updates, and never accepts owner/verification/activation fields from the form. Contact/identity/banking documents are deliberately not collected. Capability absence disables persistence. Public delivery/property workspaces remount on account identity change to clear private cached state.

Proposed future workflow: draft → submitted → accepted → picked_up → in_transit → delivered; cancellation before collection is a terminal state. Current UI is an explicitly labelled role simulator, with no real order ID, API call or location tracking. Its role dropdown is not an authorisation mechanism.

Before any operational schema, define authenticated customer ownership, approved courier and transactional assignment, atomic RPC transitions with expected revision, idempotency key uniqueness, append-only audit events, expiry of contact access, cancellation/dispute rules and proof-of-delivery privacy. Only the assigned courier may advance collection/transit/delivery; unrelated couriers cannot inspect customer routes. Late cancellation must go through reviewed dispute handling. Never let clients write arbitrary status/assignment/verification fields or choose a database role. Courier approval/admin permissions require a separate audited server workflow; no service-role key belongs in frontend code.

## Food marketplace

Current restaurant/menu editor, availability flags, restaurant discovery, single-restaurant cart and order preview are in memory only. No sample restaurant is seeded as operational. Prices are integer minor units; line quantities and item counts are bounded. Cross-restaurant carts require an explicit clear rather than silently dropping items. Unavailable/missing items invalidate planning. Allergen information is publisher supplied, not verified; customers must confirm details directly.

Next schema proposal should split public published restaurant/menu fields from private restaurant ownership/onboarding and customer orders. RLS must protect unpublished menus, customer contacts, orders and merchant dashboards. Use server-authoritative menu prices, inventory, operating hours, currency, fee/tax breakdown and fulfilment rules. The server must recompute totals from IDs and quantities; never accept the local cart subtotal or assumed delivery availability as authoritative. Price changes require reconfirmation. Restaurant acknowledgement, rejection, preparation, cancellation, refunds and delivery handoff require separately reviewed state machines and audit logs. No order/checkout integration should be activated before these contracts and policies are approved.

## Events and tickets

013 v2 covers basic event information/enquiries only, not tickets, holds, reservations or attendee data. New ticket categories are local user-entered scenarios, not organiser-supplied offers. Planning capacity is not remaining inventory; quantities are capped and calculations use minor units. No tickets, QR codes, receipts or reservations are issued.

A future event-ticket migration needs organiser-owned ticket categories, public safe category projection, authoritative prices/currency/fees, atomic capacity allocation, private customer reservations/attendees, idempotent booking RPCs and verified organiser/admin roles. Prevent overselling with transaction locks and unique allocation IDs; cancellations/release must be audited. Any expiry/cleanup jobs are a separate approval step, never enabled by this batch. Do not expose attendee lists or mix public event descriptions with private purchaser contacts. Real payments and ticket issuance stay disabled until the backend and operational rules are approved.
