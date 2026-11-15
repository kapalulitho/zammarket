import {useEffect,useState} from 'react';
import {supabase} from '../supabase';
import {Brand} from './Design';
import ProfileEditor from './ProfileEditor';
import ThemeControl from './ThemeControl';
import {profileAccess} from '../lib/profiles';
import {navigate} from '../lib/routes';
import {verifyEmailCode,resendEmailCode,otpErrorMessage} from '../lib/emailOtp';

export default function ProfileGate({user,component:Content,onLogout,logoutBusy}) {
  const [profile,setProfile]=useState(null);
  const [loading,setLoading]=useState(true);
  const [error,setError]=useState('');
  const [refresh,setRefresh]=useState(0);
  const [code,setCode]=useState('');
  const [busy,setBusy]=useState(false);
  const [notice,setNotice]=useState('');
  const [needsVerification,setNeedsVerification]=useState(false);
  useEffect(()=>{
    if(!user.email_confirmed_at)return;
    let active=true;
    supabase.from('marketplace_profiles').select('*').eq('id',user.id).maybeSingle()
      .then(async({data,error:failure})=>{if(!active)return;if(failure)throw failure;let needs=false;if(!data?.completed_at){const check=await supabase.rpc('marketplace_profile_requires_verification');if(check.error)throw check.error;needs=check.data===true;}if(!active)return;setProfile(data);setNeedsVerification(needs);setError('');})
      .catch(()=>{if(active)setError('Profile setup is not available yet. Please retry or contact ZamNexus support.');})
      .finally(()=>{if(active)setLoading(false);});
    return()=>{active=false;};
  },[user.id,user.email_confirmed_at,refresh]);
  async function verify(event){event.preventDefault();setBusy(true);setNotice('');try{
    await verifyEmailCode(supabase.auth,user.email,code,!user.email_confirmed_at);setLoading(true);setRefresh(value=>value+1);
  }catch(failure){setNotice(otpErrorMessage(failure));}finally{setBusy(false);}}
  async function resend(){if(busy)return;setBusy(true);setNotice('');try{await resendEmailCode(supabase.auth,user.email,!user.email_confirmed_at);setCode('');setNotice('A new verification code was requested. Check your inbox and spam folder and use the newest code.');}catch(failure){setNotice(otpErrorMessage(failure,'resend'));}finally{setBusy(false);}}
  function saved(next){const first=!profile?.completed_at;setProfile(next);if(first)navigate('/home',true);}
  if(profileAccess(user,profile)==='ready')return <Content user={user} profile={profile} onProfileSaved={saved} onLogout={onLogout} logoutBusy={logoutBusy}/>;
  return <div className="guest-shell"><header className="guest-header"><div className="brand"><Brand/></div><ThemeControl/><button className="text-button" disabled={logoutBusy} onClick={onLogout}>Log out</button></header><main className="guest-main">
    {(!user.email_confirmed_at || needsVerification)?<section className="form-page auth-page"><h1>Verify your email.</h1><p>Confirm your sign-in email before setting up your profile.</p><form onSubmit={verify}><label>Email code<input required type="text" inputMode="numeric" autoComplete="one-time-code" pattern="[0-9]{6}" minLength={6} maxLength={6} placeholder="Six-digit code" title="Enter the six-digit verification code" value={code} onChange={event=>setCode(event.target.value)}/></label><button className="primary-button" disabled={busy}>Verify email</button></form><button className="text-button" disabled={busy} onClick={resend}>Resend verification email</button><p role="status">{notice}</p></section>:
      loading?<section className="session-screen" role="status"><span className="session-spinner"/><p>Getting your profile ready...</p></section>:
        error?<section className="form-page centered-page"><h1>Let’s get you set up.</h1><p role="alert">{error}</p><button className="primary-button" onClick={()=>{setLoading(true);setRefresh(value=>value+1);}}>Retry profile setup</button></section>:
          <ProfileEditor key={user.id} user={user} profile={profile} onSaved={saved}/>}</main></div>;
}
