-- REVIEW ONLY. Approve separately: enables permanent Storage deletion.
-- First deploy cleanup-sold-photos, set its PHOTO_CLEANUP_SECRET, and create Vault
-- entries named project_url and photo_cleanup_secret through the dashboard.
create extension if not exists pg_cron;
create extension if not exists pg_net;
select cron.schedule('zammarket-sold-photo-cleanup','*/15 * * * *', $$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name='project_url')
      || '/functions/v1/cleanup-sold-photos',
    headers := jsonb_build_object('Content-Type','application/json','Authorization','Bearer ' ||
      (select decrypted_secret from vault.decrypted_secrets where name='photo_cleanup_secret')),
    body := '{}'::jsonb
  );
$$);
-- Deliberate activation step; keep disabled until staging tests pass and approved.
update public.marketplace_cleanup_settings set enabled=true where singleton;
