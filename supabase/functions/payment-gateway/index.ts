import {stagingRuntime,boundedBody,sandboxProviders} from '../_shared/staging-runtime.ts';
import {createSandboxProvider} from '../_shared/payment-providers.mjs';

Deno.serve(async request=>{
 const origin=Deno.env.get('STAGING_APP_ORIGIN')||'';
 const headers={
  'Content-Type':'application/json',
  'Cache-Control':'no-store',
  'Access-Control-Allow-Origin':origin,
  'Access-Control-Allow-Headers':'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods':'POST, OPTIONS',
  'Vary':'Origin'
 };

 const respond=(status:number,value:object)=>
  new Response(JSON.stringify(value),{status,headers});

 if(!origin||request.headers.get('Origin')!==origin)
  return respond(403,{error:'Origin denied'});

 if(request.method==='OPTIONS')
  return new Response(null,{status:204,headers});

 if(request.method!=='POST')
  return respond(405,{error:'Method denied'});

 try{
  const runtime=stagingRuntime('PAYMENT_GATEWAY_ENABLED');
  const auth=request.headers.get('Authorization')||'';

  if(!auth.startsWith('Bearer '))
   return respond(401,{error:'Authentication required'});

  const caller=runtime.caller(auth);
  const identity=await caller.auth.getUser();

  if(identity.error||!identity.data.user)
   return respond(401,{error:'Authentication required'});

  const body=JSON.parse(await boundedBody(request));

  if(
   Object.keys(body).some(
    key=>!['action','intent_id','channel','phone','refund_id'].includes(key)
   )
  ){
   return respond(400,{error:'Unsupported payment fields'});
  }

  const configs=sandboxProviders();

  if(body.action==='checkout'){
   if(typeof body.intent_id!=='string'||typeof body.channel!=='string')
    return respond(400,{error:'Valid payment intent and channel required'});

   const owned=await caller
    .from('payment_intents')
    .select('id,payer_id')
    .eq('id',body.intent_id)
    .eq('payer_id',identity.data.user.id)
    .single();

   if(owned.error)
    return respond(403,{error:'Intent unavailable'});

   const config=configs[body.channel];

   if(!config||!config.providerId)
    return respond(503,{error:'Approved sandbox adapter unavailable'});

   const adapter=createSandboxProvider(body.channel,config);

   const attempt=await runtime.server.rpc('payment_begin_attempt',{
    p_intent:body.intent_id,
    p_provider:config.providerId,
    p_channel:body.channel,
    p_merchant:config.merchantId
   });

   if(attempt.error||attempt.data?.payer_id!==identity.data.user.id)
    return respond(409,{error:'Intent cannot begin'});

   const checkout=await adapter.checkout(
    attempt.data,
    body.channel==='mobile_money'?{phone:body.phone}:{}
   );

   const bound=await runtime.server.rpc('payment_bind_reference',{
    p_attempt:attempt.data.attempt_id,
    p_reference:checkout.reference
   });

   if(bound.error)
    return respond(503,{
     error:'Provider result uncertain; reconcile before retrying'
    });

   return respond(200,{
    intent_id:body.intent_id,
    state:'provider_pending',
    checkout_url:checkout.checkout_url
   });
  }

  if(body.action==='refund'){
   if(typeof body.refund_id!=='string')
    return respond(400,{error:'Valid refund request required'});

   // Explicitly verify that the refund belongs to this signed-in user.
   const owned=await caller
    .from('payment_refund_requests')
    .select('id,state,payer_id')
    .eq('id',body.refund_id)
    .eq('payer_id',identity.data.user.id)
    .single();

   if(
    owned.error||
    owned.data?.payer_id!==identity.data.user.id||
    !['approved','processing'].includes(owned.data.state)
   ){
    return respond(403,{error:'Approved owned refund required'});
   }

   const reference='refund:'+body.refund_id;

   const reserved=await runtime.server.rpc('payment_refund_work',{
    p_id:body.refund_id,
    p_reference:reference,
    p_succeeded:null
   });

   if(reserved.error)
    return respond(409,{error:'Refund unavailable'});

   const value=reserved.data;
   const config=configs[value.channel];

   if(
    config?.providerId!==value.provider||
    config?.merchantId!==value.merchant_id
   ){
    return respond(503,{error:'Bound sandbox adapter unavailable'});
   }

   await createSandboxProvider(value.channel,config).refund(
    value.payment_reference,
    value.amount_minor,
    reference
   );

   return respond(200,{
    refund_id:body.refund_id,
    state:'processing'
   });
  }

  if(body.action==='reconcile'){
   const permitted=await caller.rpc('admin_operations_allowed');

   if(permitted.error||permitted.data!==true)
    return respond(403,{error:'MFA administrator required'});

   const owned=await caller
    .from('payment_intents')
    .select('id')
    .eq('id',body.intent_id)
    .single();

   if(owned.error)
    return respond(403,{error:'Intent unavailable'});

   return respond(409,{
    error:'Reconciliation runs through the trusted provider-report job, not browser-supplied amounts'
   });
  }

  return respond(400,{error:'Unsupported action'});

 }catch{
  return respond(503,{
   error:'Sandbox operation unavailable; inspect history before retrying'
  });
 }
});