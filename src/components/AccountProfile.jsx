import AccountCompletion from './AccountCompletion';
import {useState} from 'react';
import {supabase} from '../supabase';
import {Icon} from './Design';
import ProfileEditor from './ProfileEditor';
export default function AccountProfile({user,profile,onProfileSaved,onNavigate,onLogout,logoutBusy}) {
  const [editing,setEditing]=useState(false);
  const [passwordBusy,setPasswordBusy]=useState(false);
  const [passwordNotice,setPasswordNotice]=useState('');
  async function savePassword(event){event.preventDefault();const form=event.currentTarget;const fields=Object.fromEntries(new FormData(form));if(fields.password!==fields.confirm_password){setPasswordNotice('Passwords do not match.');return;}setPasswordBusy(true);try{const current=await supabase.auth.getUser();if(current.error||current.data.user?.id!==user.id)throw new Error();const {error}=await supabase.auth.updateUser({password:fields.password});if(error)throw error;form.reset();setPasswordNotice('Password updated. Use it for your next sign-in.');}catch{setPasswordNotice('Unable to update your password. Sign in again and retry.');}finally{setPasswordBusy(false);}}
  if(editing)return <ProfileEditor user={user} profile={profile} onSaved={next=>{onProfileSaved(next);setEditing(false);}} onCancel={()=>setEditing(false)}/>;
  const avatar=profile.avatar_path?supabase.storage.from('avatars').getPublicUrl(profile.avatar_path).data.publicUrl:null;
  return <section className="form-page"><div className="profile-heading">{avatar?<img className="profile-avatar" src={avatar} alt="Your avatar"/>:<div className="page-icon"><Icon name="user" size={25}/></div>}<div><span className="eyebrow">YOUR ACCOUNT</span><h1>{profile.shop_name}</h1><p>@{profile.username} · {profile.account_type==='business'?'Business / shop':'Personal account'}</p></div></div>
    <AccountCompletion user={user} profile={profile} onNavigate={onNavigate}/><p>Your private sign-in email: {user.email}</p><p>Contact visibility and avatar can be changed at any time.</p>
    <button className="secondary-button" onClick={()=>onNavigate('Workspace')}>My workspace & activity</button><button className="primary-button" onClick={()=>setEditing(true)}>Edit profile & visibility</button>
    <div className="listing-actions">{['Saved','My Listings','Messages','Post'].map(page=><button className="primary-button" key={page} onClick={()=>onNavigate(page)}>{page==='Post'?'Post an item':page==='Saved'?'Saved products':page}</button>)}</div>
    <button className="text-button" onClick={()=>onNavigate('Explore')}>Saved searches & discovery preferences</button><details className="password-settings"><summary>Set or change your password</summary><form onSubmit={savePassword}><label>New password<input required type="password" name="password" minLength={8} maxLength={128} autoComplete="new-password"/></label><label>Confirm new password<input required type="password" name="confirm_password" minLength={8} maxLength={128} autoComplete="new-password"/></label><button className="primary-button" disabled={passwordBusy}>{passwordBusy?'Updating...':'Update password'}</button></form><p role="status">{passwordNotice}</p></details>
    <button className="secondary-button" disabled={logoutBusy} onClick={onLogout}>{logoutBusy?'Signing out...':'Log out'}</button>
  </section>;
}
