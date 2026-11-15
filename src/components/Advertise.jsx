export default function Advertise({onNavigate}){
  return <section className="hub-page">
    <button type="button" className="text-button" onClick={()=>window.history.length>1?window.history.back():onNavigate('Home')}>← Back</button>
    <h1>Advertise with ZamNexus</h1>
    <p className="hub-intro">Home page promotion slots are coming soon.</p>
    <div className="hub-grid">
      <button type="button" className="hub-card" onClick={()=>onNavigate('Post')}><span className="hub-text"><strong>Post a product</strong><small>List something for sale now.</small></span></button>
      <button type="button" className="hub-card" onClick={()=>onNavigate('Home')}><span className="hub-text"><strong>Back to Home</strong></span></button>
    </div>
  </section>;
}
