export function BackendNotice({capability,commerce=false}){
 if(capability.loading)return <p role="status" className="setup-notice">Checking availability...</p>;
 if(capability.ready)return null;
 return <div className="setup-notice" role="status"><strong>{capability.missing?'Setup required':'Temporarily unavailable'}</strong><p>{capability.missing?`This interface is built, but publishing/storage requires the corrected ${commerce?'014':'013'} v2 draft, security validation and separate approval. Original migrations remain on HOLD. Nothing has been published.`:capability.error||'Backend capability could not be confirmed.'}</p><button className="text-button" onClick={capability.retry}>Check again</button></div>;
}
export function ModuleEmpty({title='Nothing published yet.',children}){return <div className="empty-state"><h2>{title}</h2><p>{children||'Check back as the community adds new listings.'}</p></div>;}
