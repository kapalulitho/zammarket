import test from 'node:test';
import assert from 'node:assert/strict';
import {verifyEmailCode,resendEmailCode,otpErrorMessage,otpResendSeconds} from '../src/lib/emailOtp.js';

test('resend cooldown rounds up and ends at its deadline',()=>{assert.equal(otpResendSeconds(61000,1000),60);assert.equal(otpResendSeconds(61000,60999),1);assert.equal(otpResendSeconds(61000,61000),0);assert.equal(otpResendSeconds(61000,62000),0);assert.equal(otpResendSeconds(NaN,1000),0);});

test('signup verification sends the exact requested payload and preserves leading zeroes',async()=>{
 let payload; const auth={verifyOtp:async value=>{payload=value;return {data:{user:{id:'verified'}},error:null};}};
 const data=await verifyEmailCode(auth,'test@example.invalid',' 012345 ');
 assert.deepEqual(payload,{email:'test@example.invalid',token:'012345',type:'signup'});
 assert.equal(data.user.id,'verified');
});
test('malformed codes are rejected before contacting Supabase',async()=>{
 const auth={verifyOtp:()=>{throw new Error('must not run');}};
 for(const token of ['','12345','1234567','12a456'])await assert.rejects(verifyEmailCode(auth,'test@example.invalid',token),/six-digit/);
});
test('sign-in code compatibility keeps the email verification type',async()=>{
 let payload;await verifyEmailCode({verifyOtp:async value=>{payload=value;return {data:{},error:null};}},'test@example.invalid','123456',false);
 assert.equal(payload.type,'email');
});
test('signup resend uses resend signup and propagates errors',async()=>{
 let payload;await resendEmailCode({resend:async value=>{payload=value;return {error:null};}},'test@example.invalid');
 assert.deepEqual(payload,{type:'signup',email:'test@example.invalid'});
 await assert.rejects(resendEmailCode({resend:async()=>({error:new Error('offline')})},'test@example.invalid'),/offline/);
});
test('expired/incorrect, throttled and offline responses get useful messages',()=>{
 assert.match(otpErrorMessage({code:'otp_expired'}),/incorrect or has expired/);
 assert.match(otpErrorMessage({status:429}),/Too many attempts/);
 assert.match(otpErrorMessage({name:'AuthRetryableFetchError'}),/internet connection/);
 assert.match(otpErrorMessage({},'resend'),/resend/);
});
