-- EMERGENCY ROLLBACK ONLY. Restores the previous, known-defective function.
-- Run only if the approved 012 correction must be reverted; no records/policies changed.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
DO $guard$
BEGIN
 IF coalesce((SELECT md5(replace(pg_get_functiondef(p.oid), E'\r\n', E'\n')) FROM pg_proc p WHERE p.oid=to_regprocedure('public.marketplace_message_membership_guard()')), '') <> '8ca43a0da6c82a813576887f00c3807d' THEN
   RAISE EXCEPTION 'Rollback stopped: current function differs from approved 012; review before restoring';
 END IF;
END $guard$;
CREATE OR REPLACE FUNCTION public.marketplace_message_membership_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL THEN
   IF current_user NOT IN ('postgres','service_role') THEN RAISE EXCEPTION 'Sign in required'; END IF;
 ELSE
   IF NOT public.marketplace_complete_member() THEN RAISE EXCEPTION 'Complete your verified profile first'; END IF;
   IF tg_table_name='messages' AND new.sender_id IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'Sender mismatch'; END IF;
   IF tg_table_name='conversations' AND new.buyer_id IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'Buyer mismatch'; END IF;
 END IF;
 RETURN new;
END $$;
COMMIT;
