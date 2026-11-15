import {useEffect,useState} from 'react';
import {Icon} from './Design';
// Moving banner on Home. The first slide is the ZamNexus message; paid promotions (when they exist) slide in after it.
const brand={key:'brand',title:<>One Platform.<br/><span>Endless Possibilities.</span></>,text:'Shop • Sell • Book • Learn',action:'Explore now',page:'Directory'};
const advertise={key:'advertise',title:<>Advertise<br/><span>with ZamNexus.</span></>,text:'Reach local customers on the home page.',action:'Learn more',page:'Advertise'};
const SECONDS=5;
export default function HomeHero({onNavigate,promotions=[]}){
  const slides=[brand,...promotions.map(item=>({...item,sponsored:true})),advertise];
  const [index,setIndex]=useState(0);
  const [paused,setPaused]=useState(false);
  const [touchX,setTouchX]=useState(null);
  const reduce=typeof window!=='undefined'&&Boolean(window.matchMedia?.('(prefers-reduced-motion: reduce)').matches);
  const count=slides.length;
  const slide=slides[index%count];
  useEffect(()=>{
    if(paused||reduce||count<2)return undefined;
    const timer=setTimeout(()=>setIndex(current=>(current+1)%count),SECONDS*1000);
    return()=>clearTimeout(timer);
  },[index,paused,reduce,count]);
  function swipe(event){
    if(touchX===null)return;
    const move=event.changedTouches[0].clientX-touchX;setTouchX(null);
    if(Math.abs(move)>40)setIndex(current=>(current+(move<0?1:count-1))%count);
  }
  return <section className={`home-hero ${slide.image?'home-hero-photo':''}`} aria-label="Highlights" aria-roledescription="carousel"
    style={slide.image?{backgroundImage:`linear-gradient(rgba(16,28,50,.65),rgba(16,28,50,.65)),url(${slide.image})`,backgroundSize:'cover',backgroundPosition:'center'}:undefined}
    onMouseEnter={()=>setPaused(true)} onMouseLeave={()=>setPaused(false)} onFocus={()=>setPaused(true)} onBlur={()=>setPaused(false)}
    onTouchStart={event=>setTouchX(event.touches[0].clientX)} onTouchEnd={swipe}>
    <div className="home-hero-slide" key={slide.key} aria-live={paused?'polite':'off'}>
      {slide.sponsored&&<span className="home-hero-tag">Sponsored</span>}
      <h2>{slide.title}</h2>
      <p>{slide.text}</p>
      <button type="button" className="gold-button" onClick={()=>onNavigate(slide.page)}>{slide.action} <Icon name="arrow" size={16}/></button>
    </div>
    {count>1&&<div className="home-hero-controls">
      <div className="home-hero-dots">{slides.map((item,position)=><button type="button" key={item.key} aria-label={`Show slide ${position+1} of ${count}`} aria-current={position===index%count} onClick={()=>setIndex(position)}/>)}</div>
      <button type="button" className="home-hero-pause" onClick={()=>setPaused(value=>!value)} aria-pressed={paused}>{paused?'Play':'Pause'}</button>
    </div>}
  </section>;
}
export function TrustStrip({onNavigate}){
  return <section className="trust-strip" aria-label="Safety">
    <div><b>Shop with confidence</b><small>Meet in public places. Report any problem.</small></div>
    <button type="button" onClick={()=>onNavigate('Safety')}>Safety tips</button>
  </section>;
}
