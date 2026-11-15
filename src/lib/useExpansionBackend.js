import {useEffect,useState} from 'react';
import {supabase} from '../supabase';
export default function useExpansionBackend(module){
 const [state,setState]=useState({loading:true,ready:false,error:''});const [revision,setRevision]=useState(0);
 useEffect(()=>{let active=true;supabase.rpc(module==='property'?'property_capabilities':'delivery_capabilities').then(({data,error})=>{if(active)setState({loading:false,ready:!error&&data?.version===1&&data?.private_data===true&&(module==='property'?data.private_images===true&&data.saved_private===true:data.planning_only===true&&data.bookings===false&&data.payments===false),error:error&&!['PGRST202','42883'].includes(error.code)?'Backend availability could not be checked. Try again when connected.':''});}).catch(()=>{if(active)setState({loading:false,ready:false,error:'Connection unavailable. Your previews have not been submitted.'});});return()=>{active=false;};},[module,revision]);
 return {...state,retry:()=>setRevision(value=>value+1)};
}
