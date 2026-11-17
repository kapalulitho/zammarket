import { useSyncExternalStore } from 'react';

export const pagePaths = {History:'/history','Revenue Operations':'/revenue-operations','Secure Operations':'/secure-operations','Admin Review':'/admin-review','Digital Library':'/digital-library','Accommodation Operations':'/accommodation-operations','Event Operations':'/event-operations','Job Operations':'/job-operations','Property Operations':'/property-operations','Logistics Operations':'/logistics-operations','Learning Operations':'/learning-operations','Agriculture Operations':'/agriculture-operations','Service Operations':'/service-operations','Digital Operations':'/digital-operations','Order Centre':'/order-centre','Food Operations':'/food-operations','Delivery Operations':'/delivery-operations',Workspace:'/workspace',Admin:'/admin',Safety:'/safety',Home:'/home',Explore:'/explore',Categories:'/categories',Agriculture:'/agriculture',Digital:'/digital-products',Services:'/services',Events:'/events',Jobs:'/jobs',Learning:'/learning',Directory:'/directory',Delivery:'/delivery',Food:'/food',Stays:'/stays',Logistics:'/logistics',Property:'/property',Shops:'/shops',Storefront:'/storefront',Inventory:'/inventory',Promotions:'/promotions',Notifications:'/notifications',Enquiries:'/enquiries',Compare:'/compare',Saved:'/saved',Post:'/post',Messages:'/messages',Cart:'/cart',Orders:'/orders',Business:'/business',Profile:'/profile','My Listings':'/my-listings','My Activity':'/my-activity',Account:'/account',Seller:'/seller',Campuses:'/campuses',Advertise:'/advertise'};
export function pageFromPath(path) {
  return Object.keys(pagePaths).find(page => pagePaths[page] === path) ?? 'Home';
}
export function authPath(path) {return ['/', '/signin', '/create-account'].includes(path);}
export function browsePath(path) {return ['/home','/explore','/categories','/services','/agriculture','/digital-products','/events','/jobs','/learning','/directory','/delivery','/food','/property','/stays','/logistics','/shops','/compare','/campuses','/advertise','/safety','/seller'].includes(path);}
export function publicPath(path) {return authPath(path) || browsePath(path);}
export function navigate(path, replace = false) {
  if (window.location.pathname === path && !window.location.search && !window.location.hash) return;
  window.history[replace ? 'replaceState' : 'pushState']({},'',path);
  window.dispatchEvent(new PopStateEvent('popstate'));
  window.scrollTo({top:0,behavior:'auto'});
}
const subscribe = callback => {
  window.addEventListener('popstate',callback);
  return () => window.removeEventListener('popstate',callback);
};
export function usePath() {
  return useSyncExternalStore(subscribe,() => window.location.pathname,() => '/');
}
