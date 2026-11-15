-- APPROVED by user for controlled application; do not assume it is already applied.
-- No row changes, policy/grant changes, deletions or cleanup activation.
-- Requires the already-applied 010 profile migration.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
DO $guard$
BEGIN
 IF coalesce((SELECT md5(pg_get_functiondef(p.oid)) FROM pg_proc p
   WHERE p.oid=to_regprocedure('public.marketplace_message_membership_guard()')), '')
   NOT IN ('e1731bea1a1daaf2b88cfdb773c67d66','d02fbe83e19f489cff07e31e2707409c') THEN
   RAISE EXCEPTION '012 stopped: current function differs from the reviewed original; inspect before retrying';
 END IF;
END $guard$;
CREATE OR REPLACE FUNCTION public.marketplace_message_membership_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL THEN
   IF current_user NOT IN ('postgres','service_role') THEN RAISE EXCEPTION 'Sign in required'; END IF;
 ELSE
   IF NOT public.marketplace_complete_member() THEN RAISE EXCEPTION 'Complete your verified profile first'; END IF;
   -- Separate branches: NEW has a different record shape on each table.
   -- An AND expression may resolve a nonexistent field before short-circuiting.
   IF tg_table_name='messages' THEN
     IF new.sender_id IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'Sender mismatch'; END IF;
   ELSIF tg_table_name='conversations' THEN
     IF new.buyer_id IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'Buyer mismatch'; END IF;
   ELSE
     RAISE EXCEPTION 'Unsupported messaging table';
   END IF;
 END IF;
 RETURN new;
END $$;
COMMIT;
