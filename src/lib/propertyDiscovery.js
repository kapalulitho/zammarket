export const PROPERTY_PAGE_SIZE=12;
export function propertyLink(id){if(!/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i.test(id))throw new Error('Only saved properties can have shared links.');return `/property?property=${encodeURIComponent(id)}`;}
export function propertyIdFromSearch(search){const id=new URLSearchParams(search).get('property');if(!id)return null;try{propertyLink(id);return id;}catch{return 'invalid';}}
export function searchWords(value){return String(value).toLowerCase().match(/[\p{L}\p{N}]+/gu)?.slice(0,8)??[];}
export function propertyQuery(query,filters){
 for(const word of searchWords(filters.search))query=query.or(`title.ilike.%${word}%,description.ilike.%${word}%,location.ilike.%${word}%`);
 if(filters.location)query=query.ilike('location',`%${filters.location.replace(/[\\%_]/g,'\\$&')}%`);
 for(const [key,column] of [['type','property_type'],['purpose','purpose'],['basis','price_basis']])if(filters[key])query=query.eq(column,filters[key]);
 if(filters.min!=='')query=query.gte('price',Number(filters.min));if(filters.max!=='')query=query.lte('price',Number(filters.max));if(filters.bedrooms!=='')query=query.gte('bedrooms',Number(filters.bedrooms));
 return filters.sort==='low'?query.order('price').order('id'):filters.sort==='high'?query.order('price',{ascending:false}).order('id'):query.order('created_at',{ascending:false}).order('id');
}
export function validPropertyRange(filters){return ['min','max','bedrooms'].every(key=>filters[key]===''||Number.isFinite(Number(filters[key]))&&Number(filters[key])>=0)&&(filters.min===''||filters.max===''||Number(filters.min)<=Number(filters.max));}
