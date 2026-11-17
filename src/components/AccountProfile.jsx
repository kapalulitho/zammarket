import {useState} from 'react';
import {supabase} from '../supabase';
import {Icon} from './Design';
import ProfileEditor from './ProfileEditor';
export default function AccountProfile({user,profile,onProfileSaved,onNavigate,onLogout,logoutBusy}) {
  const [editing,setEditing]=useState(false);
  const [passwordBusy,setPasswordBusy]=useState(false);
  const [passwordNotice,setPasswordNotice]=useState('');
  const [sessionsBusy,setSessionsBusy]=useState(false);
  const [sessionsNotice,setSessionsNotice]=useState('');
  async function savePassword(event){event.preventDefault();const form=event.currentTarget;const fields=Object.fromEntries(new FormData(form));if(fields.password!==fields.confirm_password){setPasswordNotice('Passwords do not match.');return;}setPasswordBusy(true);try{const current=await supabase.auth.getUser();if(current.error||current.data.user?.id!==user.id)throw new Error();const {error}=await supabase.auth.updateUser({password:fields.password});if(error)throw error;form.reset();setPasswordNotice('Password updated. Use it for your next sign-in.');}catch{setPasswordNotice('Unable to update your password. Sign in again and retry.');}finally{setPasswordBusy(false);}}
  async function signOutOthers(){if(sessionsBusy)return;setSessionsBusy(true);setSessionsNotice('');try{const current=await supabase.auth.getUser();if(current.error||current.data.user?.id!==user.id)throw new Error();const value=await supabase.auth.signOut({scope:'others'});if(value.error)throw value.error;setSessionsNotice('Your other sessions have been signed out.');}catch{setSessionsNotice('We could not confirm the sign-out. Try again shortly.');}finally{setSessionsBusy(false);}}
  if(editing)return <ProfileEditor user={user} profile={profile} onSaved={next=>{onProfileSaved(next);setEditing(false);}} onCancel={()=>setEditing(false)}/>;
  const avatar=profile.avatar_path?supabase.storage.from('avatars').getPublicUrl(profile.avatar_path).data.publicUrl:null;
  const actions=[
    ['My Listings','bag','My listings'],
    ['Saved','heart','Saved products'],
    ['Messages','message','Messages'],
    ['Post','plus','Post an item'],
    ['History','grid','Orders & activity'],
    ['Notifications','bell','Notifications'],
    ['Explore','search','Saved searches'],
    ['Safety','check','Safety & help'],
  ];
  if(profile.account_type==='business')actions.unshift(['Business','box','Business workspace']);
  return <section className="hub-page" aria-labelledby="account-title">
    <div className="profile-heading">{avatar?<img className="profile-avatar" src={avatar} alt="Your avatar"/>:<div className="page-icon"><Icon name="user" size={25}/></div>}<div><h1 id="account-title">{profile.shop_name}</h1><p>@{profile.username} · {profile.account_type==='business'?'Business':'Personal'}</p></div></div>
    <div className="hub-grid">
      <button type="button" className="hub-card" onClick={()=>setEditing(true)}>
        <span className="hub-icon"><Icon name="user" size={22}/></span>
        <span className="hub-text"><strong>Edit profile</strong><small>Name, photo, contacts</small></span>
      </button>
      {actions.map(([page,icon,label])=><button type="button" className="hub-card" key={page} onClick={()=>onNavigate(page)}>
        <span className="hub-icon"><Icon name={icon} size={22}/></span>
        <span className="hub-text"><strong>{label}</strong></span>
      </button>)}
    </div>
    <details className="password-settings"><summary>Security</summary>
      <p>Sign-in email: {user.email} · {user.email_confirmed_at?'Verified':'Verification required'}</p>
      <form onSubmit={savePassword}><label>New password<input required type="password" name="password" minLength={8} maxLength={128} autoComplete="new-password"/></label><label>Confirm new password<input required type="password" name="confirm_password" minLength={8} maxLength={128} autoComplete="new-password"/></label><button className="secondary-button" disabled={passwordBusy}>{passwordBusy?'Updating...':'Update password'}</button></form>
      <p role="status">{passwordNotice}</p>
      <button className="text-button" disabled={sessionsBusy} onClick={signOutOthers}>{sessionsBusy?'Signing out…':'Sign out other sessions'}</button>
      <p role="status">{sessionsNotice}</p>
    </details>
    <button type="button" className="hub-signout" disabled={logoutBusy} onClick={onLogout}>{logoutBusy?'Signing out...':'Log out'}</button>
  </section>;
}
