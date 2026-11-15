import ImageGallery from './ImageGallery';
import {ProductPlaceholder} from './Design';
export default function ProductGallery({photos,title,category}){
 if(!photos.length)return <ProductPlaceholder category={category}/>;
 return <ImageGallery slides={photos.map(src=>({src}))} title={title}/>;
}
