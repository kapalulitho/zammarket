// Credentials arrive via stdin, never command arguments or logs. No network/SQL.
import fs from 'node:fs';
import {parseStagingConfiguration} from '../src/lib/stagingConfiguration.js';
import {selectBackendEnvironment} from '../src/lib/environment.js';
let input='';for await(const chunk of process.stdin){input+=chunk;if(input.length>8192)process.exit(1);}
try{
 const values=JSON.parse(input),url=new URL(String(values.url).trim()),key=String(values.key).trim();
 const ref=url.hostname.match(/^([a-z0-9]{20})\.supabase\.co$/)?.[1];
 const path='.env.staging.local',original=fs.readFileSync(path,'utf8'),env=parseStagingConfiguration(original);
 const names=['VITE_SUPABASE_URL','VITE_SUPABASE_PUBLISHABLE_KEY','VITE_STAGING_PROJECT_REF'];
 if(names.some(name=>!env[name]?.includes('REPLACE_WITH')))throw new Error();
 const source=fs.readFileSync('src/supabase.js','utf8');
 const production={url:source.match(/const productionSupabaseUrl\s*=\s*'([^']+)'/)?.[1],key:source.match(/const productionSupabasePublishableKey\s*=\s*'([^']+)'/)?.[1]};
 if(!production.url||!production.key||!ref||/[\r\n\s#"'$]/.test(key))throw new Error();
 const next={...env,VITE_SUPABASE_URL:url.href,VITE_SUPABASE_PUBLISHABLE_KEY:key,VITE_STAGING_PROJECT_REF:ref};
 selectBackendEnvironment({...next,MODE:'staging'},production);
 let updated=original;for(const name of names)updated=updated.replace(new RegExp('^'+name+'=.*$','m'),name+'='+next[name]);
 if(fs.readFileSync(path,'utf8')!==original)throw new Error();
 fs.writeFileSync(path,updated);console.log('Saved staging placeholders. Production untouched.');
}catch{console.error('Not saved: verify the staging URL/publishable key, unchanged placeholders and file write access. No values displayed.');process.exitCode=1;}
