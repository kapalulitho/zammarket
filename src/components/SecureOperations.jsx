import {useEffect,useMemo,useRef,useState} from 'react';
import {supabase,backendMode} from '../supabase';
import {createCompletionSystems,paymentSources,safeCheckoutUrl} from '../lib/completionSystems';
import {formatMinor} from '../lib/servicePlanning';

const requestKey=()=>crypto.randomUUID();
const zambiaTime=value=>new Date(value).toLocaleString('en-ZM',{timeZone:'Africa/Lusaka'});

export default function SecureOperations({user,onNavigate}){
 const repo=useMemo(()=>createCompletionSystems(supabase,backendMode,user),[user]);
 const keys=useRef(new Map());
 const [tab,setTab]=useState('payments'),[cap,setCap]=useState(null),[data,setData]=useState(null),[error,setError]=useState(''),[notice,setNotice]=useState(''),[busy,setBusy]=useState(false),[revision,setRevision]=useState(0),[checkout,setCheckout]=useState(null),[lessons,setLessons]=useState([]),[courseDetail,setCourseDetail]=useState(null);

 useEffect(()=>{
  let active=true;
  if(backendMode!=='staging')return;
  repo.capability().then(value=>{
   if(!active||value?.version!==1)throw new Error('The held secure backend is unavailable.');
   setCap(value);
   return repo.load();
  }).then(value=>{
   if(active){setData(value);setError('');}
  }).catch(failure=>{
   if(active)setError(failure.message);
  });
  return()=>{active=false;};
 },[repo,revision]);

 const keyFor=value=>{
  if(!keys.current.has(value))keys.current.set(value,requestKey());
  return keys.current.get(value);
 };

 async function perform(action,message){
  if(busy)return;
  setBusy(true);
  setError('');
  setNotice('');
  try{
   const value=await action();
   if(value==null)throw new Error('No server confirmation.');
   setNotice(message);
   setRevision(value=>value+1);
   return value;
  }catch(failure){
   setError(failure.message);
  }finally{
   setBusy(false);
  }
 }

 const sources=paymentSources(data,user.id);
 const events=(data?.ownEntries||[]).filter(row=>row.kind==='event');
 const learning=(data?.ownEntries||[]).filter(row=>row.kind==='learning');

 if(backendMode!=='staging')return <section className="platform-page">
  <span className="eyebrow">SECURE OPERATIONS</span>
  <h1>Payments, allocations, tickets & courses</h1>
  <div className="setup-notice">These sensitive systems are disabled on the production connection. They require held migrations 036–040, isolated staging review and explicit activation.</div>
 </section>;

 if(!cap||!data)return <section className="platform-page">
  <span className="eyebrow">STAGING-ONLY SECURE OPERATIONS</span>
  <h1>Payments, capacity, tickets & learning</h1>
  {error?<p role="alert">{error}</p>:<p role="status">Checking the reviewed staging capabilities…</p>}
 </section>;

 return <section className="platform-page">
  <span className="eyebrow">STAGING-ONLY SECURE OPERATIONS</span>
  <h1>Payments, capacity, tickets & learning</h1>
  <p>Every action is server-authorized. No live money, booking, ticket or course publication is enabled here.</p>

  {error&&<p role="alert">{error}</p>}
  {notice&&<p role="status">{notice}</p>}

  <div className="setup-notice">
   <strong>Server gates:</strong> payments {cap.payments?'enabled':'off'} · stock {cap.stock?'enabled':'off'} · ticket issue {cap.ticket_issuance?'enabled':'off'} · course publishing {cap.course_publishing?'enabled':'off'} · moderation {cap.moderation?'enabled':'off'}.
  </div>

  <nav className="module-tabs">
   {[['payments','Payments'],['allocations','Inventory'],['tickets','Tickets'],['courses','Courses'],['moderation','Moderation']].map(([value,label])=><button key={value} aria-pressed={tab===value} onClick={()=>setTab(value)}>{label}</button>)}
   <button disabled={busy} onClick={()=>setRevision(value=>value+1)}>Refresh</button>
  </nav>

  {tab==='payments'&&<Payments
   data={data}
   sources={sources}
   cap={cap}
   busy={busy}
   checkout={checkout}
   onCreate={(kind,source)=>perform(()=>repo.createIntent(kind,source,keyFor(`intent:${kind}:${source}`)),'Server-priced sandbox intent created. No money moved.')}
   onCheckout={async(intent,channel,phone)=>{
    const value=await perform(()=>repo.checkout(intent,channel,phone),'Sandbox handoff prepared; settlement awaits a signed callback.');
    if(value?.checkout_url)setCheckout(safeCheckoutUrl(value.checkout_url));
   }}
   onRefund={(intent,amount,reason)=>perform(()=>repo.requestRefund(intent,amount,reason,keyFor(`refund:${intent}:${amount}:${reason}`)),'Refund request recorded for independent review.')}
  />}

  {tab==='allocations'&&<Allocations
   data={data}
   cap={cap}
   busy={busy}
   user={user}
   onReserve={order=>perform(()=>repo.reserveStock(order,keyFor(`stock:${order}`)),'Stock hold created. It expires server-side and is not a sale.')}
  />}

  {tab==='tickets'&&<Tickets
   data={data}
   cap={cap}
   busy={busy}
   user={user}
   events={events}
   onIssue={(reservation,intent)=>perform(()=>repo.issueTickets(reservation,intent,keyFor(`ticket:${reservation}`)),'Ticket credentials were returned once. Store them securely.')}
   onRotate={ticket=>perform(()=>repo.rotateTicket(ticket),'Replacement credential returned once; the earlier credential is invalid.')}
   onValidate={(event,credential)=>perform(()=>repo.validateTicket(event,credential),'Ticket validated once; attendance was updated.')}
  />}

  {tab==='courses'&&<Courses
   data={data}
   cap={cap}
   busy={busy}
   user={user}
   learning={learning}
   lessons={lessons}
   courseDetail={courseDetail}
   onSave={(source,course,courseRevision,summary,days)=>perform(()=>repo.saveCourse(source,course,courseRevision,summary,days),'Private course draft saved.')}
   onPublish={(course,courseRevision)=>perform(()=>repo.publishCourse(course,courseRevision),'Course publication confirmed by staging.')}
   onUnpublish={(course,courseRevision)=>perform(()=>repo.unpublishCourse(course,courseRevision),'Course withdrawn from public discovery.')}
   onActivate={(request,intent)=>perform(()=>repo.activateEnrolment(request,intent,keyFor(`enrol:${request}`)),'Eligible learner access grant created.')}
   onLessons={async course=>{
    setCourseDetail(course);
    setLessons([]);
    try{setLessons(await repo.courseLessons(course.id));}
    catch(failure){setError(failure.message);}
   }}
   onProgress={(grant,lesson,state,seconds)=>perform(()=>repo.saveProgress(grant,lesson,state,seconds),'Learning progress saved for the authorised learner.')}
  />}

  {tab==='moderation'&&<Moderation cap={cap} onNavigate={onNavigate}/>}
 </section>;
}

