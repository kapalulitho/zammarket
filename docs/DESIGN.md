# ZamNexus visual identity

The local React/Vite redesign keeps Supabase integration and existing marketplace
features. It does not run SQL, delete records/photos, or change production permissions.

## Direction

A friendly local-discovery marketplace: white surfaces, ink-blue typography, cobalt
gradients, restrained shadows, consistent line icons, and editorial spacing. The
original bag/Z mark replaces the old square letter. No stock logo, remote font,
animation library, or icon dependency is loaded by the app.

- Primary: #245be8; dark blue: #1544bc; ink: #142849.
- Page background: #f8faff; surfaces: white; borders: #e7ecf5.
- System typography stack with strong heading hierarchy and readable form controls.
- Small-screen cards use two columns; tablet uses three; desktop uses four.
- All motion respects prefers-reduced-motion, including programmatic scrolling.
- Original illustration and logo are lightweight SVGs in public/.

## Components and assets

`src/components/Design.jsx` contains the brand, welcome layout, line icons, no-photo
placeholder, empty-state illustration, and loading skeletons. Shared styling lives
in `src/App.css`. Account, seller, messages, listing management, posting, and detail
views share the same visual system. No unavailable backend functionality is simulated.

Create Account and Sign In use the existing email-code flow. Signup explicitly allows
creating a user; Sign In does not create accounts implicitly. No test emails were sent.
Auth provider/template configuration remains unchanged. A new account can also be
created from the switch below the sign-in form.

`brand-mark.svg` is the transparent primary mark. `favicon.svg` matches it. The
192/512 PNGs and 180px Apple touch icon are padded to keep the mark inside mask-safe
bounds. `site.webmanifest` supplies standalone display metadata. No service worker
or offline capability is added. Already-installed home-screen shortcuts may retain
old icons until refreshed or re-added; actual iOS/Android installation was not tested.

Optional icon regeneration (temporary authoring dependencies only):

```powershell
npm install --prefix .validation --no-save --package-lock=false @electric-sql/pglite @resvg/resvg-js
node scripts/render-brand-icons.mjs
```

## Preview and verification

The local preview is http://127.0.0.1:5173/. To start it if needed:

```powershell
npm run dev -- --host 127.0.0.1
```

Run `npm test`, `npm run lint`, and `npm run build`. Browser checks covered desktop
1440px, tablet 768px, phones 390px and 320px, welcome/account switching, search/empty
state/reset, product details, and Messages' signed-out state. A small-screen horizontal
overflow and product-opening scroll position were corrected. No live authenticated
posting, account creation, or messages were submitted during visual QA.
