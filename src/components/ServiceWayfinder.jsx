import {useEffect,useRef} from 'react';
import {Icon} from './Design';
const items=[['Home','Home','home'],['Explore','Shop','bag'],['Property','Property','home'],['Stays','Accommodation','home'],['Logistics','Logistics','car'],['Delivery','Delivery','car'],['Food','Food','food'],['Events','Events','calendar'],['Jobs','Jobs','briefcase'],['Learning','Learning','book'],['Services','Services','user'],['Agriculture','Agriculture','box'],['Digital','Digital','laptop']];
export default function ServiceWayfinder({current,onNavigate}){
 const box=useRef(null);
 // Keep the selected service centred in the row so it is always visible.
 useEffect(()=>{
  const row=box.current;const active=row?.querySelector('[aria-current="page"]');
  if(!row||!active)return;
  const offset=active.getBoundingClientRect().left-row.getBoundingClientRect().left+row.scrollLeft;
  row.scrollTo({left:Math.max(0,offset-(row.clientWidth-active.offsetWidth)/2),behavior:'auto'});
 },[current]);
 return <nav ref={box} className="service-wayfinder" aria-label="Marketplace services">{items.map(([page,label,icon])=><button key={page} aria-current={current===page?'page':undefined} onClick={()=>onNavigate(page)}><Icon name={icon} size={16}/>{label}</button>)}</nav>;
}