function Payments({data,sources,cap,busy,checkout,onCreate,onCheckout,onRefund}){
 return <div>
  <h2>Server-priced sandbox payments</h2>
  <p>Amounts come from an order, reservation, request or billing cycle. The browser cannot supply a price, result or provider reference.</p>

  <form className="module-form form-page" onSubmit={event=>{
   event.preventDefault();
   const [kind,id]=String(new FormData(event.currentTarget).get('source')).split('|');
   onCreate(kind,id);
  }}>
   <label>Payable record
    <select name="source" required defaultValue="">
     <option value="" disabled>Select an eligible record</option>
     {sources.map(row=><option key={row.kind+row.id} value={row.kind+'|'+row.id}>{row.label}</option>)}
    </select>
   </label>
   <button disabled={busy||!cap.payments||!sources.length}>Create server-priced intent</button>
  </form>

  {!sources.length&&<p>No eligible positive-priced records are available.</p>}

  <h3>My payment intents</h3>
  {data.intents.map(intent=><article className="managed-listing" key={intent.id}>
   <strong>{intent.source_kind} · {formatMinor(intent.amount_minor)}</strong>
   <p>{intent.state} · expires {zambiaTime(intent.quote_expires_at)}</p>

   {['created','provider_pending','failed'].includes(intent.state)&&<form className="module-form" onSubmit={event=>{
    event.preventDefault();
    const form=new FormData(event.currentTarget);
    onCheckout(intent.id,form.get('channel'),form.get('phone'));
   }}>
    <label>Sandbox channel
     <select name="channel">
      <option value="mobile_money">Mobile money</option>
      <option value="card">Card sandbox</option>
     </select>
    </label>
    <label>Mobile number (mobile-money only)
     <input name="phone" inputMode="tel" placeholder="+260971234567"/>
    </label>
    <button disabled={busy||!cap.payments}>Request sandbox handoff</button>
   </form>}

   {intent.state==='settled'&&<form className="module-form" onSubmit={event=>{
    event.preventDefault();
    const form=new FormData(event.currentTarget);
    onRefund(intent.id,form.get('amount'),form.get('reason'));
   }}>
    <label>Refund amount ZMW
     <input required name="amount" min="0.01" step="0.01" type="number"/>
    </label>
    <label>Reason
     <textarea required name="reason" minLength="5" maxLength="1000"/>
    </label>
    <button disabled={busy}>Request refund review</button>
   </form>}
  </article>)}

  {checkout&&<p role="status">Sandbox checkout link: <a href={checkout} target="_blank" rel="noopener noreferrer">continue securely</a>. Do not enter real payment details.</p>}

  <h3>Refund history</h3>
  {data.refunds.map(row=><p key={row.id}>{formatMinor(row.amount_minor)} · {row.state} · {row.reason}</p>)}
 </div>;
}

