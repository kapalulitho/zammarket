export const moduleKinds={
 event:{page:'Events',title:'Events',singular:'event',intro:'Discover gatherings, workshops and experiences in your area.',organisation:'Organiser',category:'Event category',format:'Event type',formats:['In person','Online','Hybrid'],extra:'Programme / attendance information'},
 job:{page:'Jobs',title:'Jobs',singular:'job',intro:'Find local opportunities and connect with employers.',organisation:'Company / employer',category:'Job category',format:'Employment type',formats:['Full time','Part time','Contract','Internship'],extra:'Requirements / application instructions'},
 service:{page:'Services',title:'Professional services',singular:'service',intro:'Discover local professionals and ask about their services.',organisation:'Professional / business name',category:'Profession / expertise',format:'Service format',formats:['At customer location','At provider location','Online','Flexible'],extra:'Qualifications / service scope'},
 learning:{page:'Learning',title:'Learning',singular:'learning listing',intro:'Find tutors, courses and opportunities to learn.',organisation:'Tutor / institution',category:'Subject / topic',format:'Listing type',formats:['Tutor','Course','Workshop','Educational resource'],extra:'Level / duration / learning outcomes'},
};
export function moduleInput(kind,values){
 if(!moduleKinds[kind])throw new Error('Unsupported listing type.');
 const result={kind};
 for(const [field,max,min] of [['title',200,3],['description',6000,10],['location',200,2],['organisation',120,0],['category',100,0],['format',80,0],['extra',3000,0],['price_unit',40,0]]){
  result[field]=String(values[field]??'').trim();if(result[field].length<min||result[field].length>max)throw new Error(`Check ${field.replaceAll('_',' ')}.`);
 }
 result.price=values.price===''||values.price==null?null:Number(values.price);if(result.price!==null&&(!Number.isFinite(result.price)||result.price<0))throw new Error('Enter a valid nonnegative price or leave it blank.');
 result.starts_at=null;result.ends_at=null;result.deadline=values.deadline||null;
 for(const field of ['starts_at','ends_at'])if(values[field]){const date=new Date(`${values[field]}${String(values[field]).length===16?':00':''}+02:00`);if(Number.isNaN(date.getTime()))throw new Error('Enter a valid Zambia date and time.');result[field]=date.toISOString();}
 if(kind==='event'&&!result.starts_at)throw new Error('Choose an event start date and time.');
 if(result.ends_at&&(!result.starts_at||result.ends_at<result.starts_at))throw new Error('Event end must be after its start.');
 result.status=values.status==='published'?'published':'draft';return result;
}
