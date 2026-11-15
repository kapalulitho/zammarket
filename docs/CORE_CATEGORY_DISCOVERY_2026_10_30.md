# Core category and discovery expansion — 30 October 2026

Implemented in the original C:\Users\kapalu\Documents\ZamMarket project. Main app remains http://127.0.0.1:5173/home. No production writes, configuration changes, migrations, policies, accounts, photos or existing listing fields were changed. Staging remains separate.

## Completed in this batch

- One explicit twelve-section category map now connects Shopping, Food, Jobs, Events, Agriculture, Property, Accommodation, Delivery, Logistics, Services, Learning and Digital Products to their actual workspaces. Categories has a complete section directory plus separate shopping chips. The approved eight compact homepage service icons remain in their existing order.
- Shopping feed and storefront queries defensively exclude explicitly classified non-shopping records. Case and common shopping aliases are normalized. Others no longer absorbs explicitly named service categories. Classification uses explicit kind/module/category fields, never guesses from a product title. Ambiguous legacy Others records remain products until an owner deliberately recategorizes them; no data was silently rewritten or moved.
- Header search has a section selector and submit action. Typing no longer switches pages or discards module-local drafts. Food, Jobs, Events, Learning, Services, Property, Accommodation, Logistics, Agriculture, Digital and business discovery receive scoped searches. Clearing the header clears the current section query. Delivery retains its workflow rather than pretending a parcel request is product search.
- Property public discovery excludes legacy nightly offers; owner management can still see them. New nightly offers are directed to Accommodation, with a clear validation message. No legacy property is deleted or automatically transferred.
- Shopping browse uses bounded client rendering: eight homepage products, then 24 per discovery batch with Show more. This is not server pagination; the existing backend fetch remains unchanged.
- Homepage adds clearly labeled local discovery entry points for food, accommodation and agriculture alongside existing products, recommendations, business discovery and visit-based trends. No fabricated user activity or live offers were introduced.
- Post product explains its shopping purpose and links to other service workspaces.
- Promotions now support validating, reviewing and downloading an unsent local campaign proposal even while backend activation is unavailable. No campaign publication, purchase or payment occurs.
- Mobile navigation uses Home, Explore, Post, Messages and Profile. Search and the twelve-section directory adapt to small screens.

## Functionality and backend boundaries

**Connected existing core:** authenticated profiles, shopping reads, existing owner listing/RPC management, saved products and participant messaging continue to use their existing Supabase contracts. This batch did not re-run live posting or send messages to real users; passing local tests are not proof of a new live two-account messaging test.

**Useful local functionality:** scoped filters, category navigation, saved searches and visit-based recommendations, Food restaurant/menu/cart planning, Job application preparation, Event planning, Agriculture/Digital catalogues and promotion proposal export. Local drafts are not published businesses, real orders, applications or tickets. Persistence limits remain stated in each workspace.

**Staging-gated:** persistent business profiles, logos, branches, contacts, accommodation rooms and logistics service/enquiry drafts use the previously isolated staging integration where available. No business publication or operations have been activated. Full live two-account permission/media tests remain outstanding.

**Awaiting backend/security approval:** held service/commerce migrations and production business activation. Keep 013_v2–021 and production 022/023 on HOLD. Staging's six previously approved files are a separate historical approval; this batch applies none. Real payments, bookings, orders, dispatch and cleanup remain disabled.

## Validation

- npm test: 98 passed, zero failures, including five new category/scoped-search/property-boundary regressions.
- npm run lint: passed.
- npm run build: passed.
- Main app /home: HTTP 200.
- Browser: twelve category destinations rendered; Food opened /food with restaurant/menu interface; typing rice stayed on Food; submitting populated Food's own filter.
- Android-sized homepage: measured window.innerWidth 360, document scrollWidth 345 (no horizontal overflow), approved hero, compact icons, header and five-item mobile navigation rendered correctly. Screenshot: .validation/core-home-mobile.png. Browser viewport override reset after checking.
- No fresh live email delivery, cross-account permissions, production mutations or migration validation claimed.

## Files changed

New: src/lib/marketplaceCategories.js; src/lib/useScopedSearch.js; src/components/MarketplaceCategories.jsx; src/components/HomeLocalDiscoveries.jsx; tests/marketplaceCategories.test.js; this report.

Updated: src/App.jsx; src/components/FoodMarketplace.jsx; src/components/BusinessServiceDirectory.jsx; src/components/LocalVerticalMarketplace.jsx; src/components/ModuleMarketplace.jsx; src/components/Storefronts.jsx; src/components/PropertyMarketplace.jsx; src/components/PropertyEditor.jsx; src/components/SellerProfile.jsx; src/components/ServiceWayfinder.jsx; src/components/CampaignDraftEditor.jsx; src/lib/property.js; src/lib/expansion.js; src/business-foundation.css; docs/NEXT_BATCH_PROGRESS.md.

## Next recommended batch

Validate explicit cross-service listing metadata against isolated staging fixtures, then introduce safe server pagination and shared search URL parameters. Complete two-account staging ownership/messaging/media validation before activating persistent service publishing. Email-template editing remains externally blocked by staging sender configuration; verification is not bypassed. Public likes visibility and unrestricted legacy listing-image size/MIME settings remain pending separate security approval.
