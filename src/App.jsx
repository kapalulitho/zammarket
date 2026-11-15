import FilterPanel from './components/FilterPanel';
import PostChooser from './components/PostChooser';
import {parseSmartSearch,smartMatches} from './lib/smartSearch';
import {campusNames} from './lib/campuses';
import {workPageKinds} from './lib/workSystems';
import {WorkspaceProvider} from './components/WorkspacePlans';
import CustomerWorkspace from './components/CustomerWorkspace';
import PurchasePlanner from './components/PurchasePlanner';
import AdminFoundation from './components/AdminFoundation';
import SafetyWorkspace from './components/SafetyWorkspace';

import {shoppingListings,shoppingCategory,listingDomain,sectionDestination,searchPage,sectionFromSearch,marketplaceSections} from './lib/marketplaceCategories';
import MarketplaceCategories from './components/MarketplaceCategories';
import CoreJourneyGuide from './components/CoreJourneyGuide';
import {useProductLink,selectProductLink} from './lib/useProductLink';
import {productLink,productIdFromSearch} from './lib/productLinks';
import {createVisitSignals,safeSearchTopic} from './lib/discoverySignals';
import ServiceWayfinder from './components/ServiceWayfinder';
import CategoryActions,{categoryLabels} from './components/CategoryActions';
import SectionHeader from './components/SectionHeader';
import { useState, useEffect, useRef, useMemo, lazy, Suspense } from "react";
import "./App.css";
import "./platform.css";
import './stage3.css';
import './layout-cleanup.css';
import './property-delivery.css';
import './service-planning.css';
import './detail-discovery.css';
import './business-foundation.css';
import './navigation.css';
import './ui-refresh.css';
import './theme-premium.css';
import {showDeveloperNotes} from './lib/devNotes';
import { Brand, Icon, EmptyArt, ListingSkeletons } from "./components/Design";
import { supabase } from "./supabase";
import AuthBoundary from "./components/AuthBoundary";
import { navigate, pageFromPath, pagePaths, publicPath } from "./lib/routes";
import {savedListingIds,savedProducts} from "./lib/saved";
import {filterProducts,rememberViewed,compareSelection} from './lib/discovery';
import {desktopNavigation,moreNavigation,zambiaProvinces} from './config/platform';
import ThemeControl from './components/ThemeControl';
import ProductCard from './components/ProductCard';
import ZambiaLocationFields from './components/ZambiaLocationFields';
import {HomeDestinations,LocalBusinessPreview} from './components/HomeDiscovery';
import HomeHero,{TrustStrip} from './components/HomeHero';
import ProductGallery from './components/ProductGallery';
import { listingPhotos, listingInput, validatePhoto, money } from "./lib/listings";
import { availability } from "./lib/availability";
import { availabilityLabel, sortFeedListings } from "./lib/availability";

const FoodOperations=lazy(()=>import('./components/FoodOperations'));
const DeliveryOperations=lazy(()=>import('./components/DeliveryOperations'));
const ShopOrderCentre=lazy(()=>import('./components/ShopOrderCentre'));
const WorkOperations=lazy(()=>import('./components/WorkOperations'));
const CapacityOperations=lazy(()=>import('./components/CapacityOperations'));
const DigitalLibrary=lazy(()=>import('./components/DigitalLibrary'));
const AdminReviewOperations=lazy(()=>import('./components/AdminReviewOperations'));
const AccountHistory=lazy(()=>import('./components/AccountHistory'));
const MyActivity=lazy(()=>import('./components/MyActivity'));
const Campuses=lazy(()=>import('./components/Campuses'));
const Advertise=lazy(()=>import('./components/Advertise'));
const AccountHub=lazy(()=>import('./components/AccountHub'));
const activityPages=['Orders','Saved','Cart','My Listings','History','Order Centre','Enquiries','Notifications'];
const accountPages=['Profile','Business','Workspace','Safety'];
const navPage=name=>name==='Explore'?'Directory':name;
const sectionPages=['Campuses','Explore','Stays','Logistics','Agriculture','Digital','Property','Delivery','Food','Events','Jobs','Learning','Services','Shops','Storefront','Directory'];
function navCurrent(name,page){return page===name||(name==='Explore'&&sectionPages.includes(page))||(name==='My Activity'&&activityPages.includes(page))||(name==='Account'&&accountPages.includes(page));}
const RevenueOperations=lazy(()=>import('./components/RevenueOperations'));
const SecureOperations=lazy(()=>import('./components/SecureOperations'));
const ProductCart=lazy(()=>import('./components/ProductCart'));
const Messages=lazy(()=>import('./components/Messages'));
const MyListings=lazy(()=>import('./components/MyListings'));
const SellerProfile=lazy(()=>import('./components/SellerProfile'));
const AccountProfile=lazy(()=>import('./components/AccountProfile'));
const CompareProducts=lazy(()=>import('./components/CompareProducts'));
const ServicesDirectory=lazy(()=>import('./components/PlatformPages').then(module=>({default:module.ServicesDirectory})));

const PropertyMarketplace=lazy(()=>import('./components/PropertyMarketplace'));
const DeliveryWorkspace=lazy(()=>import('./components/DeliveryWorkspace'));
const FoodMarketplace=lazy(()=>import('./components/FoodMarketplace'));

const BusinessWorkspace=lazy(()=>import('./components/BusinessWorkspace'));
const BusinessServiceDirectory=lazy(()=>import('./components/BusinessServiceDirectory'));

const SavedSearches=lazy(()=>import('./components/SavedSearches'));
const RecommendationShelf=lazy(()=>import('./components/RecommendationShelf'));
const LocalVerticalMarketplace=lazy(()=>import('./components/LocalVerticalMarketplace'));
const ModuleMarketplace=lazy(()=>import('./components/ModuleMarketplace'));
const Storefronts=lazy(()=>import('./components/Storefronts'));
const InventoryDashboard=lazy(()=>import('./components/InventoryDashboard'));
const StockPanel=lazy(()=>import('./components/InventoryDashboard').then(module=>({default:module.StockPanel})));
const RevenueHub=lazy(()=>import('./components/RevenueHub'));
const NotificationInbox=lazy(()=>import('./components/NotificationInbox'));
const EnquiryInbox=lazy(()=>import('./components/NotificationInbox').then(module=>({default:module.EnquiryInbox})));

const categories = [
  "All Items",
  "Phones",
  "Electronics",
  "Fashion",
  "Shoes",
  "Home & Living",
  "Vehicles",
  "Others",
];

const MAX_PHOTOS = 5;
const scrollBehavior = () => window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth";

const photoButtonStyle = {
  flex: 1,
  padding: "12px 10px",
  border: "2px dashed #bbb",
  borderRadius: 12,
  textAlign: "center",
  cursor: "pointer",
  fontWeight: 600,
};

const linkButtonStyle = {
  background: "none",
  border: "none",
  color: "#2563eb",
  fontWeight: 600,
  cursor: "pointer",
};

