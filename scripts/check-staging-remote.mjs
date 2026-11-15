// Read-only staging probes. No signup/session/token requests, SQL or row contents.
import fs from 'node:fs/promises';
import {parseStagingConfiguration} from '../src/lib/stagingConfiguration.js';
import {selectBackendEnvironment} from '../src/lib/environment.js';
async function main(){
 const env=parseStagingConfiguration(await fs.readFile('.env.staging.local','utf8'));
 const source=await fs.readFile('src/supabase.js','utf8');
 const production={url:source.match(/const productionSupabaseUrl\s*=\s*'([^']+)'/)?.[1],key:source.match(/const productionSupabasePublishableKey\s*=\s*'([^']+)'/)?.[1]};
 if(!production.url||!production.key)throw new Error('Identity check unavailable. No request sent.');
 const backend=selectBackendEnvironment({...env,MODE:'staging'},production);
 const results=[];
 async function probe(label,path,auth=false){try{const response=await fetch(backend.url+path,{method:'GET',headers:{apikey:backend.key,Accept:'application/json'},redirect:'error',signal:AbortSignal.timeout(12000)});const row={check:label,http_status:response.status};
  if(auth&&response.ok){const body=await response.json();row.email_enabled=body.external?.email===true;row.email_confirmation_required=body.mailer_autoconfirm===false;row.anonymous_enabled=body.external?.anonymous_users===true;}
  row.result=response.ok?(auth?'AUTH_SETTINGS_REACHABLE':'ZERO_ROW_SELECT_ACCEPTED'):response.status===404?'NOT_EXPOSED_OR_MISSING':response.status===401?(auth?'KEY_OR_ACCESS_REJECTED':'ANONYMOUS_ACCESS_DENIED'):response.status===403?'ACCESS_DENIED':'REQUEST_FAILED';results.push(row);
 }catch{results.push({check:label,result:'NETWORK_OR_TLS_FAILURE'});}}
 await probe('Auth settings','/auth/v1/settings',true);
 if(results[0].result!=='AUTH_SETTINGS_REACHABLE'){console.log(JSON.stringify(results[0]));console.log('Stopped after Auth connectivity failure; no table probes attempted.');process.exitCode=1;return;}
 for(const table of ['listings','marketplace_profiles','conversations','messages','business_organisations','business_branches','business_service_entries','stay_room_options','business_service_enquiry_drafts'])await probe(table,'/rest/v1/'+table+'?select=id&limit=0');
 const report={checked_at:new Date().toISOString(),environment:'isolated staging',read_only:true,authenticated_session_used:false,limitations:'Anonymous publishable-key probes only. API acceptance does not verify table existence, grants, ownership, RLS, Storage policies or migration safety. Missing/denied objects need SQL metadata inspection.',results};
 await fs.mkdir('.validation',{recursive:true});await fs.writeFile('.validation/staging-remote-readiness.json',JSON.stringify(report,null,2));
 for(const row of results)console.log(JSON.stringify(row));
 console.log('Saved redacted read-only evidence. No data, Auth account, migration or policy changes.');
 if(results.some(row=>row.result==='NETWORK_OR_TLS_FAILURE'||row.result==='KEY_OR_ACCESS_REJECTED'))process.exitCode=1;
}
main().catch(()=>{console.error('Staging check stopped safely. Check local configuration/access; no environment values displayed.');process.exitCode=1;});

