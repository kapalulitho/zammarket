export function Icon({name = 'bag', size = 22, ...props}) {
  const paths = {
    search: <><circle cx="10.8" cy="10.8" r="6.8"/><path d="m16 16 4.5 4.5"/></>,
    bag: <><path d="M5 7h14l1.5 14h-17L5 7Z"/><path d="M8 8V6a4 4 0 0 1 8 0v2"/></>,
    grid: <><rect x="3" y="3" width="7" height="7" rx="2"/><rect x="14" y="3" width="7" height="7" rx="2"/><rect x="3" y="14" width="7" height="7" rx="2"/><rect x="14" y="14" width="7" height="7" rx="2"/></>,
    phone: <><rect x="6" y="2" width="12" height="20" rx="3"/><path d="M10 5h4m-3 14h2"/></>,
    laptop: <><rect x="4" y="4" width="16" height="12" rx="2"/><path d="m4 16-2 4h20l-2-4M9 20h6"/></>,
    shirt: <path d="m8 3-6 4 3 5 3-2v11h8V10l3 2 3-5-6-4c-1 3-7 3-8 0Z"/>,
    shoe: <><path d="M3 14c3 0 5-3 5-7l5 3 2 5 6 2v4H3v-7Z"/><path d="m11 12 3-1m-1 4 3-1M3 18h18"/></>,
    home: <><path d="m3 11 9-8 9 8M5 10v11h14V10M10 21v-7h4v7"/></>,
    car: <><path d="m5 7 2-4h10l2 4 2 4v7H3v-7l2-4ZM5 7h14M3 12h18M6 18v3m12-3v3M6 15h2m8 0h2"/></>,
    box: <><path d="m12 2 9 5v10l-9 5-9-5V7l9-5ZM3 7l9 5 9-5M12 12v10M7.5 4.5l9 5"/></>,
    message: <path d="M21 11a9 9 0 0 1-9 9H4l-3 2 2-6a9 9 0 1 1 18-5ZM7 10h10M7 14h6"/>,
    user: <><circle cx="12" cy="8" r="4"/><path d="M4 22v-3a8 8 0 0 1 16 0v3"/></>,
    heart: <path d="M20.8 4.6a5.4 5.4 0 0 0-7.6 0L12 5.8l-1.2-1.2a5.4 5.4 0 1 0-7.6 7.6L12 21l8.8-8.8a5.4 5.4 0 0 0 0-7.6Z"/>,
    plus: <path d="M12 4v16M4 12h16"/>,
    arrow: <path d="M4 12h16m-6-6 6 6-6 6"/>,
    pin: <><path d="M20 10c0 6-8 12-8 12S4 16 4 10a8 8 0 0 1 16 0Z"/><circle cx="12" cy="10" r="2.5"/></>,
    check: <path d="m5 12 4 4L19 6"/>,
    spark: <path d="m12 2 2.5 7.5L22 12l-7.5 2.5L12 22l-2.5-7.5L2 12l7.5-2.5L12 2Z"/>,
    close: <path d="m6 6 12 12M6 18 18 6"/>,
    menu: <path d="M4 6h16M4 12h16M4 18h16"/>,
    bell:<><path d="M5 17h14l-2-3V9a5 5 0 0 0-10 0v5l-2 3Z"/><path d="M10 21h4M12 2v2"/></>,
    calendar:<><rect x="3" y="5" width="18" height="17" rx="3"/><path d="M7 2v6m10-6v6M3 11h18m-13 5h2m4 0h2"/></>,
    briefcase:<><rect x="3" y="7" width="18" height="14" rx="2"/><path d="M8 7V3h8v4M3 12l9 3 9-3m-9 0v5"/></>,
    book:<><path d="M12 5C8 2 4 3 2 4v16c3-2 7-2 10 0 3-2 7-2 10 0V4c-3-1-7-2-10 1Zm0 0v15"/></>,
    food:<><path d="M4 2v6m3-6v6m3-6v6M4 8h6l-3 4v10M18 2c-4 5-4 10 0 10V2Zm0 10v10"/></>,
    store:<><path d="M3 10 5 3h14l2 7M4 11v11h16V11M9 22v-8h6v8"/><path d="M3 10c0 3 4 3 4 0 0 3 5 3 5 0 0 3 5 3 5 0 0 3 4 3 4 0"/></>,
  };
  return <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.65" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" {...props}>{paths[name] ?? paths.bag}</svg>;
}

export function Brand({compact = false}) {
  return <><img className="brand-symbol" src="/brand-mark.svg" width="48" height="48" alt=""/>
    {!compact && <span className="brand-wordmark"><strong>Zam<span>Nexus</span></strong></span>}</>;
}

export function Welcome({user, onAccount, onSignIn, onSell, onBrowse, hidden, allowBrowse = true}) {
  return <section className="welcome" hidden={hidden} aria-labelledby="welcome-title">
    <div className="welcome-copy">
      <div className="welcome-eyebrow"><span className="mini-dot"/> A little more local. A lot more possibility.</div>
      <h1 id="welcome-title">Big finds.<br/><span>Closer to home.</span></h1>
      <p>Your next favourite thing could be just around the corner. Buy, sell, and discover something good on Zambia’s local marketplace.</p>
      <div className="welcome-actions">{user ? <>
        <button className="primary-button" onClick={onSell}>Sell something great <Icon name="arrow" size={19}/></button>
        <a className="secondary-button" href="#listings">Explore the market</a>
      </> : <>
        <button className="primary-button" onClick={onAccount}>Create Account <Icon name="arrow" size={19}/></button>
        <button className="secondary-button" onClick={onSignIn}>Sign In</button>
      </>}</div>
      <div className="welcome-benefits"><span><Icon name="pin" size={16}/> Made for Zambia</span><span><Icon name="bag" size={16}/> Local finds, in ZMW</span></div>
      {!user && allowBrowse && <a className="browse-link" href="/home" onClick={onBrowse ? event=>{event.preventDefault();onBrowse();}:undefined}>Just looking? Explore the marketplace <Icon name="arrow" size={16}/></a>}
    </div>
    <div className="welcome-art"><div className="art-caption"><span className="art-kicker">THE JOY OF FINDING SOMETHING GOOD</span><span>Right here. Around you.</span></div>
      <img src="/marketplace-illustration.svg" width="560" height="440" alt="An original illustration of a shopping bag, trainers, headphones, and a phone" fetchPriority="high"/>
      <div className="art-bottom"><span>ZamNexus</span><span>Shop Local, Sell Easy. <Icon name="spark" size={17}/></span></div>
    </div>
  </section>;
}

export function ProductPlaceholder({category}) {
  const names = {Phones:'phone',Electronics:'laptop',Fashion:'shirt',Shoes:'shoe','Home & Living':'home',Vehicles:'car'};
  return <div className="product-placeholder" aria-label="No product photo"><span><Icon name={names[category] ?? 'bag'} size={58}/></span><small>Picture the possibilities</small></div>;
}

export function EmptyArt({name='search'}) {
  return <div className="empty-art" aria-hidden="true"><span className="empty-orbit"/><span className="empty-spark"><Icon name="spark" size={18}/></span><Icon name={name} size={46}/></div>;
}

export function ListingSkeletons() {
  return <div role="status" aria-label="Loading listings"><span className="sr-only">Loading listings...</span><div className="product-grid" aria-hidden="true">{Array.from({length:4},(_,i) => <div className="skeleton-card" key={i}><div/><span/><span/><span/></div>)}</div></div>;
}
