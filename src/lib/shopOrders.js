export function shopActions(row,id){if(row.seller_id===id){const next={requested:'acknowledge',acknowledged:'prepare',preparing:'ready',ready:'complete'}[row.state];return [...(next?[next]:[]),...(!['completed','cancelled'].includes(row.state)?['cancel']:[])];}return row.buyer_id===id&&row.state==='requested'?['cancel']:[];}
export function createShopOrders(client,mode,user){
 async function identity(){if(mode!=='staging'||!user?.id)throw new Error('Order requests require isolated staging.');const value=await client.auth.getUser();if(value.error||value.data?.user?.id!==user.id)throw new Error('Session changed.');}
 async function result(query){const value=await query;if(value.error)throw new Error(value.error.code==='P0001'?value.error.message:'Order request could not be confirmed. Refresh before retrying.');return value.data;}
 return {
 async capability(){await identity();return result(client.rpc('shop_workflow_capabilities'));},
 async load(ids=[]){await identity();const [orders,stocks]=await Promise.all([result(client.from('shop_order_requests').select('*').or(`buyer_id.eq.${user.id},seller_id.eq.${user.id}`).order('created_at',{ascending:false}).limit(50)),ids.length?result(client.from('marketplace_stock').select('*').in('listing_id',ids.slice(0,30))):[]]);return {orders,stocks};},
 async detail(id){await identity();const [lines,events]=await Promise.all([result(client.from('shop_order_request_lines').select('*').eq('order_id',id)),result(client.from('shop_order_request_events').select('*').eq('order_id',id).order('revision'))]);return {lines,events};},
 async submit(lines,key){await identity();return result(client.rpc('shop_submit_order_request',{p_lines:lines,p_key:key}));},
 async advance(order,action){await identity();if(!shopActions(order,user.id).includes(action))throw new Error('This action is unavailable.');return result(client.rpc('shop_advance_order_request',{p_id:order.id,p_revision:order.revision,p_action:action}));}
 };
}
