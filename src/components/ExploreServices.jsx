import { useEffect, useState } from 'react';
import { supabase } from '../supabase';
import { useStage3 } from '../lib/stage3';
import { Icon } from './Design';
import BusinessDiscovery from './BusinessDiscovery';

const serviceLinks = [
  ['Shops', 'store', 'Shops'],
  ['Services', 'user', 'Services'],
  ['Events', 'calendar', 'Events'],
  ['Jobs', 'briefcase', 'Jobs'],
  ['Learning', 'book', 'Learning'],
  ['Stays', 'home', 'Accommodation'],
  ['Logistics', 'car', 'Transport & Logistics'],
];

export default function ExploreServices({
  onNavigate,
  search = '',
  onCommunity,
}) {
  const capability = useStage3();
  const [result, setResult] = useState(null);
  const [error, setError] = useState('');

  useEffect(() => {
    if (!capability.ready) return;

    let active = true;

    supabase
      .from('community_entries')
      .select(
        'id,kind,title,description,organisation,location,category,status,owner_id,starts_at,ends_at,deadline,format,media_paths,price,price_unit,extra'
      )
      .eq('status', 'published')
      .order('created_at', { ascending: false })
      .limit(24)
      .then(({ data, error: failure }) => {
        if (!active) return;

        if (failure) {
          setError('Published listings could not be loaded.');
        } else {
          setResult(data ?? []);
          setError('');
        }
      })
      .catch(() => {
        if (active) {
          setError('Discovery is temporarily unavailable.');
        }
      });

    return () => {
      active = false;
    };
  }, [capability.ready]);

  const words = search
    .trim()
    .toLowerCase()
    .split(/\s+/)
    .filter(Boolean);

  const items = (result ?? [])
    .filter((item) =>
      words.every((word) =>
        `${item.title} ${item.organisation} ${item.location} ${item.category}`
          .toLowerCase()
          .includes(word)
      )
    )
    .slice(0, 6);

  return (
    <section className="explore-services">
      <div className="section-heading">
        <h2>Discover more</h2>
        <button
          className="text-button"
          onClick={() => onNavigate('Directory')}
        >
          View all →
        </button>
      </div>

      <div className="discovery-service-links">
        {serviceLinks.map(([page, icon, label]) => (
          <button
            key={page}
            type="button"
            onClick={() => onNavigate(page)}
            aria-label={`Explore ${label}`}
          >
            <Icon name={icon} size={22} />
            <span>
              <strong>{label}</strong>
            </span>
          </button>
        ))}
      </div>

      {error && <p role="alert">{error}</p>}

      {capability.loading ? (
        <p role="status">Loading discovery...</p>
      ) : !capability.ready ? (
        <p className="muted">
          Additional publishing features are not active yet.
        </p>
      ) : !result ? (
        <p role="status">Loading listings...</p>
      ) : items.length ? (
        <div className="module-grid">
          {items.map((item) => (
            <button
              className="module-card"
              key={item.id}
              onClick={() => onCommunity(item)}
            >
              <span className="eyebrow">{item.kind}</span>
              <h3>{item.title}</h3>
              <p>
                {[item.organisation, item.location]
                  .filter(Boolean)
                  .join(' · ')}
              </p>
            </button>
          ))}
        </div>
      ) : (
        <p className="muted">
          No matching published listings found.
        </p>
      )}

      <BusinessDiscovery
        search={search}
        onNavigate={onNavigate}
      />
    </section>
  );
}