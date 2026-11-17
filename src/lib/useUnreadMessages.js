import {useEffect,useState} from 'react';
import {supabase} from '../supabase';
import {loadReads,unreadByConversation} from './messageUnread';
// Live unread-message count for the Messages badge. Row-level security limits
// the query to the signed-in user's own conversations, for personal and
// business accounts alike.
export default function useUnreadMessages(user,ready){
  const [count,setCount]=useState(0);
  useEffect(()=>{
    if(!user||!ready)return;
    let active=true;
    async function poll(){
      if(document.hidden)return;
      try{
        const {data}=await supabase.from('messages')
          .select('id,conversation_id,sender_id,created_at')
          .order('created_at',{ascending:false}).limit(300);
        if(!active)return;
        const counts=unreadByConversation(data??[],user.id,loadReads());
        setCount(Object.values(counts).reduce((sum,value)=>sum+value,0));
      }catch{/* keep the last known count */}
    }
    poll();
    const timer=setInterval(poll,5000);
    return()=>{active=false;clearInterval(timer);};
  },[user,ready]);
  return count;
}
