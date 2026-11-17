import BusinessImageGallery from './BusinessImageGallery';
import { useEffect, useState } from 'react';
import { supabase, backendMode } from '../supabase';
import { useCommunityImage } from '../lib/useCommunityImage';
import { formatMinor } from '../lib/servicePlanning';
import { Icon } from './Design';

export default function BusinessDiscovery({ search = '', onNavigate }) {
  const [data, setData] = useState(null);
  const [error, setError] = useState('');
  const [location, setLocation] = useState('');
  const [kind, setKind] = useState('all');
  const [selected, setSelected] = useState(null);
  const [revision, setRevision] = useState(0);

  useEffect(() => {
    if (backendMode !== 'staging') return;

    let active = true;

    Promise.all([
      supabase
        .from('public_business_profiles')
        .select(
          'id,owner_id,kind,name,description,logo_path,location,phone,whatsapp,public_email'
        )
        .limit(60),

      supabase
        .from('public_business_services')
        .select(
          'id,organisation_id,kind,name,category,location,description,features,service_areas,provider_name,media_paths'
        )
        .order('created_at', { ascending: false })
        .limit(60),
    ])
      .then(([businesses, services]) => {
        if (!active) return;

        if (businesses.error || services.error) {
          setError('Business discovery is unavailable.');
          return;
        }

        setData({
          businesses: businesses.data || [],
          services: services.data || [],
        });
        setError('');
      })
      .catch(() => {
        if (active) setError('Discovery could not be loaded.');
      });

    return () => {
      active = false;
    };
  }, [revision]);

  if (backendMode !== 'staging') return null;

  const rows = data
    ? [
        ...data.businesses.map((row) => ({
          ...row,
          entry_kind: 'business',
        })),
        ...data.services.map((row) => ({
          ...row,
          entry_kind: row.kind,
        })),
      ]
    : [];

  const terms = search
    .toLowerCase()
    .trim()
    .split(/\s+/)
    .filter(Boolean);

  const filtered = rows.filter(
    (row) =>
      (kind === 'all' || row.entry_kind === kind) &&
      String(row.location || '')
        .toLowerCase()
        .includes(location.toLowerCase().trim()) &&
      terms.every((term) =>
        [
          row.name,
          row.description,
          row.category,
          row.provider_name,
          ...(row.service_areas || []),
        ]
          .join(' ')
          .toLowerCase()
          .includes(term)
      )
  );

  return (
    <section className="explore-services business-discovery">
      <div className="section-heading">
        <h2>Discover businesses</h2>

        <button
          className="text-button"
          onClick={() => setRevision((value) => value + 1)}
          aria-label="Refresh businesses"
        >
          <Icon name="refresh-cw" size={17} />
        </button>
      </div>

      <div className="listing-filters">
        <label>
          Location
          <input
            value={location}
            onChange={(event) => setLocation(event.target.value)}
            placeholder="Town or area"
          />
        </label>

        <label>
          Type
          <select
            value={kind}
            onChange={(event) => setKind(event.target.value)}
          >
            <option value="all">All</option>
            <option value="business">Businesses</option>
            <option value="stay">Accommodation</option>
            <option value="logistics">Logistics</option>
          </select>
        </label>
      </div>

      {error ? (
        <p role="alert">{error}</p>
      ) : !data ? (
        <p role="status">Loading...</p>
      ) : selected ? (
        <PublicDetails
          key={selected.id}
          item={selected}
          business={
            data.businesses.find(
              (row) => row.id === selected.organisation_id
            ) || selected
          }
          onBack={() => setSelected(null)}
          onNavigate={onNavigate}
        />
      ) : filtered.length ? (
        <div className="module-grid">
          {filtered.map((row) => (
            <button
              className="module-card"
              key={row.entry_kind + row.id}
              onClick={() => setSelected(row)}
            >
              <Icon
                name={
                  row.entry_kind === 'stay'
                    ? 'home'
                    : row.entry_kind === 'logistics'
                      ? 'car'
                      : 'store'
                }
                size={25}
              />

              <h3>{row.name}</h3>
              <p>{row.location || 'Location not shared'}</p>
            </button>
          ))}
        </div>
      ) : (
        <div className="empty-state">
          <Icon name="store" size={32} />
          <h3>No results found</h3>
          <button
            className="text-button"
            onClick={() => onNavigate('Business')}
          >
            Business workspace
          </button>
        </div>
      )}
    </section>
  );
}

function PublicDetails({ item, business, onBack, onNavigate }) {
  const [rooms, setRooms] = useState(null);
  const [error, setError] = useState('');

  const logo = useCommunityImage(
    business.logo_path,
    'business-media'
  );

  useEffect(() => {
    if (item.entry_kind !== 'stay') return;

    let active = true;

    supabase
      .from('public_stay_rooms')
      .select('id,name,guest_capacity,nightly_minor,currency')
      .eq('entry_id', item.id)
      .then(({ data, error: failure }) => {
        if (!active) return;

        if (failure) {
          setError('Room information is unavailable.');
        } else {
          setRooms(data || []);
        }
      })
      .catch(() => {
        if (active) setError('Room information is unavailable.');
      });

    return () => {
      active = false;
    };
  }, [item.id, item.entry_kind]);

  return (
    <article className="managed-listing">
      <button className="back-button" onClick={onBack}>
        ← Back
      </button>

      {logo && (
        <img
          className="business-logo"
          src={logo}
          alt="Business logo"
        />
      )}

      {item.entry_kind !== 'business' && (
        <BusinessImageGallery
          paths={item.media_paths}
          title={item.name}
        />
      )}

      <h3>{item.name}</h3>

      <p>{item.provider_name || business.name}</p>

      {item.description && (
        <p className="preserve-lines">{item.description}</p>
      )}

      <p>{item.location || 'Location not shared'}</p>

      {item.features && (
        <p className="preserve-lines">{item.features}</p>
      )}

      {item.service_areas?.length > 0 && (
        <p>
          Service areas: {item.service_areas.join(' · ')}
        </p>
      )}

      <div className="public-contacts">
        {business.whatsapp && (
          <p>
            <a
              href={
                'https://wa.me/' +
                business.whatsapp.replace(/\D/g, '')
              }
              target="_blank"
              rel="noopener noreferrer"
            >
              WhatsApp
            </a>
          </p>
        )}

        {business.public_email && (
          <p>
            <a href={'mailto:' + business.public_email}>
              Email business
            </a>
          </p>
        )}
      </div>

      {error && <p role="alert">{error}</p>}

      {item.entry_kind === 'stay' && (
        <>
          <h4>Room options</h4>

          <p className="muted">
            Room details do not confirm availability.
          </p>

          {rooms === null ? (
            <p role="status">Loading rooms...</p>
          ) : (
            rooms.map((room) => (
              <p key={room.id}>
                {room.name} · Up to {room.guest_capacity} guests ·{' '}
                {formatMinor(room.nightly_minor)} / night
              </p>
            ))
          )}
        </>
      )}

      {item.entry_kind !== 'business' && (
        <>
          <button
            className="text-button"
            onClick={() =>
              onNavigate(
                item.entry_kind === 'stay'
                  ? 'Stays'
                  : 'Logistics'
              )
            }
          >
            Make an enquiry
          </button>

          <p className="muted">
            Enquiries are not bookings or confirmed quotations.
          </p>
        </>
      )}
    </article>
  );
}