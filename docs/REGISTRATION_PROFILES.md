# Registration, profiles, and compact feed — local implementation

Status update: the user has since applied 009, 010 and approved 012, supplied catalog
verification and confirmed real email-code login plus saved profile/avatar persistence.
The earlier undeployed findings below describe the original implementation stage.
Guest browsing is now supported; private actions still require verified profile setup.
See STAGE1_VERIFICATION.md and STAGE2_PROGRESS.md for current evidence and limits.

No live migration, security policy, Auth setting, Storage object, listing, or user was
changed. No real signup, verification email, or avatar upload was submitted during tests.

## Implemented locally

New registrations use email/password, matching password confirmation, and Supabase
signup email OTP verification. Password sign-in is the default. Pending unconfirmed
accounts can resume email verification from sign-in. Code-based sign-in remains as a
compatibility/recovery option for older passwordless users; Profile offers set/change
password through Supabase Auth. Passwords are never written into profile tables,
metadata, local draft storage, logs, or public seller responses.

Auth sessions remain the source of truth. Guests see only welcome/auth screens.
Verified users still cannot enter the marketplace until a saved profile exists.
Profile-loading/error states fail closed. Direct URLs cannot skip verification/setup.
Initial profile saves additionally require an OTP-authenticated session according to
the signed JWT's AMR claim. This protects legacy accounts created while email auto-
confirmation was enabled. Existing completed profiles can subsequently sign in with
passwords without repeating setup. The new table starts empty; no old account/profile
is automatically reassigned or marked complete.

The required fields are a case-insensitive unique username (3–30 ASCII letters,
numbers, underscores), a case-insensitive unique public/shop name (3–60 characters),
and personal/business account type. Both account types may buy and sell; neither
confers administrator permissions. Optional fields: avatar, WhatsApp, phone, public
contact email, town/location, and address. Phone numbers use international format.

Contact visibility defaults private. Each field has an independent public toggle.
The public seller RPC returns only opted-in values, never the private sign-in email.
The public contact email must differ from the login email to prevent accidental
exposure. The raw profile table is owner-readable only; direct writes are revoked.
The reviewed save RPC validates ownership, verified email, fields, uniqueness, and
confirmation. Unique indexes handle concurrent signup/name collisions safely.

The setup form previews an optional avatar, supports removing/replacing it, and
shows a review screen listing public/private choices. Users must check confirmation
before saving/entering Home. Back to edit preserves entered details. Profile editing
uses the same review flow. Avatars use UUID filenames under the account's own folder,
JPEG/PNG/WebP signature checks, and a 2 MB limit. Removing/replacing an avatar clears
or changes its reference; old bytes are retained, not automatically deleted.

Feed cards now contain only image, one-line ellipsized title, ZMW price, and location.
Category/status/condition/like labels are removed from cards; likes remain in Details.
Category and availability filters remain. The default sort ranks Available first,
then Coming Soon, Temporarily Unavailable, Sold, newest first within each group.
Explicit newest/price sorts are still available. Details retain prominent status,
including explicit sold/unavailable text. Zambia date-based availability is unchanged.
Images use 4:3 aspect ratio. Grid columns: 2 on phones, 3 at medium widths, 4 on
desktop, and 5 at 1400px+. No existing listings or photos are hidden/deleted in data.

## Live read-only findings

- Auth settings returned email enabled, signup enabled, **mailer_autoconfirm=true**.
  This currently skips signup email verification and must change before rollout.
- The new marketplace_profiles endpoint returned PGRST205/404: table not deployed.
- Existing schema reports showed listings/likes and legacy seller columns. There was
  no profile table or profile RLS in that report. A fresh catalog preflight is provided.

Registration now checks public Auth settings and fails closed when confirmation is
disabled/unknown. It never intentionally creates a new auto-confirmed account.
Until the approved profile schema is deployed, signed-in users see setup unavailable
instead of bypassing required profile completion. This is a deliberate rollout gate.

## Supabase dashboard/configuration still required — not performed

