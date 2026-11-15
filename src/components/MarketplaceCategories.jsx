import { marketplaceSections } from '../lib/marketplaceCategories';
import { Icon } from './Design';

export default function MarketplaceCategories({ onNavigate }) {
  return (
    <section className="platform-page marketplace-categories-page">
      <div className="section-heading">
        <div>
          <span className="eyebrow">ZAMNEXUS</span>
          <h1>Explore</h1>
        </div>
      </div>

      <div className="marketplace-section-grid">
        {marketplaceSections.map(([label, page, icon]) => (
          <button
            key={page}
            type="button"
            onClick={() => onNavigate(page)}
            aria-label={`Open ${label}`}
          >
            <span className="category-icon">
              <Icon name={icon} size={25} />
            </span>
            <strong>{label}</strong>
          </button>
        ))}
      </div>
    </section>
  );
}