# 025 administrator foundation — HOLD, not executed

Depends on baseline listings/auth and proposed 024 safety table. No dependency on 012. New membership table and read-only aggregate RPC only; no users are granted membership. No existing account, listing, policy, message, photo, category or promotion changes. No self-grant path, profile metadata role or user management API. The browser does not call this RPC on the production connection.

RLS enabled; no client table privileges or policies. Only the authenticated role may call the empty-search-path definer RPC, which checks enabled server-owned membership for auth.uid() before reading aggregate counts. Non-admin and anonymous access must fail. This is NOT a full moderation/user-management system. No private messages, login emails, identity documents or report descriptions are returned.

Before any activation: explicit migration approval, isolated staging test, inspect default/inherited grants and table/function owners, verify malicious profile metadata cannot grant rights, check two accounts and disabled membership. Privileged project operators can still administer server-owned memberships. Provisioning a real administrator is a separate sensitive approval, never part of this migration. Consider short-lived admin sessions, MFA assurance enforcement, audit logging and incident procedures before enabling privileged mutation endpoints. This read-only foundation grants none.

No SQL runtime validation performed yet. Rollback should first revoke RPC execution and disable approved memberships through a separately approved change. Retain data; do not drop populated objects automatically. Production remains unchanged.
