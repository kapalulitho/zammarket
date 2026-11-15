const numberOrNull=value=>value===''||value==null?null:Number(value);
export const promotionLabels={sponsored_listing:'Sponsored listing',boost:'Paid boost',business_subscription:'Business subscription',advertising:'Advertising campaign'};
export function stockInput(quantity,variants=[]){
 if(!Array.isArray(variants)||variants.length>30)throw new Error('Use at most 30 variants.');
 const labels=new Set();const options=variants.map(row=>{
  const label=String(row.label??'').trim();const units=Number(row.quantity);const price=numberOrNull(row.price);
  if(!label||label.length>100)throw new Error('Each variant needs a label of 1–100 characters.');
  if(labels.has(label.toLowerCase()))throw new Error('Each size / colour option needs a different label.');labels.add(label.toLowerCase());
  if(row.quantity===''||row.quantity==null||!Number.isInteger(units)||units<0||units>1000000)throw new Error('Variant quantities must be whole numbers from 0 to 1,000,000.');
  if(price!==null&&(!Number.isFinite(price)||price<0))throw new Error('Variant prices must be zero or more.');
  return {label,quantity:units,price};
 });
 const total=options.length?options.reduce((sum,row)=>sum+row.quantity,0):Number(quantity);
 if((!options.length&&(quantity===''||quantity==null))||!Number.isInteger(total)||total<0||total>1000000)throw new Error('Total stock must be a whole number from 0 to 1,000,000.');
 return {quantity:total,variants:options};
}
export function stockSummary(items,stocks,threshold=3){
 const ids=new Set(items.map(item=>String(item.id)));const known=stocks.filter(stock=>ids.has(String(stock.listing_id)));
 return {products:items.length,published:known.length,unknown:items.length-known.length,units:known.reduce((sum,row)=>sum+Number(row.quantity),0),empty:known.filter(row=>row.quantity===0).length,low:known.filter(row=>row.quantity>0&&row.quantity<=threshold).length};
}
export function slugifyShopName(value){return String(value??'').normalize('NFKD').replace(/[\u0300-\u036f]/g,'').toLowerCase().replace(/[^a-z0-9]+/g,'-').replace(/^-+|-+$/g,'').slice(0,60).replace(/-+$/,'');}
export function shopReadiness(values){return [{label:'Shop name',ready:String(values.name??'').trim().length>=3&&String(values.name).length<=80},{label:'Unique handle format',ready:/^[a-z0-9][a-z0-9-]{2,59}$/.test(values.slug??'')},{label:'Description',ready:String(values.description??'').trim().length>=10&&String(values.description).length<=3000},{label:'Business location',ready:String(values.location??'').trim().length>=2&&String(values.location).length<=200}];}
export function promotionInput(values){
 const payload={name:String(values.name??'').trim(),kind:values.kind,listing_id:values.listing_id||null,budget:numberOrNull(values.budget),starts_on:values.starts_on||null,ends_on:values.ends_on||null,notes:String(values.notes??'').trim(),state:'draft'};
 if(payload.name.length<3||payload.name.length>100)throw new Error('Enter a campaign name of 3–100 characters.');
 if(!['sponsored_listing','boost','business_subscription','advertising'].includes(payload.kind))throw new Error('Choose a promotion type.');
 if(payload.budget!==null&&(!Number.isFinite(payload.budget)||payload.budget<0))throw new Error('Enter a valid nonnegative draft budget.');
 for(const date of [payload.starts_on,payload.ends_on])if(date&&(!/^\d{4}-\d{2}-\d{2}$/.test(date)||!Number.isFinite(Date.parse(date))||new Date(date).toISOString().slice(0,10)!==date))throw new Error('Choose valid campaign dates.');
 if((payload.starts_on&&!payload.ends_on)||(!payload.starts_on&&payload.ends_on))throw new Error('Choose both dates, or leave both blank.');
 if(payload.ends_on&&payload.ends_on<payload.starts_on)throw new Error('End date must not precede start date.');
 if(payload.notes.length>2000)throw new Error('Campaign notes must be at most 2,000 characters.');return payload;
}
