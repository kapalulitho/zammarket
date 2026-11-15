import {Icon} from './Design';
import {categoryLabels,myLabels} from './CategoryActions';
const postWord={Property:'List',Stays:'List'};
// One shared header for every section page: back arrow, section name, and one main action.
export default function SectionHeader({category,onAction,onBack,notice}){
  const label=categoryLabels[category]||category;
  return <header className="section-header">
    <div className="section-header-row">
      <button type="button" className="icon-button section-back" aria-label="Back" onClick={onBack}><Icon name="arrow" size={20}/></button>
      <h1>Explore</h1>
      <button type="button" className="primary-button section-post" onClick={()=>onAction('post')}><Icon name="plus" size={16}/>{postWord[category]||'Post'}</button>
    </div>
    <button type="button" className="section-mine" onClick={()=>onAction('mine')}>{myLabels[category]||`My ${label}`}</button>
    {notice&&<p className="category-notice" role="status">{notice}</p>}
  </header>;
}
