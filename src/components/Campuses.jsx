import {useState} from 'react';
import {Icon} from './Design';
import SectionHeader from './SectionHeader';
import ProductCard from './ProductCard';
import {campuses,campusById,campusOf} from '../lib/campuses';
const KEY='zamnexus_campus';
const read=()=>{try{return campusById(localStorage.getItem(KEY));}catch{return null;}};
const tiles=[['Shop',null,'bag'],['Food','Food','food'],['Services','Services','user'],['Accommodation','Stays','home'],['Events','Events','calendar'],['Study','','book'],['Campus updates','','message']];
export default function Campuses({products=[],onOpen,money,onNavigate,onPost}){
  const [campus,setCampus]=useState(read);
  function choose(item){try{if(item)localStorage.setItem(KEY,item.id);else localStorage.removeItem(KEY);}catch{/* private mode */}setCampus(item);}
  const header=<SectionHeader category="Campuses" onBack={()=>campus?choose(null):window.history.back()} onAction={action=>action==='post'?onPost(campus?campus.name:''):onNavigate('My Listings')}/>;
  if(!campus)return <section className="hub-page campus-page">{header}
    <h2>Choose your campus</h2>
    <label className="campus-select">University or college
      <select defaultValue="" onChange={event=>choose(campusById(event.target.value))}>
        <option value="" disabled>Choose your campus</option>
        {campuses.map(item=><option key={item.id} value={item.id}>{item.name === item.full ? item.name : `${item.name} · ${item.full}`}</option>)}
      </select>
    </label>
  </section>;
  const items=products.filter(product=>campusOf(product)===campus.id);
  return <section className="hub-page campus-page">{header}
    <div className="campus-bar"><h2>{campus.name}</h2><button type="button" className="text-button" onClick={()=>choose(null)}>Change campus</button></div>
    <div className="campus-tiles">{tiles.map(([label,target,icon])=><button type="button" key={label} className="campus-tile" disabled={target===''} onClick={()=>target&&onNavigate(target)}>
      <Icon name={icon} size={20}/><span>{label}</span>{target===''&&<small>Soon</small>}</button>)}</div>
    <h2>Listings at {campus.name}</h2>
    {items.length?<div className="product-grid">{items.map(product=><ProductCard key={product.id} product={product} onOpen={onOpen} formatMoney={money}/>)}</div>
      :<div className="empty-state"><h2>No listings at {campus.name} yet</h2><button type="button" className="primary-button" onClick={()=>onPost(campus.name)}>Sell at {campus.name}</button></div>}
  </section>;
}
