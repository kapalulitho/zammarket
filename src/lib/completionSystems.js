const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const CREDENTIAL=/^([0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12})\.([0-9a-f]{64})$/i;

export function zambiaMobile(value){return /^\+260\d{9}$/.test(String(value||'').replaceAll(' ',''));}

export function ticketCredential(value){
 const match=CREDENTIAL.exec(String(value||'').trim());
 return match?{ticketId:match[1].toLowerCase(),token:match[2].toLowerCase()}:null;
}

export function paymentMinor(value){
 const numeric=Number(value);
 if(!Number.isFinite(numeric)||numeric<=0||numeric>1000000000)return null;
 const minor=Math.round(numeric*100);
 return Number.isSafeInteger(minor)&&minor>0?minor:null;
}

export function safeCheckoutUrl(value){
 try{
  const url=new URL(value);
  return url.protocol==='https:'&&!url.username&&!url.password?url.href:null;
 }catch{return null;}
}

export function paymentSources(data,userId){
 const rows=[];

 for(const order of data?.shopOrders||[])
  if(order.buyer_id===userId&&['requested','acknowledged'].includes(order.state))
   rows.push({kind:'shopping',id:order.id,label:`Shopping order ${order.id.slice(0,8)} · ZMW ${(order.subtotal_minor/100).toFixed(2)}`});

 for(const order of data?.foodOrders||[])
  if(order.customer_id===userId&&['submitted','accepted','preparing','ready'].includes(order.state))
   rows.push({kind:'food',id:order.id,label:`Food order ${order.id.slice(0,8)} · ZMW ${(order.total_minor/100).toFixed(2)}`});

 for(const stay of data?.stays||[])
  if(stay.guest_id===userId&&['requested','confirmed'].includes(stay.state))
   rows.push({kind:'stay',id:stay.id,label:`Stay request ${stay.id.slice(0,8)} · ZMW ${(stay.subtotal_minor/100).toFixed(2)}`});

 for(const event of data?.reservations||[])
  if(event.buyer_id===userId&&event.state==='held')
   rows.push({kind:'event',id:event.id,label:`Event reservation ${event.id.slice(0,8)} · ZMW ${((event.quantity*event.unit_price_minor)/100).toFixed(2)}`});

 for(const request of data?.work||[])
  if(request.requester_id===userId&&['accepted','enrolled','scheduled','awaiting_verification'].includes(request.state)&&Number(request.quote_minor)>0)
   rows.push({kind:'work',id:request.id,label:`${request.kind} request: ${request.title_snapshot} · ZMW ${(request.quote_minor/100).toFixed(2)}`});

 for(const cycle of data?.cycles||[])
  if(cycle.owner_id===userId&&cycle.state==='due')
   rows.push({kind:'billing',id:cycle.id,label:`Business billing cycle · ZMW ${(cycle.amount_minor/100).toFixed(2)}`});

 return rows;
}

