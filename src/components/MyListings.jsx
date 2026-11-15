import { useEffect, useState } from 'react';
import { supabase } from '../supabase';
import { Icon, EmptyArt } from './Design';
import { availability, availabilityLabel } from '../lib/availability';
import { money, listingPhotos } from '../lib/listings';
import { listingEditInput, ownedListing } from '../lib/listingManagement';

const STATUS_OPTIONS = ['Available', 'Coming Soon', 'Sold', 'Temporarily Unavailable'];

export default function MyListings({ user, ready, now, onChanged, onNavigate, onView }) {
  const [items, setItems] = useState([]);
  const [editing, setEditing] = useState(null);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  const [loading, setLoading] = useState(true);
  const [refresh, setRefresh] = useState(0);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');

  function reload() {
    setLoading(true);
    setRefresh(value => value + 1);
  }

  useEffect(() => {
    if (!ready) return;

    let active = true;

    supabase
      .from('marketplace_listings')
      .select('*')
      .eq('user_id', user.id)
      .is('deleted_at', null)
      .order('created_at', { ascending: false })
      .then(({ data, error: failure }) => {
        if (!active) return;

        if (failure) {
          setError('Unable to load your listings. Please retry.');
        } else {
          setItems(data ?? []);
          setError('');
        }
      })
      .catch(() => {
        if (active) {
          setError('Unable to load your listings. Please retry.');
        }
      })
      .finally(() => {
        if (active) setLoading(false);
      });

    return () => {
      active = false;
    };
  }, [ready, user.id, refresh]);

  async function save(event) {
    event.preventDefault();

    const values = Object.fromEntries(new FormData(event.target));

    try {
      // Status buttons above the form manage availability; saving keeps the
      // listing's current status unless the owner changed it separately.
      await update(editing, listingEditInput({ ...values, status: editing.status }));
    } catch (failure) {
      setError(failure.message);
    }
  }

  async function update(item, values = {}, remove = false) {
    if (busy || !ready) return;

    if (!ownedListing(item, user)) {
      setError('This listing is not owned by your current account. Refresh before retrying.');
      return;
    }

    if (
      remove &&
      !window.confirm(
        'Delete this listing? It will be hidden immediately. Photos will be retained. Message history is retained.'
      )
    ) {
      return;
    }

    setBusy(true);
    setError('');

    try {
      const current = await supabase.auth.getUser();

      if (current.error || current.data.user?.id !== user.id) {
        throw new Error('Your session changed. Sign in again before editing.');
      }

      const { error: failure } = await supabase.rpc('manage_listing', {
        p_id: String(item.id),
        p_revision: item.revision,
        p_title: values.title ?? item.title,
        p_price: Object.hasOwn(values, 'price') ? Number(values.price) : item.price,
        p_category: values.category ?? item.category,
        p_location: values.location ?? item.location,
        p_description: values.description ?? item.description,
        p_status: values.status ?? item.status,
        p_available_from: Object.hasOwn(values, 'available_from')
          ? values.available_from || null
          : item.available_from,
        p_delete: remove,
      });

      if (failure) throw failure;

      setEditing(null);
      reload();
      await onChanged();
    } catch (failure) {
      setError(
        failure.message || 'Unable to update listing. Refresh before retrying.'
      );
    } finally {
      setBusy(false);
    }
  }

  if (!ready) {
    return (
      <section className="form-page centered-page">
        <EmptyArt name="bag" />
        <h1>A little space for your shop.</h1>
        <p>Your seller dashboard is getting ready. Your existing listings are unchanged.</p>
      </section>
    );
  }

  const owned = items.filter(item => ownedListing(item, user));

  const filtered = owned.filter(item =>
    item.title.toLowerCase().includes(search.toLowerCase()) &&
    (statusFilter === 'all' || availability(item, now) === statusFilter)
  );

  const clearFilters = () => {
    setSearch('');
    setStatusFilter('all');
  };

  return (
    <section className="form-page">
      <div className="page-icon">
        <Icon name="bag" size={25} />
      </div>

      <span className="eyebrow">YOUR LITTLE CORNER OF THE MARKET</span>
      <h1>My Listings</h1>

      <p className="muted">
        Edit details, change availability or remove listings. Changes appear in
        Shop, Home and Campus feeds right away.
      </p>

      {error && (
        <p role="alert" className="listing-error">
          {error} <button className="text-button" onClick={reload}>Retry</button>
        </p>
      )}

      <div className="listing-filters">
        <label>
          Find your listing
          <input
            value={search}
            onChange={event => setSearch(event.target.value)}
            placeholder="Listing title"
          />
        </label>

        <label>
          Status
          <select
            value={statusFilter}
            onChange={event => setStatusFilter(event.target.value)}
          >
            <option value="all">All statuses</option>
            {STATUS_OPTIONS.map(value => (
              <option key={value}>{value}</option>
            ))}
          </select>
        </label>

        <button className="text-button" disabled={loading || busy} onClick={reload}>
          Refresh
        </button>
      </div>

      {!loading && owned.length > 0 && (
        <p className="muted" role="status">
          {search || statusFilter !== 'all'
            ? `${filtered.length} of ${owned.length} listings match.`
            : `${owned.length} listing${owned.length === 1 ? '' : 's'}.`}
        </p>
      )}

      {onNavigate && (
        <button
          className="primary-button"
          disabled={busy}
          onClick={() => onNavigate('Post')}
        >
          Post another item
        </button>
      )}

      {loading ? (
        <p role="status">Loading your listings...</p>
      ) : !owned.length ? (
        <div className="empty-state">
          <EmptyArt name="bag" />
          <h3>No listings yet</h3>
          <p>Post your first item with photos, a price and your location. It appears in the marketplace as soon as it is available.</p>
          {onNavigate && (
            <button className="primary-button" onClick={() => onNavigate('Post')}>
              Post your first item
            </button>
          )}
          <button className="text-button" disabled={busy} onClick={reload}>
            Refresh
          </button>
        </div>
      ) : !filtered.length ? (
        <div className="empty-state">
          <h3>No listings match</h3>
          <p>Try a different title or status filter.</p>
          <button className="secondary-button" onClick={clearFilters}>
            Clear filters
          </button>
        </div>
      ) : null}

      {filtered.map(item => {
        const photo = listingPhotos(item)[0];
        const status = availability(item, now);
        const locked = busy || !!item.cleanup_token;

        return (
          <article className="managed-listing my-listing" key={item.id}>
            <div className="my-listing-photo" aria-hidden="true">
              {photo ? (
                <img src={photo} alt="" loading="lazy" decoding="async" />
              ) : (
                <Icon name="bag" size={26} />
              )}
            </div>

            <div className="my-listing-body">
              <header className="my-listing-header">
                <h2>{item.title}</h2>
                <span
                  className={`availability-badge status-${status
                    .toLowerCase()
                    .replaceAll(' ', '-')}`}
                  role="status"
                >
                  {status}
                </span>
              </header>

              <p className="my-listing-price">{money(item.price)}</p>

              <p className="my-listing-meta">
                <span>{item.category || 'Uncategorised'}</span>
                <span>
                  <Icon name="pin" size={13} /> {item.location || 'Location not set'}
                </span>
                {status === 'Coming Soon' && <span>{availabilityLabel(item, now)}</span>}
              </p>

              {item.photos_deleted_at && (
                <p className="muted">Photos have been permanently removed.</p>
              )}

              {item.cleanup_token && (
                <p className="muted">
                  Photo cleanup is in progress. Editing will be available when it finishes.
                </p>
              )}

              {item.status === 'sold' &&
                item.image_urls?.length > 0 &&
                !item.image_paths?.length && (
                  <p className="muted">
                    These older photos need a verified Storage mapping before
                    automatic cleanup can remove them.
                  </p>
                )}

              <div className="listing-actions">
                {onView && (
                  <button
                    className="secondary-button"
                    disabled={busy}
                    onClick={() => onView(item)}
                  >
                    View
                  </button>
                )}

                <button
                  disabled={locked}
                  onClick={() =>
                    setEditing(current => (current?.id === item.id ? null : item))
                  }
                >
                  {editing?.id === item.id ? 'Close editor' : 'Edit'}
                </button>

                {item.status !== 'active' && (
                  <button
                    disabled={locked}
                    onClick={() => update(item, { status: 'active' })}
                  >
                    Restore availability
                  </button>
                )}

                {item.status !== 'sold' && (
                  <button disabled={locked} onClick={() => update(item, { status: 'sold' })}>
                    Mark as Sold
                  </button>
                )}

                {item.status !== 'temporarily_unavailable' && (
                  <button
                    disabled={locked}
                    onClick={() => update(item, { status: 'temporarily_unavailable' })}
                  >
                    Pause
                  </button>
                )}

                <button disabled={locked} onClick={() => update(item, {}, true)}>
                  Delete
                </button>
              </div>

              {editing?.id === item.id && (
                <form
                  key={`${item.id}-${item.revision}`}
                  onSubmit={save}
                >
                  <label>
                    Title
                    <input
                      required
                      maxLength={200}
                      name="title"
                      defaultValue={item.title}
                    />
                  </label>

                  <label>
                    Price (ZMW)
                    <input
                      required
                      name="price"
                      type="number"
                      min="0"
                      step="0.01"
                      defaultValue={item.price}
                    />
                  </label>

                  <label>
                    Category
                    <input
                      required
                      maxLength={100}
                      name="category"
                      defaultValue={item.category}
                    />
                  </label>

                  <label>
                    Location
                    <input
                      required
                      maxLength={200}
                      name="location"
                      defaultValue={item.location}
                    />
                  </label>

                  <label>
                    Description
                    <textarea
                      required
                      maxLength={10000}
                      name="description"
                      defaultValue={item.description}
                    />
                  </label>

                  <label>
                    Availability
                    <select
                      name="availability"
                      defaultValue={item.available_from ? 'date' : 'now'}
                      onChange={event =>
                        setEditing({
                          ...editing,
                          dateSelected: event.target.value === 'date',
                        })
                      }
                    >
                      <option value="now">Available Now</option>
                      <option value="date">Available From a Selected Date</option>
                    </select>
                  </label>

                  {(editing.dateSelected ?? !!item.available_from) && (
                    <label>
                      Available from (Zambia date)
                      <input
                        required
                        type="date"
                        name="available_from"
                        defaultValue={item.available_from ?? ''}
                      />
                    </label>
                  )}

                  <p className="muted">
                    Details are saved with the listing's current status. Change
                    availability with the status buttons above.
                  </p>

                  <div className="listing-actions">
                    <button className="primary-button" disabled={busy}>
                      {busy ? 'Saving...' : 'Save changes'}
                    </button>

                    <button
                      type="button"
                      disabled={busy}
                      onClick={() => setEditing(null)}
                    >
                      Cancel
                    </button>
                  </div>
                </form>
              )}
            </div>
          </article>
        );
      })}
    </section>
  );
}
