import {useMemo} from 'react';
import {visitRecommendations} from '../lib/shoppingDiscovery';
import {lusakaDate} from '../lib/availability';
import ProductCard from './ProductCard';
export default function RecommendationShelf({products,recentIds,savedIds=[],location='',now,onOpen,formatMoney}){const day=lusakaDate(now),recent=recentIds.join(','),saved=savedIds.join(',');const items=useMemo(()=>visitRecommendations(products,{recentIds:recent?recent.split(','):[],savedIds:saved?saved.split(','):[],location},day),[products,recent,saved,location,day]);return items.length?<section><h3>More local finds for this visit</h3><p>Available products matching categories you viewed/saved or the town you selected. No global popularity or purchase prediction is implied.</p><div className="product-grid">{items.map(product=><ProductCard key={product.id} product={product} onOpen={onOpen} formatMoney={formatMoney}/>)}</div></section>:null;}
