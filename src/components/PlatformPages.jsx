import {Icon} from './Design';
import {serviceDirectory} from '../config/platform';
import {useStage3} from '../lib/stage3';
export function ServicesDirectory({onNavigate,compact=false}){
  const Heading=compact?'h2':'h1';
  const capability=useStage3();
  return <section className="platform-page"><span className="eyebrow">ONE ACCOUNT. MORE LOCAL POSSIBILITIES.</span><Heading>Explore ZamNexus.</Heading><p className="muted">The marketplace is open. Publishing in new modules requires approved backend setup.</p><div className="service-directory">{serviceDirectory.map(service=>{const available=!service.preview&&service.page&&(!service.setup||capability.ready);return <article className="service-tile" key={service.name}><span className="page-icon"><Icon name={service.icon}/></span><span className={`service-state ${available?'is-live':''}`}>{service.preview?'Local preview':available?'Available':service.page?'Setup required':'Planned'}</span><h3>{service.name}</h3><p>{service.description}</p>{service.page&&<button className="text-button" onClick={()=>onNavigate(service.page)}>Explore {service.name.toLowerCase()} →</button>}</article>;})}</div></section>;
}
