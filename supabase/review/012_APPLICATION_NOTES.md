# Approved 012 — controlled application

Status: user reported success and supplied fingerprint 8f359cb0a0f8ce17ae4f45e7ba32cfed, matching the exact tested correction with CRLF line endings. The initial LF-only verification false negative is corrected locally; no additional live migration is needed. Do not rerun 012. Two real test-account messaging checks are still pending.

Approval scope: only fix marketplace_message_membership_guard; preserve accounts, listings, messages, permissions, public likes policy and photo limits. No Stage 2 work or automatic cleanup.

## Recovery and scope

This is a function-only change, not a data migration. The original function was recovered from 010 and its PostgreSQL fingerprint matched the live report exactly: e1731bea1a1daaf2b88cfdb773c67d66. The migration accepts that reviewed original or its line-ending-normalized equivalent, and aborts otherwise.

012_rollback_RESTORE_PREVIOUS_FUNCTION.sql is a tested function-level rollback. It restores the original function and therefore restores its known messaging bug. It must only be used if reverting 012 is necessary. It does not restore a full database and is not an instruction to remove any data. Its guard refuses to replace an unexpected newer function.

The approved SQL contains transaction/session timeout settings, a read-only catalog validation block and exactly one CREATE OR REPLACE FUNCTION. No account/listing/message DML, policies, grants, triggers, bucket settings or cleanup jobs are changed. CREATE OR REPLACE preserves function identity, owner and ACL. Local tests verify metadata/policy preservation, rollback/reapply, owner isolation, sender checks and conversation participant privacy.

## Apply once, then verify

1. Run the entire 012_message_trigger_fix_PENDING_APPROVAL.sql in a new query on the intended ZamMarket project. Approval is recorded in the header; the old filename is retained.
2. If success is reported, run 012_verify_READ_ONLY.sql. Expected: matches_tested_fix=true, security_invoker=true, anon_execute=false, authenticated_execute=false, enabled_triggers=2, empty search_path.
3. If a connection error appears, run the read-only verification before any retry. Do not infer execution status from a network error. If the guard reports a different function, inspect it; do not remove the guard or rerun 009/010.
4. With two dedicated test accounts in separate browser sessions, use one explicitly labelled non-sensitive QA listing owned by account A. Account B starts a conversation and sends a harmless test message; account A replies. Refresh both to confirm persistence. Do not use the four old unowned listings for this test: they cannot identify a seller.
5. Test own versus other-user access and a nonparticipant separately. Local regression passes are not evidence of two real authenticated sessions.
6. Preserve test records unless cleanup is separately requested. Report actual outcomes in docs/STAGE1_VERIFICATION.md.

No connected Supabase administrative tool is available in this session; the user performs the SQL Editor execution and shares the result. No live application has been claimed merely from local test success.
