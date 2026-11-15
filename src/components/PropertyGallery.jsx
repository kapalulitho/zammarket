import ImageGallery from './ImageGallery';
export default function PropertyGallery({item,compact=false}){const slides=[...(item.media_paths??[]).map(path=>({path,bucket:'property-media'})),...(item.local_photos??[]).map(src=>({src}))];return <ImageGallery slides={slides} title={item.title} compact={compact}/>;}
