import { useEffect, useRef, useState } from 'react';
import { supabase, registrationRequiresEmailConfirmation, backendMode } from '../supabase';
import { Brand, Welcome } from './Design';
import ProfileGate from './ProfileGate';
import ThemeControl from './ThemeControl';
import {verifyEmailCode,resendEmailCode,otpErrorMessage,otpResendSeconds} from '../lib/emailOtp';
import { createAuthSession } from '../lib/authSession';
import { navigate, publicPath, authPath, browsePath, usePath } from '../lib/routes';

function AuthForm({mode}) {
  const [step,setStep] = useState('email');
  const [useCode,setUseCode] = useState(false);
  const [email,setEmail] = useState('');
  const [busy,setBusy] = useState(false);
  const [error,setError] = useState('');
  const [notice,setNotice] = useState('');
  const [codeRound,setCodeRound] = useState(0);
  const [resendAt,setResendAt] = useState(0);
  const [clock,setClock] = useState(Date.now);
  const resendWait=otpResendSeconds(resendAt,clock);
  function markCodeRequested(){const now=Date.now();setClock(now);setResendAt(now+60000);}
  useEffect(()=>{if(step!=='code'||!resendAt)return;const timer=setInterval(()=>{const now=Date.now();setClock(now);if(now>=resendAt)clearInterval(timer);},1000);return()=>clearInterval(timer);},[step,resendAt]);
  async function submit(event) {
    event.preventDefault();
    if (busy) return;
    const form = Object.fromEntries(new FormData(event.currentTarget));
    setBusy(true); setError(''); setNotice('');
    try {
      if (step === 'email') {
        const address = String(form.email).trim();
        if(mode === 'signup') {
          if(!await registrationRequiresEmailConfirmation())throw new Error('Registration configuration unavailable');
          if(form.password !== form.confirm_password) throw new Error('Passwords do not match.');
          const {data,error:failure}=await supabase.auth.signUp({email:address,password:String(form.password)});
          if(failure)throw failure;
          if(data?.session){await supabase.auth.signOut({scope:'local'});throw new Error('Registration configuration unavailable');}
          setEmail(address);setStep('code');markCodeRequested();
        } else if(useCode) {
          const {error:failure}=await supabase.auth.signInWithOtp({email:address,options:{shouldCreateUser:false}});if(failure)throw failure;setEmail(address);setStep('code');markCodeRequested();
        } else {
          const {error:failure}=await supabase.auth.signInWithPassword({email:address,password:String(form.password)});
          if(failure?.code === 'email_not_confirmed'){setEmail(address);setStep('code');return;}
          if(failure)throw failure;
        }
      } else {
        await verifyEmailCode(supabase.auth,email,form.code,!useCode);
        // The Auth subscription opens Home. Do not manufacture a local login flag.
      }
    } catch (failure) {setError(failure.message === 'Registration configuration unavailable' ? 'Registration is not available right now. Please try again later.' : failure.message === 'Passwords do not match.' ? failure.message : step === 'email' ? mode === 'signup' ? 'Unable to register. Check your details and password requirements, then retry.' : 'Sign-in failed. Check your email/password and verify your email first.' : otpErrorMessage(failure));}
    finally {setBusy(false);}
  }
  return <section className="form-page auth-page">
    <div className="auth-brand"><Brand/></div><span className="eyebrow">YOUR LOCAL MARKETPLACE</span>
    <h1>{step === 'code' ? 'Check your inbox.' : mode === 'signup' ? 'Your next chapter starts local.' : 'Good to see you again.'}</h1>
    <p className="muted">{step === 'code' ? (backendMode === 'staging' ? `Confirm ${email} using the link in your newest email, or enter its six-digit code if one is included.` : `Enter the six-digit code from the newest email we sent to ${email}. Can't find it? Check spam, then use Resend below.`) : mode === 'signup' ? 'Create your ZamNexus account and make room for new possibilities.' : 'Sign in to your ZamNexus account. Your local marketplace is waiting.'}</p>
    {step==='code'&&backendMode==='staging'&&<details className="setup-notice"><summary>Received a confirmation link instead of a code?</summary><p>This staging environment still needs its email template configured for codes. You can confirm with the link from your latest email, then sign in here with the same email and password. Avoid creating the account again. Email verification is still required.</p><button type="button" className="text-button" onClick={()=>navigate('/signin')}>Already confirmed? Go to Sign In</button></details>}
    {error && <p role="alert" className="auth-error">{error}</p>}
    {notice && <p role="status" className="muted">{notice}</p>}
    <form key={`${step}-${codeRound}`} onSubmit={submit}>
      {step === 'email' ? <label>Email<input required type="email" name="email" autoComplete="email" maxLength={254} defaultValue={email}/></label> :
        <label>Code from email<input required name="code" type="text" inputMode="numeric" autoComplete="one-time-code" pattern="[0-9]{6}" minLength={6} maxLength={6} placeholder="Six-digit code" title="Enter the six-digit verification code"/></label>}
      {step === 'email' && !useCode && <><label>Password<input required type="password" name="password" minLength={mode === 'signup' ? 8 : 1} maxLength={128} autoComplete={mode === 'signup' ? 'new-password' : 'current-password'}/></label>
        {mode === 'signup' && <><label>Confirm password<input required type="password" name="confirm_password" minLength={8} maxLength={128} autoComplete="new-password"/></label><p className="muted">At least 8 characters. We’ll send an email verification code next.</p></>}</>}
      <button className="primary-button" disabled={busy}>{busy ? 'Please wait...' : step === 'email' ? mode === 'signup' ? 'Create account & send code' : useCode ? 'Send sign-in code' : 'Sign In' : useCode ? 'Verify and sign in' : 'Verify email'}</button>
    </form>
    {step === 'code' ? <p><button className="text-button" disabled={busy||resendWait>0} onClick={async () => {if(busy||otpResendSeconds(resendAt)>0)return;setBusy(true);setError('');setNotice('');try{await resendEmailCode(supabase.auth,email,!useCode);markCodeRequested();setCodeRound(value=>value+1);setNotice('A new verification code was requested. Check your inbox and spam folder, then use the newest code.');}catch(failure){setError(otpErrorMessage(failure,'resend'));}finally{setBusy(false);}}}>{resendWait>0?`Resend available in ${resendWait}s`:'Resend verification code'}</button></p> :
      <p className="auth-switch">{mode === 'signup' ? 'Already part of the community?' : 'New around here?'} <button disabled={busy} className="text-button" onClick={() => navigate(mode === 'signup' ? '/signin' : '/create-account')}>{mode === 'signup' ? 'Sign In' : 'Create Account'}</button></p>}
    {mode === 'signin' && step === 'email' && <p><button className="text-button" disabled={busy} onClick={()=>setUseCode(value=>!value)}>{useCode?'Use email & password':'Previously used email codes, or forgot your password?'}</button></p>}
    <button className="back-button" onClick={() => navigate('/')}>← Back to welcome</button>
  </section>;
}

