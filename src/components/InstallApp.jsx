import {useEffect,useState} from 'react';
// Offers "Install ZamNexus" once the browser allows it (Android/Chrome/Edge
// desktop). iPhones install via Safari's Share menu instead, so this button
// simply stays hidden there.
export default function InstallApp(){
  const [prompt,setPrompt]=useState(null);
  const [installed,setInstalled]=useState(()=>window.matchMedia('(display-mode: standalone)').matches||window.navigator.standalone===true);
  useEffect(()=>{
    const onPrompt=event=>{event.preventDefault();setPrompt(event);};
    const onInstalled=()=>{setInstalled(true);setPrompt(null);};
    window.addEventListener('beforeinstallprompt',onPrompt);
    window.addEventListener('appinstalled',onInstalled);
    return()=>{window.removeEventListener('beforeinstallprompt',onPrompt);window.removeEventListener('appinstalled',onInstalled);};
  },[]);
  if(installed||!prompt)return null;
  return <button className="text-button" onClick={async()=>{setPrompt(null);try{await prompt.prompt();}catch{/* User dismissed or the browser declined; nothing to do. */}}}>Install ZamNexus on this device</button>;
}
