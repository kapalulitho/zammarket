import {deliveryActions} from './operationalWorkflows.js';
export function createDeliveryOperations(client,mode,user){
 async function identity(){if(mode!=='staging'||!user?.id)throw new Error('Delivery operations are staging-only.');const value=await client.auth.getUser();if(value.error||value.data?.user?.id!==user.id)throw new Error('Session changed. Sign in again.');}
 async function result(query){const value=await query;if(value.error)throw new Error(value.error.code==='P0001'?value.error.message:'Delivery request could not be confirmed. Refresh before retrying.');return value.data;}
 return {
 async capability(){await identity();return result(client.rpc('delivery_workflow_capabilities'));},
 async load(){await identity();return result(client.from('delivery_jobs').select('*').or(`customer_id.eq.${user.id},courier_id.eq.${user.id}`).order('created_at',{ascending:false}).limit(50));},
 async tracking(id){await identity();return result(client.from('delivery_job_events').select('*').eq('job_id',id).order('revision'));},
 async submit(values,key){await identity();return result(client.rpc('submit_delivery_job',{p_pickup:values.pickup.trim(),p_destination:values.destination.trim(),p_parcel:values.parcel.trim(),p_key:key}));},
 async advance(job,action){await identity();if(!deliveryActions(job,user.id).includes(action))throw new Error('This transition is unavailable for your account.');const value=await client.rpc('advance_delivery_job',{p_id:job.id,p_revision:job.revision,p_action:action});if(value.error)throw new Error('Transition could not be confirmed. Refresh before retrying.');return {confirmed:true};}
 };
}
