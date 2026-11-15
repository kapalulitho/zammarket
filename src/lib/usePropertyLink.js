import {useSyncExternalStore} from 'react';
import {propertyIdFromSearch,propertyLink} from './propertyDiscovery';
const subscribe=callback=>{window.addEventListener('popstate',callback);return()=>window.removeEventListener('popstate',callback);};
export function usePropertyLink(){return propertyIdFromSearch(useSyncExternalStore(subscribe,()=>window.location.search,()=>''));}
export function selectPropertyLink(id){window.history.pushState({},'',id?propertyLink(id):'/property');window.dispatchEvent(new PopStateEvent('popstate'));}
