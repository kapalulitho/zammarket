import {useEffect,useState} from 'react';
import {supabase} from '../supabase';
import {Icon} from './Design';
import {profileInput,contactFields} from '../lib/profiles';
import {validatePhoto} from '../lib/listings';

const labels={whatsapp:'WhatsApp number'};
export default function ProfileEditor({user,profile,onSaved,onCancel}) {
  const [draft,setDraft]=useState(null);
  const [reviewing,setReviewing]=useState(false);
  const [avatar,setAvatar]=useState(null);
  const [removeAvatar,setRemoveAvatar]=useState(false);
  const [error,setError]=useState('');
  const [busy,setBusy]=useState(false);
  useEffect(()=>()=>{if(avatar)URL.revokeObjectURL(avatar.preview);},[avatar]);
  const avatarPath=removeAvatar?'':profile?.avatar_path??'';
  const preview=avatar?.preview || (avatarPath?supabase.storage.from('avatars').getPublicUrl(avatarPath).data.publicUrl:null);
  async function chooseAvatar(event) {
    const file=event.target.files?.[0]; event.target.value=''; if(!file)return;
    setError('');setBusy(true);
    try {if(file.size>2*1024*1024)throw new Error('Choose an avatar up to 2 MB.');await validatePhoto(file);setAvatar({file,preview:URL.createObjectURL(file)});setRemoveAvatar(false);}
    catch(failure){setError(failure.message);}finally{setBusy(false);}
  }
  function review(event) {
    event.preventDefault();if(busy)return;setError('');
    try {setDraft(profileInput(Object.fromEntries(new FormData(event.currentTarget)),user.email));setReviewing(true);}
    catch(failure){setError(failure.message);}finally{setBusy(false);}
  }
  async function save() {
    if(busy)return;setBusy(true);setError('');
    try {
      let path=avatarPath;
      if(avatar){const ext=await validatePhoto(avatar.file);path=`${user.id}/${crypto.randomUUID()}.${ext}`;
        const {error:failure}=await supabase.storage.from('avatars').upload(path,avatar.file,{contentType:avatar.file.type,upsert:false});if(failure)throw failure;}
      const {data,error:failure}=await supabase.rpc('save_marketplace_profile',{p_profile:{...draft,avatar_path:path},p_confirm:true});
      if(failure)throw failure;
      onSaved(data);
    }catch(failure){setError(failure.code==='23505'?'That username or shop name is already taken. Go back and choose another.':'Your profile could not be saved. Please retry. If you uploaded an avatar, it has been retained.');}
    finally{setBusy(false);}
  }
  return <section className="form-page profile-setup"><div className="page-icon"><Icon name="user" size={25}/></div>
    <span className="eyebrow">{reviewing?'REVIEW BEFORE YOU CONTINUE':'MAKE YOURSELF AT HOME'}</span>
    <h1>{reviewing?'Does everything look right?':profile?'Edit your profile.':'Set up your profile.'}</h1>
    <p>Your sign-in email is only used to sign in — it stays private and never appears on your profile. Add your WhatsApp number so people can reach you; it stays hidden unless you choose to show it.</p>
    {error&&<p role="alert" className="auth-error">{error}</p>}
    {reviewing?<><div className="profile-review">
      {preview&&<img className="profile-avatar" src={preview} alt="Your selected avatar"/>}
      <h2>{draft.shop_name}</h2><p>@{draft.username} · {draft.account_type==='business'?'Business / shop':'Personal account'}</p>
      <dl>{contactFields.map(field=><div key={field}><dt>{labels[field]}</dt><dd>{draft[field]||'Not provided'} <small>{draft[field]&&draft[`show_${field}`]?'Public':'Private / hidden'}</small></dd></div>)}</dl>
      <p>Avatar, username and shop name are public. Your sign-in email never appears on your profile.</p>
      <label className="consent-row"><input type="checkbox" required form="profile-confirm"/> I reviewed my details and public visibility choices.</label>
    </div><form id="profile-confirm" onSubmit={event=>{event.preventDefault();save();}}><div className="listing-actions">
      <button type="button" disabled={busy} onClick={()=>setReviewing(false)}>Back to edit</button>
      <button className="primary-button" disabled={busy}>{busy?'Saving...':profile?'Confirm and save':'Confirm and enter marketplace'}</button>
    </div></form></>:<form onSubmit={review}>
      <div className="avatar-editor">{preview?<img className="profile-avatar" src={preview} alt="Your avatar preview"/>:<div className="profile-avatar avatar-placeholder"><Icon name="user" size={34}/></div>}
        <label>Avatar (optional)<input type="file" accept="image/jpeg,image/png,image/webp" disabled={busy} onChange={chooseAvatar}/><small>JPG, PNG or WebP, up to 2 MB. Public when saved.</small></label>
        {preview&&<button type="button" className="text-button" disabled={busy} onClick={()=>{setAvatar(null);setRemoveAvatar(true);}}>Remove avatar</button>}
      </div>
      <label>Unique username<input required name="username" minLength={3} maxLength={30} pattern="[a-zA-Z0-9_]{3,30}" defaultValue={draft?.username??profile?.username??''} placeholder="e.g. lusaka_finds" autoComplete="username"/><small>3–30 letters, numbers or underscores. Checked again when saving.</small></label>
      <label>Public name / shop name (unique)<input required name="shop_name" minLength={3} maxLength={60} defaultValue={draft?.shop_name??profile?.shop_name??user.user_metadata?.display_name??''}/></label>
      <label>Account type<select required name="account_type" defaultValue={draft?.account_type??profile?.account_type??''}><option value="" disabled>Choose account type</option><option value="individual">Personal account</option><option value="business">Business / shop</option></select></label>
      {contactFields.map(field=><div className="contact-field" key={field}><label>{labels[field]} (optional)<input name={field} type="tel" maxLength={18} placeholder="+260971234567" defaultValue={draft?.[field]??profile?.[field]??''}/><small>For example 0971234567 or +260971234567.</small></label>
        <label className="consent-row"><input type="checkbox" name={`show_${field}`} defaultChecked={draft?.[`show_${field}`]??profile?.[`show_${field}`]??false}/> Show this number on my public profile</label></div>)}
      <button className="primary-button" disabled={busy}>{busy?"Checking avatar...":"Review profile"}</button>{onCancel&&<button type="button" className="text-button" onClick={onCancel}>Cancel</button>}
    </form>}
  </section>;
}
