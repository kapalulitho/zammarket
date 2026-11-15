import {useCommunityImage} from '../lib/useCommunityImage';
export default function CommunityImage({path,alt='',...props}){const url=useCommunityImage(path);return url?<img {...props} src={url} alt={alt}/>:<span className="media-placeholder" role="img" aria-label={alt||'Image unavailable'}>Image unavailable</span>;}
