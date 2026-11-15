import {useState} from 'react';
import {WorkspaceContext as Plans,useWorkspacePlans} from '../lib/workspaceContext';
import {keepWorkspacePlan} from '../lib/workspacePlans';

export function WorkspaceProvider({owner,children}){
 const [rows,setRows]=useState([]);
 function keep(input){if(!owner)throw new Error('Sign in before keeping a workspace plan.');const id=crypto.randomUUID(),date=new Date().toISOString();const checked=keepWorkspacePlan([],input,id,date)[0];setRows(current=>keepWorkspacePlan(current,checked,id,date));}
 return <Plans.Provider value={{owner,rows,keep,remove:id=>setRows(current=>current.filter(row=>row.id!==id)),clear:()=>setRows([])}}>{children}</Plans.Provider>;
}
export function KeepPlanButton({title,text,section}){const workspace=useWorkspacePlans(),[notice,setNotice]=useState(null);if(!workspace?.owner)return null;return <span className="keep-plan-control"><button type="button" className="text-button" onClick={()=>{try{workspace.keep({title,text,section});setNotice({text,message:'Kept in My workspace for this signed-in session. Nothing submitted.'});}catch(failure){setNotice({text,message:failure.message});}}}>Keep in My workspace</button>{notice?.text===text&&<small role="status">{notice.message}</small>}</span>;}
