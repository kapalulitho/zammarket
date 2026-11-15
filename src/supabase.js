import {selectBackendEnvironment} from './lib/environment.js';
import {registrationAllowed} from './lib/profiles.js';
import { createClient } from '@supabase/supabase-js';

const productionSupabaseUrl = 'https://tznbkieczyxwpyhpxeui.supabase.co/';
const productionSupabasePublishableKey = 'sb_publishable_05jgqWu7iWoWJfWvKeL_Mw_1nCmV7UJ';

const backend=selectBackendEnvironment(import.meta.env,{url:productionSupabaseUrl,key:productionSupabasePublishableKey});
const supabaseUrl=backend.url;const supabasePublishableKey=backend.key;
export const backendMode=backend.mode;
export const supabase = createClient(
  supabaseUrl,
  supabasePublishableKey,
  { auth: { ...(backend.storageKey?{storageKey:backend.storageKey}:{}), persistSession: true, autoRefreshToken: true, detectSessionInUrl: true } }
);

// Registration must never silently skip email verification when dashboard settings
// are misconfigured. Uses the same browser-safe publishable key as the SDK.
export async function registrationRequiresEmailConfirmation() {
  const response = await fetch(new URL('auth/v1/settings', supabaseUrl), {
    headers: {apikey:supabasePublishableKey}, signal:AbortSignal.timeout(10000),
  });
  if (!response.ok) throw new Error('Unable to check email confirmation settings');
  const settings = await response.json();
  return registrationAllowed(settings);
}
