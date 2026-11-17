-- DRAFT - requires user approval before running. Do not assume it is applied.
-- Purpose: let signed-out visitors open seller profiles (browse -> seller -> message).
-- Safety: the function returns only public, consent-filtered fields (shared WhatsApp,
-- location if chosen) and only for complete, verified members. No email or private data.
-- Preflight first: confirm the function definition has not changed since 010, e.g.
--   select md5(pg_get_functiondef(p.oid)) from pg_proc p
--   where p.oid = to_regprocedure('public.public_seller_profile(uuid)');
-- If the hash differs from the applied 010 definition, stop and inspect instead.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
GRANT EXECUTE ON FUNCTION public.public_seller_profile(uuid) TO anon;
COMMIT;
