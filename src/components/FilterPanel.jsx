import {Icon} from './Design';
// Keeps filters tucked away behind one "Filter" button so the results come first.
export default function FilterPanel({children,label='Filter'}){
  return <details className="filter-panel"><summary><Icon name="menu" size={18}/> {label}</summary>{children}</details>;
}
