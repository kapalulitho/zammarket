import {Icon} from './Design';
const groups=[
  {title:'Shopping',items:[
    ['My orders and purchases','Orders','bag','Follow what you have bought.'],
    ['My cart','Cart','bag','Products waiting to be ordered.'],
    ['Saved items','Saved','heart','Products you saved for later.'],
    ['My listings','My Listings','box','Products you are selling.'],
    ['Customer orders','Order Centre','box','Orders placed by your customers.']
  ]},
  {title:'Bookings and requests',items:[
    ['Food orders','Food Operations','food','Your food orders and requests.'],
    ['Event tickets','Event Operations','spark','Your events and tickets.'],
    ['Stays and bookings','Accommodation Operations','grid','Your accommodation requests.'],
    ['Job applications','Job Operations','briefcase','Jobs you applied for or posted.'],
    ['Deliveries','Delivery Operations','car','Your delivery requests.']
  ]},
  {title:'Updates',items:[
    ['Notifications','Notifications','bell','Messages from the platform.'],
    ['Enquiries','Enquiries','message','Questions sent to and from you.'],
    ['History','History','grid','Your recent activity.']
  ]}
];
export default function MyActivity({onNavigate}){
  return <section className="hub-page" aria-labelledby="my-activity-title">
    <span className="eyebrow">MY ACTIVITY</span>
    <h1 id="my-activity-title">Everything you have started</h1>
    <p className="hub-intro">Orders, bookings, saved items and your own listings, all in one place.</p>
    <button type="button" className="primary-button hub-sell" onClick={()=>onNavigate('Post')}><Icon name="plus" size={18}/> Sell an item</button>
    {groups.map(group=><div className="hub-group" key={group.title}>
      <h2>{group.title}</h2>
      <div className="hub-grid">{group.items.map(([label,page,icon,text])=><button type="button" className="hub-card" key={page} onClick={()=>onNavigate(page)}>
        <span className="hub-icon"><Icon name={icon} size={22}/></span>
        <span className="hub-text"><strong>{label}</strong><small>{text}</small></span>
      </button>)}</div>
    </div>)}
  </section>;
}
