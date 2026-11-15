import {Icon,ProductPlaceholder} from './Design';
import {listingPhotos} from '../lib/listings';
import {useState} from 'react';
export default function ProductCard({product,onOpen,formatMoney}){
 const photo=listingPhotos(product)[0];
 const [failedPhoto,setFailedPhoto]=useState(null);
 return <article className="product-card"><button type="button" className="product-art product-photo-button" aria-label={`View ${product.title||'product'}`} onClick={()=>onOpen(product)}>{photo&&failedPhoto!==photo?<img src={photo} alt="" loading="lazy" decoding="async" onError={()=>setFailedPhoto(photo)}/>:<ProductPlaceholder category={product.category}/>}</button><div className="product-info"><h3><button className="listing-title" title={product.title} onClick={()=>onOpen(product)}>{product.title||'Untitled listing'}</button></h3><strong className="product-price">{formatMoney(product.price)}</strong><span className="product-location"><Icon name="pin" size={13}/>{product.location||'Location not provided'}{product.location?', Zambia':''}</span></div></article>;
}
