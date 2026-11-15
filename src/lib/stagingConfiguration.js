export const stagingVariables=['VITE_ZAMMARKET_ENV','VITE_STAGING_ACK','VITE_STAGING_PROJECT_REF','VITE_SUPABASE_URL','VITE_SUPABASE_PUBLISHABLE_KEY'];
// Never include values or source lines in errors: configuration can contain credentials.
export function parseStagingConfiguration(source){
 const env={};for(const line of source.replace(/^\uFEFF/,'').split(/\r?\n/)){const text=line.trim();if(!text||text.startsWith('#'))continue;const match=text.match(/^([A-Z][A-Z0-9_]*)\s*=\s*(.*)$/);if(!match)throw new Error('Invalid staging configuration line. Use NAME=value.');const [,name,raw]=match;if(!stagingVariables.includes(name))throw new Error('Unexpected staging variable. Use only the five names in .env.staging.example.');if(Object.hasOwn(env,name))throw new Error('Duplicate staging variable. Keep each required name once.');let value=raw.trim();if(value.startsWith('"')||value.startsWith("'")){if(value.length<2||value.at(-1)!==value[0])throw new Error('Unclosed staging configuration quote.');value=value.slice(1,-1);}env[name]=value;}
 return env;
}
export function stagingConfigurationStatus(env){return stagingVariables.map(name=>({name,status:!env[name]?'MISSING':/REPLACE_WITH/.test(env[name])?'PLACEHOLDER':'PRESENT'}));}
