-- Run after applying approved 012. Catalog reads only; no application RPC execution.
BEGIN READ ONLY;
SELECT p.proname AS function_name,
 md5(pg_get_functiondef(p.oid)) AS definition_fingerprint,
 md5(replace(pg_get_functiondef(p.oid), E'\r\n', E'\n'))='8ca43a0da6c82a813576887f00c3807d' AS matches_tested_fix,
 NOT p.prosecdef AS security_invoker,
 p.proconfig AS function_settings,
 has_function_privilege('anon',p.oid,'EXECUTE') AS anon_execute,
 has_function_privilege('authenticated',p.oid,'EXECUTE') AS authenticated_execute,
 (SELECT count(*) FROM pg_trigger t WHERE t.tgfoid=p.oid AND NOT t.tgisinternal AND t.tgenabled='O') AS enabled_triggers
FROM pg_proc p
WHERE p.oid=to_regprocedure('public.marketplace_message_membership_guard()');
ROLLBACK;
