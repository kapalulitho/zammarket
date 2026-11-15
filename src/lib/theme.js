export const THEME_KEY='zammarket.theme';
let memoryPreference='system';
export function resolveTheme(preference,systemDark=false){if(preference==='warm'||preference==='emerald')return preference;return preference==='dark'||(preference!=='light'&&systemDark)?'dark':'light';}
export function themePreference(){try{return ['light','warm','emerald','dark','system'].includes(localStorage.getItem(THEME_KEY))?localStorage.getItem(THEME_KEY):memoryPreference;}catch{return memoryPreference;}}
export function applyTheme(){
  const theme=resolveTheme(themePreference(),window.matchMedia('(prefers-color-scheme: dark)').matches);
  document.documentElement.dataset.theme=theme;
  document.querySelector('meta[name="theme-color"]')?.setAttribute('content',theme==='dark'?'#0b1220':theme==='warm'?'#F6F0E4':theme==='emerald'?'#0F3D2E':'#101C32');
}
export function setThemePreference(value){
  if(!['light','warm','emerald','dark','system'].includes(value))return;
  memoryPreference=value;try{localStorage.setItem(THEME_KEY,value);}catch{/* Theme still works in memory when storage is blocked. */}
  applyTheme();window.dispatchEvent(new Event('zammarket-theme'));
}
export function subscribeTheme(callback){
  const media=window.matchMedia('(prefers-color-scheme: dark)');
  const changed=()=>{applyTheme();callback();};
  const stored=event=>{if(event.key===THEME_KEY||event.key===null)changed();};
  window.addEventListener('zammarket-theme',changed);window.addEventListener('storage',stored);media.addEventListener('change',changed);
  return()=>{window.removeEventListener('zammarket-theme',changed);window.removeEventListener('storage',stored);media.removeEventListener('change',changed);};
}
