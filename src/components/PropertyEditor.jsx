import {useRef,useState} from 'react';
import {propertyTypes,propertyPurposes,priceBases,propertyInput} from '../lib/property';
// Short three-step form: Basics -> Photos -> Details. All fields stay in one <form>, so saving works exactly as before.
const steps=['Basics','Photos','Details'];
export default function PropertyEditor({item,onReview,onCancel,busy}){
 const [error,setError]=useState('');const [step,setStep]=useState(1);const form=useRef(null);
 function next(){
  const fields=form.current.querySelectorAll(`[data-step="${step}"] input,[data-step="${step}"] select,[data-step="${step}"] textarea`);
  for(const field of fields){if(!field.reportValidity())return;}
  setError('');setStep(value=>Math.min(steps.length,value+1));
 }
 function submit(event){
  event.preventDefault();
  if(step<steps.length){next();return;}
  try{const el=event.currentTarget;const values=Object.fromEntries(new FormData(el));onReview(propertyInput(values),Array.from(el.elements.photos.files),item);}catch(failure){setError(failure.message);}
 }
 return <form ref={form} className="module-form form-page" onSubmit={submit}>
  <div className="step-header">
   <button type="button" className="back-link" disabled={busy} onClick={onCancel}>← Back</button>
   <h2>{item?'Edit property':'Post a property'}</h2>
   <p className="muted">Step {step} of {steps.length} · {steps[step-1]}</p>
   <div className="step-bar" aria-hidden="true"><span style={{width:`${step/steps.length*100}%`}}/></div>
  </div>
  {error&&<p role="alert">{error}</p>}
  <div data-step="1" hidden={step!==1}>
   <label>Title<input name="title" required minLength={3} maxLength={150} defaultValue={item?.title}/></label>
   <div className="form-columns">
    <label>Property type<select name="property_type" defaultValue={item?.property_type}>{propertyTypes.map(value=><option key={value}>{value}</option>)}</select></label>
    <label>Sale or rent<select name="purpose" defaultValue={item?.purpose}>{propertyPurposes.map(value=><option key={value}>{value}</option>)}</select></label>
   </div>
   <label>Posting as<select name="agent_type" defaultValue={item?.agent_type}><option>Owner</option><option>Agent</option></select><small>Self-declared, not a verified badge.</small></label>
  </div>
  <div data-step="2" hidden={step!==2}>
   <label>Photos<input name="photos" type="file" accept="image/jpeg,image/png,image/webp" multiple/><small>Up to 8 photos, 5 MB each.{item?.media_paths?.length?` ${item.media_paths.length} existing kept.`:''}</small></label>
  </div>
  <div data-step="3" hidden={step!==3}>
   <label>Town / area<input name="location" required minLength={2} maxLength={200} defaultValue={item?.location} placeholder="e.g. Lusaka, Woodlands"/><small>Town or area only, no street address.</small></label>
   <div className="form-columns">
    <label>Price (ZMW)<input name="price" type="number" required min="0" max="1000000000000" step="0.01" defaultValue={item?.price}/></label>
    <label>Price basis<select name="price_basis" defaultValue={item?.price_basis}>{priceBases.filter(value=>value!=='Per night'||item?.price_basis===value).map(value=><option key={value}>{value}</option>)}</select></label>
   </div>
   <div className="form-columns">{[['bedrooms','Bedrooms'],['bathrooms','Bathrooms'],['area_sqm','Area (m²)']].map(([key,label])=><label key={key}>{label}<input name={key} type="number" min="0" max={key==='area_sqm'?'1000000000000':'100'} step={key==='area_sqm'?'0.01':'1'} defaultValue={item?.[key]??''}/></label>)}</div>
   <label>Description<textarea name="description" rows={4} required minLength={20} maxLength={6000} defaultValue={item?.description}/></label>
   <label>Visibility<select name="status" defaultValue={item?.status==='published'?'published':'draft'}><option value="draft">Private draft</option><option value="published">Public listing</option></select></label>
  </div>
  <div className="listing-actions">
   {step>1&&<button type="button" className="secondary-button" disabled={busy} onClick={()=>setStep(step-1)}>Back</button>}
   {step<steps.length?<button type="button" className="primary-button" onClick={next}>Next</button>:<button className="primary-button" disabled={busy}>{busy?'Checking photos…':'Review property'}</button>}
  </div>
 </form>;
}