// ZamNexus signature sound: a short warm sting, reused everywhere for
// recognition. Preference follows the same pattern as lib/theme.js.
export const SOUND_KEY='zammarket.sound';
let audioElement=null;
let memoryPreference='on';

export function soundPreference(){
 try{return localStorage.getItem(SOUND_KEY)==='off'?'off':'on';}catch{return memoryPreference;}
}
export function setSoundPreference(value){
 if(!['on','off'].includes(value))return;
 memoryPreference=value;try{localStorage.setItem(SOUND_KEY,value);}catch{/* Preference still works in memory when storage is blocked. */}
 window.dispatchEvent(new Event('zammarket-sound'));
}
export function subscribeSound(callback){
 const changed=()=>callback();
 const stored=event=>{if(event.key===SOUND_KEY||event.key===null)changed();};
 window.addEventListener('zammarket-sound',changed);window.addEventListener('storage',stored);
 return()=>{window.removeEventListener('zammarket-sound',changed);window.removeEventListener('storage',stored);};
}

// Respect the browser's own quiet preference: never sound when the system
// asks for reduced motion, which users often enable alongside quiet modes.
export function playBrandSting(){
 if(soundPreference()==='off')return;
 try{
  if(typeof window.matchMedia==='function'&&window.matchMedia('(prefers-reduced-motion: reduce)').matches)return;
 }catch{}
 try{
  if(!audioElement){
   audioElement=new Audio('/sounds/zamnexus-sting.wav');
   audioElement.preload='auto';
   audioElement.volume=0.45;
  }
  audioElement.currentTime=0;
  audioElement.play().catch(()=>{/* Browsers block audio before the first interaction; later plays work. */});
 }catch{/* Sound must never break the action that triggered it. */}
}
