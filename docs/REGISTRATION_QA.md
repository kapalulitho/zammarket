# Registration verification — 28 October 2026

## Automated local checks

- `npm test`: 34 passed.
- `npm run lint`: passed.
- `npm run build`: passed.
- `node scripts/validate-profiles.mjs --full`: passed against disposable local PostgreSQL, including the proposed backend/profile migrations. This does not establish the deployed database state.

## Isolated browser checks

Run against a separate Vite server with a mock Supabase client; no real emails, accounts, listings or photos were changed:

- Password mismatch blocks registration.
- Registration opens the six-digit verification screen without marketplace controls.
- Incorrect code displays the incorrect/expired message and denies access.
- Resend clears the input and displays confirmation; a superseded code is rejected using a simulated `otp_expired` response. Natural live expiry was not tested.
- Direct access to Home, Categories, Post, Messages, Profile and My Listings redirects unverified visitors to welcome.
- Correct code opens mandatory profile setup; username, shop name and account type are reviewed and confirmed before HomeFeed.
- Authenticated refresh preserves access.
- Logout returns to welcome; incorrect password fails; correct repeat login returns to HomeFeed for the completed account.

## Live read-only observations

- Development site responds at http://127.0.0.1:5173/.
- Supabase Auth settings: email enabled, signup enabled, automatic email confirmation disabled (Confirm email enabled).
- `marketplace_profiles` REST lookup returns HTTP 404 / PGRST205. Profile setup cannot be completed against the live backend yet.
- Live RPC probes were not executed: automatic approval review rejected POST RPC calls because deployed side effects were not established. Live RLS and RPC behavior therefore remain unverified.

## Manual / approval-dependent checks

The user will enter their own credentials and codes privately. Real signup email delivery, six-digit template content, resend delivery, natural code expiry, live verified login/session refresh/logout and live profile completion remain unverified. Do not claim delivery from a successful signup response alone.

Use an unregistered test email at the real port 5173, submit signup once, inspect the inbox privately, and enter the code yourself. Report only the outcome or error text, never the password or code. An existing account cannot establish new-signup delivery.

Review and approve the pending backend/profile SQL before applying it in Supabase. Re-run the read-only preflight immediately before any approved deployment, then test owner/non-owner permissions with test accounts. No live migrations, policies, listings, photos or accounts were modified during this QA run. Automatic photo deletion remains disabled.
