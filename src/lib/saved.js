export function savedListingIds(likes, userId) {
  if (!userId) return new Set();
  return new Set((likes ?? []).filter(like=>like.user_id===userId && like.listing_id!=null).map(like=>String(like.listing_id)));
}

export function savedProducts(products, likes, userId) {
  const ids=savedListingIds(likes,userId);
  return (products ?? []).filter(product=>!product.deleted_at && ids.has(String(product.id)));
}
