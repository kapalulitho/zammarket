import {Icon} from './Design';
// Shared top action bar for every marketplace category: POST | MY <CATEGORY> | MESSAGES.
// The page that uses it decides what each action opens, so every category looks and behaves alike.
export const categoryLabels={Explore:'Shop',Property:'Property',Stays:'Accommodation',Logistics:'Logistics',Delivery:'Delivery',Food:'Food',Events:'Events',Jobs:'Jobs',Learning:'Learning',Services:'Services',Agriculture:'Agriculture',Digital:'Digital products'};
// The wording of the second button changes with the category.
export const myLabels={Explore:'My Products',Food:'My Food Listings',Events:'My Events',Campuses:'My Listings',Property:'My Properties',Stays:'My Accommodation',Jobs:'My Jobs',Learning:'My Courses',Delivery:'My Deliveries',Logistics:'My Logistics',Agriculture:'My Agriculture Listings',Digital:'My Digital Products',Services:'My Services'};
const categoryIcons={Explore:'bag',Food:'food',Events:'calendar',Property:'home',Stays:'home',Jobs:'briefcase',Learning:'book',Delivery:'car',Logistics:'car',Agriculture:'box',Digital:'laptop',Services:'briefcase'};
export default function CategoryActions({category,onAction,notice}){
 const label=categoryLabels[category]||category;
 return <section className="category-actions" aria-label={`${label} actions`}>
  <div className="category-actions-row">
   <button type="button" className="primary-button" onClick={()=>onAction('post')}><Icon name="plus" size={16}/>Post</button>
   <button type="button" className="secondary-button" onClick={()=>onAction('mine')}><Icon name={categoryIcons[category]||'bag'} size={16}/>{myLabels[category]||`My ${label}`}</button>
   <button type="button" className="secondary-button" onClick={()=>onAction('messages')}><Icon name="message" size={16}/>Messages</button>
  </div>
  {notice&&<p className="category-notice" role="status">{notice}</p>}
 </section>;
}