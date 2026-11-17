import { shoppingListings } from '../lib/marketplaceCategories';
import CommunityImage from './CommunityImage';
import { useEffect, useState } from 'react';
import { supabase } from '../supabase';
import { Icon } from './Design';
import { sortFeedListings } from '../lib/availability';
import { filterProducts } from '../lib/discovery';
import ProductCard from './ProductCard';
import SellerReviews from './SellerReviews';

export default function SellerProfile({
  seller,
  ready,
  now,
  onProduct,
  onMessage,
  onBack,
  signedIn = true,
  user,
  onCommunity,
  onReport
}) {
  const [shop, setShop] = useState(null);
  const [community, setCommunity] = useState([]);
  const [publicProfile, setPublicProfile] = useState(null);
  const [items, setItems] = useState([]);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);
  const [refresh, setRefresh] = useState(0);
  const [search, setSearch] = useState('');
  const [category, setCategory] = useState('All Items');
  const [sort, setSort] = useState('recommended');
  const [limit, setLimit] = useState(12);
  const [soldLimit, setSoldLimit] = useState(8);

  const currentTime = now instanceof Date ? now.getTime() : Date.now();

  const allItems = shoppingListings(items);

  // Sold listings are kept separately from products currently for sale.
  const soldItems = allItems
    .filter(item => item.status === 'sold' && item.sold_at)
    .sort((a, b) => Date.parse(b.sold_at) - Date.parse(a.sold_at));

  // Sold products never appear in the available-product catalogue.
  const availableItems = allItems.filter(item => item.status !== 'sold');

  const catalogue = sortFeedListings(
    filterProducts(availableItems, { search, category }),
    sort,
    now
  );

  const filteredSoldItems = filterProducts(soldItems, {
    search,
    category
  });

  const money = value =>
    value == null
      ? 'Price on enquiry'
      : new Intl.NumberFormat('en-ZM', {
          style: 'currency',
          currency: 'ZMW',
          currencyDisplay: 'code',
          maximumFractionDigits: 2
        }).format(Number(value));

  function soldDate(value) {
    if (!value) return 'Sale date unavailable';

    const timestamp = Date.parse(value);
    if (!Number.isFinite(timestamp)) return 'Sale date unavailable';

    return new Intl.DateTimeFormat('en-ZM', {
      timeZone: 'Africa/Lusaka',
      day: 'numeric',
      month: 'long',
      year: 'numeric'
    }).format(new Date(timestamp));
  }

  function isArchived(item) {
    const soldTime = Date.parse(item.sold_at || '');
    return Number.isFinite(soldTime) &&
      currentTime >= soldTime + 7 * 24 * 60 * 60 * 1000;
  }

  useEffect(() => {
    let active = true;

    setLoading(true);
    setError('');

    supabase
      .from('seller_shops')
      .select('*')
      .eq('owner_id', seller.id)
      .eq('status', 'published')
      .maybeSingle()
      .then(({ data, error: failure }) => {
        if (active && !failure) setShop(data);
      })
      .catch(() => {});

    supabase
      .from('community_entries')
      .select('*')
      .eq('owner_id', seller.id)
      .eq('status', 'published')
      .order('created_at', { ascending: false })
      .limit(12)
      .then(({ data, error: failure }) => {
        if (active && !failure) setCommunity(data ?? []);
      })
      .catch(() => {});

    if (signedIn) {
      supabase
        .rpc('public_seller_profile', { p_user_id: seller.id })
        .then(({ data, error: failure }) => {
          if (active && !failure) setPublicProfile(data);
        })
        .catch(() => {});
    }

    const query = supabase
      .from(ready ? 'marketplace_listings' : 'listings')
      .select('*')
      .eq('user_id', seller.id);

    (ready ? query.is('deleted_at', null) : query)
      .then(({ data, error: failure }) => {
        if (!active) return;

        if (failure) {
          setError('Unable to load this seller. Please retry.');
        } else {
          setItems(shoppingListings(data ?? []));
          setError('');
        }
      })
      .catch(() => {
        if (active) {
          setError('Unable to load this seller. Please retry.');
        }
      })
      .finally(() => {
        if (active) setLoading(false);
      });

    return () => {
      active = false;
    };
  }, [seller.id, ready, refresh, signedIn]);

  return (
    <section className="form-page">
      <button className="back-button" onClick={onBack}>
        ← Back to listings
      </button>

      <div className="page-icon">
        <Icon name="user" size={25} />
      </div>

      <span className="eyebrow">MEET YOUR LOCAL SELLER</span>

      {publicProfile?.avatar_path && (
        <img
          className="profile-avatar"
          src={supabase.storage
            .from('avatars')
            .getPublicUrl(publicProfile.avatar_path).data.publicUrl}
          alt="Seller avatar"
        />
      )}

      {shop?.media_paths?.[0] && (
        <CommunityImage
          className="storefront-banner"
          path={shop.media_paths[0]}
          alt={`${shop.name} storefront`}
        />
      )}

      <h1>
        {shop?.name ||
          publicProfile?.shop_name ||
          seller.name ||
          'Local seller'}
      </h1>

      {shop && (
        <section className="shop-about">
          <p className="preserve-lines">{shop.description}</p>
          <p>{shop.location}</p>

          {shop.hours && (
            <p className="preserve-lines">
              <strong>Business hours</strong>
              <br />
              {shop.hours}
            </p>
          )}

          {shop.policies && (
            <p className="preserve-lines">
              <strong>Shop policies</strong>
              <br />
              {shop.policies}
            </p>
          )}
        </section>
      )}

      {publicProfile && (
        <div className="public-contacts">
          <p>@{publicProfile.username}</p>

          {publicProfile.whatsapp && (
            <p>
              <a
                href={`https://wa.me/${publicProfile.whatsapp.replace('+', '')}`}
                target="_blank"
                rel="noopener noreferrer"
              >
                WhatsApp seller
              </a>
            </p>
          )}

          {publicProfile.location && <p>{publicProfile.location}</p>}
        </div>
      )}

      {error && (
        <p role="alert">
          {error}{' '}
          <button onClick={() => setRefresh(value => value + 1)}>
            Retry
          </button>
        </p>
      )}

      <div className="listing-filters">
        <label>
          Search this seller
          <input
            value={search}
            onChange={event => {
              setSearch(event.target.value);
              setLimit(12);
              setSoldLimit(8);
            }}
          />
        </label>

        <label>
          Category
          <select
            value={category}
            onChange={event => {
              setCategory(event.target.value);
              setLimit(12);
              setSoldLimit(8);
            }}
          >
            <option>All Items</option>
            {[...new Set(allItems.map(row => row.category).filter(Boolean))]
              .sort()
              .map(value => (
                <option key={value}>{value}</option>
              ))}
          </select>
        </label>

        <label>
          Sort available products
          <select value={sort} onChange={event => setSort(event.target.value)}>
            <option value="recommended">Recommended</option>
            <option value="low">Lowest price</option>
            <option value="high">Highest price</option>
            <option value="new">Newest</option>
          </select>
        </label>
      </div>

      <section className="seller-available-products">
        <h2>Available Products</h2>

        {loading ? (          <p role="status">Loading seller listings...</p>
        ) : !error && catalogue.length === 0 ? (
          <p>No available products currently.</p>
        ) : (
          <>
            <p>{catalogue.length} available products</p>

            <div className="product-grid">
              {catalogue.slice(0, limit).map(item => (
                <div className="seller-product-cell" key={item.id}>
                  <ProductCard
                    product={item}
                    onOpen={onProduct}
                    formatMoney={money}
                  />
                  {onMessage && (
                    <button
                      className="text-button"
                      onClick={() => onMessage(item)}
                    >
                      Ask about this item
                    </button>
                  )}
                </div>
              ))}
            </div>

            {catalogue.length > limit && (
              <button
                className="secondary-button"
                onClick={() => setLimit(value => value + 12)}
              >
                Show more products
              </button>
            )}
          </>
        )}
      </section>

      <section className="seller-sold-history">
        <span className="eyebrow">SELLER'S SALES RECORD</span>
        <h2>Previously Sold</h2>

        <p className="muted">
          These products have already been sold. They remain in the seller's
          public history and are not available for purchase.
        </p>

        {loading ? (
          <p role="status">Loading sold history...</p>
        ) : filteredSoldItems.length === 0 ? (
          <p>No previous sales to display yet.</p>
        ) : (
          <>
            <p>{filteredSoldItems.length} previously sold products</p>

            <div className="product-grid">
              {filteredSoldItems.slice(0, soldLimit).map(item => (
                <article className="sold-history-item" key={item.id}>
                  <span className="availability-badge status-sold">
                    SOLD
                  </span>

                  <ProductCard
                    product={item}
                    onOpen={onProduct}
                    formatMoney={money}
                  />

                  <div className="sold-history-meta">
                    <p>
                      <strong>Sold:</strong> {soldDate(item.sold_at)}
                    </p>

                    <p>
                      {isArchived(item)
                        ? 'Archived from the normal marketplace after seven days.'
                        : 'Recently sold.'}
                    </p>
                  </div>
                </article>
              ))}
            </div>

            {filteredSoldItems.length > soldLimit && (
              <button
                className="secondary-button"
                onClick={() => setSoldLimit(value => value + 8)}
              >
                Show more sold items
              </button>
            )}
          </>
        )}
      </section>

      {community.length > 0 && onCommunity && (
        <section className="provider-portfolio">
          <h2>Services & community listings</h2>

          {community.map(item => (
            <article className="managed-listing" key={item.id}>
              <span className="eyebrow">{item.kind}</span>

              <h3>
                <button
                  className="listing-title"
                  onClick={() => onCommunity(item)}
                >
                  {item.title}
                </button>
              </h3>

              <p>
                {item.category} · {item.location}
              </p>

              {item.kind === 'service' && item.extra && (
                <p className="preserve-lines">{item.extra}</p>
              )}
            </article>
          ))}
        </section>
      )}

      {onReport && (
        <button className="text-button" onClick={onReport}>
          Prepare a user report
        </button>
      )}

      <SellerReviews sellerId={seller.id} user={user} />
    </section>
  );
}
