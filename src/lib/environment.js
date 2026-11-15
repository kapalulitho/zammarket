export function selectBackendEnvironment(env,production){
 const mode=env.VITE_ZAMMARKET_ENV||(env.MODE==='staging'?'staging':'production');
 if(env.MODE==='staging'&&mode!=='staging')throw new Error('Staging mode cannot use the production configuration.');
 if(mode==='production'){if(env.VITE_SUPABASE_URL||env.VITE_SUPABASE_PUBLISHABLE_KEY)throw new Error('Custom backend variables require explicit staging mode.');return {...production,mode};}
 if(mode!=='staging'||env.VITE_STAGING_ACK!=='ISOLATED_NON_PRODUCTION')throw new Error('Staging configuration refused: explicit isolation acknowledgement required.');
 const ref=String(env.VITE_STAGING_PROJECT_REF||'');let url;try{url=new URL(env.VITE_SUPABASE_URL);}catch{throw new Error('Staging configuration refused: valid project URL required.');}
 if(!/^[a-z0-9]{20}$/.test(ref)||url.protocol!=='https:'||url.hostname!==`${ref}.supabase.co`||url.username||url.password||url.port||url.pathname!=='/'||url.search||url.hash||url.origin===new URL(production.url).origin)throw new Error('Staging configuration refused: use a distinct isolated Supabase project.');
 const key=String(env.VITE_SUPABASE_PUBLISHABLE_KEY||'');if(!key.startsWith('sb_publishable_')||key.length<25)throw new Error('Staging requires a browser-safe publishable key; secret/service-role keys are forbidden.');
 if(production.key&&key===production.key)throw new Error('Staging configuration refused: production key reuse is forbidden.');
 return {url:url.origin,key,mode,storageKey:`zammarket-staging-${ref}`};
}
