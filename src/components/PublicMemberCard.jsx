import {useEffect,useState} from 'react';
import {supabase} from '../supabase';
export default function PublicMemberCard({item,user,kind,onSeller}){
 const [result,setResult]=useState(null);
 useEffect(()=>{if(!user||item.local_only)return;let active=true;supabase.rpc('public_seller_profile',{p_user_id:item.owner_id}).then(({data,error})=>{if(active&&!error)setResult({id:item.owner_id,data});}).catch(()=>{});return()=>{active=false;};},[item.owner_id,item.local_only,user]);
 const profile=result?.id===item.owner_id?result.data:null;
 return <aside className="tool-preview"><span className="eyebrow">{kind==='job'?'EMPLOYER':kind==='service'?'SERVICE PROVIDER':'INSTRUCTOR / INSTITUTION'}</span>{profile?.avatar_path&&<img className="profile-avatar" alt="Public profile avatar" src={supabase.storage.from('avatars').getPublicUrl(profile.avatar_path).data.publicUrl}/>}<h3>{item.organisation||profile?.shop_name||'Community publisher'}</h3>{profile?.username&&<p>@{profile.username}</p>}{profile?.location&&<p>{profile.location}</p>}<p>{kind==='service'?'Provider information and qualifications have not been independently verified.':kind==='job'?'Employer information is publisher supplied and has not been independently verified.':'Teaching qualifications and accreditation have not been independently verified.'}</p>{!item.local_only&&<button className="text-button" onClick={()=>onSeller({id:item.owner_id,name:item.organisation||profile?.shop_name})}>View public profile →</button>}</aside>;
}
