# 024 safety requests — review notes, HOLD

Not applied. No existing tables, policies, records or Storage buckets are changed. Adds marketplace_safety_requests and an authenticated submission RPC; depends on 010's marketplace_complete_member(), not 012. No cascade deletes. Target references are untrusted text, not proof of ownership, misconduct or business identity.

Private requests are readable only by their submitter. Authenticated clients have SELECT only; no direct inserts, updates or deletes. RPC derives owner from auth.uid(), requires verified complete membership, serializes per-account submissions and caps five requests in 24 hours with duplicate protection. Empty function search_path and explicit object qualification protect the definer context. No staff role, moderation access, badge granting or document bucket is introduced. Existing privileged project administrators remain privileged.

The local UI is NOT connected. Backend activation needs separate approval, PostgreSQL/staging validation, schema preflight, two-account SELECT/RPC spoofing tests, concurrent limit tests, anonymous denial, constraints and catalog inspection. Check that function grants and inherited/default role permissions do not create bypasses. Test actual function execution against the installed helper before approval. This draft has not been executed or SQL-runtime validated here.

Risks: reports may contain personal allegations despite warnings; establish privacy notice, retention policy, audited staff workflow and incident response before accepting real submissions. Five-per-account limits do not stop coordinated abuse. Credential detection in the local UI is advisory, not a data-loss-prevention guarantee. Verification preparation does not verify a business. Never collect identity documents through this table.

Rollback: disable RPC execution first in a separately approved migration; retain the table and received reports. Do not drop populated objects to roll back. Clean staging installation can be removed only with explicit destructive approval. Production remains unchanged.
