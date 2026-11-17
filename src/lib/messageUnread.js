// Client-side read tracking for the unread badge. The messages table has no
// read_at column, so "read" means: a message arrived before the recipient's
// last recorded visit to that conversation (stored on this device).
const KEY='zammarket_message_reads';
export function loadReads(){
  try{const value=JSON.parse(localStorage.getItem(KEY));return value&&typeof value==='object'?value:{};}
  catch{return{};}
}
export function saveReads(map){try{localStorage.setItem(KEY,JSON.stringify(map));}catch{/* storage unavailable */}}
export function markConversationRead(conversationId,reads){return {...reads,[conversationId]:new Date().toISOString()};}
export function unreadByConversation(rows,userId,reads){
  const counts={};
  for(const row of rows){
    if(row.sender_id===userId)continue;
    const cutoff=reads[row.conversation_id];
    if(cutoff&&new Date(row.created_at)<=new Date(cutoff))continue;
    counts[row.conversation_id]=(counts[row.conversation_id]??0)+1;
  }
  return counts;
}
