import {useId,useSyncExternalStore} from 'react';
import {soundPreference,setSoundPreference,subscribeSound} from '../lib/sound';
export default function SoundControl(){
  const id=useId();const preference=useSyncExternalStore(subscribeSound,soundPreference,()=>'on');
  return <label className="theme-control" htmlFor={id}><span className="sr-only">Signature sound</span><select id={id} value={preference} onChange={event=>setSoundPreference(event.target.value)}><option value="on">Sound on</option><option value="off">Sound off</option></select></label>;
}
