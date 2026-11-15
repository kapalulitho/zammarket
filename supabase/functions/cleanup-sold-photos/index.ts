import { createClient } from 'npm:@supabase/supabase-js@2';
import { runCleanup } from './worker.js';

// Set verify_jwt=false ONLY for this function; a dedicated scheduler secret is
// checked below. Never send the service-role key or this secret to the browser.
Deno.serve(async (request: Request) => {
  const secret = Deno.env.get('PHOTO_CLEANUP_SECRET');
  if (!secret || request.headers.get('Authorization') !== `Bearer ${secret}`) {
    return new Response('Unauthorized', {status: 401});
  }
  if (request.method !== 'POST') return new Response('Method not allowed', {status: 405});
  const client = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
    auth: {persistSession: false, autoRefreshToken: false},
    global: {fetch: (input, init) => fetch(input, {...init, signal: AbortSignal.timeout(20000)})},
  });
  let completed = 0;
  try {
    // Stop before claim leases can expire. Each HTTP request is also bounded.
    completed = await runCleanup(client, Date.now() + 120000);
    return Response.json({completed});
  } catch {
    // Failed claims remain locked and retryable; no false success or restoration
    // of a listing whose photos may already have been partly deleted.
    console.error('Photo cleanup failed; inspect locked listings and retry.');
    return Response.json({error: 'Cleanup incomplete', completed}, {status: 500});
  }
});
