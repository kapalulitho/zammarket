# Registration update

Stage 2 update: /home and /categories now support guest browsing as requested in
the master instructions. /saved, /post, /messages, /profile and /my-listings remain
authenticated, with verified profile completion. Guest private links redirect to
sign-in; logout still returns welcome. The older auth-only observations below are
historical. See STAGE2_PROGRESS.md for current implementation and tests.

The original email-code-only flow documented below is superseded by email/password
registration plus email OTP and a required reviewed profile. See [the current
registration/profile rollout notes](REGISTRATION_PROFILES.md). The auth/session
boundary and guarded routes remain in place, now with an additional ProfileGate.

# Authentication boundary and routes

`AuthBoundary` owns Supabase session state above the entire marketplace. The
marketplace is not mounted while Auth is loading, failed, or signed out. That also
prevents its listing/like/feature queries from running for guests. Supabase session
persistence, automatic token refresh, and URL session detection are explicitly enabled.

The public routes are `/`, `/signin`, and `/create-account`. All other URLs are
guarded. A signed-out deep link redirects to welcome. Authenticated main routes are
`/home`, `/categories`, `/post`, `/messages`, `/profile`, and `/my-listings`.
Browser Back/Forward updates the visible main page. Existing internal product and
seller selections remain component state; shareable product URLs are not added here.

Signup and sign-in reuse the email-code UI and Supabase OTP endpoints. A successful
sign-in event opens Home. Restoring an existing session preserves a protected main
route after refresh; a restored public URL opens Home. Signup allows account creation;
Sign In does not silently create a new account. No fake local login flag is used.

Cached sessions are validated using getUser before rendering protected content.
Subscription events take precedence over stale restoration responses. Token refresh
and user metadata updates preserve the current page. A signout event immediately
unmounts the marketplace; its drafts, photos, selected product, filters, and messages
are discarded. Preview object URLs are released. Uploaded Storage files are preserved.
Logout is available in the desktop header and on Profile, including mobile. A failed
logout displays an error instead of falsely reporting success. Local-scope logout
clears this browser's session; other devices are not forcibly signed out.

This route guard controls the app experience, not database authorization. Existing
live RLS policies remain unchanged, including public reads allowed by those policies.
Direct API access is governed by RLS. The previously proposed backend security setup
still needs separate approval. No data was deleted or security settings changed.

## Verification

- `npm test`: session loading, persisted-session restoration, failed validation,
  sign-in/restore races, logout and refresh, cross-tab signout races, failed logout,
  cleanup/unsubscribe, metadata/token events, and public/protected route classification.
- Real local app: signed-out direct visits to all six main routes returned to welcome
  with no search, listing, posting, profile, or marketplace navigation controls.
- Isolated test server on port 5174: mocked Supabase Auth exercised both signup and
  login through the UI, Home redirects, authenticated direct Post URL and refresh,
  mobile navigation/Profile logout, and signed-out refresh. The loading screen was
  observed before restoration with no marketplace content. No email or real signup
  was submitted. The mock configuration was kept in ignored `.validation/`, never
  imported by production code, and the temporary test server was stopped afterward.
- Browser checks used responsive layouts. Build and lint checks passed. Real-provider
  email delivery and fresh live signup were not independently exercised by the agent.

## Deployment

The local preview remains http://127.0.0.1:5173/. Before deploying, configure the host
to serve `index.html` for SPA navigation paths. Otherwise directly loading `/profile`
could return the host's 404 before React runs. This depends on the chosen host and no
live hosting configuration was changed. Keep Supabase redirect URLs and email-token
templates configured for the actual production domain. Never ship the test server.
