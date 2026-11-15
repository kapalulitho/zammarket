# Stage 4 — isolated staging and business persistence

No staging credentials are currently configured. No project was provisioned, no remote SQL executed and no production credentials copied. The local staging adapter refuses every business request when backendMode is not staging; the existing production marketplace remains available.

## Setup, one step at a time

1. Create or select a genuinely separate, empty Supabase project. Confirm its project reference differs from production. Do not copy production data, accounts, photos, database passwords or service-role keys. Obtain approval before incurring costs.
2. Privately copy `.env.staging.example` to ignored `.env.staging.local`. Fill only that project's URL, matching project reference and browser publishable key. Keep the explicit staging acknowledgement. Never paste credentials into chat. Run `npm run check:staging`; any refusal must be resolved before starting the app.
3. Review the exact empty baseline and migrations before requesting SQL approval. Proposed staging order: `supabase/staging/000_empty_baseline_STAGING_ONLY_HOLD.sql`, existing 009, 010, 012, then held 022 and 023. These business drafts do not require 013–021. Do not apply originals and v2 alternatives together. Stop on collisions rather than dropping existing objects. This step is NOT permission to execute any migration.
4. After explicit approval for exact staging SQL, apply only that reviewed set in the staging Dashboard. Record hashes and results. Keep both publication flags false. Business/company creation must not change existing profile account types or grant staff ownership over product listings/messages.
5. Configure email confirmation and the signup/sign-in code templates in staging only. Set localhost:5180 redirect URLs. Use two controlled test inboxes and non-sensitive test fixtures. If another inbox is unavailable, mark native two-account tests pending; local fixture results cannot substitute for them.
6. Run `npm run dev:staging`. Verify the staging banner, port 5180 and separate session. Missing staging configuration must refuse startup; never substitute the production key to bypass a failure.
7. Run `supabase/staging/024_business_READ_ONLY.sql` in staging. Save object/fingerprint/RLS/policy/grant/bucket evidence privately; compare with the reviewed sources. Check the commented read-only publication queries after tables exist. Schema presence alone is not a security pass.

## Native validation checklist

Use Account A and Account B in separate browser sessions. Never share OTPs/passwords. Request approval for any additional SQL/security changes, not for ordinary writes of approved synthetic test data.

- Auth: signup code delivery/verification, incorrect/expired/resend, profile completion, refresh recovery, logout and protected URL access. Record actual email delivery only when observed in the test inbox.
- Core: A posts a non-sensitive listing; refresh retains it. B cannot edit A's record or spoof owner IDs. A can manage status; future availability uses Zambia dates and remains available after the selected day. B can start a product conversation; nonparticipants cannot read/write it. Preserve the 012 tested trigger fingerprint.
- Business: A creates a draft organisation, contact choices, logo and branch in Business. Reload then revisit; fields must persist. Edit only the intended organisation/branch. B cannot read raw private records or alter them. Membership role metadata must not grant listing, messaging or organisation write rights. No staff invitations are enabled.
- Services: In Stays/Logistics choose A's saved business, create a private service draft, add room options or service areas. Reload to verify details and integer nightly ZMW values. Another owner must not change them. Public discovery should remain empty with flags false.
- Storage: own logo <=2 MB and service images <=5 MB; reject foreign folder, traversal, mismatched signature/MIME, unsupported formats and oversized inputs. Direct Storage requests must also enforce bucket limits and policy ownership. Test signing as owner, other account and anonymous; unpublished media must fail for others. Overwrite/delete must remain denied. Signatures use 60-second lifetimes; newly denied reads do not revoke already-issued URLs until expiry. Validate native expiry and do not log signed URLs. Frontend validation alone does not establish trusted server file validation/scanning.
- Draft enquiries: publication remains off, so drafts against unpublished offers must be rejected. Testing public projection/revocation and successful draft creation requires separately approved synthetic publication in staging. Even then drafts are author-only, never submitted or visible to providers. No booking, quote commitment, payment or dispatch is permitted.
- Refresh/error handling: a failed save must not display success; retry only after reloading. Partial image uploads are retained for manual review, never automatically deleted. Service and room saves are deliberately separate; do not imply atomic all-in-one creation.

## Acceptance and rollback

Record source hashes, date, role, action, expected/actual result and pass/fail. A local PGlite pass does not prove native Storage/PostgREST/Auth behaviour. Keep public-likes privacy, legacy image limits and all operational gates pending. Before production consideration require reviewed native evidence and separate approval.

Before transaction commit, SQL failure rolls back. After deployment, prefer a forward corrective migration and disabled UI/publication, preserving rows/photos. Do not automatically drop tables/buckets or run cleanup. No destructive rollback is authorised.
