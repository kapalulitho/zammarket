import {Icon} from './Design';
const rows=[
  ['My profile','Profile','user','Your name, photo and contact details.'],
  ['Business workspace','Business','box','Your business profile and tools.'],
  ['Notifications','Notifications','bell','Updates and alerts.'],
  ['History','History','grid','Your recent activity.'],
  ['Safety and help','Safety','check','Report a problem or get help.']
];
export default function AccountHub({user,profile,onNavigate,onLogout,logoutBusy}){
  const name=profile?.username||user?.email||'Your account';
  return <section className="hub-page" aria-labelledby="account-title">
    <span className="eyebrow">ACCOUNT</span>
    <h1 id="account-title">{name}</h1>
    <p className="hub-intro">Manage your profile, your business and your settings.</p>
    <div className="hub-grid">{rows.map(([label,page,icon,text])=><button type="button" className="hub-card" key={page} onClick={()=>onNavigate(page)}>
      <span className="hub-icon"><Icon name={icon} size={22}/></span>
      <span className="hub-text"><strong>{label}</strong><small>{text}</small></span>
    </button>)}</div>
    <button type="button" className="hub-signout" disabled={logoutBusy} onClick={onLogout}>{logoutBusy?'Signing out...':'Log out'}</button>
  </section>;
}