export default function AuthBoundary({component: Content}) {
  const [year] = useState(() => new Date().getFullYear());
  const [state,setState] = useState({status:'loading',user:null,error:''});
  const [logoutBusy,setLogoutBusy] = useState(false);
  const [logoutError,setLogoutError] = useState('');
  const controller = useRef(null);
  const path = usePath();
  useEffect(() => {
    const session = createAuthSession(supabase.auth,next => {
      if (next.status === 'anonymous' && next.reason === 'signout') navigate('/',true);
      else if (next.status === 'anonymous' && !publicPath(window.location.pathname)) navigate('/signin',true);
      if (next.status === 'authenticated' && (next.reason === 'signin' || authPath(window.location.pathname))) navigate('/home',true);
      if (next.status !== 'authenticated') setLogoutError('');
      setState(next);
    });
    controller.current = session;
    return () => {session.stop(); controller.current = null;};
  },[]);
  useEffect(() => {
    if (state.status === 'anonymous' && !publicPath(path)) navigate('/signin',true);
    if (state.status === 'authenticated' && authPath(path)) navigate('/home',true);
  },[state.status,path]);
  async function logout() {
    if (logoutBusy) return;
    setLogoutBusy(true); setLogoutError('');
    try {await controller.current.signOut();}
    catch {setLogoutError('Unable to sign out. Check your connection and try again.');}
    finally {setLogoutBusy(false);}
  }
  if (state.status === 'authenticated') return <>{logoutError && <p className="app-notice" role="alert">{logoutError}</p>}<ProfileGate key={state.user.id} user={state.user} component={Content} onLogout={logout} logoutBusy={logoutBusy}/></>;
  if (state.status === 'anonymous' && browsePath(path)) return <Content user={null} profile={null} onLogin={()=>navigate('/signin')}/>;
  return <div className="guest-shell">
    <header className="guest-header"><button className="brand" onClick={() => navigate('/')} aria-label="ZamNexus welcome"><Brand/></button><ThemeControl/></header>
    <main className="guest-main">
      {state.status === 'loading' ? <section className="session-screen" role="status"><img src="/brand-mark.svg" width="64" height="64" alt=""/><span className="session-spinner"/><p>Getting your ZamNexus ready...</p></section> :
        state.status === 'error' ? <section className="form-page centered-page"><h1>Let’s reconnect.</h1><p role="alert">{state.error}</p><button className="primary-button" onClick={() => controller.current.retry()}>Try again</button></section> :
          path === '/signin' || path === '/create-account' ? <AuthForm key={path} mode={path === '/create-account' ? 'signup' : 'signin'}/> :
            <Welcome onBrowse={()=>navigate('/home')} onAccount={() => navigate('/create-account')} onSignIn={() => navigate('/signin')}/>}
    </main>
    <footer className="guest-footer"><span>© {year} ZamNexus</span><span>Shop Local, Sell Easy.</span></footer>
  </div>;
}