export function createCompletionSystems(client,mode,user){

 async function identity(){
  if(mode!=='staging'||!user?.id)
   throw new Error('Secure operations require isolated staging.');

  const value=await client.auth.getUser();

  if(value.error||value.data.user?.id!==user.id)
   throw new Error('Your session changed. Sign in again and retry.');
 }

 async function result(query,message='The secure operation could not be confirmed. Refresh before retrying.'){
  const value=await query;

  if(value.error)
   throw new Error(value.error.code==='P0001'?value.error.message:message);

  return value.data;
 }

 return {

  async capability(){
   await identity();
   return result(client.rpc('completion_capabilities'),'The reviewed secure backend is unavailable.');
  },

  async load(){
   await identity();

   const [
    intents,
    refunds,
    batches,
    allocations,
    tickets,
    library,
    programs,
    work,
    holds,
    shopOrders,
    foodOrders,
    stays,
    reservations,
    cycles,
    ownEntries
   ]=await Promise.all([

    result(client.from('payment_intents').select('id,source_kind,source_id,amount_minor,currency,state,refunded_minor,quote_expires_at,created_at').order('created_at',{ascending:false}).limit(80)),

    result(client.from('payment_refund_requests').select('id,intent_id,amount_minor,state,reason,created_at').order('created_at',{ascending:false}).limit(80)),

    result(client.from('shop_allocation_batches').select('id,order_id,buyer_id,seller_id,state,expires_at,created_at').order('created_at',{ascending:false}).limit(80)),

    result(client.from('appointment_allocations').select('id,request_id,slot_id,requester_id,provider_id,state,expires_at,created_at').order('created_at',{ascending:false}).limit(80)),

    result(client.from('event_tickets').select('id,reservation_id,event_id,buyer_id,organiser_id,ordinal,state,issued_at,used_at,revoked_at,rotated_at').order('issued_at',{ascending:false}).limit(100)),

    result(client.rpc('course_my_library')),

    result(client.from('course_programs').select('id,source_entry_id,title_snapshot,summary,status,revision,access_days,published_price_minor,updated_at').eq('instructor_id',user.id).order('updated_at',{ascending:false}).limit(60)),

    result(client.from('marketplace_work_requests').select('id,kind,target_id,title_snapshot,requester_id,provider_id,state,quote_minor,created_at').or(`requester_id.eq.${user.id},provider_id.eq.${user.id}`).order('created_at',{ascending:false}).limit(100)),

    result(client.from('event_reservation_holds').select('reservation_id,category_id,state,expires_at,created_at').order('created_at',{ascending:false}).limit(80)),

    result(client.from('shop_order_requests').select('id,buyer_id,seller_id,subtotal_minor,state,created_at').eq('buyer_id',user.id).order('created_at',{ascending:false}).limit(80)),

    result(client.from('food_orders').select('id,customer_id,merchant_id,total_minor,state,created_at').eq('customer_id',user.id).order('created_at',{ascending:false}).limit(80)),

    result(client.from('stay_reservation_requests').select('id,guest_id,host_id,subtotal_minor,state,created_at').eq('guest_id',user.id).order('created_at',{ascending:false}).limit(80)),

    result(client.from('event_reservations').select('id,buyer_id,organiser_id,event_id,quantity,unit_price_minor,state,created_at').eq('buyer_id',user.id).order('created_at',{ascending:false}).limit(80)),

    result(client.from('billing_cycles').select('id,owner_id,amount_minor,state,ends_at,created_at').eq('owner_id',user.id).order('created_at',{ascending:false}).limit(80)),

    result(client.from('community_entries').select('id,kind,title,status,price,price_unit,starts_at,ends_at').eq('owner_id',user.id).in('kind',['event','learning']).order('created_at',{ascending:false}).limit(100))

   ]);

   return {
    intents,
    refunds,
    batches,
    allocations,
    tickets,
    library,
    programs,
    work,
    holds,
    shopOrders,
    foodOrders,
    stays,
    reservations,
    cycles,
    ownEntries
   };
  },

  async createIntent(kind,source,key){
   await identity();
   return result(client.rpc('payment_create_intent',{
    p_kind:kind,
    p_source:source,
    p_key:key
   }));
  },

  async checkout(intent,channel,phone){
   await identity();

   if(channel==='mobile_money'&&!zambiaMobile(phone))
    throw new Error('Use a Zambia mobile number such as +260971234567.');

   const body={
    action:'checkout',
    intent_id:intent,
    channel,
    ...(channel==='mobile_money'?{phone:String(phone).replaceAll(' ','') }:{})
   };

   const value=await client.functions.invoke('payment-gateway',{body});

   if(value.error)
    throw new Error('Sandbox checkout could not be started.');

   return value.data;
  },

  async requestRefund(intent,amount,reason,key){
   await identity();

   if(!paymentMinor(amount)||String(reason||'').trim().length<5)
    throw new Error('Enter a positive amount and a short reason.');

   return result(client.rpc('payment_request_refund',{
    p_intent:intent,
    p_amount:paymentMinor(amount),
    p_reason:String(reason).trim(),
    p_key:key
   }));
  },

  async reserveStock(order,key){
   await identity();

   return result(client.rpc('reserve_shop_allocation',{
    p_order:order,
    p_key:key
   }));
  },

  async commitStock(batch,intent){
   await identity();

   return result(client.rpc('commit_shop_allocation',{
    p_batch:batch,
    p_intent:intent||null
   }));
  },

  async issueTickets(reservation,intent,key){
   await identity();

   return result(client.rpc('issue_event_tickets',{
    p_reservation:reservation,
    p_payment_intent:intent||null,
    p_key:key
   }));
  },

  async rotateTicket(ticket){
   await identity();

   return result(client.rpc('rotate_event_ticket',{
    p_ticket:ticket
   }));
  },

  async validateTicket(event,credential){
   await identity();

   if(!ticketCredential(credential))
    throw new Error('Scan or paste a complete ticket credential.');

   return result(client.rpc('validate_event_ticket',{
    p_event:event,
    p_credential:credential.trim()
   }));
  },

  async saveCourse(source,course,revision,summary,days){
   await identity();

   return result(client.rpc('course_save_program',{
    p_source:source,
    p_course:course||null,
    p_revision:revision??null,
    p_summary:summary,
    p_access_days:Number(days)
   }));
  },

  async saveCourseModule(course,module,position,title){
   await identity();

   return result(client.rpc('course_save_module',{
    p_course:course,
    p_module:module||null,
    p_position:Number(position),
    p_title:title
   }));
  },

  async saveCourseLesson(course,module,lesson,position,title,summary,preview){
   await identity();

   return result(client.rpc('course_save_lesson',{
    p_course:course,
    p_module:module,
    p_lesson:lesson||null,
    p_position:Number(position),
    p_title:title,
    p_summary:summary,
    p_preview:!!preview
   }));
  },

  async publishCourse(course,revision){
   await identity();

   return result(client.rpc('course_publish',{
    p_course:course,
    p_revision:revision
   }));
  },

  async unpublishCourse(course,revision){
   await identity();

   return result(client.rpc('course_unpublish',{
    p_course:course,
    p_revision:revision
   }));
  },

  async activateEnrolment(request,intent,key,expiresAt){
   await identity();

   return result(client.rpc('course_activate_enrolment',{
    p_request:request,
    p_payment_intent:intent||null,
    p_key:key,
    p_expires_at:expiresAt||null
   }));
  },

  // Corrected progress-state handling.
  // The interface may send "started", but the database expects "in_progress".
  async saveProgress(grant,lesson,state,seconds){
   await identity();

   const normalizedState=state==='started'?'in_progress':state;

   if(
    !['not_started','in_progress','completed'].includes(normalizedState)||
    !Number.isInteger(Number(seconds))||
    Number(seconds)<0||
    Number(seconds)>86400
   ){
    throw new Error('Progress details are invalid.');
   }

   return result(client.rpc('course_save_progress',{
    p_grant:grant,
    p_lesson:lesson,
    p_state:normalizedState,
    p_position_seconds:Number(seconds)
   }));
  },

  async courseLessons(course){
   await identity();

   return result(client.from('course_lessons')
    .select('id,module_id,position,title,summary,preview')
    .eq('course_id',course)
    .order('position')
    .limit(500));
  },

  async courseMaterials(course){
   await identity();

   return result(client.rpc('course_owner_materials',{
    p_course:course
   }));
  },

  async requestMaterial(material){
   await identity();

   const value=await client.functions.invoke('course-delivery',{
    body:{material_id:material}
   });

   if(value.error)
    throw new Error('Protected course delivery is unavailable.');

   return value.data;
  }

 };
}