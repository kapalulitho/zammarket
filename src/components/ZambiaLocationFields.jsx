import {useState} from 'react';
import {zambiaProvinces} from '../config/platform';
import {formatZambiaLocation} from '../lib/locations';
export default function ZambiaLocationFields(){
 const [province,setProvince]=useState('');const [town,setTown]=useState('');
 return <fieldset className="location-fields"><legend>Where is the item?</legend><label>Province<select required value={province} onChange={event=>setProvince(event.target.value)}><option value="" disabled>Choose province</option>{zambiaProvinces.map(value=><option key={value}>{value}</option>)}</select></label><label>Town / district<input required maxLength={120} value={town} onChange={event=>setTown(event.target.value)} placeholder="Enter your town or district" autoComplete="address-level2"/></label><input type="hidden" name="location" value={formatZambiaLocation(town,province)}/><small>Use a town or district, not a private street address.</small></fieldset>;
}
