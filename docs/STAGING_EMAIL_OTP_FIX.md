# Staging signup email mismatch — 30 October 2026

**Live Dashboard finding:** template editing is locked until custom SMTP or a qualifying plan/hook is available, and the current OTP length is **8**. The HTML below is prepared but not installed. Follow STAGING_OTP_BLOCKERS_2026_10_30.md for current blockers; do not attempt to paste into disabled controls or truncate an eight-digit code. Six-digit setting changes require approval.

Inspection: AuthBoundary calls Supabase signUp(email,password), opens its six-digit code form, then verifyEmailCode invokes verifyOtp({email,token,type:'signup'}). The installed SDK retains this signup type; the sign-in-code path uses type:'email'. Signup resend uses auth.resend({type:'signup',email}); existing error handling covers wrong/expired codes and rate limits. No local login flag bypass is used. Verified users still must complete their profile.

The user received a confirmation link rather than a numeric code. A Confirm sign up email containing only ConfirmationURL is incompatible with the code-entry UI. Supabase's Token template variable outputs the OTP; it does not itself set the OTP length. Ensure the staging Email OTP length is six if the Dashboard exposes that setting, and verify actual length in the next delivered email. Never truncate a longer code or weaken confirmation. No Auth code change is needed for the reported link-versus-code mismatch.

## Exact proposed staging change — not applied

Project: the separate staging Dashboard whose reference matches the existing staging environment. Do not edit production.

Subject: **Your ZamMarket Staging verification code**

Body: copy the full `supabase/staging/email/confirm-signup-otp.html`. The functional replacement is:

```html
<!-- Replace the existing confirmation-link paragraph: -->
<p><a href="{{ .ConfirmationURL }}">Confirm your email</a></p>

<!-- With an explicit code paragraph: -->
<p>Enter this code in ZamMarket Staging:</p>
<p>{{ .Token }}</p>
```

The supplied full template has staging branding and no confirmation link. It does not claim an expiry duration that has not been verified. Save a private copy of the previous subject/body before replacement for rollback. This is an email-template configuration change only: no SQL, database policies, payments or publication flags change. The new template affects future sends, not already delivered emails.

## Apply and test, one step at a time

1. In the verified staging Dashboard open Authentication, then its email templates section and **Confirm sign up**. Depending on Dashboard layout, templates are under Emails or Email Templates. Keep Confirm email enabled.
2. Copy the previous subject/body privately. Set the subject above and paste the prepared full HTML body, review that it contains `{{ .Token }}`, and save **in staging only**. The agent has not saved this change.
3. Return to the staging app code page and select Resend verification code once. Do not repeatedly re-register the same unconfirmed account or delete it. If the code page was lost, use Sign In with the existing unconfirmed staging email/password privately; the email-not-confirmed flow opens code entry, then resend. For an already confirmed account use normal sign-in; a signup resend is not applicable.
4. Wait for the newest email. Report only whether a six-digit code arrived, never the code. Rate limits/default SMTP restrictions may require waiting or separately approved SMTP setup; do not disable verification.
5. Enter the newest code privately. Expected: verified Supabase session, then mandatory profile setup (or Home if already complete). Confirm refresh keeps the session. Report the outcome/error only.
6. After the successful flow, deliberately incorrect/expired-code checks should be performed on a dedicated unconfirmed test flow, with limited attempts. Do not claim natural expiry from a simulated error. No live email test is passed until delivery and verification are actually observed/reported.

Related sign-in flow: the separate Magic Link/OTP template also needs Token for email-code sign-in; changing Confirm sign up does not modify that template. Review it separately rather than altering unrelated templates automatically.

Sources: https://supabase.com/docs/guides/auth/auth-email-templates and https://supabase.com/docs/guides/auth/auth-email-passwordless . No production settings or staging templates changed during preparation.

Update: approved staging Email OTP length is now saved as6 and verified by reopening settings. Expiry remains3600; template editing remains locked pending approved sender/plan setup. Production unchanged.

