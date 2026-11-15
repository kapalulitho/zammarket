import test from 'node:test';
import assert from 'node:assert/strict';
import {selectBackendEnvironment} from '../src/lib/environment.js';
import {opportunityDraft,filterOpportunities,productCartSummary} from '../src/lib/opportunities.js';
const production={url:'https://production.example',key:'fixture'};
test('staging fails closed without isolation, on production targets and secret keys',()=>{
 assert.equal(selectBackendEnvironment({},production).mode,'production');assert.throws(()=>selectBackendEnvironment({MODE:'staging'},production));assert.throws(()=>selectBackendEnvironment({MODE:'staging',VITE_ZAMMARKET_ENV:'production'},production));
 const ref='abcdefghijklmnopqrst',env={MODE:'staging',VITE_ZAMMARKET_ENV:'staging',VITE_STAGING_ACK:'ISOLATED_NON_PRODUCTION',VITE_STAGING_PROJECT_REF:ref,VITE_SUPABASE_URL:`https://${ref}.supabase.co`,VITE_SUPABASE_PUBLISHABLE_KEY:'sb_publishable_fixture_no_real_key'};
 assert.equal(selectBackendEnvironment(env,production).storageKey,`zammarket-staging-${ref}`);assert.throws(()=>selectBackendEnvironment(env,{url:env.VITE_SUPABASE_URL,key:''}));assert.throws(()=>selectBackendEnvironment({...env,VITE_SUPABASE_PUBLISHABLE_KEY:'sb_secret_fixture'},production));assert.throws(()=>selectBackendEnvironment({...env,VITE_SUPABASE_URL:`https://${ref}.supabase.co/evil`},production));
 assert.throws(()=>selectBackendEnvironment(env,{...production,key:env.VITE_SUPABASE_PUBLISHABLE_KEY}),/reuse/);
});
test('opportunity drafts cannot submit applications or grant course access',()=>{
 const item={id:'local',title:'Test job'};const job=opportunityDraft('job',{note:'Non-sensitive skills preview',state:'submitted',applicant_id:'spoof'},item);assert.equal(job.state,'draft');assert.equal(job.applicant_id,undefined);const course=opportunityDraft('learning',{note:'Learn a useful skill',hours:3},item);assert.deepEqual(course.completed,[]);assert.throws(()=>opportunityDraft('learning',{note:'Valid learning goal',hours:99},item));
});
test('salary comparisons require one basis and null prices do not mean free',()=>{
 const items=[{price:100,price_unit:'month',category:'IT'},{price:null,price_unit:'month',category:'IT'},{price:0,price_unit:'course',category:'Art'}];assert.equal(filterOpportunities(items,{kind:'job',min:10}).length,0);assert.equal(filterOpportunities(items,{kind:'job',basis:'month',min:10}).length,1);assert.equal(filterOpportunities(items,{kind:'learning',free:true}).length,1);
});
test('product cart excludes missing/unavailable rows and uses integer currency arithmetic',()=>{
 const products=[{id:'a',price:'10.10',status:'active'},{id:'b',price:20,status:'sold'}];const result=productCartSummary([{id:'a',quantity:3},{id:'b',quantity:2},{id:'gone',quantity:1}],products,item=>item.status==='active');assert.equal(result.total_minor,3030);assert.equal(result.incomplete,true);assert.throws(()=>productCartSummary([{id:'a',quantity:21}],products,()=>true));
});
