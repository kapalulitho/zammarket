import {listingInput} from './listings.js';
export function listingEditInput(values){if(!['active','sold','temporarily_unavailable'].includes(values.status))throw new Error('Choose a supported listing status.');return {...listingInput(values),status:values.status};}
export function ownedListing(item,user){return !!user?.id&&item?.user_id===user.id;}

