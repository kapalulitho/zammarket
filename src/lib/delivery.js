export const parcelSizes=['Document','Small parcel','Medium parcel','Large parcel'];
export function deliveryInput(values){
 const data={};for(const [key,min,max] of [['pickup',2,200],['destination',2,200],['description',3,500],['notes',0,1000]]){data[key]=String(values[key]??'').trim();if(data[key].length<min||data[key].length>max)throw new Error(`Check ${key}.`);}
 data.weight_kg=values.weight_kg===''||values.weight_kg==null?null:Number(values.weight_kg);
 if(data.weight_kg!==null&&(!Number.isFinite(data.weight_kg)||data.weight_kg<=0||data.weight_kg>1000))throw new Error('Weight must be greater than zero and no more than 1,000 kg.');
 if(!parcelSizes.includes(values.parcel_size))throw new Error('Choose a parcel size.');data.parcel_size=values.parcel_size;data.state='planning';return data;
}
export const deliveryStages=['Plan request','Review parcel','Booking unavailable','Courier assignment unavailable','Tracking unavailable'];
