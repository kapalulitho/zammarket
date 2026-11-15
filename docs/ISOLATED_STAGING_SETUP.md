# Isolated Supabase staging setup — prepared, not provisioned

No separate staging project or credentials were available. No remote database, user, policy, template or billing setting was changed. All migration drafts remain HOLD. Do not treat these instructions as production approval.

## 1. Choose the isolated project

Use a separate Supabase project approved by the owner, with a different project reference, database and Storage. Do not use the current ZamMarket project, branches that contain production data, or a production data export. If project creation requests payment or exceeds an approved allowance, stop for explicit owner approval. No project was created by this batch.

Record the staging project reference from Dashboard and manually compare it with production. Create only controlled test accounts through staging Auth. Never copy auth.users, identities, passwords, production listings, messages or photos. Keep dashboard/API service-role and database credentials out of the frontend and this chat.

## 2. Configure the local staging frontend

Copy `.env.staging.example` to `.env.staging.local` in the project root. Fill the separate staging project reference, its URL and browser-safe **publishable** key privately in that ignored file. Set the explicit `ISOLATED_NON_PRODUCTION` acknowledgement. Do not put service-role/database keys in any VITE variable.

Run `npm run check:staging`. It validates explicit mode, matching reference/URL, a different production origin and publishable-key shape without printing credentials or making requests. It does not establish project ownership or remote key/project correspondence; confirm those in Dashboard.

Run `npm run dev:staging`, then open http://127.0.0.1:5180/. The command refuses to start without valid configuration. Vite staging mode also refuses production fallback at runtime, even if environment flags are missing or mistakenly say production. Staging sessions use their own Auth storage key. A visible STAGING banner appears on authentication and marketplace pages. Existing production configuration remains the default for `npm run dev` and its Auth session key is preserved.

Do not run `npm run build:staging` without configuration; it is guarded too. Keep staging artifacts separate from production deployment. There is no deployment or migration command in these scripts.

## 3. Review and initialise an empty staging schema

Obtain approval for the exact staging SQL before executing it. Select the staging project in Dashboard and check its project reference again before each batch. No automatic remote SQL runner is supplied.

On a brand-new project with no ZamMarket tables, review `supabase/staging/000_empty_baseline_STAGING_ONLY_HOLD.sql`. It creates only empty listings/likes prerequisite tables and the legacy listing-images bucket. It intentionally fails on name collisions; do not change it to replace or drop existing objects. Do not run it on an already configured project. Native Supabase Auth/Storage schemas are used, never recreated.

Review/apply approved staging baseline in order: empty prerequisite baseline → 009 unified backend → 010 profiles/registration → 012 message trigger fix. Do not also apply their source migration fragments. Confirm profiles/verification and existing core functionality using staging test accounts. The staging baseline reproduces the legacy public listing-images bucket; its missing size/MIME limits and public-likes privacy remain pending separate fixes, not silently changed in production.

Review 013/014 v2 preflight; only the corrected v2 clean-install drafts are candidates, never originals plus replacements. Then validate 015/016 separately if approved. Finally review 017 Food, 018 Tickets (requires 013 v2), and 019 Delivery operations. Their operation settings default FALSE and must remain FALSE for initial schema/permission checks. Applying a draft is not approval to activate its gate, add real providers, issue tickets, accept orders, dispatch couriers or collect payments.

Each draft uses a transaction. Any failure before commit must be rolled back before retrying. Do not apply against conflicting existing schemas or invent a DROP-based reset. Preserve staging evidence; no destructive reset/cleanup script is supplied.

## 4. Configure staging Auth only

In the staging Dashboard verify Email signups and Confirm email; use the sign-up template's `{{ .Token }}` for the OTP flow. Configure local staging Site URL/appropriate redirects for http://127.0.0.1:5180/ only. Never change production Auth settings while doing this. Use test inboxes you control; enter passwords and codes privately. Delivery is not established until a test recipient actually receives a message.

## 5. Validate before any operational gate approval

Follow STAGING_VALIDATION_013_016.md and 017_019_REVIEW.md. Test at least owner/merchant, customer, approved courier, unrelated verified user, incomplete/unverified account and anonymous clients. Ordinary client sessions must never use service-role privileges.

- Verify real Storage signing/private drafts/published references/expiry, not only SQL policy rows.
- Use >12 Property records to check server filters/counts/pagination, owner-only draft links and private favourites.
- Reproduce 014 variant sanitisation, receipt identity immutability, revocation and review withdrawal. A trusted idempotent receipt issuance workflow is still required.
- Keep 017–019 gates FALSE and assert operational RPCs reject requests and clients cannot change gates or direct-write operational tables.
- Only after explicit separate staging test approval may gates be enabled in the disposable project for synthetic transactions. Exercise concurrent Food stock/price changes and ticket allocations from independent sessions, idempotent retries, capacity/quantity caps, data isolation, service-only dispatch, stale revisions and contact revocation. Do not enable gates in production. Re-disable staging gates after controlled tests; preserve records and reports.
- Food fulfilment/cancellation/refund RPCs, ticket hold-expiry policy/issuance and Delivery late-cancellation/dispute/provider approval/proof-of-delivery processes are incomplete. They block production activation even if basic fixtures pass. No automatic expiry/deletion or payment setup is authorised.

Record exact file versions, environment, results and remaining failures without secrets. Production migration approval, operational activation, live providers/orders/payments and deployment are separate decisions after backup/rollback review. Local PGlite fixture results are not a remote staging pass.
