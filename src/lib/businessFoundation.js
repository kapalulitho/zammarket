export const workspaceKinds={personal:'Personal seller',small_business:'Small business',company:'Company'};
export function businessPlanInput(values,loginEmail=''){
 const result={kind:values.kind};if(!workspaceKinds[result.kind])throw new Error('Choose a workspace type.');
 for(const [key,min,max] of [['name',3,100],['description',10,3000],['location',2,200],['phone',0,18],['whatsapp',0,18],['public_email',0,254]]){result[key]=String(values[key]??'').trim();if(result[key].length<min||result[key].length>max)throw new Error(`Check ${key.replaceAll('_',' ')}.`);}
 for(const key of ['phone','whatsapp']){result[key]=result[key].replace(/[ ()-]/g,'');if(result[key]&&!/^\+[1-9]\d{6,14}$/.test(result[key]))throw new Error('Use an international contact number, such as +260971234567.');}
 if(result.public_email&&(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(result.public_email)||result.public_email.toLowerCase()===loginEmail.trim().toLowerCase()))throw new Error('Use a valid public email different from your private login email.');
 for(const key of ['phone','whatsapp','public_email','location'])result[`show_${key}`]=values[`show_${key}`]===true||values[`show_${key}`]==='on';return result;
}
export function publicBusinessPlan(plan){return {name:plan.name,description:plan.description,kind:plan.kind,...Object.fromEntries(['phone','whatsapp','public_email','location'].map(key=>[key,plan[`show_${key}`]?plan[key]:null]))};}
export function businessSummary(items,ownerId){const owned=items.filter(item=>item.user_id===ownerId&&!item.deleted_at);return {total:owned.length,sold:owned.filter(item=>item.status==='sold').length,unavailable:owned.filter(item=>item.status==='temporarily_unavailable').length};}
