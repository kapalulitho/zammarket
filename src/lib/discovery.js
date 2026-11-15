export function filterProducts(products,{search='',category='All Items',location='',condition='',minPrice='',maxPrice=''}={}){
  if([minPrice,maxPrice].some(value=>value!==''&&(!Number.isFinite(Number(value))||Number(value)<0))||(minPrice!==''&&maxPrice!==''&&Number(minPrice)>Number(maxPrice)))return [];
  const terms=search.trim().toLocaleLowerCase().split(/\s+/).filter(Boolean);
  return products.filter(item=>{
    const text=[item.title,item.category,item.location,item.description].filter(Boolean).join(' ').toLocaleLowerCase();
    const price=item.price==null||item.price===''?NaN:Number(item.price);
    return terms.every(term=>text.includes(term))
      && (category==='All Items'||item.category===category)
      && String(item.location??'').toLocaleLowerCase().includes(location.trim().toLocaleLowerCase())
      && (!condition||item.condition===condition)
      && (minPrice===''||(Number.isFinite(price)&&price>=Number(minPrice)))
      && (maxPrice===''||(Number.isFinite(price)&&price<=Number(maxPrice)));
  });
}
export function rememberViewed(ids,id,max=12){return [...new Set([String(id),...ids.map(String)])].slice(0,max);}
export function compareSelection(ids,id,max=3){const value=String(id);return ids.includes(value)?ids.filter(item=>item!==value):ids.length<max?[...ids,value]:ids;}
