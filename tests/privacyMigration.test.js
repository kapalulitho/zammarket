import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const sql = readFileSync(new URL('../supabase/review/011_public_like_counts_and_private_saves_PENDING_APPROVAL.sql', import.meta.url), 'utf8');
const app = readFileSync(new URL('../src/App.jsx', import.meta.url), 'utf8');
const messages = readFileSync(new URL('../src/components/Messages.jsx', import.meta.url), 'utf8');

test('public likes migration restricts row reads to the signed-in owner', () => {
  assert.match(sql, /CREATE POLICY zammarket_likes_read_own[\s\S]*?USING \(user_id = \(SELECT auth\.uid\(\)\)\)/);
  assert.match(sql, /CREATE POLICY zammarket_likes_read_owner_guard[\s\S]*?AS RESTRICTIVE[\s\S]*?USING \(user_id = \(SELECT auth\.uid\(\)\)\)/);
  assert.match(sql, /REVOKE SELECT ON public\.likes FROM PUBLIC, anon, authenticated/);
  assert.doesNotMatch(sql, /CREATE POLICY zammarket_likes_read ON public\.likes[\s\S]*?USING \(true\)/i);
});

test('public likes RPC exposes only bounded counts for visible listings', () => {
  assert.match(sql, /RETURNS TABLE\(listing_id text, like_count bigint\)/);
  assert.match(sql, /count\(\*\)::bigint/);
  assert.match(sql, /cardinality\(p_listing_ids\) BETWEEN 1 AND 100/);
  assert.match(sql, /listing\.id::text = l\.listing_id::text[\s\S]*?listing\.deleted_at IS NULL/);
  assert.match(sql, /GRANT EXECUTE ON FUNCTION public\.public_listing_like_counts\(text\[\]\) TO authenticated/);
  assert.match(sql, /WHERE \(SELECT auth\.uid\(\)\) IS NOT NULL/);
  assert.match(sql, /DROP POLICY IF EXISTS zammarket_likes_read ON public\.likes/);
});

test('public participant details use the privacy-filtered profile RPC', () => {
  assert.doesNotMatch(app, /from\(['"]marketplace_profiles['"]\)/);
  assert.doesNotMatch(messages, /from\(['"]marketplace_profiles['"]\)/);
  assert.match(app, /rpc\('public_seller_profile'/);
  assert.match(messages, /rpc\('public_seller_profile'/);
});
