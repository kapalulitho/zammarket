import {useEffect,useState} from 'react';
import {supabase} from '../supabase';
import {validatePhoto} from './listings';
export {moduleKinds,moduleInput} from './community.js';
export function useStage3(group='modules'){
 const [state,setState]=useState({loading:true,ready:false,error:'',missing:false});const [revision,setRevision]=useState(0);
 useEffect(()=>{let active=true;supabase.rpc(group==='commerce'?'stage3_commerce_capabilities':'stage3_capabilities').then(({data,error})=>{
  if(!active)return;if(error){setState({loading:false,ready:false,missing:error.code==='PGRST202'||error.code==='42883',error:'Backend setup is not available.'});return;}
  setState({loading:false,ready:data?.version===2&&(group==='commerce'?data?.safe_variants===true&&data?.immutable_receipts===true:data?.private_media===true),missing:data?.version!==2||(group==='commerce'?data?.safe_variants!==true||data?.immutable_receipts!==true:data?.private_media!==true),error:''});
 }).catch(()=>{if(active)setState({loading:false,ready:false,missing:false,error:'Could not check backend availability. Check your connection.'});});return()=>{active=false;};},[group,revision]);
 return {...state,retry:()=>{setState({loading:true,ready:false,error:'',missing:false});setRevision(value=>value+1);}};
}
export async function uploadCommunityMedia(user,file){
 if(!file)return null;const extension=await validatePhoto(file);const {data,error}=await supabase.auth.getUser();
 if(error||data.user?.id!==user.id)throw new Error('Sign in again before uploading.');
 const path=`${user.id}/${crypto.randomUUID()}.${extension}`;const uploaded=await supabase.storage.from('marketplace-media').upload(path,file,{upsert:false,contentType:file.type});if(uploaded.error)throw uploaded.error;return path;
}
export async function assertStage3User(user){const {data,error}=await supabase.auth.getUser();if(error||!user||data.user?.id!==user.id)throw new Error('Your session changed. Sign in again before saving.');}
export function safeStage3Error(error){return error?.code==='23505'?'That name/reference already exists. Refresh and try another.':error?.code==='42501'?'This action is not permitted for this account.':'The action could not be confirmed. Refresh before retrying; uploaded photos are preserved.';}
