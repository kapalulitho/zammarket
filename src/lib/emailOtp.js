export function otpResendSeconds(deadline,now=Date.now()) {
  return Number.isFinite(deadline)&&Number.isFinite(now)?Math.max(0,Math.ceil((deadline-now)/1000)):0;
}

export function otpErrorMessage(error, action = 'verify') {
  if(error?.message === 'Enter the six-digit code from your email.')return error.message;
  if (error?.status === 429 || ['over_email_send_rate_limit','over_request_rate_limit'].includes(error?.code)) {
    return 'Too many attempts. Please wait a little before trying again.';
  }
  if (error?.code === 'otp_expired' || /expired|invalid token|invalid otp/i.test(error?.message ?? '')) {
    return 'This code is incorrect or has expired. Request a new code and try again.';
  }
  if (error?.name === 'AuthRetryableFetchError' || /fetch|network/i.test(error?.message ?? '')) {
    return 'Unable to connect. Check your internet connection and try again.';
  }
  return action === 'resend'
    ? 'We couldn’t resend your code. Please wait and try again.'
    : 'The code could not be verified. Check all six digits or request a new code.';
}

export async function verifyEmailCode(auth, email, value, signup = true) {
  const token = String(value ?? '').trim();
  if (!/^\d{6}$/.test(token)) throw new Error('Enter the six-digit code from your email.');
  // Explicit signup type requested for registration; retained by the installed SDK.
  const result = signup
    ? await auth.verifyOtp({email, token, type:'signup'})
    : await auth.verifyOtp({email, token, type:'email'});
  if (result.error) throw result.error;
  return result.data;
}

export async function resendEmailCode(auth, email, signup = true) {
  const result = signup
    ? await auth.resend({type:'signup', email})
    : await auth.signInWithOtp({email, options:{shouldCreateUser:false}});
  if (result.error) throw result.error;
}
