import {useScopedSearch} from '../lib/useScopedSearch';
import CommunityImage from './CommunityImage';
import {useEffect,useState} from 'react';
import {supabase} from '../supabase';
import {useStage3} from '../lib/stage3';
import StorefrontEditor from './StorefrontEditor';
import {BackendNotice,ModuleEmpty} from './Stage3Shared';
export default function Storefronts({user,onSeller,onNavigate,edit=false,search='',profile}){
 const capability=useStage3();const [shops,setShops]=useState([]);const [mine,setMine]=useState(null);const [error,setError]=useState('');const [notice,setNotice]=useState('');const [loaded,setLoaded]=useState(false);const [revision,setRevision]=useState(0);
 const [directorySearch,setDirectorySearch]=useScopedSearch(search,'Shops');
 useEffect(()=>{if(!capability.ready)return;let active=true;const query=edit?supabase.from('seller_shops').select('*').eq('owner_id',user.id):supabase.from('seller_shops').select('*').eq('status','published').order('created_at',{ascending:false}).limit(36);
 query.then(({data,error:failure})=>{if(!active)return;if(failure)throw failure;setShops(data??[]);if(edit)setMine(data?.[0]??null);setError('');}).catch(()=>{if(active)setError('Storefronts could not be loaded.');}).finally(()=>{if(active)setLoaded(true);});return()=>{active=false;};},[capability.ready,edit,user,revision]);
 const filteredShops=shops.filter(shop=>[shop.name,shop.location,shop.description].join(' ').toLowerCase().includes(directorySearch.trim().toLowerCase()));
 return <section className="platform-page"><span className="eyebrow">LOCAL PEOPLE. REAL BUSINESSES.</span><h1>{edit?'Your storefront':'Local businesses'}</h1><p className="muted">{edit?'Create a public shop profile and connect it to your existing product catalogue.':'Explore published storefronts. No verification badge is shown without an approved verification process.'}</p><BackendNotice capability={capability}/>{error&&<p role="alert">{error}</p>}{notice&&<p role="status" className="success-notice">{notice}</p>}
 {!edit&&<div className="listing-filters"><label>Find a business<input value={directorySearch} onChange={event=>setDirectorySearch(event.target.value)} placeholder="Shop name, town or description"/></label>{directorySearch&&<button className="text-button" onClick={()=>setDirectorySearch('')}>Clear search</button>}</div>}
 {edit?(capability.ready&&!loaded?<p role="status">Loading your storefront...</p>:<StorefrontEditor key={mine?.id??'new'} shop={mine} user={user} profile={profile} ready={capability.ready&&!error} onNavigate={onNavigate} onSaved={next=>{setMine(next);setNotice('Storefront saved.');setRevision(value=>value+1);}}/>)
 :capability.ready&&!loaded?<p role="status">Loading businesses...</p>:error?<ModuleEmpty title="Business discovery is unavailable."/>:filteredShops.length?<div className="module-grid">{filteredShops.map(shop=><button className="module-card" key={shop.id} onClick={()=>onSeller({id:shop.owner_id,name:shop.name})}>{shop.media_paths?.[0]&&<CommunityImage path={shop.media_paths[0]} alt="" loading="lazy"/>}<h2>{shop.name}</h2><p>{shop.location}</p><small>Visit storefront →</small></button>)}</div>:<ModuleEmpty title={capability.ready?(shops.length?'No matching businesses.':'No published storefronts yet.'):'Storefront publishing needs setup.'}/>}
 </section>;
}