function Allocations({data,cap,busy,user,onReserve}){
 const orders=data.shopOrders.filter(row=>row.buyer_id===user.id&&['requested','acknowledged'].includes(row.state));

 return <div>
  <h2>Stock holds & appointment capacity</h2>
  <p>Finite stock is held for 15 minutes, then commits only after matching verified payment. Food and stays retain their own server locks.</p>

  {orders.map(row=><article className="managed-listing" key={row.id}>
   <strong>Shopping order {row.id.slice(0,8)} · {formatMinor(row.subtotal_minor)}</strong>
   <p>{row.state}</p>
   <button disabled={busy||!cap.stock} onClick={()=>onReserve(row.id)}>Hold exact stock</button>
  </article>)}

  {data.batches.map(batch=><article className="managed-listing" key={batch.id}>
   <strong>Stock hold {batch.id.slice(0,8)} · {batch.state}</strong>
   <p>Expires {zambiaTime(batch.expires_at)}</p>
  </article>)}

  <h3>Appointment allocations</h3>
  {data.allocations.map(row=><p key={row.id}>{row.state} · request {row.request_id.slice(0,8)} · expires {zambiaTime(row.expires_at)}</p>)}

  {!orders.length&&!data.batches.length&&!data.allocations.length&&<p>No authorised allocation records yet.</p>}
 </div>;
}

function Tickets({data,cap,busy,user,events,onIssue,onRotate,onValidate}){
 const reservations=data.reservations.filter(row=>row.buyer_id===user.id&&row.state==='held');

 return <div>
  <h2>Secure tickets & attendance</h2>
  <p>Issue only after exact verified payment—or for a free reservation. Credentials are returned only when issued or replaced, and organisers validate them once.</p>

  {reservations.map(row=>{
   const payment=data.intents.find(intent=>intent.source_kind==='event'&&intent.source_id===row.id&&intent.state==='settled');

   return <article className="managed-listing" key={row.id}>
    <strong>Reservation {row.id.slice(0,8)} · {row.quantity} ticket(s)</strong>
    <p>{formatMinor(row.quantity*row.unit_price_minor)} · {data.holds.find(hold=>hold.reservation_id===row.id)?.state||'legacy reservation'}</p>
    <button disabled={busy||!cap.ticket_issuance} onClick={()=>onIssue(row.id,payment?.id||null)}>Issue / recover tickets</button>
   </article>;
  })}

  <h3>My ticket wallet</h3>
  {data.tickets.filter(row=>row.buyer_id===user.id).map(row=><article className="managed-listing" key={row.id}>
   <strong>Ticket {row.ordinal} · {row.state}</strong>
   <p>Event {row.event_id.slice(0,8)} · issued {zambiaTime(row.issued_at)}</p>
   {row.state==='issued'&&<button disabled={busy||!cap.ticket_issuance} onClick={()=>onRotate(row.id)}>Replace credential</button>}
  </article>)}

  <h3>Organiser validation</h3>
  <form className="module-form form-page" onSubmit={event=>{
   event.preventDefault();
   const form=new FormData(event.currentTarget);
   onValidate(form.get('event'),form.get('credential'));
  }}>
   <label>My event
    <select name="event" required defaultValue="">
     <option value="" disabled>Select event</option>
     {events.map(row=><option key={row.id} value={row.id}>{row.title}</option>)}
    </select>
   </label>
   <label>Ticket credential
    <textarea name="credential" required maxLength="120" placeholder="Scan or paste the ticket credential"/>
   </label>
   <button disabled={busy||!cap.ticket_validation||!events.length}>Validate once & record attendance</button>
  </form>
 </div>;
}

