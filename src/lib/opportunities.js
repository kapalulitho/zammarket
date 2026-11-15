export function opportunityDraft(kind,values,item){
 if(!['job','learning'].includes(kind))throw new Error('Unsupported opportunity type.');
 const note=String(values.note??'').trim();if(note.length<10||note.length>2000)throw new Error('Use a non-sensitive note of 10–2,000 characters.');
 if(kind==='job')return {kind,entry_id:item.id,title:item.title,organisation:item.organisation,location:item.location,note,state:'draft',availability:String(values.availability??'To discuss').slice(0,80),...careerPreparation(values)};
 const hours=Number(values.hours);if(!Number.isInteger(hours)||hours<1||hours>40)throw new Error('Plan 1–40 whole study hours per week.');
 return {kind,entry_id:item.id,title:item.title,organisation:item.organisation,location:item.location,note,hours,state:'preview',completed:[]};
}
export function filterOpportunities(items,{category='',min='',max='',basis='',free=false,kind}={}){
 const low=min===''?null:Number(min),high=max===''?null:Number(max);
 if((low!==null&&(!Number.isFinite(low)||low<0))||(high!==null&&(!Number.isFinite(high)||high<0))||(low!==null&&high!==null&&low>high)||(kind==='job'&&(low!==null||high!==null)&&!basis))return [];
 return items.filter(item=>(!category||item.category===category)&&(!basis||item.price_unit===basis)&&(!free||item.price===0)&&(low===null||item.price!=null&&item.price>=low)&&(high===null||item.price!=null&&item.price<=high));
}
export function productCartSummary(lines,products,isAvailable){
 const seen=new Set();let total=0;const items=lines.map(line=>{const product=products.find(item=>String(item.id)===line.id);if(seen.has(line.id)||!Number.isInteger(line.quantity)||line.quantity<1||line.quantity>20)throw new Error('Use unique products with quantities of 1–20.');seen.add(line.id);const price=Number(product?.price),valid=product&&String(product.price??'').trim()!==''&&Number.isFinite(price)&&price>=0&&Number.isSafeInteger(Math.round(price*100))&&isAvailable(product);const subtotal=valid?Math.round(price*100)*line.quantity:0;if(!Number.isSafeInteger(subtotal)||!Number.isSafeInteger(total+subtotal))throw new Error('This subtotal is too large for a safe preview.');total+=subtotal;return {...line,product,available:!!valid,subtotal};});return {items,total_minor:total,incomplete:items.some(item=>!item.available)};
}
import {careerPreparation} from './careerEvents.js';
