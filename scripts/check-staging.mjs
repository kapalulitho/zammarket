// Configuration only. No requests, SQL, project creation or key output.
import fs from 'node:fs';
import {selectBackendEnvironment} from '../src/lib/environment.js';
import {parseStagingConfiguration,stagingConfigurationStatus} from '../src/lib/stagingConfiguration.js';
const path='.env.staging.local';if(!fs.existsSync(path)){console.log('STAGING NOT CONFIGURED: create an isolated project only with owner approval, then configure .env.staging.local. No remote validation run.');process.exit(process.argv.includes('--require-config')?1:0);}
let env;try{env=parseStagingConfiguration(fs.readFileSync(path,'utf8'));}catch(error){console.error(error.message);process.exit(1);}
const status=stagingConfigurationStatus(env);for(const row of status)console.log(`${row.name}: ${row.status}`);
if(status.some(row=>row.status!=='PRESENT')){console.log('STAGING NOT CONFIGURED: fill missing/placeholder values privately; no remote validation run.');process.exit(process.argv.includes('--require-config')?1:0);}
const source=fs.readFileSync('src/supabase.js','utf8');const productionUrl=source.match(/const productionSupabaseUrl\s*=\s*'([^']+)'/)?.[1];
const productionKey=source.match(/const productionSupabasePublishableKey\s*=\s*'([^']+)'/)?.[1];
try{if(!productionUrl||!productionKey)throw new Error('Production identity could not be verified; staging refused.');selectBackendEnvironment({...env,MODE:'staging'},{url:productionUrl,key:productionKey});console.log('Staging configuration passes local identity/isolation checks. This does not verify ownership, remote schema or key/project correspondence; no remote validation run.');}catch(error){console.error(error.message);process.exitCode=1;}
