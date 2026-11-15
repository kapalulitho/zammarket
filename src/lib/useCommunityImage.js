import {useEffect,useState} from 'react';
import {supabase} from '../supabase';
export function useCommunityImage(path,bucket='marketplace-media'){
 const [image,setImage]=useState({path:null,url:''});
 useEffect(()=>{let active=true;let timer;
  async function refresh(){try{const {data,error}=await supabase.storage.from(bucket).createSignedUrl(path,60);if(active){setImage({path,bucket,url:!error?data?.signedUrl||'':''});timer=setTimeout(refresh,45000);}}catch{if(active)setImage({path,url:''});}}
  if(path)refresh();return()=>{active=false;clearTimeout(timer);};
 },[path,bucket]);return image.path===path&&image.bucket===bucket?image.url:'';
}
