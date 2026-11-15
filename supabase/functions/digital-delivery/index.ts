// STAGING ONLY. Not deployed. Keep DIGITAL_DELIVERY_ENABLED unset until approved.
import {createClient} from 'npm:@supabase/supabase-js@2.117.3';
Deno.serve(async request=>{
 const origin=Deno.env.get('STAGING_APP_ORIGIN')||'',headers={'Access-Control-Allow-Origin':origin,'Access-Control-Allow-Headers':'authorization, apikey, content-type, x-client-info','Access-Control-Allow-Methods':'POST, OPTIONS','Cache-Control':'no-store','Vary':'Origin'};
 const respond=(status:number,body:object)=>new Response(JSON.stringify(body),{status,headers:{...headers,'Content-Type':'application/json'}});
 if(!origin||request.headers.get('Origin')!==origin)return respond(403,{error:'Origin denied'});
 if(request.method==='OPTIONS')return new Response(null,{status:204,headers});
 if(request.method!=='POST')return respond(405,{error:'Method denied'});
 const url=Deno.env.get('SUPABASE_URL')||'',ref=Deno.env.get('EXPECTED_STAGING_PROJECT_REF')||'';
 if(Deno.env.get('ZAMMARKET_ENV')!=='staging'||Deno.env.get('DIGITAL_DELIVERY_ENABLED')!=='true'||!ref||ref==='tznbkieczyxwpyhpxeui'||url.replace(/\/$/,'')!==`https://${ref}.supabase.co`)return respond(503,{error:'Staging delivery not activated'});
 try{
 const authorization=request.headers.get('Authorization')||'';if(!authorization.startsWith('Bearer '))return respond(401,{error:'Authentication required'});
 const publicKey=Deno.env.get('SUPABASE_ANON_KEY')||'',secret=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')||'';
 if(!publicKey||!secret)return respond(503,{error:'Server configuration unavailable'});
 if(Number(request.headers.get('content-length')||0)>512)return respond(413,{error:'Request too large'});
 const reader=request.body?.getReader();let raw='';if(reader){const decoder=new TextDecoder();let length=0;while(true){const chunk=await reader.read();if(chunk.done)break;length+=chunk.value.byteLength;if(length>512){await reader.cancel();return respond(413,{error:'Request too large'});}raw+=decoder.decode(chunk.value,{stream:true});}raw+=decoder.decode();}if(raw.length>512)return respond(413,{error:'Request too large'});const body=JSON.parse(raw);
 if(!body||Object.keys(body).some(key=>key!=='asset_id')||!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(body.asset_id||''))return respond(400,{error:'Invalid asset'});
 const caller=createClient(url,publicKey,{global:{headers:{Authorization:authorization}},auth:{persistSession:false,autoRefreshToken:false}});
 const identity=await caller.auth.getUser();if(identity.error||!identity.data.user)return respond(401,{error:'Authentication required'});
 const permission=await caller.rpc('digital_authorize_delivery',{p_asset:body.asset_id});if(permission.error||typeof permission.data!=='string'||permission.data.includes('..')||!permission.data.match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\/[A-Za-z0-9][A-Za-z0-9._/-]{0,499}$/i)||permission.data.includes('//'))return respond(403,{error:'Digital access denied or limit reached'});
 // Privileged client is used only after caller-scoped eligibility/scan/revocation checks.
 const server=createClient(url,secret,{auth:{persistSession:false,autoRefreshToken:false}});
 const expiresAt=new Date(Date.now()+60000).toISOString();
 const signed=await server.storage.from('digital-products').createSignedUrl(permission.data,60,{download:true});
 if(signed.error||!signed.data?.signedUrl)return respond(503,{error:'Download unavailable'});
 return respond(200,{url:signed.data.signedUrl,expires_in:60,expires_at:expiresAt});
 }catch{return respond(400,{error:'Download request unavailable'});}
});
