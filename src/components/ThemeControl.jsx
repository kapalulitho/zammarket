import {useId,useSyncExternalStore} from 'react';
import {themePreference,setThemePreference,subscribeTheme} from '../lib/theme';
export default function ThemeControl(){
  const id=useId();const preference=useSyncExternalStore(subscribeTheme,themePreference,()=> 'system');
  return <label className="theme-control" htmlFor={id}><span className="sr-only">Appearance</span><select id={id} value={preference} onChange={event=>setThemePreference(event.target.value)}><option value="system">System</option><option value="light">Light</option><option value="warm">Warm</option><option value="emerald">Emerald</option><option value="dark">Dark</option></select></label>;
}
