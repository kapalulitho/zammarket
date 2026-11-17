# Connect the existing ZamNexus Worker to GitHub

This project already has a Wrangler configuration. Connect the existing Cloudflare Worker to this repository; do not create a second Worker.

## Before connecting

- Repository: `kapalulitho/zammarket`
- Production branch: `main`
- Root directory: repository root
- Wrangler Worker name: `zammarket` (from `wrangler.jsonc`)

Cloudflare requires the existing Worker name to match the `name` in the Wrangler configuration. Keep that name unchanged unless the actual Cloudflare Worker is deliberately renamed too.

## Connect the existing Worker

1. Open the Cloudflare dashboard and go to **Workers & Pages**.
2. Select the existing Worker that serves the live ZamNexus website.
3. Open **Settings → Builds**.
4. Select **Connect** and follow the GitHub authorization prompts.
5. Select the `kapalulitho/zammarket` repository.
6. Set the production branch to `main` and the root directory to the repository root.
7. Use `npm run deploy` as the deploy command. This project script runs the production build and then `wrangler deploy`.
8. Save the settings. Check the first build result before treating the connection as complete.

If the dashboard asks for a separate build command, either leave it empty and use `npm run deploy`, or set the build command to `npm run build` and the deploy command to `npx wrangler deploy`. Do not run the build twice.

## Deployment safety

- A push to the configured production branch can deploy to the live Worker. Merge only changes that have been reviewed and tested.
- Keep day-to-day changes on feature branches and use pull requests.
- Do not paste Cloudflare API tokens, account IDs, secrets, or Supabase credentials into chat or source files.
- Confirm whether the existing Worker is already connected before selecting **Connect**. Avoid creating a new Worker or changing the live Worker name by accident.
- This repository's Wrangler name is intentionally still `zammarket` for compatibility with the existing deployment. The public product name is ZamNexus.

Official Cloudflare guide: https://developers.cloudflare.com/workers/ci-cd/builds/
