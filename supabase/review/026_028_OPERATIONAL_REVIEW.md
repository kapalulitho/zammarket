# Operational workflow migrations 026–028 — HOLD review

All three are unexecuted review drafts. They are NOT approved for staging or production. No default-FALSE operational setting is enabled by any of these migrations. Existing migration files, including 024 and 025, remain unchanged/HOLD.

## 026 Food workflows

Depends on 010 verified complete membership and held 017 Food tables/RPC. Adds food_order_events (order/revision key, actor, prior/new state and timestamp), participant-only SELECT RLS, capability RPC, owner-only restaurant and menu save RPCs and food_advance_order. Existing Food tables retain their grants/policies; no restaurant approval, public status or accepting-orders permission is granted to owners. New restaurants remain unapproved drafts. Existing operational enabled flag is untouched.

Order creation still uses 017's authoritative prices, item snapshots, restaurant/menu locking, bounded quantities, account-scoped idempotency and stock decrement. 026 completes seller accept → prepare → ready → complete and participant cancellation. Customer cancellation is limited to submitted orders; merchant cancellation is available until terminal. Cancellation restores finite menu units and appends an event atomically, under restaurant-first/menu stable lock ordering. Revision checks prevent replayed stock restoration. Restaurant creation serializes its per-owner count check; menu count/editing serialize on restaurant ownership.

Menu edits are rejected for dishes in open orders, protecting stock-mode changes, restoration and snapshot consistency. Dish removal is not supported. No payment/refund is processed. Existing trusted service-role writes from 017 still require separate operational governance and can bypass ordinary client assumptions. Only non-privileged client constraints were designed here.

Risks to validate: concurrent create/cancel/edit/transition; old populated 017 orders; units-null versus finite-stock lifecycle; restore overflow under privileged changes; lost-response idempotency; lock timing; stale revisions and role spoofing. Order history exposes only participant records. No new media bucket or uploads.

## 027 Delivery capability

Depends on held 019. Adds one authenticated read-only definer function exposing version, existing disabled/enabled flag and the current user's server-owned courier approval boolean. No approval assignment, dispatch, contact data or capability settings are changed. Existing 019 participant RLS and lifecycle RPCs remain the sole operational authority. UI cannot grant a courier role or assign a job.

Validate anonymous rejection, unrelated-user event/job denial, approval changes, assigned-courier-only actions, customer cancellation, stale revisions and disabled flag behavior. Current UI uses areas only and never fetches the private contact table. Actual dispatcher/courier onboarding, GPS and payment integrations remain unimplemented/disabled.

## 028 Shopping order requests

Depends on original listings/009/010 and corrected 014_v2 stock schema. Adds disabled-by-default shop_order_settings; participant order-request headers, immutable line snapshots and append-only status events; buyer/seller indexes; participant SELECT RLS; capability, submit and transition RPCs.

Clients have no direct operational INSERT/UPDATE/DELETE. Server derives buyer/seller, enforces verified membership, one seller per bounded basket, excludes self-purchases/deleted/unavailable/future listings using Africa/Lusaka dates, validates stock and variants and computes ZMW minor-unit item snapshots. No client price, seller or total is accepted. Unique buyer/key plus per-buyer serialization gives idempotent retries and bounded open requests. Seller transitions and customer cancellation are revision-checked and append events.

IMPORTANT: requests do NOT reserve or decrement inventory. They are a durable customer-to-seller request/fulfilment record, not guaranteed checkout stock, a paid order or dispatch. Multiple requests may compete for the same stock; sellers must confirm stock separately. Do not activate as guaranteed order allocation. Inventory reservation and authoritative quote expiry need another reviewed extension before a true checkout service.

New foreign keys reference existing listings/users and do not cascade delete. If approved later, referenced historical records cannot be hard-deleted until retention is designed; existing soft deletion remains the intended listing workflow. No current rows are modified by installation. 014 original and 014_v2 are alternatives, not sequential migrations; stop if wrong schema exists.

Validate unrelated-account denial for headers/lines/events, forged seller/price/variant, duplicate lines/keys, expired availability, deleted listings, null/NaN prices, bounded totals, concurrency, stale transitions and default role privileges.

## Shared approval and rollback requirements

No PostgreSQL runtime execution or live RLS validation has been performed. JavaScript tests/lint/build do not validate these SQL drafts. Before approval inspect exact dependencies and default/inherited grants, use an isolated staging backup/snapshot, test with two verified non-sensitive accounts and retain all default operational flags false. Authorizing schema installation must not imply enabling operations. Use separate explicit approval to enable staging test operations; real production operations remain a separate future decision.

Rollback: keep operation flags false, revoke new RPC execution through a separately reviewed change and preserve order/history rows. Do not drop populated tables or delete user data to roll back. No automatic rollback/destructive script is supplied.
