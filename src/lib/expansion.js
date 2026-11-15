export const verticals={
 Property:{title:'Property sales & rentals',intro:'Prepare a property listing for review. Discovery, bookings and deposits are not active.',fields:[['title','Listing title'],['location','Town / area'],['category','Property type'],['price','Price (ZMW)'],['basis','Long-term rent / sale'],['details','Rooms, facilities and viewing arrangements']]},
 Delivery:{title:'Delivery planning',intro:'Plan a delivery enquiry. No courier is booked, tracked or charged.',fields:[['title','Parcel description'],['location','Collection town / area'],['destination','Destination town / area'],['weight','Approximate weight (kg)'],['details','Handling needs and preferred day']]},
 Food:{title:'Food & restaurants',intro:'Prepare a menu offer. Ordering, checkout and food delivery are not active.',fields:[['title','Dish / menu title'],['location','Town / collection area'],['category','Cuisine / meal type'],['price','Price (ZMW)'],['details','Ingredients, allergens and collection hours']]},
};
export function verticalDraft(kind,values){
 const config=verticals[kind];if(!config)throw new Error('Unsupported module.');
 const data=Object.fromEntries(config.fields.map(([key])=>[key,String(values[key]??'').trim()]));
 if(data.title.length<3||data.title.length>150)throw new Error('Use a title of 3–150 characters.');
 if(data.location.length<2||data.location.length>200)throw new Error('Enter a town or area.');
 if(Object.values(data).some(value=>value.length>2000))throw new Error('Keep each field under 2,000 characters.');
 for(const key of ['price','weight'])if(data[key]&&(!Number.isFinite(Number(data[key]))||Number(data[key])<0))throw new Error('Prices and weights must be zero or more.');
 if(kind==='Delivery'&&data.destination.length<2)throw new Error('Enter the destination area.');
 return data;
}
export function sellerInsights(items){
 const categories=new Map();const locations=new Map();
 for(const item of items){categories.set(item.category||'Uncategorised',(categories.get(item.category||'Uncategorised')||0)+1);locations.set(item.location||'Not specified',(locations.get(item.location||'Not specified')||0)+1);}
 return {total:items.length,sold:items.filter(item=>item.status==='sold').length,missingPhotos:items.filter(item=>!item.image_url&&!item.image_urls?.length).length,categories:[...categories].sort((a,b)=>b[1]-a[1]),locations:[...locations].sort((a,b)=>b[1]-a[1])};
}
export function campaignPlan(values){
 const start=Date.parse(values.starts_on),end=Date.parse(values.ends_on);const days=Number.isFinite(start)&&Number.isFinite(end)&&end>=start?Math.floor((end-start)/86400000)+1:null;
 const budget=values.budget===''||values.budget==null?null:Number(values.budget);
 return {days,dailyBudget:days&&budget!==null&&Number.isFinite(budget)&&budget>=0?budget/days:null};
}
export function filterCommunity(items,{search='',location='',format='',upcoming=false,today=''}){
 const words=search.toLowerCase().trim().split(/\s+/).filter(Boolean);
 return items.filter(item=>{const date=item.ends_at||item.starts_at;const localDate=date?new Date(Date.parse(date)+7200000).toISOString().slice(0,10):'';return words.every(word=>[item.title,item.description,item.category,item.organisation].join(' ').toLowerCase().includes(word))&&String(item.location).toLowerCase().includes(location.toLowerCase())&&(!format||item.format===format)&&(!upcoming||(!item.deadline||item.deadline>=today)&&(!date||localDate>=today));});
}
