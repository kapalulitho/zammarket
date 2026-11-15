export function money(price) {
  return new Intl.NumberFormat('en-ZM', {
    style: 'currency',
    currency: 'ZMW',
    currencyDisplay: 'code',
    minimumFractionDigits: 0,
    maximumFractionDigits: 2,
  }).format(price);
}

export function listingPhotos(listing) {
  return [...new Set([...(Array.isArray(listing.image_urls) ? listing.image_urls : []), listing.image_url]
    .filter(url => typeof url === 'string' && /^https?:\/\//i.test(url)))];
}

export async function validatePhoto(file) {
  const extensions = {'image/jpeg':'jpg','image/png':'png','image/webp':'webp'};
  if (!extensions[file.type] || file.size > 5 * 1024 * 1024 || file.size === 0) {
    throw new Error('Choose JPG, PNG, or WebP images up to 5 MB each.');
  }
  const bytes = new Uint8Array(await file.slice(0, 12).arrayBuffer());
  const jpeg = bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255;
  const png = [137,80,78,71,13,10,26,10].every((byte,index) => bytes[index] === byte);
  const webp = String.fromCharCode(...bytes.slice(0,4)) === 'RIFF'
    && String.fromCharCode(...bytes.slice(8,12)) === 'WEBP';
  if (!(file.type === 'image/jpeg' ? jpeg : file.type === 'image/png' ? png : webp)) {
    throw new Error('One of the selected files is not a valid JPG, PNG, or WebP image.');
  }
  return extensions[file.type];
}

export function listingInput(values) {
  const fields = {title:200,location:200,description:10000};
  const result = {};
  for (const [field,max] of Object.entries(fields)) {
    result[field] = String(values[field] ?? '').trim();
    if (!result[field] || result[field].length > max) throw new Error(`Please enter a valid ${field}.`);
  }
  result.category = String(values.category === 'Others' && values.customCategory?.trim()
    ? values.customCategory : values.category ?? '').trim();
  if (!result.category || result.category.length > 100) throw new Error('Please enter a valid category.');
  result.price = Number(values.price);
  if (!String(values.price ?? '').trim() || !Number.isFinite(result.price) || result.price < 0) {
    throw new Error('Please enter a valid price.');
  }
  if (values.availability === 'date') {
    const date = String(values.available_from ?? '');
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || !Number.isFinite(Date.parse(`${date}T00:00:00Z`))
      || new Date(`${date}T00:00:00Z`).toISOString().slice(0,10) !== date) {
      throw new Error('Please select a valid availability date.');
    }
    result.available_from = date;
  } else result.available_from = null;
  return result;
}
