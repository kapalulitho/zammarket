# Stage 4 — staging validation and persistent business preparation

29 October 2026. Continued the existing project and reviewed the Core Business Foundation report plus exact 022/023 drafts. Those SQL files are unchanged and remain HOLD. No remote schema, policies, users, photos or other production data were changed. No real staging credentials are configured, so a Supabase project was not connected or provisioned.

## Implemented locally

- A reusable staging-only business repository with fresh session checks, explicit owner filters, validated/allowlisted payloads and no automatic publication. Production, test and unknown modes are refused before SDK access. Existing backend configuration still requires a distinct staging project and browser-safe publishable key.
- Business workspace: create/edit persisted business drafts, personal/small-business/company type, contact opt-ins, optional new logo, saved branch creation/editing and summaries. Logo replacement preserves old files. No staff rights/invitations or existing account-type changes.
- Accommodation/Logistics: select an owned saved business, create/edit saved service drafts, validated service areas, append private media, display short-lived signed galleries, room-option creation/editing with integer nightly ZMW pricing and capacity. Rooms are not available dates or stock. Existing search also filters matching owned saved services by name/town/category/service areas.
- Private enquiry draft preparation/readback against published staging offers only. The database requires published offers, so with the current false gates no successful enquiry draft can be created. The UI explains this instead of weakening the check. Drafts are not sent to providers, and no booking, transport quote commitment or dispatch occurs.
- Distinct local previews remain available on production. New persistent controls require staging mode plus the approved schema; missing schema/permissions produces an error and never falls back to production. Existing homepage/icons, Explore links, galleries and navigation are preserved.
- Added a read-only metadata preflight and setup/validation runbook. No automatic migration executor supplied.

## Validation results

- 79 automated tests passed, zero failures. Six new repository tests cover mode refusal before SDK access, changed sessions, ignored role/status/owner injection, owner-scoped updates, service/room schema mapping, private enquiry payloads, room-parent identity and image limits/path boundaries.
- Lint and production build passed.
- Disposable in-memory PostgreSQL: 009/010/012 authentication/profile/listing/messaging checks and 022/023 owner/manager isolation, no membership self-escalation, contact projection, gated media, private enquiry and capacity checks passed. The new read-only preflight also executes successfully in that fixture. Existing policy definitions remain unchanged.
- Browser at isolated localhost:5174: synthetic business creation, business restoration after reload, branch save and summary updates passed using a mock adapter. These fixtures use local browser storage only; they are not native Supabase or RLS evidence. Temporary tab and test server closed afterward; normal localhost:5173 left alone.
- `check:staging`: NOT CONFIGURED. No live email, native Storage signing/expiry, direct file upload enforcement, real two-account RLS or actual Supabase persistence pass is claimed.

## Remaining requirements

Follow `STAGE4_STAGING_RUNBOOK.md` one step at a time. Need a distinct empty staging project, its privately configured publishable credentials, two controlled test accounts and explicit approval for exact staging SQL (baseline → 009 → 010 → 012 → 022 → 023). Neither this report nor the runbook authorises execution. Read-only `supabase/staging/024_business_READ_ONLY.sql` is inspection, not a migration.

022/023 review: owner-only raw business data and explicit opt-in public projections remain appropriate foundations; reserved staff memberships do not confer existing listing/message rights. Both publication gates remain false. Organisation-to-existing-storefront linking, provider moderation, native media validation/signature tests, staff delegation and enquiry submission still need reviewed contracts and validation. Public projection and contact/media revocation tests require separately approved synthetic publication in staging. Signed URLs already issued may survive for their 60-second lifetime.

Image signature/size checks in the browser supplement bucket limits; they do not prove trusted server image decoding/scanning. No client overwrite/delete or automatic orphan cleanup is added. If uploads succeed but a later record save fails, files are retained and the error asks for reload before retrying. Service and room saves are separate, not atomic. Enquiry draft history currently shows the newest 50 author-owned plans. Public discovery and operational actions stay gated.

## Changed files

- `src/lib/businessRepository.js` — new staging-only adapter.
- `src/components/PersistentBusinessTools.jsx` — shared saved business/service/room/enquiry UI and signed media.
- `src/components/BusinessWorkspace.jsx`, `BusinessServiceDirectory.jsx`, `src/App.jsx` — integration and staging/local-preview wording.
- `src/business-foundation.css` — responsive persistent editor styling.
- `tests/businessRepository.test.js`, `scripts/business-service-checks.mjs` — targeted tests/preflight execution.
- `.validation/business-test.config.mjs`, `.validation/business-mock.js` — isolated synthetic UI fixture, no SDK/network backend.
- `supabase/staging/024_business_READ_ONLY.sql`, `docs/STAGE4_STAGING_RUNBOOK.md`, this report and roadmap/master/matrix updates.

## Next milestone

Obtain native isolated staging evidence for authentication, listing ownership, messaging and business media, then persistent service save/refresh tests. Resolve failures without opening production permissions. After review, separately approve limited public business discovery and an audited enquiry-submission design. Payments, bookings, dispatch, automatic cleanup and all held migrations remain disabled/unapplied pending explicit approval. Public-likes privacy and legacy image limits remain separately tracked.
