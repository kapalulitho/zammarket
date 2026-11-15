// Local preparation only. No network, SQL execution, credentials or overwrite.
import fs from 'node:fs/promises';
import {createHash} from 'node:crypto';
const files=['supabase/staging/000_empty_baseline_STAGING_ONLY_HOLD.sql','supabase/review/009_backend_setup_PENDING_APPROVAL.sql','supabase/review/010_profiles_registration_PENDING_APPROVAL.sql','supabase/review/012_message_trigger_fix_PENDING_APPROVAL.sql','supabase/review/022_business_foundation_HOLD_DRAFT.sql','supabase/review/023_stays_logistics_HOLD_DRAFT.sql'];
try{await fs.writeFile('.env.staging.local',await fs.readFile('.env.staging.example'),{flag:'wx'});console.log('Created ignored staging template; no credentials filled.');}catch(error){if(error.code!=='EEXIST')throw error;console.log('Existing staging configuration preserved; no values displayed.');}
const migrations=await Promise.all(files.map(async(path,index)=>({order:index+1,path,sha256:createHash('sha256').update(await fs.readFile(path)).digest('hex'),state:'HOLD — exact SQL approval required before execution'})));
await fs.mkdir('.validation',{recursive:true});await fs.writeFile('.validation/staging-migration-manifest.json',JSON.stringify({generated_at:new Date().toISOString(),environment:'isolated staging only',executed:false,migrations},null,2));
console.log('Prepared .validation/staging-migration-manifest.json with source hashes and manual order. No SQL applied.');
