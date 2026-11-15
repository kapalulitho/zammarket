// STAGING ONLY. Do not deploy or set COURSE_DELIVERY_ENABLED until 040 is reviewed,
// installed in the isolated staging project and its database gate is deliberately enabled.
import {boundedBody,stagingRuntime} from '../_shared/staging-runtime.ts';

const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

Deno.serve(async request=>{
 const origin=Deno.env.get('STAGING_APP_ORIGIN')||'';
 const headers={
  'Access-Control-Allow-Origin':origin,
  'Access-Control-Allow-Headers':'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods':'POST, OPTIONS',
  'Cache-Control':'no-store',
  'Vary':'Origin'
 };
 const respond=(status:number,body:object)=>new Response(JSON.stringify(body),{status,headers:{...headers,'Content-Type':'application/json'}});
 if(!origin||request.headers.get('Origin')!==origin)return respond(403,{error:'Origin denied'});
 if(request.method==='OPTIONS')return new Response(null,{status:204,headers});
 if(request.method!=='POST')return respond(405,{error:'Method denied'});
 try{
  const runtime=stagingRuntime('COURSE_DELIVERY_ENABLED');
  const authorization=request.headers.get('Authorization')||'';
  if(!authorization.startsWith('Bearer '))return respond(401,{error:'Authentication required'});
  if(Number(request.headers.get('content-length')||0)>512)return respond(413,{error:'Request too large'});
  const raw=await boundedBody(request,512);
  const body=JSON.parse(raw||'{}');
  if(!body||Object.keys(body).some(key=>key!=='material_id')||!UUID.test(body.material_id||''))return respond(400,{error:'Invalid material'});
  const caller=runtime.caller(authorization);
  const identity=await caller.auth.getUser();
  if(identity.error||!identity.data.user)return respond(401,{error:'Authentication required'});
  // Only the service role can call this RPC. The RPC independently checks the learner,
  // active grant, expiry, publication, moderation, refund and approved scan state.
  const permission=await runtime.server.rpc('course_authorize_delivery',{p_material:body.material_id,p_learner:identity.data.user.id});
  const path=permission.data;
  if(permission.error||typeof path!=='string'||path.length>500||path.includes('..')||path.includes('//')||!/^[0-9a-f-]{36}\/[0-9a-f-]{36}\/[A-Za-z0-9][A-Za-z0-9._-]{0,199}$/i.test(path))return respond(403,{error:'Course access denied or expired'});
  const signed=await runtime.server.storage.from('course-materials').createSignedUrl(path,60,{download:true});
  if(signed.error||!signed.data?.signedUrl)return respond(503,{error:'Course material unavailable'});
  return respond(200,{url:signed.data.signedUrl,expires_in:60,expires_at:new Date(Date.now()+60000).toISOString()});
 }catch{
  return respond(503,{error:'Course delivery unavailable'});
 }
});