function Courses({data,cap,busy,user,learning,lessons,courseDetail,onSave,onPublish,onUnpublish,onActivate,onLessons,onProgress}){
 const instructorRequests=data.work.filter(row=>row.kind==='learning'&&row.provider_id===user.id&&row.state==='enrolled');

 return <div>
  <h2>Secure course management & learning library</h2>
  <p>Outlines remain drafts until all private materials have passed scanning. Paid access requires exact verified payment and delivery uses short-lived signed links.</p>

  <form className="module-form form-page" onSubmit={event=>{
   event.preventDefault();
   const form=new FormData(event.currentTarget);
   onSave(form.get('source'),form.get('course')||null,form.get('revision')===''?null:Number(form.get('revision')),form.get('summary'),form.get('days'));
  }}>
   <label>Owned learning listing
    <select name="source" required defaultValue="">
     <option value="" disabled>Select source</option>
     {learning.map(row=><option key={row.id} value={row.id}>{row.title}</option>)}
    </select>
   </label>

   <label>Existing draft (optional)
    <select name="course">
     <option value="">Create a course draft</option>
     {data.programs.filter(row=>row.status==='draft').map(row=><option key={row.id} value={row.id}>{row.title_snapshot}</option>)}
    </select>
   </label>

   <label>Draft revision for edit (blank for new)
    <input name="revision" type="number" min="0"/>
   </label>

   <label>Course summary
    <textarea name="summary" required minLength="10" maxLength="3000"/>
   </label>

   <label>Access days
    <input name="days" type="number" required min="1" max="365" defaultValue="30"/>
   </label>

   <button disabled={busy||!learning.length}>Save private course draft</button>
  </form>

  {data.programs.map(row=><article className="managed-listing" key={row.id}>
   <strong>{row.title_snapshot} · {row.status}</strong>
   <p>{row.summary} · revision {row.revision}</p>
   <button disabled={busy} onClick={()=>onLessons(row)}>View authorised lessons</button>
   {row.status==='draft'
    ?<button disabled={busy||!cap.course_publishing} onClick={()=>onPublish(row.id,row.revision)}>Publish after server checks</button>
    :<button disabled={busy} onClick={()=>onUnpublish(row.id,row.revision)}>Unpublish</button>}
  </article>)}

  {courseDetail?<section className="managed-listing">
   <h3>{courseDetail.title_snapshot} lessons</h3>
   {lessons.map(row=><p key={row.id}>{row.position}. {row.title}{row.preview?' · preview':''}</p>)}
   {!lessons.length&&<p>No accessible lessons yet.</p>}
  </section>:null}

  <h3>Activate enrolled learners</h3>
  {instructorRequests.map(row=>{
   const payment=data.intents.find(intent=>intent.source_kind==='work'&&intent.source_id===row.id&&intent.state==='settled');

   return <article className="managed-listing" key={row.id}>
    <strong>{row.title_snapshot}</strong>
    <p>Enrolled request {row.id.slice(0,8)}</p>
    <button disabled={busy||!cap.course_publishing} onClick={()=>onActivate(row.id,payment?.id||null)}>Grant eligible course access</button>
   </article>;
  })}

  <h3>My active library</h3>
  {data.library.map(row=><article className="managed-listing" key={row.grant_id}>
   <strong>{row.title}</strong>
   <p>{row.completed_lessons}/{row.total_lessons} lessons · access until {zambiaTime(row.expires_at)}</p>
   <button disabled={busy||!lessons[0]} onClick={()=>onProgress(row.grant_id,lessons[0].id,'in_progress',0)}>Save first loaded lesson progress</button>
  </article>)}
 </div>;
}

function Moderation({cap,onNavigate}){
 return <div>
  <h2>Server-enforced moderation</h2>
  <p>Suspensions and content restrictions are decided through MFA-protected review. This page does not grant administration or remove content from the browser.</p>
  <p className="setup-notice">Enforcement is {cap.moderation?'enabled in staging':'off'}. Production remains unchanged pending separate approval.</p>
  <button onClick={()=>onNavigate('Admin Review')}>Open authorised review workspace</button>
 </div>;
}