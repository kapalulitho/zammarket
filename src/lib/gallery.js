export function swipeDirection(start,end,zoom=1){if(!start||zoom!==1)return 0;const dx=end.x-start.x,dy=end.y-start.y;return Math.abs(dx)>=50&&Math.abs(dx)>Math.abs(dy)*1.4?(dx<0?1:-1):0;}
export function galleryIndex(index,delta,length){return Math.max(0,Math.min(length-1,index+delta));}
export function safePhotoUrl(value){return typeof value==='string'&&/^(https?:\/\/|blob:|\/[^/])/i.test(value)?value:null;}
