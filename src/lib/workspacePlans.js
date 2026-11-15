export const workspaceSections=['Explore','Food','Jobs','Events','Agriculture','Property','Stays','Delivery','Logistics','Services','Learning','Digital','Business','Inventory','Promotions','Orders','Safety'];
export function workspacePlan(input){
 const title=String(input.title??'').trim(),text=String(input.text??'').trim();
 if(title.length<3||title.length>120||!text||text.length>12000||!workspaceSections.includes(input.section))throw new Error('Use a supported section, a title of 3–120 characters and a plan within 12,000 characters.');
 if(/(?:sb_secret_|password\s*[:=]|eyJ[A-Za-z0-9_-]{20,})/i.test(text))throw new Error('Remove passwords or credentials before keeping a plan.');
 return {title,text,section:input.section,state:'unsent'};
}
export function keepWorkspacePlan(rows,input,id,createdAt){const plan=workspacePlan(input);return [{...plan,id,created_at:createdAt},...rows.filter(row=>!(row.title===plan.title&&row.text===plan.text&&row.section===plan.section))].slice(0,50);}