function Marketplace({user,profile,onProfileSaved,onLogout,logoutBusy,onLogin=()=>navigate('/signin')}) {
  const [search, setSearch] = useState("");
  const [searchScope,setSearchScope]=useState("current");
  const [category, setCategory] = useState("All Items");
  const [page, setPage] = useState(() => pageFromPath(window.location.pathname));
  const [safetyTarget,setSafetyTarget]=useState(null);
  const ListingsHeading=page==='Saved'?'h1':'h2';
  const visitSignals=useMemo(()=>{void user?.id;return createVisitSignals();},[user?.id]);const [signalRevision,setSignalRevision]=useState(0);
  function recordDiscovery(event){if(visitSignals.record(event))setSignalRevision(value=>value+1);}
  const [cart,setCart]=useState({owner:user?.id??null,lines:[]});const cartLines=cart.owner===(user?.id??null)?cart.lines:[];
  function changeCart(lines){setCart({owner:user?.id??null,lines});}
  function addToCart(product){if(!user){onLogin();return;}if(availability(product,now)!=='Available'){setActionError('Only available listings can be added to this preview.');return;}const id=String(product.id);const prior=cartLines.find(row=>row.id===id);if(prior?.quantity>=20||cartLines.length>=30&&!prior){setActionError('Use at most 30 products and 20 units each.');return;}changeCart(prior?cartLines.map(row=>row.id===id?{...row,quantity:row.quantity+1}:row):[...cartLines,{id,quantity:1}]);setActionError('');}
  function logoutWithCartReset(){changeCart([]);setRecentIds([]);visitSignals.enable(false);return onLogout();}
  const [selectedProduct, setSelectedProduct] = useState(null);
  const linkedProductId=useProductLink();
  const [productLinkError,setProductLinkError]=useState('');
  const [products, setProducts] = useState([]);
  const [likes, setLikes] = useState([]);
  const [likesLoading,setLikesLoading]=useState(!!user);
  const [likesError,setLikesError]=useState('');
  const [savingLike,setSavingLike]=useState(null);
  const likeBusy=useRef(false);
  const [showOther, setShowOther] = useState(false);
  const [photos, setPhotos] = useState([]);
  const [posting, setPosting] = useState(false);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState("");
  const [sort, setSort] = useState("recommended");
  const [feedWindow,setFeedWindow]=useState({key:"",limit:24});
  const [statusFilter, setStatusFilter] = useState("all");
  const [locationFilter, setLocationFilter] = useState("");
  const [postKind, setPostKind] = useState(null);
  const [postStep, setPostStep] = useState(1);
  const [postCampus, setPostCampus] = useState("");
  const [review, setReview] = useState({});
  const postFormRef = useRef(null);
  const [minPrice,setMinPrice]=useState('');
  const [maxPrice,setMaxPrice]=useState('');
  const [conditionFilter,setConditionFilter]=useState('');
  const [recentIds,setRecentIds]=useState([]);
  const [compareIds,setCompareIds]=useState([]);
  const menuRef=useRef(null);
  const [seller, setSeller] = useState(null);
  const [communityEntry,setCommunityEntry]=useState(null);
  const [checkingPhotos, setCheckingPhotos] = useState(false);
  const photoRefs = useRef([]);
  const mounted = useRef(true);
  const productRequest = useRef(0);
  const backendReady = useRef(false);
  useEffect(() => {
    mounted.current = true;
    return () => {mounted.current = false;};
  }, []);
  const [featuresReady, setFeaturesReady] = useState(false);
  useEffect(()=>{if(!linkedProductId)return;let active=true;if(linkedProductId==='invalid'){Promise.resolve().then(()=>{if(active)setProductLinkError('This product link is invalid.');});return()=>{active=false;};}supabase.from(featuresReady?'marketplace_listings':'listings').select('*').eq('id',linkedProductId).maybeSingle().then(({data,error})=>{if(!active)return;if(error||!data||data.deleted_at||listingDomain(data)!=='shopping'){setProductLinkError('This product is unavailable or you do not have access.');setSelectedProduct(null);}else{setProductLinkError('');setSelectedProduct(data);}}).catch(()=>{if(active)setProductLinkError('The product link could not be loaded. Please retry.');});return()=>{active=false;};},[linkedProductId,featuresReady]);
  const [availabilityMode, setAvailabilityMode] = useState("now");
  const [clockOffset, setClockOffset] = useState(0);
  const [now, setNow] = useState(()=>new Date());
  const [initialConversation, setInitialConversation] = useState(null);
  const [initialDraft, setInitialDraft] = useState('');
  const [startingConversation, setStartingConversation] = useState(false);
  const [actionError, setActionError] = useState("");

  async function loadProducts(ready = backendReady.current) {
    const request = ++productRequest.current;
    setLoading(true);
    setLoadError("");
    try {
      const query = supabase.from(ready === true ? "marketplace_listings" : "listings").select("*").order("created_at", {ascending:false});
      const { data, error } = await (ready === true ? query.is("deleted_at", null) : query);
      if (!mounted.current || request !== productRequest.current) return;
      if (error) throw error;
      const visible = shoppingListings(data ?? []);
      setProducts(visible);
      const visibleIds=new Set(visible.map(item=>String(item.id)));
      setRecentIds(ids=>ids.filter(id=>visibleIds.has(id)));
      setCompareIds(ids=>ids.filter(id=>visibleIds.has(id)));
      setSelectedProduct(current => current ? visible.find(item => item.id === current.id) ?? (productIdFromSearch(window.location.search)===String(current.id)?current:null) : null);
    } catch {
      if (mounted.current && request === productRequest.current) setLoadError("We couldn't load listings. Please try again.");
    } finally {
      if (mounted.current && request === productRequest.current) setLoading(false);
    }
  }

  useEffect(() => {
    let active = true;
    async function checkFeatures() {
      try {
        const {data, error} = await supabase.rpc("zammarket_features");
        if (!active || error || data?.version !== 1) return;
        const firstReady = !backendReady.current;
        backendReady.current = true;
        setFeaturesReady(true);
        const serverTime = new Date(data.server_now).getTime();
        if (Number.isFinite(serverTime)) setClockOffset(serverTime - Date.now());
        // Refresh once when the backend becomes ready, not the entire feed every minute.
        if (firstReady) await loadProducts(true);
      } catch { /* Existing browsing remains usable before migrations are approved. */ }
    }
    checkFeatures();
    const timer = setInterval(checkFeatures, 60000);
    return () => {active = false; clearInterval(timer);};
  }, []);

  useEffect(() => {
    const tick = () => setNow(new Date(Date.now() + clockOffset));
    tick();
    const timer = setInterval(tick, 1000);
    window.addEventListener("focus", tick);
    return () => {clearInterval(timer); window.removeEventListener("focus", tick);};
  }, [clockOffset]);


  useEffect(() => { photoRefs.current = photos; }, [photos]);
  useEffect(() => () => photoRefs.current.forEach(p => URL.revokeObjectURL(p.preview)), []);

  useEffect(() => {
    const syncPage = () => {
      setPage(pageFromPath(window.location.pathname));
      setSelectedProduct(null); setSeller(null);
    };
    window.addEventListener("popstate",syncPage);
    return () => window.removeEventListener("popstate",syncPage);
  }, []);

  useEffect(() => {
    // Defer startup so Strict Mode cleanup can cancel its redundant first request.
    const timer=setTimeout(()=>loadProducts(),0);
    return()=>clearTimeout(timer);
  }, []);

  async function loadLikes() {
    if(!user)return;
    try {
      const {data,error}=await supabase.from('likes').select('listing_id, user_id');
      if(error)throw error;
      if(mounted.current){setLikes(data??[]);setLikesError('');}
    } catch {if(mounted.current)setLikesError('Your saved products could not be loaded. Please retry.');}
    finally {if(mounted.current)setLikesLoading(false);}
  }
  useEffect(()=>{
    if(!user)return;
    let active=true;
    supabase.from('likes').select('listing_id, user_id').then(({data,error})=>{
      if(!active)return;
      if(error)throw error;
      setLikes(data??[]);setLikesError('');
    }).catch(()=>{if(active)setLikesError('Your saved products could not be loaded. Please retry.');})
      .finally(()=>{if(active)setLikesLoading(false);});
    return()=>{active=false;};
  },[user]);
  function retryLikes(){setLikesLoading(true);setLikesError('');return loadLikes();}

  function likeCount(listingId) {
    return likes.filter((l) => l.listing_id === listingId).length;
  }

  const ownSavedIds=savedListingIds(likes,user?.id);
  function isLiked(listingId) {return ownSavedIds.has(String(listingId));}

  async function toggleLike(listingId) {
    if(!user){onLogin();return;}
    if(likeBusy.current||likesLoading||likesError)return;
    likeBusy.current=true;setSavingLike(listingId);setActionError('');
    const wasSaved=isLiked(listingId);
    try {
    if (wasSaved) {
      setLikes(
        likes.filter(
          (l) => !(l.listing_id === listingId && l.user_id === user.id)
        )
      );
      const { error } = await supabase
        .from("likes")
        .delete()
        .eq("listing_id", listingId)
        .eq("user_id", user.id);
      if (error) throw error;
    } else {
      setLikes([...likes, { listing_id: listingId, user_id: user.id }]);
      const { error } = await supabase
        .from("likes")
        .insert({ listing_id: listingId, user_id: user.id });
      if (error) throw error;
    }
    } catch {
      if(mounted.current){setActionError('This save could not be confirmed. Please refresh your saved products before retrying.');await loadLikes();}
    } finally {likeBusy.current=false;if(mounted.current)setSavingLike(null);}
  }

  const visibleProducts=page==='Saved'?savedProducts(products,likes,user?.id):products;
  const smart = parseSmartSearch(search);
  const filteredProducts = sortFeedListings(filterProducts(smart?visibleProducts.filter(item=>smartMatches(item,smart)):visibleProducts,{search:smart?'':search,location:locationFilter,condition:conditionFilter,minPrice,maxPrice}).filter((product) => {
    const matchesCategory =
      category === "All Items" || shoppingCategory(product.category) === category;
    return matchesCategory && (statusFilter === "all" || availability(product, now) === statusFilter);
  }), sort, now);
  const feedKey=JSON.stringify([page,search,category,statusFilter,locationFilter,conditionFilter,minPrice,maxPrice,sort]);
  const feedLimit=page==='Home'?8:feedWindow.key===feedKey?feedWindow.limit:24;
  const recentProducts=recentIds.map(id=>products.find(item=>String(item.id)===id)).filter(Boolean);
  const comparisonProducts=compareIds.map(id=>products.find(item=>String(item.id)===id)).filter(Boolean);
  const conditions=[...new Set(products.map(item=>item.condition).filter(Boolean))];
  const priceRangeInvalid=[minPrice,maxPrice].some(value=>value!==''&&(!Number.isFinite(Number(value))||Number(value)<0))||(minPrice!==''&&maxPrice!==''&&Number(minPrice)>Number(maxPrice));
  function clearSectionSearch(){setSearch('');window.dispatchEvent(new CustomEvent('zammarket-section-search',{detail:{page:searchPage('current',page),text:''}}));}
  // After a search, bring the results into view automatically so nobody has to scroll to find them.
  function scrollToSearchResults(){
    const selectors=['#listings:not([hidden]) .product-grid','#listings:not([hidden]) .empty-state','main .module-grid','main .product-grid','main .empty-state'];
    let tries=0;
    const attempt=()=>{
      const target=selectors.map(selector=>document.querySelector(selector)).find(Boolean);
      if(!target){if(++tries<30)requestAnimationFrame(attempt);return;}
      const header=document.querySelector('.topbar');
      const offset=(header?header.offsetHeight:0)+16;
      const top=target.getBoundingClientRect().top+window.scrollY-offset;
      window.scrollTo({top:Math.max(0,top),behavior:scrollBehavior()});
    };
    requestAnimationFrame(()=>requestAnimationFrame(attempt));
  }
  function submitSectionSearch(){const text=search.trim();const smartTarget=searchScope==='current'?parseSmartSearch(text)?.section:null;const section=searchScope==='current'?(sectionFromSearch(text)||smartTarget):null;if(section){goTo(section);setSearch('');window.dispatchEvent(new CustomEvent("zammarket-section-search",{detail:{page:section,text:''}}));return;}const target=searchPage(searchScope,page);const topic=safeSearchTopic(text);if(topic)recordDiscovery({kind:"search",action:"search",id:topic,label:topic,location:locationFilter});goTo(target,{preserveSearch:true});window.dispatchEvent(new CustomEvent("zammarket-section-search",{detail:{page:target,text}}));if(text)scrollToSearchResults();}
  function clearFilters(){setSearch('');setCategory('All Items');setStatusFilter('all');setLocationFilter('');setMinPrice('');setMaxPrice('');setConditionFilter('');}
  function toggleCompare(id){
    if(!compareIds.includes(String(id))&&compareIds.length>=3){setActionError('Compare up to three products. Remove one to add another.');return;}
    setCompareIds(ids=>compareSelection(ids,id));setActionError('');
  }

  async function messageSeller(product) {
    if(!user){onLogin();return;}
    if (!featuresReady) {setActionError("Messaging is awaiting the approved database setup."); return;}
    if (startingConversation) return;
    setStartingConversation(true); setActionError("");
    try {
      const {data, error} = await supabase.rpc("start_conversation", {p_listing_id:String(product.id)});
      if (error) throw error;
      setInitialConversation(data);
      setInitialDraft(product?.title ? `Hi, is the "${product.title}" still available?` : '');
      goTo("Messages");
    } catch {setActionError("Unable to start this conversation. Please refresh and try again.");}
    finally {setStartingConversation(false);}
  }

  function openProduct(product) {
    recordDiscovery({kind:'product',action:'click',id:String(product.id),label:product.title,category:product.category,location:product.location});
    setSelectedProduct(product);
    selectProductLink(product.id);
    setRecentIds(ids=>rememberViewed(ids,product.id));
    window.scrollTo({top:0,behavior:scrollBehavior()});
  }

  const [categoryIntent,setCategoryIntent]=useState({page:null,action:null,nonce:0});const [categoryNotice,setCategoryNotice]=useState({page:null,text:''});
  const [backTo,setBackTo]=useState(null);const returnPages=['Messages','My Listings','Post'];
  // Forget the "go back" target once the person leaves Post / My Listings / Messages, and reset the category action so returning does not reopen a form.
  useEffect(()=>{if(showDeveloperNotes)document.documentElement.setAttribute('data-staging','1');},[]);
  useEffect(()=>{if(page!=='Post'){setPostKind(null);setPostStep(1);setPostCampus('');}},[page]);
  useEffect(()=>{if(!returnPages.includes(page))setBackTo(null);if(categoryIntent.page&&categoryIntent.page!==page)setCategoryIntent({page:null,action:null,nonce:0});},[page]);
  // The prefilled "is this still available?" draft belongs to one freshly started conversation only.
  useEffect(()=>{if(page!=='Messages')setInitialDraft('');},[page]);
  const bridgedCategories=['Explore','Property','Food'];
  function categoryAction(action){
    // Messages: always the one central messaging page.
    if(action==='messages'){setBackTo(page);goTo('Messages');return;}
    // Shop: reuse the existing Post and My Listings pages.
    if(page==='Explore'){setBackTo(page);if(action==='post'){setPostKind('product');setPostCampus('');}goTo(action==='post'?'Post':'My Listings');return;}
    // Actions that change data need an account; browsing never does.
    if(!user){onLogin();return;}
    if(bridgedCategories.includes(page)){setCategoryNotice({page:null,text:''});setCategoryIntent({page,action,nonce:Date.now()});return;}
    const label=categoryLabels[page]||page;
    setCategoryNotice({page,text:action==='post'?`Posting in ${label} opens when its setup is complete. You can browse listings below.`:`Your ${label} listings will appear here when posting opens. You can browse listings below.`});
  }
  function startProductPost(campusName=''){setPostKind('product');setPostCampus(campusName);setPostStep(1);goTo('Post');}
  const navPost=target=>target==='Post'?startProductPost():goTo(target);
  function postNext(){
    const box=postFormRef.current?.querySelector(`[data-step="${postStep}"]`);
    if(box&&![...box.querySelectorAll('input,select,textarea')].every(field=>field.reportValidity()))return;
    if(postStep===2)setReview(Object.fromEntries(new FormData(postFormRef.current).entries()));
    setPostStep(step=>Math.min(3,step+1));
  }
  function goTo(nextPage,{preserveSearch=false}={}) {
    nextPage=sectionDestination(nextPage,Object.keys(pagePaths));
    if(!nextPage){setActionError("This section is not available.");return;}
    if(!preserveSearch)setSearchScope("current");
    if(nextPage!==page&&!preserveSearch)setSearch("");
    if(['Services','Events','Jobs','Learning','Property','Delivery','Food','Agriculture','Digital'].includes(nextPage))recordDiscovery({kind:'service',action:'click',id:nextPage,label:nextPage==='Digital'?'Digital Products':nextPage,location:locationFilter});
    if(!user&&!publicPath(pagePaths[nextPage]??'/home')){onLogin();return;}
    if(nextPage==='Saved')clearFilters();
    if(menuRef.current)menuRef.current.open=false;
    setCommunityEntry(null);
    navigate(pagePaths[nextPage] ?? '/home');
    setPage(nextPage);
    setSeller(null);
    setSelectedProduct(null);
    window.scrollTo({ top: 0, behavior: scrollBehavior() });
  }
  function openInterest(row){if(row.kind==='product'){const product=products.find(item=>String(item.id)===row.id);if(product){openProduct(product);return;}}if(row.kind==='search'){setSearch(row.label);goTo('Explore');return;}goTo(row.kind==='event'?'Events':row.kind==='service'?(['Services','Events','Jobs','Learning','Property','Delivery','Food','Agriculture','Digital'].includes(row.id)?row.id:'Services'):'Explore');}
  function openSeller(nextSeller){if(linkedProductId)selectProductLink(null);setSeller(nextSeller);setSelectedProduct(null);setPage('Seller');window.scrollTo({top:0,behavior:scrollBehavior()});}
  function openCommunity(item){goTo({event:'Events',job:'Jobs',service:'Services',learning:'Learning'}[item.kind]);setCommunityEntry(item);}

  async function addPhotos(fileList) {
    if (checkingPhotos || posting) return;
    setCheckingPhotos(true);
    try {
      const files = Array.from(fileList ?? []);
      const available = MAX_PHOTOS - photos.length;
      if (files.length > available) alert(`You can add ${available} more photo(s).`);
      const chosen = files.slice(0,available);
      await Promise.all(chosen.map(validatePhoto));
      setPhotos(current => [...current, ...chosen.map(file => ({file,preview:URL.createObjectURL(file)}))]);
    } catch (error) {alert(error.message);}
    finally {setCheckingPhotos(false);}
  }

  async function handlePost(event) {
    event.preventDefault();
    if (!user || posting || checkingPhotos) return;
    setPosting(true);
    const values = Object.fromEntries(new FormData(event.target));

    const image_urls = [];
    const uploadedPaths = [];
    let insertStarted = false;
    try {
    const {data: authData, error: authError} = await supabase.auth.getUser();
    if (authError || !authData.user || authData.user.id !== user.id) {
      throw new Error("Your session changed. Please sign in again before posting.");
    }
    const postingUser = authData.user;
    const input = listingInput(values);
    for (const { file } of photos) {
      if (!mounted.current) throw new Error("Your session changed. Please sign in again before posting.");
      const ext = await validatePhoto(file);
      const path = `${postingUser.id}/${crypto.randomUUID()}.${ext}`;
      const { error: upErr } = await supabase.storage
        .from("listing-images")
        .upload(path, file);
      if (upErr) {
        throw new Error("Photo upload failed: " + upErr.message);
      }
      uploadedPaths.push(path);
      image_urls.push(
        supabase.storage.from("listing-images").getPublicUrl(path).data.publicUrl
      );
    }

    if (!mounted.current) throw new Error("Your session changed. Please sign in again before posting.");
    insertStarted = true;
    const { error } = await supabase.from("listings").insert({
      user_id: postingUser.id,
      seller_id: postingUser.id,
      seller_name: profile.shop_name,
      title: input.title, price: input.price, category: input.category,
      location: input.location, description: input.description+(campusNames.includes(values.campus)?`\n\nCampus: ${values.campus}`:''),
      image_urls,
      ...(featuresReady ? {available_from: input.available_from,
        image_paths: [...uploadedPaths]} : {}),
    });
    if (error) throw error;
    if (!mounted.current) return;
    // Once committed, uploaded images belong to the listing.
    uploadedPaths.length = 0;
    photos.forEach(photo => URL.revokeObjectURL(photo.preview));
    setPhotos([]);
    setShowOther(false);
    await loadProducts();
    goTo("Home");
    } catch (error) {
      if (!mounted.current) return;
      // Preserve uploaded files. Their removal requires a separately reviewed cleanup.
      if (uploadedPaths.length) console.warn("Uploaded photos retained after unsuccessful or unconfirmed posting.");
      alert(insertStarted && !/^[0-9A-Z]{5}$/.test(error.code ?? "")
        ? "Posting could not be confirmed. Refresh listings before retrying to avoid a duplicate. Uploaded photos have been preserved."
        : "Could not post: " + error.message);
    } finally {
      setPosting(false);
    }
  }

  return (
    <div className={`app-shell ${compareIds.length?'has-comparison':''}`}>
      <a className="skip-link" href="#main-content">Skip to content</a>
      <header className="topbar">
        <details className="nav-menu" ref={menuRef} onKeyDown={event=>{if(event.key==='Escape'){event.currentTarget.open=false;event.currentTarget.querySelector('summary')?.focus();}}}><summary aria-label="Open ZamNexus navigation"><Icon name="menu"/></summary><div className="nav-menu-panel"><span className="eyebrow">YOUR ZAMNEXUS</span><nav aria-label="All services and pages">{[...desktopNavigation,...moreNavigation].map(([name,icon])=><button key={name} className={[desktopNavigation.some(row=>row[0]===name)?'dup-desktop':'',desktopNavigation.some(row=>row[0]===name)?'dup-bottom':''].join(' ').trim()||undefined} onClick={()=>goTo(navPage(name))}><Icon name={icon} size={18}/>{name==='Post'?'Sell':name}</button>)}</nav><ThemeControl/></div></details>
        <button className="brand" onClick={() => goTo("Home")}>
          <Brand />
        </button>

        <div className="header-search">
          <select className="search-section-select" aria-label="Search section" value={searchScope} onChange={event=>setSearchScope(event.target.value)}><option value="current">Here</option><option value="Shops">Businesses</option>{marketplaceSections.map(([label,target])=><option key={target} value={target}>{label}</option>)}</select>
          <input
            onKeyDown={event=>{if(event.key==='Enter'){event.preventDefault();submitSectionSearch();}}} aria-label="Search products, services, jobs"
            placeholder="Search products, services, jobs..."
            value={search}
            onChange={(event) => {
              setSearch(event.target.value);
            }}
          />
          {search && (
            <button className="clear-search" aria-label="Clear search" onClick={clearSectionSearch}>
              <Icon name="close" size={17}/>
            </button>
          )}
          <button className="clear-search search-submit" aria-label="Run section search" onClick={submitSectionSearch}><Icon name="search" size={19}/></button>
        </div>
        <ThemeControl/>

        {page!=="Home"&&<button className="sell-button" onClick={() => goTo("Post")}>
          <Icon name="plus" size={18}/> <span>Sell an item</span>
        </button>}
        <button className="header-signin" disabled={logoutBusy} onClick={user?logoutWithCartReset:onLogin}>
          {user ? logoutBusy ? "Signing out..." : "Log out" : "Sign In"}
        </button>
        <button className="profile-trigger" aria-label={user?'Open profile':'Sign in'} onClick={()=>goTo('Profile')}><Icon name="user"/></button>
        <button className="notification-trigger" aria-label="Open notifications" onClick={()=>goTo('Notifications')}><Icon name="bell"/></button>
      </header>
      <nav className="account-nav" aria-label="Desktop navigation">
        {desktopNavigation.map(([name])=><button key={name} aria-current={navCurrent(name,page)?'page':undefined} onClick={()=>goTo(navPage(name))}>{name==='Post'?'Sell':name}</button>)}
      </nav>

      <main id="main-content">
        
        {backTo&&returnPages.includes(page)&&<button type="button" className="back-link" onClick={()=>goTo(backTo)}>← Back to {categoryLabels[backTo]||backTo}</button>}
        {['Explore','Stays','Logistics','Agriculture','Digital','Property','Delivery','Food','Events','Jobs','Learning','Services'].includes(page)&&<SectionHeader category={page} onAction={categoryAction} onBack={()=>window.history.length>1?window.history.back():goTo('Directory')} notice={categoryNotice.page===page?categoryNotice.text:''}/>}
        <Suspense fallback={<section className="session-screen" role="status"><span className="session-spinner"/><p>Loading your page...</p></section>}>
        {actionError && <p role="alert" className="app-notice">{actionError}</p>}
        {linkedProductId&&productLinkError&&<p role="alert" className="app-notice">{productLinkError} <button onClick={()=>goTo('Home')}>Browse products</button></p>}
        {likesError && <p role="alert" className="app-notice">{likesError} <button className="text-button" onClick={retryLikes}>Retry saved products</button></p>}
        {!user && <p className="guest-browse-note">Welcome, browse local finds. <button className="text-button" onClick={onLogin}>Sign in to save, message or sell</button></p>}

        {selectedProduct ? (
          <section className="detail-page">
            <button className="back-button" onClick={() => goTo(backTo&&returnPages.includes(backTo)?backTo:'Home')}>
              {backTo&&returnPages.includes(backTo)?`← Back to ${backTo}`:'← Back to listings'}
            </button>
            <div className="detail-card">
              <div
                className="detail-art"
                style={{ background: selectedProduct.color }}
              >
                <ProductGallery key={selectedProduct.id} photos={listingPhotos(selectedProduct)} title={selectedProduct.title} category={selectedProduct.category}/>
              </div>
              <div className="detail-info">
                <span className="eyebrow">{selectedProduct.condition}</span>
                <h1>{selectedProduct.title}</h1>
                <button className="text-button" onClick={async()=>{try{await navigator.clipboard.writeText(new URL(productLink(selectedProduct.id),window.location.origin).href);setActionError('Product link copied.');}catch{setActionError('Copy this product link: '+new URL(productLink(selectedProduct.id),window.location.origin).href);}}}>Copy product link</button>
                <h2>{money(selectedProduct.price)}</h2>
                <p className={`availability-badge status-${availability(selectedProduct, now).toLowerCase().replaceAll(" ","-")}`} role="status">{availabilityLabel(selectedProduct, now)}</p>
                {availability(selectedProduct,now) === 'Sold' && <p className="detail-status-note">This item has been sold.</p>}
                {availability(selectedProduct,now) === 'Temporarily Unavailable' && <p className="detail-status-note">This item is temporarily unavailable.</p>}
                <p className="detail-location"><Icon name="pin" size={17}/> {selectedProduct.location}, Zambia</p>
                <p>{selectedProduct.description}</p>
                <Suspense fallback={<p role="status">Loading stock details...</p>}><StockPanel key={selectedProduct.id} listingId={selectedProduct.id}/></Suspense>
                {selectedProduct.user_id && <button className="seller-link" onClick={() => {
                  openSeller({id:selectedProduct.user_id,name:selectedProduct.seller_name});
                  setSelectedProduct(null); setPage("Seller");
                }}>View seller profile</button>}
                <button
                  type="button"
                  onClick={() => toggleLike(selectedProduct.id)}
                  disabled={!!user&&(savingLike!==null||likesLoading||!!likesError)}
                  aria-pressed={user?isLiked(selectedProduct.id):undefined}
                  style={{
                    ...linkButtonStyle,
                    color: isLiked(selectedProduct.id) ? "red" : "inherit",
                    fontSize: 18,
                    marginBottom: 12,
                    padding: 0,
                  }}
                >
                  {isLiked(selectedProduct.id) ? "♥" : "♡"}{" "}
                  {!user?'Sign in to save':savingLike===selectedProduct.id?'Saving...':isLiked(selectedProduct.id)?'Remove from saved':'Save product'}
                  {user&&<small> · {likeCount(selectedProduct.id)} {likeCount(selectedProduct.id)===1?'save':'saves'}</small>}
                </button>
                <br />
                <button className="text-button" onClick={()=>{setSafetyTarget({kind:'listing',reference:String(selectedProduct.id)});goTo('Safety');}}>Prepare a listing report</button><button className="secondary-button" onClick={()=>addToCart(selectedProduct)}>Add to cart preview</button><button className="text-button" onClick={()=>goTo('Cart')}>Open cart ({cartLines.reduce((sum,row)=>sum+row.quantity,0)})</button><button className="secondary-button compare-product" aria-pressed={compareIds.includes(String(selectedProduct.id))} onClick={()=>toggleCompare(selectedProduct.id)}>{compareIds.includes(String(selectedProduct.id))?'Remove from comparison':'Compare product'}</button>
                {user?.id === selectedProduct.user_id ?
                  <button className="primary-button" onClick={() => goTo("My Listings")}>Manage my listings</button> :
                  <button className="primary-button" disabled={startingConversation} onClick={() => messageSeller(selectedProduct)}>
                    {startingConversation ? "Opening..." : "Message Seller"}
                  </button>}
              </div>
            </div>
          </section>
        ) : ['Stays','Logistics'].includes(page)? <BusinessServiceDirectory key={`${page}-${user?.id||'guest'}`} kind={page} user={user} initialSearch={search} onNavigate={goTo}/> : ['Agriculture','Digital'].includes(page)? <LocalVerticalMarketplace key={page} kind={page} user={user} initialSearch={search} onNavigate={goTo}/> : ['Events','Jobs','Services','Learning'].includes(page)? <ModuleMarketplace key={`${page}-${user?.id||'guest'}`} onNavigate={goTo} onActivity={recordDiscovery} kind={{Events:'event',Jobs:'job',Services:'service',Learning:'learning'}[page]} user={user} onLogin={onLogin} onSeller={openSeller} initialEntry={communityEntry} initialSearch={search}/> : page==='Directory'? <ServicesDirectory onNavigate={goTo}/> : page==='Property'? <PropertyMarketplace key={user?.id||'guest-property'} initialSearch={search} user={user} onLogin={onLogin} onSeller={openSeller} onNavigate={goTo} intent={categoryIntent.page==='Property'?categoryIntent:null}/> : page==='Delivery'? <DeliveryWorkspace key={user?.id||'guest-delivery'} user={user} onLogin={onLogin} onNavigate={goTo}/> : page==='Food'? <FoodMarketplace initialSearch={search} onNavigate={goTo} intent={categoryIntent.page==='Food'?categoryIntent:null}/> : page==='Shops'? <Storefronts user={user} onSeller={openSeller} onNavigate={goTo} search={search}/> : page==='Storefront'&&user? <Storefronts user={user} profile={profile} edit onNavigate={goTo}/> : page==='Inventory'&&user? <InventoryDashboard user={user} onNavigate={goTo}/> : page==='Promotions'&&user? <RevenueHub user={user} onNavigate={goTo}/> : page==='Notifications'&&user? <NotificationInbox user={user} onNavigate={goTo}/> : page==='Enquiries'&&user? <EnquiryInbox user={user}/> : page==='Cart'? <ProductCart loading={loading} loadError={loadError} onRefresh={loadProducts} lines={cartLines} products={products} now={now} onChange={changeCart} onNavigate={goTo}/> : page==='Orders'? <PurchasePlanner key={user?.id||'guest'} lines={cartLines} products={products} now={now} onNavigate={goTo}/> : page==='Revenue Operations'&&user? <RevenueOperations key={user.id} user={user} onNavigate={goTo}/> : page==='Secure Operations'&&user? <SecureOperations key={user.id} user={user} onNavigate={goTo}/> : page==='History'&&user? <AccountHistory key={user.id} user={user} onNavigate={goTo}/> : page==='Admin Review'&&user? <AdminReviewOperations key={user.id} user={user} onNavigate={goTo}/> : page==='Digital Library'&&user? <DigitalLibrary key={user.id} user={user} onNavigate={goTo}/> : ['Accommodation Operations','Event Operations'].includes(page)&&user? <CapacityOperations key={page+user.id} kind={page==='Event Operations'?'event':'stay'} user={user} onNavigate={goTo}/> : workPageKinds[page]&&user? <WorkOperations key={page+user.id} kind={workPageKinds[page]} user={user} onNavigate={goTo}/> : page==='Order Centre'&&user? <ShopOrderCentre key={user.id} user={user} products={products} lines={cartLines} onNavigate={goTo}/> : page==='Food Operations'&&user? <FoodOperations key={user.id} user={user} onNavigate={goTo}/> : page==='Delivery Operations'&&user? <DeliveryOperations key={user.id} user={user} onNavigate={goTo}/> : page==='Workspace'&&user? <CustomerWorkspace onNavigate={goTo} recentProducts={recentProducts} onOpen={openProduct}/> : page==='Admin'&&user? <AdminFoundation key={user.id} user={user} onNavigate={goTo}/> : page==='Safety'&&user? <SafetyWorkspace key={user.id+(safetyTarget?.reference||'')} initialTarget={safetyTarget} user={user} onNavigate={goTo}/> : page==='Business'&&user? <BusinessWorkspace key={user.id} user={user} profile={profile} ready={featuresReady} onNavigate={navPost}/> : page==='Compare'? <CompareProducts items={comparisonProducts} onRemove={toggleCompare} onOpen={openProduct} onBrowse={()=>goTo('Explore')} formatMoney={money} now={now}/> : page === "Messages" ? (
          <Messages key={`${user?.id ?? "guest"}-${initialConversation ?? "inbox"}`} user={user} ready={featuresReady}
            initialConversation={initialConversation} initialDraft={initialDraft} onOpenListing={openProduct} onLogin={() => goTo("Profile")} />
        ) : page === "My Listings" && user ? (
          <MyListings onNavigate={navPost} key={user.id} user={user} ready={featuresReady} now={now} onChanged={() => loadProducts()} onView={product=>{setBackTo('My Listings');openProduct(product);}} />
        ) : page === "Seller" && seller ? (
          <SellerProfile onReport={()=>{setSafetyTarget({kind:'user',reference:String(seller.id)});goTo('Safety');}} key={seller.id} seller={seller} ready={featuresReady} now={now} signedIn={!!user} user={user} onCommunity={openCommunity}
            onProduct={openProduct} onMessage={messageSeller} onBack={() => goTo("Home")} />
        ) : page === "Advertise" ? (
          <Advertise onNavigate={goTo} />
        ) : page === "Campuses" ? (
          <Campuses products={products} onOpen={openProduct} money={money} onNavigate={goTo} onPost={startProductPost} />
        ) : page === "My Activity" && user ? (
          <MyActivity onNavigate={goTo} />
        ) : page === "Account" && user ? (
          <AccountHub user={user} profile={profile} onNavigate={goTo} onLogout={logoutWithCartReset} logoutBusy={logoutBusy} />
        ) : page === "Profile" && user ? (
          <AccountProfile key={user.id} user={user} profile={profile} onProfileSaved={onProfileSaved} onNavigate={goTo} onLogout={logoutWithCartReset} logoutBusy={logoutBusy} />
        ) : page === "Post" ? (
          <section className="form-page">
            <button className="back-button" onClick={() => postKind==='product'?setPostKind(null):goTo("Home")}>← Back</button>
            <div className="page-icon"><Icon name="bag" size={25}/></div>
            <span className="eyebrow">SOMETHING GREAT TO SHARE?</span>
            <h1>{postKind==='product'?'Post a product':'What do you want to post?'}</h1>{postKind!=='product'&&<PostChooser onProduct={()=>setPostKind('product')} onNavigate={goTo}/>}
            {postKind==='product'&&(<form ref={postFormRef} onSubmit={event=>{if(postStep<3){event.preventDefault();postNext();return;}handlePost(event);}}>
<p className="post-progress">Step {postStep} of 3</p>
<div className="post-step" data-step="1" hidden={postStep!==1}><div>
                <p style={{ margin: "0 0 8px", fontWeight: 600 }}>
                  Photos ({photos.length}/{MAX_PHOTOS})
                </p>

                {photos.length > 0 && (
                  <div style={{ display: "flex", gap: 10, flexWrap: "wrap", marginBottom: 12 }}>
                    {photos.map((p, i) => (
                      <div key={p.preview} style={{ position: "relative" }}>
                        <img
                          src={p.preview}
                          alt=""
                          style={{ width: 90, height: 90, objectFit: "cover", borderRadius: 12 }}
                        />
                        <button
                          type="button"
                          aria-label="Remove photo"
                          disabled={posting || checkingPhotos}
                          onClick={() => {
                            URL.revokeObjectURL(p.preview);
                            setPhotos(photos.filter((_, idx) => idx !== i));
                          }}
                          style={{
                            position: "absolute",
                            top: -6,
                            right: -6,
                            borderRadius: "50%",
                            width: 24,
                            height: 24,
                            border: "none",
                            background: "#111",
                            color: "#fff",
                            cursor: "pointer",
                          }}
                        >
                          ×
                        </button>
                      </div>
                    ))}
                  </div>
                )}

                {photos.length < MAX_PHOTOS && (
                  <div style={{ display: "flex", gap: 10 }}>
                    <label style={photoButtonStyle}>
                      <Icon name="grid" size={22}/> Select photos
                      <input
                        type="file"
                        disabled={posting || checkingPhotos}
                        accept="image/jpeg,image/png,image/webp"
                        multiple
                        hidden
                        onChange={(e) => {
                          addPhotos(e.target.files);
                          e.target.value = "";
                        }}
                      />
                    </label>
                    <label style={photoButtonStyle}>
                      <Icon name="phone" size={22}/> Take photo
                      <input
                        type="file"
                        disabled={posting || checkingPhotos}
                        accept="image/jpeg,image/png,image/webp"
                        capture="environment"
                        hidden
                        onChange={(e) => {
                          addPhotos(e.target.files);
                          e.target.value = "";
                        }}
                      />
                    </label>
                  </div>
                )}
              </div>

              <label>
                Item title
                <input required maxLength={200} name="title" placeholder="e.g. Smartphone" />
              </label><label>
                Category
                <select
                  required
                  name="category"
                  defaultValue=""
                  onChange={(e) => setShowOther(e.target.value === "Others")}
                >
                  <option value="" disabled>Select category</option>
                  {categories.slice(1).map((item) => (
                    <option key={item}>{item}</option>
                  ))}
                </select>
              </label>
              {showOther && (
                <label>
                  Your category (optional)
                  <input name="customCategory" placeholder="e.g. Books" />
                </label>
              )}<label>
                Price (ZMW)
                <input required name="price" type="number" min="0" step="0.01" placeholder="e.g. 2500" />
              </label></div>
<div className="post-step" data-step="2" hidden={postStep!==2}><label>Campus (optional)<select name="campus" defaultValue={postCampus} key={postCampus}><option value="">Not on a campus</option>{campusNames.map(name=><option key={name} value={name}>{name}</option>)}</select></label><ZambiaLocationFields/><label>
                Description
                <textarea required maxLength={10000} name="description" rows="4" placeholder="Describe your item..." />
              </label>{featuresReady && <>
                <label>Availability<select name="availability" value={availabilityMode} onChange={event => setAvailabilityMode(event.target.value)}>
                  <option value="now">Available Now</option><option value="date">Available From a Selected Date</option>
                </select></label>
                {availabilityMode === "date" && <label>Available from (Zambia date)<input required name="available_from" type="date" /></label>}
                
              </>}</div>
<div className="post-step post-review" data-step="3" hidden={postStep!==3}><h2>Review</h2>
<dl>{[['Title',review.title],['Price',review.price?`ZMW ${review.price}`:''],['Category',review.category==='Others'&&review.customCategory?review.customCategory:review.category],['Campus',review.campus],['Place',Object.entries(review).filter(([key])=>/province|district|town|location/i.test(key)).map(([,value])=>value).filter(Boolean).join(', ')],['Photos',String(photos.length)],['Available',review.availability==='date'?`From ${review.available_from}`:'Now']].filter(([,value])=>value).map(([label,value])=><div key={label}><dt>{label}</dt><dd>{value}</dd></div>)}</dl>
<p className="muted">{String(review.description||'').slice(0,160)}</p></div>
<div className="post-nav">{postStep>1&&<button type="button" className="secondary-button" onClick={()=>setPostStep(step=>step-1)}>Back</button>}
{postStep<3?<button type="button" className="primary-button" onClick={postNext}>Next</button>:<button className="primary-button" type="submit" disabled={posting || checkingPhotos}>
                {posting ? "Posting..." : checkingPhotos ? "Checking photos..." : "Post item"}
              </button>
            }</div>
      </form>)}
          </section>
        ) : (
          <>
            {page === "Home" && !search.trim() && <><HomeHero onNavigate={goTo}/><HomeDestinations onNavigate={goTo}/></>}
            {page==='Categories'&&<MarketplaceCategories onNavigate={goTo}/>}
            {page==='Explore'&&<section className="member-welcome"><span className="eyebrow">SHOP</span><h1>Shop local finds.</h1><p>Browse by category, search or filter. No location tracking is used.</p></section>}
            {page==='Explore'&&<><CoreJourneyGuide onNavigate={goTo} ready={featuresReady}/><SavedSearches key={user?.id||"guest"} owner={user?.id||"guest"} filters={{search,category,location:locationFilter,condition:conditionFilter,minPrice,maxPrice,status:statusFilter,sort}} onApply={query=>{setSearch(query.search);setCategory(query.category);setLocationFilter(query.location);setConditionFilter(query.condition);setMinPrice(query.minPrice);setMaxPrice(query.maxPrice);setStatusFilter(query.status);setSort(query.sort);goTo("Explore");}}/></>}
            {page==='Home'&&recentProducts.length>0&&<section className="recent-section"><div className="section-heading"><div><span className="eyebrow">YOUR CURRENT VISIT</span><h2>Recently viewed.</h2><p className="muted">Kept only in memory for this visit.</p></div><button className="text-button" onClick={()=>setRecentIds([])}>Clear history</button></div><div className="product-grid">{recentProducts.slice(0,4).map(product=><ProductCard key={product.id} product={product} onOpen={openProduct} formatMoney={money}/>)}</div></section>}

            <section className="category-section" hidden={page==='Saved'||(page==='Home'&&!search.trim())}>
              <div className="section-heading">
                <div>
                  <span className="eyebrow">SHOPPING PRODUCT CATEGORIES</span>
                  <h2>A little of everything. <span className="heading-soft">Something for you.</span></h2>
                </div>
              </div>
              <div className="category-list">
                {categories.map((item, index) => (
                  <button
                    key={item}
                    className={`category-chip ${category === item ? "active" : ""}`}
                    aria-pressed={category === item}
                    onClick={() => {
                      setCategory(item);
                      goTo("Explore");
                    }}
                  >
                    <span className="category-icon"><Icon name={["grid","phone","laptop","shirt","shoe","home","car","box"][index]} size={25}/></span>
                    {item}
                  </button>
                ))}
              </div>
            </section>

            <section className={`listings-section ${page==='Home'&&!search.trim()?'home-feed':''}`} id="listings" hidden={page === "Categories"}>
              <div className="section-heading listings-heading">
                <div>
                  <span className="eyebrow">{page==='Saved'?'KEPT FOR ANOTHER LOOK':'FRESH FROM THE NEIGHBOURHOOD'}</span>
                  <ListingsHeading>{page==='Saved'?'Your saved finds.':search.trim() ? `Finds for “${search}”` : category === "All Items" ? page==='Home'?'Featured products':'Discover your next favourite.' : category}</ListingsHeading>
                  <p className="muted">{filteredProducts.length} listings</p>
                </div>
                <select
                  className="sort-select"
                  aria-label="Sort listings"
                  value={sort}
                  onChange={event => setSort(event.target.value)}
                >
                  <option value="recommended">Available first</option>
                  <option value="new">Newest first</option>
                  <option value="low">Price: low to high</option>
                  <option value="high">Price: high to low</option>
                </select>
              </div>

              <FilterPanel><div className="listing-filters">
                <label>Availability<select value={statusFilter} onChange={event => setStatusFilter(event.target.value)}>
                  <option value="all">All statuses</option>{["Available","Coming Soon","Temporarily Unavailable","Sold"].map(value => <option key={value}>{value}</option>)}
                </select></label>
                <label>Location<input list="market-locations" value={locationFilter} onChange={event => setLocationFilter(event.target.value)} placeholder="Choose or enter a town" /></label>
              </div></FilterPanel><datalist id="market-locations">{[...new Set([...zambiaProvinces,...products.map(item=>item.location).filter(Boolean)])].sort().map(location=><option key={location} value={location}/>)}</datalist>
              <details className="advanced-filters"><summary>More filters</summary><div className="advanced-filter-fields"><label>Minimum price (ZMW)<input type="number" min="0" step="0.01" value={minPrice} onChange={event=>setMinPrice(event.target.value)}/></label><label>Maximum price (ZMW)<input type="number" min="0" step="0.01" value={maxPrice} onChange={event=>setMaxPrice(event.target.value)}/></label><label>Condition<select value={conditionFilter} onChange={event=>setConditionFilter(event.target.value)}><option value="">Any condition</option>{conditions.map(value=><option key={value}>{value}</option>)}</select></label><button className="text-button" onClick={clearFilters}>Reset filters</button></div>{priceRangeInvalid&&<p role="alert">Enter prices of zero or more, with minimum no greater than maximum.</p>}</details>
              {locationFilter&&<p className="muted">Showing matching locations for “{locationFilter}”. Results use seller-provided locations, not measured distance.</p>}
              {loading || (page==='Saved'&&likesLoading) ? <ListingSkeletons /> : loadError || (page==='Saved'&&likesError) ? (
                <div className="empty-state" role="alert"><p>{loadError||likesError}</p>
                  <button className="primary-button" onClick={() => {loadProducts();if(page==='Saved')retryLikes();}}>Try again</button>
                </div>
              ) : filteredProducts.length ? (
                <><p className="smart-summary">{smart&&<>Showing: {smart.summary.join(' · ')} <button type="button" className="text-button" onClick={()=>setSearch('')}>Clear</button></>}</p><div className="product-grid">
                  {filteredProducts.slice(0,page==='Home'&&!search.trim()?8:feedLimit).map(product=><ProductCard key={product.id} product={product} onOpen={openProduct} formatMoney={money}/>)}
                </div></>
              ) : (
                <div className="empty-state">
                  <EmptyArt/>
                  <h3>{page==='Saved'?'No saved items yet':search.trim()?'Not available on ZamNexus yet':'No listings yet'}</h3>
                  
                  <button
                    className="primary-button"
                    onClick={() => {
                      clearFilters();
                    }}
                  >
                    Clear filters
                  </button>
                  {page==='Saved'&&<button className="text-button" onClick={()=>goTo('Home')}>Browse products</button>}
                </div>
              )}
            </section>
            {page === "Home" && !search.trim() && <TrustStrip onNavigate={goTo}/>}
            {page!=='Categories'&&filteredProducts.length>feedLimit&&<div className="listing-actions"><button className="secondary-button" onClick={()=>page==='Home'?goTo('Explore',{preserveSearch:true}):setFeedWindow({key:feedKey,limit:feedLimit+24})}>{page==='Home'?'Explore more products':'Show more matching products'}</button></div>}
          </>
        )}
        </Suspense>
      </main>

      <footer className="footer">
        <div className="footer-brand">
          <Brand />
        </div>
        <p>Bringing Zambia's buyers and sellers closer.</p>
        <span>© {now.getFullYear()} ZamNexus</span>
      </footer>
      {compareIds.length>0&&page!=='Compare'&&<aside className="comparison-tray" aria-label="Selected products to compare"><span>{comparisonProducts.length} of 3 selected</span><button className="primary-button" onClick={()=>goTo('Compare')}>Compare products</button><button className="text-button" onClick={()=>setCompareIds([])}>Clear</button></aside>}

      <nav className="bottom-nav" aria-label="Main navigation">
        {[
          ["Home", "home"],
          ["Explore", "search"],
          ["Messages", "message"],
          ["My Activity", "grid"],
          ["Account", "user"],
        ].map(([name, icon]) => (
          <button
            key={name}
            className={`nav-item ${navCurrent(name,page) ? "selected" : ""}`}
            aria-current={navCurrent(name,page) ? "page" : undefined}
            onClick={() => goTo(navPage(name))}
          >
            <span><Icon name={icon} size={22}/></span>
            <small>{name==='Account'&&!user?'Sign In':name}</small>
          </button>
        ))}
      </nav>
    </div>
  );
}
function MarketplaceSession(props){return <WorkspaceProvider key={props.user?.id||'guest'} owner={props.user?.id}><Marketplace {...props}/></WorkspaceProvider>;}
export default function App() {
  return <AuthBoundary component={MarketplaceSession}/>;
}