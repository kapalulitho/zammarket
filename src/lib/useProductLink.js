import {useSyncExternalStore} from 'react';
import {productIdFromSearch,productLink} from './productLinks.js';
const subscribe=callback=>{window.addEventListener('popstate',callback);window.addEventListener('zammarket-product-link',callback);return()=>{window.removeEventListener('popstate',callback);window.removeEventListener('zammarket-product-link',callback);};};
export function useProductLink(){return productIdFromSearch(useSyncExternalStore(subscribe,()=>window.location.search,()=>''));}
export function selectProductLink(id){window.history.pushState({},'',id?productLink(id):'/home');window.dispatchEvent(new Event('zammarket-product-link'));}
