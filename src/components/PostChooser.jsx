import {Icon} from './Design';
// First step of posting: say what you are posting. Each choice opens the right place.
const options=[['Product','bag','Sell an item',null],['Food','food','Menu or meals','Food'],['Service','user','Offer a service','Services'],['Property','home','Sell or rent','Property'],['Accommodation','home','Rooms and stays','Stays'],['Event','calendar','Tickets and events','Events'],['Job','briefcase','Hire someone','Jobs']];
export default function PostChooser({onProduct,onNavigate}){
  return <div className="hub-grid">{options.map(([label,icon,text,page])=><button type="button" className="hub-card" key={label} onClick={()=>page?onNavigate(page):onProduct()}>
    <span className="hub-icon"><Icon name={icon} size={22}/></span>
    <span className="hub-text"><strong>{label}</strong><small>{text}</small></span></button>)}</div>;
}
