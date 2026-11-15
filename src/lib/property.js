export const propertyTypes=['House','Apartment','Land','Commercial'];
export const propertyPurposes=['Sale','Rent'];
export const priceBases=['Total','Per month','Per night'];
export const propertyMoney=value=>`ZMW ${Number(value).toLocaleString('en-ZM',{maximumFractionDigits:2})}`;
export function propertyInput(values){
 const data={};for(const [key,min,max] of [['title',3,150],['location',2,200],['description',20,6000]]){data[key]=String(values[key]??'').trim();if(data[key].length<min||data[key].length>max)throw new Error(`Check the property ${key}.`);}
 if(!propertyTypes.includes(values.property_type)||!propertyPurposes.includes(values.purpose)||!priceBases.includes(values.price_basis))throw new Error('Choose the property type, purpose and price basis.');
 if(values.price_basis==='Per night')throw new Error('Nightly stays belong in Accommodation. Use sale or long-term rental pricing for Property.');
 Object.assign(data,{property_type:values.property_type,purpose:values.purpose,price_basis:values.price_basis,agent_type:values.agent_type==='Agent'?'Agent':'Owner',status:values.status==='published'?'published':'draft'});
 for(const key of ['price','bedrooms','bathrooms','area_sqm']){const value=values[key];data[key]=value===''||value==null?null:Number(value);if((key==='price'&&data[key]===null)||(data[key]!==null&&(!Number.isFinite(data[key])||data[key]<0||data[key]>1e12||(['bedrooms','bathrooms'].includes(key)&&(!Number.isInteger(data[key])||data[key]>100)))))throw new Error(`Enter a valid ${key.replaceAll('_',' ')}.`);}
 if(data.purpose==='Sale'&&data.price_basis!=='Total')throw new Error('Sale properties use a total price.');
 return data;
}
export function filterProperties(items,{search='',location='',type='',purpose='',min='',max='',bedrooms='',basis='',sort='new'}={}){
 const words=search.toLowerCase().trim().split(/\s+/).filter(Boolean);const low=min===''?null:Number(min),high=max===''?null:Number(max);
 if((low!==null&&(!Number.isFinite(low)||low<0))||(high!==null&&(!Number.isFinite(high)||high<0))||(low!==null&&high!==null&&low>high))return [];
 const result=items.filter(item=>words.every(word=>`${item.title} ${item.description} ${item.location}`.toLowerCase().includes(word))&&item.location.toLowerCase().includes(location.toLowerCase())&&(!type||item.property_type===type)&&(!purpose||item.purpose===purpose)&&(!basis||item.price_basis===basis)&&(low===null||item.price>=low)&&(high===null||item.price<=high)&&(!bedrooms||(item.bedrooms!=null&&item.bedrooms>=Number(bedrooms))));
 return sort==='low'?result.sort((a,b)=>a.price-b.price):sort==='high'?result.sort((a,b)=>b.price-a.price):result;
}
