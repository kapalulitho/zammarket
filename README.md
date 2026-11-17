# ZamNexus

A React and Vite marketplace for Zambia, using Supabase Auth, Postgres, and Storage.

Stage 3 adds the green multi-service homepage, Events/Jobs/Services/Learning forms,
storefronts, inventory/options, verified-review eligibility and private promotion
draft interfaces. New publishing requires review/approval of unapplied migrations
013/014. See [Stage 3 status](docs/STAGE3_REPORT.md) and [master plan](docs/MASTER_PLAN.md).

Latest foundation: light/dark/system appearance, expanded responsive navigation,
Explore filters, province/town posting, visit-only recently viewed products and
comparison. Optional pages load on demand. See [product status and roadmap](docs/PRODUCT_ROADMAP.md)
for implemented versus planned services; Orders/extra services are not live commerce systems.

## Cloudflare deployment

The existing deployment is configured as a Cloudflare Worker through `wrangler.jsonc`. Follow [the GitHub connection guide](docs/CLOUDFLARE_GITHUB_CONNECTION.md) to connect the existing Worker to this repository without creating a second Worker or changing its deployment name.

## Local development

Install dependencies with `npm ci`, then run `npm run dev`.
Run `npm run lint` and `npm run build` before deployment. `npm run preview` serves the production build locally.

## Current features

Browse and search listings, category filters, price sorting, listing details, email sign-in, posting with up to five photos, saved products, and editable profiles. Backend features include private buyer/seller conversations, date-based availability in Africa/Lusaka, Sold/Temporarily Unavailable, and owner listing management. Guests can browse Home, Categories and product details; saving, messaging and publishing require sign-in. See [Stage 2 progress and verification limits](docs/STAGE2_PROGRESS.md).

## Registration and private profiles

Current registration uses email/password, Supabase email OTP verification, and mandatory reviewed profile setup before marketplace entry. Username and public/shop name are uniquely enforced by the proposed database migration. Avatars and contact visibility are editable; private login email is excluded from public profiles. See [implementation, migration, and dashboard configuration](docs/REGISTRATION_PROFILES.md).

The user enabled Confirm email and applied migrations 009, 010 and approved correction 012, with supplied catalog checks. Real signup/sign-in emails, profile/avatar persistence and logout were confirmed by the user. Full two-account live tests were skipped at the user's request. Feed cards use compact 2–5 column layouts with only image/title/ZMW price/location and available-first sorting.

## Authentication and routes

Supabase Auth is the login source of truth. Session restoration finishes before the marketplace mounts; restored users are validated with `getUser()`. Signup requires email OTP, profile setup and final review; sign-in restores completed accounts, and logout returns to `/`. `/home` and `/categories` support guests; `/saved`, `/post`, `/messages`, `/profile`, and `/my-listings` are protected. Hosting must rewrite SPA routes to `index.html`; Vite does this locally. See [authentication behavior and verification](docs/AUTH.md).

## Backend review and remaining approvals

See [the review package](supabase/review/CURRENT_APPROVAL_PACKAGE.md) and [Stage 1 verification](docs/STAGE1_VERIFICATION.md) for deployment history. Do not rerun 009/010/012. Public likes privacy and listing-image upload limits remain pending separate approval. Automatic photo cleanup remains inactive; existing photos are preserved. No Stage 2 migration was required for guest browsing or the Saved view.

`npm test` runs authentication, route, availability, photo, and cleanup unit tests. `node scripts/validate-database.mjs` runs the optional disposable PostgreSQL harness after installing its local test dependency as documented in the review package.

## Supabase requirements

The existing client configuration is in `src/supabase.js`. Use only a publishable key in browser code. Never add service-role keys or database passwords.

The frontend expects:

- `listings`: id, user_id, title, price, category, location, description, image_urls. Optional display fields: condition, color, icon.
- `likes`: listing_id, user_id; enforce a unique pair and foreign keys.
- Storage bucket `listing-images`, with public image reads and authenticated uploads under the signed-in user's ID folder.

Before deployment, verify the actual schema in the Supabase dashboard. Enable row-level security. Allow public listing reads, require `auth.uid() = user_id` for inserts, and restrict update/delete to owners. Likes need owner-only writes. The current like counts require readable like records; consider an aggregate endpoint to avoid exposing user IDs.

Storage write/delete policies must restrict users to their own folder. Enforce allowed MIME types and a 5 MB limit in the bucket as well as the frontend. Failed posts preserve uploaded files for separately reviewed cleanup.

Configure the email template to send a sign-in token if using the code form. Verify allowed redirect URLs, email delivery, OTP expiry, and rate limits.

## Validation still required

Test login, logout, posting, likes, and uploads with real test accounts. Verify that another account cannot modify an owner's listings, likes, or images. No backend schema/policy migrations have been applied by this project.

## Next development

Approve and stage-test the unified backend and listing-only test cleanup; verify real authenticated uploads and messaging; then add URL routing, shareable listing links, seller profiles, notifications, and broader mobile browser QA.
