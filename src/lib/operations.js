import {availability} from './availability.js';
export function ownedCatalogue(items,owner,query='',status='all',now=new Date()){
 const terms=String(query).toLowerCase().trim().split(/\s+/).filter(Boolean);
 return items.filter(item=>owner&&item.user_id===owner&&!item.deleted_at&&(status==='all'||availability(item,now)===status)&&terms.every(term=>[item.title,item.category,item.location].join(' ').toLowerCase().includes(term)));
}
export const reportReasons=['Misleading listing','Suspected scam','Prohibited content','Harassment','Privacy concern','Other'];
export function safetyDraft(values){
 const kind=String(values.kind||'');if(!['listing','user','business_verification'].includes(kind))throw new Error('Choose a supported request type.');
 const target=String(values.target||'').trim(),details=String(values.details||'').trim();
 if(target.length<3||target.length>200||details.length<20||details.length>2000)throw new Error('Add a reference (3–200 characters) and a description (20–2,000 characters).');
 if(!reportReasons.includes(values.reason))throw new Error('Choose a valid reason.');
 if(/(?:sb_secret_|eyJ[A-Za-z0-9_-]{15,}|password\s*[:=])/i.test(details))throw new Error('Remove credentials or tokens from the description.');
 return {kind,target,reason:values.reason,details,state:'unsent'};
}