1. Run `supabase/review/010_profiles_preflight_READ_ONLY.sql`. Inspect possible profile
   table/function/policy collisions, the avatars bucket, and current listing triggers.
2. Review/approve the existing 009 backend setup if not already deployed, then review
   `010_profiles_registration_PENDING_APPROVAL.sql`. Apply to staging first. Each
   script is transactional; duplicate names/configuration mismatches abort instead
   of overwriting existing objects. Do not blindly reapply 009 to an already-migrated DB.
3. In Authentication's Email provider settings, enable **Confirm email**, keep signup
   enabled, and enforce an appropriate password minimum (the app requires 8 for signup).
   The app's read-only check must then return mailer_autoconfirm=false. Do not edit
   auth.users to fabricate confirmation timestamps or completed profiles.
4. In **Confirm sign up** email template, include `{{ .Token }}` so the user receives
   a six-digit code for verifyOtp(type=signup). Include the token in the Magic Link/OTP template
   too for legacy/recovery and first-profile re-verification. Configure Site URL,
   allowed redirect URLs, OTP expiration/rate limits, and production SMTP delivery.
5. The approved migration creates a NEW public avatars bucket: 2 MB, JPEG/PNG/WebP.
   If a bucket named avatars already exists, the migration intentionally stops for
   review. Do not alter/delete existing bucket objects. Avatars are public by design;
   private contact fields remain in the owner-only database table.
6. Test two real staging accounts: unique-name collision; password signup/code;
   incomplete-profile URL blocking; private/visible contacts; foreign avatar paths;
   owner-only listing changes; profile editing, logout and refresh. Confirm JWT AMR
   preserves the default otp method if custom access-token hooks are in use.

New listing membership triggers also run for definer RPC writes, preventing older
permissive policies or owner-management functions from bypassing profile requirements.
Existing admin/service operations without an end-user JWT retain an administrative
path; ordinary authenticated clients do not. Message membership triggers are added
when the messaging tables exist. Underlying participant RLS comes from 009.
No cleanup jobs or destructive migrations are included. Existing accounts/listings
are retained. Auth account deletion may be blocked by the new profile FK, deliberately
requiring a separately designed account-removal workflow.

## Verification performed

`npm test`, lint and production build. `node scripts/validate-profiles.mjs` tests the
profile migration against deliberately permissive old policies; `--full` tests it
integrated with 009. Both run in disposable PostgreSQL, never production. Checks
include uniqueness, OTP/email/profile gates, owner-only rows, public-field filtering,
avatar folder restrictions, immutable listing ownership, and unchanged old records.

Isolated browser Auth/Storage doubles exercised password signup, OTP, forced setup,
direct-URL blocking, review/back/edit/confirmation, and entry to Home. Browser checks
confirmed two phone columns, five desktop columns, one-line titles, no card badges,
available-first order, and Sold on Details. Actual SMTP/Storage service integration
still requires staging configuration; no claim of live signup/upload testing is made.

References: [Password Auth](https://supabase.com/docs/guides/auth/passwords),
[email templates/OTP](https://supabase.com/docs/guides/auth/auth-email-templates),
[Storage folder policies](https://supabase.com/docs/guides/storage/schema/helper-functions),
[JWT authentication methods](https://supabase.com/docs/guides/auth/jwt-fields).

## Signup OTP update

Signup verification now uses the explicitly requested `type: 'signup'` payload.
The installed SDK accepts it but marks it deprecated in favor of `email`; the legacy
sign-in-code flow still uses `email`. Both verification screens require exactly six
ASCII digits, preserving leading zeroes. Configure Supabase OTP length to six to match.
Resend uses auth.resend({type:'signup', email}) for signup, clears the previous code,
and shows a status message. Invalid/expired, throttled and offline errors are handled.
The Auth listener remains the identity source; verification never manufactures a
local logged-in flag. Complete profiles open Home; new accounts finish the required
profile review first. Supabase settings and live data were not changed by this update.
Validation: 34 unit tests, lint, and production build passed. No live emails were sent.
