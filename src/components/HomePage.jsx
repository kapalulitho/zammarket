import React from "react";
import ProductCard from "./ProductCard";

const shortcuts = [
  { label: "Shop", icon: "🛍️", page: "Explore" },
  { label: "Delivery", icon: "🚚", page: "Delivery" },
  { label: "Events", icon: "🎟️", page: "Events" },
  { label: "Jobs", icon: "💼", page: "Jobs" },
  { label: "Learning", icon: "📚", page: "Learning" },
  { label: "Food", icon: "🍽️", page: "Food" },
  { label: "Property", icon: "🏠", page: "Property" },
  { label: "More", icon: "＋", page: "Directory" },
];

export default function HomePage({
  products = [],
  loading = false,
  onNavigate,
  onOpenProduct,
  formatMoney,
  featuredIds = [],
}) {
  const featured = featuredIds.length
    ? featuredIds
        .map((id) => products.find((product) => String(product.id) === String(id)))
        .filter(Boolean)
    : [];

  return (
    <div className="zam-home">

      <section className="home-explore">
        <div className="home-section-heading">
          <div>
            <span className="eyebrow">EXPLORE ZAMNEXUS</span>
            <h2>What are you looking for?</h2>
          </div>
        </div>

        <div className="home-shortcut-grid">
          {shortcuts.map((item) => (
            <button
              type="button"
              className="home-shortcut"
              key={item.page}
              onClick={() => onNavigate(item.page)}
            >
              <span className="home-shortcut-icon" aria-hidden="true">
                {item.icon}
              </span>
              <span>{item.label}</span>
            </button>
          ))}
        </div>
      </section>

      {featured.length > 0 && (
        <section className="home-featured">
          <div className="home-section-heading">
            <div>
              <span className="eyebrow">SELECTED FINDS</span>
              <h2>Featured products</h2>
              <p>Products selected to stand out.</p>
            </div>
            <button
              type="button"
              className="text-button"
              onClick={() => onNavigate("Explore")}
            >
              View all
            </button>
          </div>

          <div className="product-grid">
            {featured.slice(0, 4).map((product) => (
              <ProductCard
                key={product.id}
                product={product}
                onOpen={onOpenProduct}
                formatMoney={formatMoney}
              />
            ))}
          </div>
        </section>
      )}

      <section className="home-latest">
        <div className="home-section-heading">
          <div>
            <span className="eyebrow">FROM LOCAL SELLERS</span>
            <h2>Latest listings</h2>
            <p>Discover products available on ZamNexus.</p>
          </div>
          <button
            type="button"
            className="text-button"
            onClick={() => onNavigate("Explore")}
          >
            Explore all
          </button>
        </div>

        {loading ? (
          <p className="home-loading">Loading products...</p>
        ) : products.length > 0 ? (
          <div className="product-grid">
            {products.slice(0, 8).map((product) => (
              <ProductCard
                key={product.id}
                product={product}
                onOpen={onOpenProduct}
                formatMoney={formatMoney}
              />
            ))}
          </div>
        ) : (
          <div className="home-empty">
            <h3>No listings yet</h3>
            <p>New products will appear here when sellers post them.</p>
            <button
              type="button"
              className="primary-button"
              onClick={() => onNavigate("Post")}
            >
              Sell an item
            </button>
          </div>
        )}
      </section>

    </div>
  );
}