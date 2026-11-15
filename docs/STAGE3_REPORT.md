# Stage 3 — modern homepage and module foundations

Latest read-only review: current 013 and 014 are on HOLD pending privacy/integrity
hardening. See their separate assessment files under supabase/review/. Local
seller tools now have stock editor previews/validation, storefront live preview
and campaign draft search/duplicate/archive controls. None enables live backend
setup or paid advertising.

29 October 2026. Existing application retained; local implementation only. No live SQL, permissions, deployment, payment activation or data deletion.

## Functional now with the existing backend

- Green mobile-first promotional banner with the approved headline/subtitle; brand, notification bell, profile action and prominent multi-service search.
- Eight rounded destinations: Shop, Delivery, Events, Jobs, Learning, Food, Property, More. Bottom navigation: Home, Explore, Post, Chats, Profile. Light/deep-navy themes retained.
- Featured existing products, local-business invitation/real-storefront preview, and discovery tailored only to categories viewed during this visit. No fake businesses, offers, sponsored placements or analytics.
- Existing posting/photos, auth/profile, product chats, saved items, comparisons and My Listings remain. Product galleries now include thumbnails and previous/next controls. Compare optionally displays published stock/options when commerce setup exists.
- Business workspace links to storefront, inventory, enquiries and promotions. Revenue summary uses actual owner listing/status counts, not invented clicks or revenue.

## Implemented, but requires migration approval/configuration

| Interface / backend | What is built | Dependency |
| --- | --- | --- |
| Events | Discovery/search/location filters, details, organiser form, Zambia-time event dates, cover upload, private drafts, edit/close and enquiries | 013 |
| Jobs | Employer/company/category/type, salary basis/deadline, details, application instructions and private enquiries; no CV/document uploads | 013 |
| Professional services | Provider expertise, service format, qualifications/scope, pricing and enquiries | 013 |
| Learning | Tutors/courses/workshops/resources, subject, level/duration/outcomes, price and enquiries | 013 |
| Storefronts | Public shop discovery/catalogue, unique handle, banner, profile avatar logo, hours/location/policies and owner editor | 013 |
| Enquiries / notifications | Private enquiry/reply inbox and recipient notifications, mark-read; product Chats remain separate and working | 013 |
| Inventory | Owner quantity dashboard, size/colour option rows and optional variant prices; public stock/options panel | 014 |
| Reviews | Public safe review projection and eligible-buyer form; verified completed receipt required, no self/duplicate reviews | 014 plus a trusted transaction-verification process, not configured |
| Revenue | Private sponsor/boost/subscription/campaign draft forms, budgets/dates/product selection, edit drafts and listing counts | 014; real payments and active placement deliberately absent |

Missing migrations show **Setup required** and disable publishing/saving. Forms can be previewed. A valid capability plus authenticated verified profile is required for writes; database ownership/RLS enforce the boundary. No form silently substitutes local browser storage for real backend persistence.

Delivery, Food and Property have honest planned-route pages with current seller-arranged collection/delivery guidance where applicable. They are not presented as functioning booking/order systems.

## Models, approvals and known issues

Review [013/014 scope and risks](../supabase/review/013_014_STAGE3_REVIEW.md). Both versioned scripts are pending approval and unapplied. Preflight is read-only and returns one report row. Do not rerun migration 012; its function is preserved and checked locally. Public likes/account identifiers and the old listing-image bucket size/MIME issue remain on the pending-fixes list. Automatic photo deletion remains inactive.

New uploads use a separate reviewed public image bucket, with owner paths and server type/size limits. Failed uploads/publishing preserve files. New foreign keys can block later hard deletion; no cleanup is inferred from this work.

## Lightweight validation

Final automated results: 43 fast unit tests pass, lint is clean, production build
succeeds with on-demand module chunks. Essential disposable-database checks for
013/014 pass while preserving the existing 012 function, policies and bucket settings.

Lint/production build and existing fast unit checks run. Disposable PostgreSQL validates only essential new permission/eligibility boundaries, with non-sensitive fixture data, before any live approval. A short isolated browser check confirms the 360 px approved homepage (eight icons, correct bottom navigation), Events route/form, visible setup notice and disabled publish button; 320 px dark form has no page-wide overflow. No new live module data or real messages were sent. Full two-real-account tests remain skipped at the owner's earlier request.

## Next recommended batch

1. Read-only preflight, exact SQL review, backup/recovery confirmation and separate approval of 013, then 014.
2. Verify first real module publication, enquiry/reply, storefront and stock changes using dedicated test data after setup. Add stable shareable module detail URLs, cursor pagination and owner filters as the first hardening batch.
3. Add moderation/reporting and a trusted sale-verification/admin workflow before opening broad review submission. Then extend applications/bookings/order workflows and analytics with consent and verified event sources.
4. Keep checkout, subscription billing, live sponsored delivery and production deployment behind separate approvals. No payment credentials are stored in frontend code.
