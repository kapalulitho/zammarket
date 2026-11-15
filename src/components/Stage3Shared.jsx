export function BackendNotice({capability}){
 if(capability.loading)return <p role="status" className="setup-notice">Checking what's available…</p>;
 if(capability.ready)return null;
 return <div className="setup-notice" role="status"><strong>{capability.missing?'Not open yet':'Temporarily unavailable'}</strong><p>{capability.missing?'You can look around, but posting and saving here are not open yet. We are finishing the final checks — anything you preview stays private to you.':capability.error||'We could not confirm what is available right now.'}</p><button className="text-button" onClick={capability.retry}>Check again</button></div>;
}
export function ModuleEmpty({title='Nothing published yet.',children}){return <div className="empty-state"><h2>{title}</h2><p>{children||'Check back as the community adds new listings.'}</p></div>;}
