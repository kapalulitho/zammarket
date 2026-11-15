import {campusFromText,campusOf} from './campuses.js';
import {sectionFromSearch} from './marketplaceCategories.js';
// "Smart search": understands everyday sentences and turns them into plain filters (budget, campus, product words).
// It only ever filters real ZamNexus listings. An AI model can later replace parseSmartSearch without changing anything else.
const STOP=new Set('i im me my we a an the and or of to for in on at is are be can could would please need needs want wants looking look find get buy where who what some any good best great nice cheap cheaper affordable near nearby around close with that this it do you your how which there here under below less than over above more from within about at least up budget k zmw zk kwacha thousand'.split(' '));
const INTENT=new Set(['need','want','looking','find','where','near','nearby','under','below','affordable','cheap','good','best','buy','around','within']);
const SYNONYMS=[
  ['phone','smartphone','iphone','samsung','tecno','infinix','itel','mobile','android'],
  ['laptop','macbook','notebook','computer','dell','lenovo','hp'],
  ['tv','television','smart tv'],['fridge','refrigerator','freezer'],['bed','mattress'],
  ['shoe','shoes','sneaker','sneakers','boots'],['cloth','clothes','clothing','dress','shirt','trouser','jeans'],
  ['book','books','textbook','textbooks'],['charger','cable','adapter','power bank'],['bag','bags','backpack','handbag']
];
const group=word=>SYNONYMS.find(list=>list.includes(word))||[word];
const toNumber=(raw,suffix)=>{const value=Number(String(raw).replace(/,/g,''));if(!Number.isFinite(value))return null;return /^(k|thousand)$/i.test(suffix||'')?value*1000:value;};
export function parseSmartSearch(input){
  const original=String(input??'').trim();
  if(!original)return null;
  let text=' '+original.toLowerCase()+' ';
  let maxPrice=null,minPrice=null;
  const upper=text.match(/\b(?:under|below|less than|cheaper than|up to|upto|max(?:imum)?|within|budget of|budget)\s*(?:zmw|zk|k)?\s*([\d][\d,]*(?:\.\d+)?)\s*(k|thousand)?/);
  if(upper){maxPrice=toNumber(upper[1],upper[2]);text=text.replace(upper[0],' ');}
  const lower=text.match(/\b(?:over|above|more than|at least|from|min(?:imum)?)\s*(?:zmw|zk|k)?\s*([\d][\d,]*(?:\.\d+)?)\s*(k|thousand)?/);
  if(lower){minPrice=toNumber(lower[1],lower[2]);text=text.replace(lower[0],' ');}
  const campus=campusFromText(text);
  if(campus)campus.aliases.forEach(alias=>{text=text.replace(new RegExp(alias,'g'),' ');});
  const words=text.replace(/[^a-z0-9\s]/g,' ').split(/\s+/).filter(Boolean);
  const keywords=words.filter(word=>!STOP.has(word)&&!/^\d+$/.test(word)).map(word=>word.length>3&&word.endsWith('s')&&!word.endsWith('ss')?word.slice(0,-1):word);
  const sentenceLike=original.split(/\s+/).length>=3||words.some(word=>INTENT.has(word));
  if(maxPrice==null&&minPrice==null&&!campus&&!sentenceLike)return null;
  const section=keywords.length===1?sectionFromSearch(keywords[0]):null;
  const summary=[...keywords];
  if(minPrice!=null)summary.push('from ZMW '+minPrice.toLocaleString('en-ZM'));
  if(maxPrice!=null)summary.push('under ZMW '+maxPrice.toLocaleString('en-ZM'));
  if(campus)summary.push(campus.name);
  return {keywords,maxPrice,minPrice,campus:campus?campus.id:null,section:section&&section!=='Explore'?section:null,summary};
}
export function smartMatches(listing,parsed){
  if(!parsed)return true;
  if(parsed.campus&&campusOf(listing)!==parsed.campus)return false;
  const price=listing.price==null||listing.price===''?NaN:Number(listing.price);
  if(parsed.maxPrice!=null&&!(Number.isFinite(price)&&price<=parsed.maxPrice))return false;
  if(parsed.minPrice!=null&&!(Number.isFinite(price)&&price>=parsed.minPrice))return false;
  const text=[listing.title,listing.category,listing.location,listing.description].filter(Boolean).join(' ').toLowerCase();
  return parsed.keywords.every(word=>group(word).some(option=>text.includes(option)));
}
