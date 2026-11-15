import {zambiaProvinces} from '../config/platform.js';
export function formatZambiaLocation(town,province){
 const place=String(town??'').trim();
 return place&&place.length<=120&&zambiaProvinces.includes(province)?`${place}, ${province}`:'';
}
