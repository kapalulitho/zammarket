import {showDeveloperNotes} from '../lib/devNotes';
import {Icon} from './Design';
export default function CoreJourneyGuide(props){if(!showDeveloperNotes)return null;return <CoreJourneyGuideInner {...props}/>;}
function CoreJourneyGuideInner({onNavigate}){
 return <details className="workflow-notebook journey-guide"><summary>New here? How ZamNexus works</summary>
  <p className="muted">Buyers: search, check the status, save or message the seller, then agree collection and payment directly. Sellers: complete your profile once, post with clear photos and a fair price, then manage availability and replies from My Listings.</p>
  <div className="journey-links">
   <button className="text-button" onClick={()=>onNavigate('Post')}><Icon name="plus" size={16}/> Post an item</button>
   <button className="text-button" onClick={()=>onNavigate('My Listings')}><Icon name="bag" size={16}/> My Listings</button>
   <button className="text-button" onClick={()=>onNavigate('Saved')}><Icon name="heart" size={16}/> Saved</button>
   <button className="text-button" onClick={()=>onNavigate('Messages')}><Icon name="message" size={16}/> Messages</button>
  </div>
 </details>;
}
