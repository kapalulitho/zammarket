const actions={click:1,save:3,search:1};
export function safeSearchTopic(value){const text=String(value??'').normalize('NFKC').trim().toLowerCase().replace(/\s+/g,' ');if(text.length<2||text.length>60||/[@:/\\]|\d{4,}/.test(text))return null;return text;}
export function createVisitSignals(){let enabled=false,events=[];return {
 isEnabled(){return enabled;},
 enable(value){enabled=!!value;if(!enabled)events=[];},clear(){events=[];},
 record(event,now=Date.now()){if(!enabled||!Object.hasOwn(actions,event.action)||!['product','service','event','search'].includes(event.kind)||!event.id||events.length>=200)return false;const id=String(event.id).slice(0,120);if(events.some(row=>row.id===id&&row.kind===event.kind&&row.action===event.action&&now-row.at<3600000)||events.filter(row=>now-row.at<60000).length>=8)return false;const label=event.kind==='search'?safeSearchTopic(event.label):String(event.label??'').slice(0,100);if(!label)return false;events.push({id,kind:event.kind,action:event.action,label,location:String(event.location??'').slice(0,100),category:String(event.category??'').slice(0,100),at:now});return true;},
 rank(location='',now=Date.now()){const rows=new Map();for(const event of events){if(now<event.at||now-event.at>86400000||location&&event.location.toLowerCase()!==location.toLowerCase())continue;const key=`${event.kind}:${event.id}`,row=rows.get(key)||{...event,score:0};row.score+=actions[event.action]*2**(-(now-event.at)/21600000);rows.set(key,row);}return [...rows.values()].sort((a,b)=>b.score-a.score||a.id.localeCompare(b.id));},
};}
