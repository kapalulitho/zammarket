// Campuses available on ZamNexus. Add a campus here and it appears everywhere.
export const campuses=[
  {id:'cbu',name:'CBU',full:'Copperbelt University',city:'Kitwe',aliases:['cbu','copperbelt university']},
  {id:'unza',name:'UNZA',full:'University of Zambia',city:'Lusaka',aliases:['unza','university of zambia']},
  {id:'mulungushi',name:'Mulungushi',full:'Mulungushi University',city:'',aliases:['mulungushi']},
  {id:'mukuba',name:'Mukuba',full:'Mukuba University',city:'',aliases:['mukuba']},
  {id:'knu',name:'KNU',full:'Kwame Nkrumah University',city:'',aliases:['knu','kwame nkrumah']},
  {id:'cavendish',name:'Cavendish',full:'Cavendish University Zambia',city:'',aliases:['cavendish']},
  {id:'zcas',name:'ZCAS',full:'ZCAS University',city:'',aliases:['zcas']},
  {id:'zaou',name:'ZAOU',full:'Zambia Open University',city:'',aliases:['zaou','zambia open university']},
  {id:'chalimbana',name:'Chalimbana',full:'Chalimbana University',city:'',aliases:['chalimbana']},
  {id:'rusangu',name:'Rusangu',full:'Rusangu University',city:'',aliases:['rusangu']},
  {id:'evelynhone',name:'Evelyn Hone',full:'Evelyn Hone College',city:'',aliases:['evelyn hone']},
  {id:'nipa',name:'NIPA',full:'National Institute of Public Administration',city:'',aliases:['nipa']}
];
export const campusById=id=>campuses.find(item=>item.id===id)||null;
export function campusFromText(text){
  const lower=String(text??'').toLowerCase();
  return campuses.find(item=>item.aliases.some(alias=>new RegExp('(^|[^a-z])'+alias+'([^a-z]|$)').test(lower)))||null;
}
// A listing belongs to a campus only when its owner chose one (the Post form adds a "Campus: NAME" line).
export function campusOf(listing){
  const found=String(listing?.description??'').match(/campus:\s*([^\n\r]+)/i);
  return found?campusFromText(found[1])?.id||null:null;
}
export const campusNames=campuses.map(item=>item.name);
