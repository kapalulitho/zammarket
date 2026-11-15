# Staging OTP investigation — actual Dashboard findings

30 October 2026. Staging project identity remains the previously verified project. No production changes, SQL, policy changes, paid upgrades, SMTP setup or Auth hooks were applied in this continuation.

## Two confirmed hosted blockers

1. **Email template editing is disabled with the current sender/plan.** Authentication → Emails → Confirm sign up shows “Set up custom SMTP to edit templates” and states that default templates will be sent. The subject is “Confirm your email address”; the preview contains a ConfirmationURL link. Source and Save are disabled. The supported alternatives menu offers Pro upgrade or Send Email hook. This is an actual Dashboard restriction, not a missing click or frontend exception. Do not bypass the disabled controls through internal APIs or claim the prepared HTML has been installed.
2. **Email OTP length is 8**, expiry 3600 seconds. Confirm email and Email provider are enabled. ZamMarket deliberately accepts six digits and verifies signup with type signup, signin codes with type email. Token renders the configured length; changing the template alone would still deliver eight digits. Nothing should truncate an eight-digit code. Reducing the live staging code length to six is security-sensitive and requires explicit action-time approval. No settings were saved.

An already-approved custom SMTP service with a suitable sender may unblock template editing, but no credentials are available here. Do not reuse production SMTP credentials, activate a provider/paid plan, invite Dashboard users merely to receive emails or install a Send Email hook without appropriate approval. Configure credentials privately if an approved service is chosen. Once sender setup and six-digit length are approved/configured, install the prepared Token template and inspect a freshly requested email. Old delivered emails do not change.

## Safe local work completed

- Successful signup/sign-in code requests start a 60-second resend cooldown; handlers also check the real clock to resist rapid repeated requests. This supplements server limits, not a security boundary. Timer stops at expiry and clears on unmount.
- Resend success clears the old input and reminds users to use the newest email. Server failures still use existing clear error messages.
- The verification submit button reads Verify email / Verify and sign in instead of ambiguously Create Account.
- Staging-only expandable help explains the link/code mismatch and discourages duplicate registration. Production email settings remain unchanged; no local verification bypass was added.
- 82 tests passed, including resend-deadline boundaries; lint and production build passed. Existing malformed/wrong/expired-code error tests remain simulated checks. No new claim of hosted email delivery or successful verification.

Files changed: src/components/AuthBoundary.jsx, src/lib/emailOtp.js, tests/emailOtp.test.js, this report and staging setup notes. Prepared HTML remains at supabase/staging/email/confirm-signup-otp.html.

## What can and cannot proceed

The approved schema is already installed. Real cross-account messaging, signed-in company/branch/service saves and native image uploads need verified staging sessions. They have not passed merely because schema checks passed. The current unconfirmed test account is preserved. No account is deleted/reassigned and no session is forged. Do not repeatedly send emails while the sender/template remains unresolved.

After approved sender/template/length configuration: use the existing signup code page and Resend once (or unconfirmed password sign-in to recover code entry), privately verify newest code, complete profile, then run owner/participant/business/media tests. Keep production, all other held migrations, publication gates, bookings, payments, dispatch and cleanup unchanged.

## Approved OTP-length update
The user explicitly approved six digits in staging only. The first save reported Failed to fetch; reopening confirmed it was still8, so one controlled retry was made. That succeeded: reopening Email provider settings showed persisted length6 with Save disabled, expiry still3600. Confirm email remains enabled; rate limits and all other provider settings were not edited. Production untouched. Evidence: .validation/staging-otp-six-digits-saved.png. The eight-digit mismatch is resolved; template editing/sender access remains blocked. No signup delivery or verification pass is claimed.

