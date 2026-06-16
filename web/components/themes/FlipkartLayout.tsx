'use client';

import { useState, useEffect, useMemo } from 'react';
import Image from 'next/image';
import { ProductDetailSheet } from '@/components/shop/product-detail-sheet';
import type { Product as AppProduct } from '@/lib/products';

/* ─── Interfaces ─────────────────────────────────────────── */
interface ShopData {
  shopName: string;
  shopNameMl: string;
  shopType: string;
  district: string;
  ownerPhone: string;
  logoUrl: string;
  bannerImageUrl: string;
}

interface Product {
  productId: string;
  name: string;
  price: number;
  offerPrice: number;
  unit: string;
  imageUrl: string;
  category: string;
  isOutOfStock: boolean;
  isFeatured?: boolean;
  isNew?: boolean;
  description?: string;
  attributes?: Record<string, unknown>;
}

interface WebsiteConfig {
  siteName: string;
  tagline: string;
  aboutText: string;
  sections: string[];
  whatsappEnabled: boolean;
  whatsappNumber: string;
  banners: string[];
  storeHoursText: string;
  storeHoursEnabled: boolean;
  couponCodes: { code: string; discountPercent: number; active: boolean }[];
  primaryButtonText: string;
  deliveryCharge: number;
  freeDeliveryAbove: number;
  minOrderAmount: number;
  logoUrl: string;
  socialLinks: {
    instagram: string;
    facebook: string;
    youtube: string;
    twitter: string;
  };
}

interface Props {
  config: WebsiteConfig;
  shop: ShopData;
  products: Product[];
  shopId?: string;
}

/* ─── Adapter ────────────────────────────────────────────── */
function toAppProduct(p: Product): AppProduct {
  return {
    id: p.productId,
    name: { en: p.name, ml: p.name },
    price: p.price,
    offerPrice: p.offerPrice ?? 0,
    unit: 'perPiece',
    category: p.category,
    image: p.imageUrl ?? '',
    isOutOfStock: p.isOutOfStock,
    description: p.description,
    attributes: p.attributes,
  };
}

/* ─── Helpers ────────────────────────────────────────────── */
const CATEGORY_EMOJI: Record<string, string> = {
  vegetables: '🥬',
  fruits: '🍎',
  dairy: '🥛',
  milk: '🥛',
  meat: '🍗',
  chicken: '🍗',
  fish: '🐟',
  seafood: '🐟',
  grocery: '📦',
  groceries: '📦',
  snacks: '🍿',
  beverages: '🧃',
  drinks: '🧃',
  bakery: '🍞',
  bread: '🍞',
  sweets: '🍭',
  spices: '🌶️',
  rice: '🍚',
  grains: '🌾',
  oils: '🫙',
  cleaning: '🧹',
  personal: '🧴',
  baby: '🍼',
  frozen: '❄️',
  organic: '🌱',
  default: '🛒',
};

function getCategoryEmoji(category: string): string {
  const key = category.toLowerCase();
  for (const [k, v] of Object.entries(CATEGORY_EMOJI)) {
    if (key.includes(k)) return v;
  }
  return CATEGORY_EMOJI.default;
}

function discountPercent(price: number, offerPrice: number): number {
  if (!price || price <= offerPrice) return 0;
  return Math.round(((price - offerPrice) / price) * 100);
}

function discountBadgeColor(pct: number): string {
  if (pct >= 40) return '#B71C1C'; // red
  if (pct >= 20) return '#F57F17'; // yellow/amber
  return '#388E3C'; // green
}

/* Simulated deterministic rating 3.5–4.8 based on productId */
function simulatedRating(productId: string): number {
  let hash = 0;
  for (let i = 0; i < productId.length; i++) hash = (hash * 31 + productId.charCodeAt(i)) & 0xffff;
  return 3.5 + ((hash % 14) / 10);
}

function StarRating({ rating }: { rating: number }) {
  const full = Math.floor(rating);
  const half = rating - full >= 0.5;
  return (
    <span className="text-yellow-400 text-xs">
      {'★'.repeat(full)}
      {half ? '½' : ''}
      {'☆'.repeat(5 - full - (half ? 1 : 0))}
    </span>
  );
}

/* Countdown timer hook */
function useCountdown(targetMs: number) {
  const [remaining, setRemaining] = useState(targetMs - Date.now());
  useEffect(() => {
    const id = setInterval(() => setRemaining(targetMs - Date.now()), 1000);
    return () => clearInterval(id);
  }, [targetMs]);
  const total = Math.max(0, remaining);
  const h = Math.floor(total / 3600000);
  const m = Math.floor((total % 3600000) / 60000);
  const s = Math.floor((total % 60000) / 1000);
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${pad(h)}:${pad(m)}:${pad(s)}`;
}

/* Flash-sale ends at next midnight */
function nextMidnightMs() {
  const d = new Date();
  d.setHours(24, 0, 0, 0);
  return d.getTime();
}

/* ─── Product Card ───────────────────────────────────────── */
function ProductCard({
  product,
  shopName,
  whatsappNumber,
  whatsappEnabled,
  onProductClick,
}: {
  product: Product;
  shopName: string;
  whatsappNumber: string;
  whatsappEnabled: boolean;
  onProductClick?: (product: Product) => void;
}) {
  const pct = discountPercent(product.price, product.offerPrice);
  const rating = simulatedRating(product.productId);
  const badgeColor = discountBadgeColor(pct);

  const handleBuy = () => {
    if (!whatsappEnabled || !whatsappNumber) return;
    const phone = whatsappNumber.replace(/\D/g, '');
    const msg = encodeURIComponent(`I want to buy ${product.name} from ${shopName}`);
    window.open(`https://wa.me/${phone}?text=${msg}`, '_blank');
  };

  return (
    <div
      className="bg-white flex flex-col cursor-pointer"
      style={{ boxShadow: '0 1px 4px rgba(0,0,0,0.12)', position: 'relative' }}
      onClick={() => onProductClick?.(product)}
    >
      {/* Discount badge */}
      {pct > 0 && (
        <span
          className="absolute top-2 left-2 text-white text-xs font-bold px-1.5 py-0.5 z-10"
          style={{ backgroundColor: badgeColor, fontSize: '10px' }}
        >
          {pct}% off
        </span>
      )}

      {/* NEW badge */}
      {product.isNew && (
        <span
          className="absolute top-2 right-2 text-white text-xs font-bold px-1.5 py-0.5 z-10"
          style={{ backgroundColor: '#2874F0', fontSize: '10px' }}
        >
          NEW
        </span>
      )}

      {/* Out of stock overlay */}
      {product.isOutOfStock && (
        <div
          className="absolute inset-0 flex items-center justify-center z-20"
          style={{ backgroundColor: 'rgba(255,255,255,0.75)' }}
        >
          <span
            className="font-bold text-sm px-3 py-1"
            style={{ backgroundColor: '#878787', color: '#fff' }}
          >
            Out of Stock
          </span>
        </div>
      )}

      {/* Image */}
      <div className="relative h-40 w-full bg-white flex items-center justify-center overflow-hidden">
        {product.imageUrl ? (
          <Image
            src={product.imageUrl}
            alt={product.name}
            fill
            className="object-contain"
            sizes="(max-width: 768px) 50vw, 25vw"
          />
        ) : (
          <span className="text-5xl">{getCategoryEmoji(product.category)}</span>
        )}
      </div>

      <div className="p-2 flex flex-col flex-1 gap-1">
        {/* Assured badge */}
        <span
          className="inline-flex items-center gap-0.5 text-xs font-semibold w-fit"
          style={{ color: '#2874F0' }}
        >
          <span
            className="inline-flex items-center justify-center w-3.5 h-3.5 rounded-full text-white text-xs"
            style={{ backgroundColor: '#2874F0', fontSize: '9px' }}
          >
            ✓
          </span>
          Assured
        </span>

        {/* Name */}
        <p
          className="text-sm font-medium leading-tight"
          style={{
            color: '#212121',
            display: '-webkit-box',
            WebkitLineClamp: 2,
            WebkitBoxOrient: 'vertical',
            overflow: 'hidden',
          }}
        >
          {product.name}
        </p>

        {/* Unit */}
        <p className="text-xs" style={{ color: '#878787' }}>
          {product.unit}
        </p>

        {/* Rating */}
        <div className="flex items-center gap-1">
          <StarRating rating={rating} />
          <span
            className="text-xs font-semibold px-1 py-0.5 rounded"
            style={{ backgroundColor: '#388E3C', color: '#fff', fontSize: '10px' }}
          >
            {rating.toFixed(1)}★
          </span>
        </div>

        {/* Price row */}
        <div className="flex items-baseline gap-1 flex-wrap mt-auto">
          <span className="text-base font-bold" style={{ color: '#212121' }}>
            ₹{product.offerPrice > 0 ? product.offerPrice : product.price}
          </span>
          {pct > 0 && (
            <>
              <span className="text-sm line-through" style={{ color: '#878787' }}>
                ₹{product.price}
              </span>
              <span className="text-xs font-medium" style={{ color: '#388E3C' }}>
                ({pct}% off)
              </span>
            </>
          )}
        </div>

        {/* BUY NOW button */}
        <button
          onClick={handleBuy}
          disabled={product.isOutOfStock}
          className="w-full h-10 text-white font-bold text-sm tracking-wide mt-1 disabled:opacity-50 disabled:cursor-not-allowed transition-opacity hover:opacity-90"
          style={{ backgroundColor: '#FB641B', borderRadius: 0, border: 'none' }}
        >
          BUY NOW
        </button>
      </div>
    </div>
  );
}

/* ─── Main Component ─────────────────────────────────────── */
export default function FlipkartLayout({ config, shop, products, shopId }: Props) {
  const [searchQuery, setSearchQuery] = useState('');
  const [activeCategory, setActiveCategory] = useState('All');
  const [sortOrder, setSortOrder] = useState<'default' | 'price_asc' | 'price_desc' | 'discount'>('default');
  const [cartCount, setCartCount] = useState(0);
  const [selectedProduct, setSelectedProduct] = useState<Product | null>(null);
  const flashSaleTarget = useMemo(() => nextMidnightMs(), []);
  const countdown = useCountdown(flashSaleTarget);

  const has = (s: string) => config.sections.includes(s);
  const aboutFirst = config.sections.indexOf('about') <= config.sections.indexOf('contact');

  const hasFlashSale = products.some((p) => p.offerPrice > 0 && p.offerPrice < p.price);

  /* Categories */
  const categories = useMemo(() => {
    const cats = Array.from(new Set(products.map((p) => p.category).filter(Boolean)));
    return ['All', ...cats];
  }, [products]);

  /* Filtered + sorted products */
  const filteredProducts = useMemo(() => {
    let list = [...products];

    if (activeCategory !== 'All') {
      list = list.filter((p) => p.category === activeCategory);
    }

    if (searchQuery.trim()) {
      const q = searchQuery.trim().toLowerCase();
      list = list.filter(
        (p) =>
          p.name.toLowerCase().includes(q) ||
          p.category.toLowerCase().includes(q) ||
          (p.description || '').toLowerCase().includes(q)
      );
    }

    if (sortOrder === 'price_asc') {
      list.sort((a, b) => (a.offerPrice || a.price) - (b.offerPrice || b.price));
    } else if (sortOrder === 'price_desc') {
      list.sort((a, b) => (b.offerPrice || b.price) - (a.offerPrice || a.price));
    } else if (sortOrder === 'discount') {
      list.sort(
        (a, b) =>
          discountPercent(b.price, b.offerPrice) - discountPercent(a.price, a.offerPrice)
      );
    }

    return list;
  }, [products, activeCategory, searchQuery, sortOrder]);

  /* Top Picks */
  const topPicks = useMemo(() => {
    const featured = products.filter((p) => p.isFeatured);
    if (featured.length >= 6) return featured.slice(0, 8);
    const rest = products.filter((p) => !p.isFeatured);
    return [...featured, ...rest].slice(0, 8);
  }, [products]);

  /* Best discount products for flash sale strip */
  const flashProducts = useMemo(
    () =>
      [...products]
        .filter((p) => p.offerPrice > 0 && p.offerPrice < p.price)
        .sort(
          (a, b) =>
            discountPercent(b.price, b.offerPrice) - discountPercent(a.price, a.offerPrice)
        )
        .slice(0, 6),
    [products]
  );

  const logoSrc = config.logoUrl || shop.logoUrl;

  return (
    <div className="min-h-screen" style={{ backgroundColor: '#F1F3F6', fontFamily: 'sans-serif' }}>

      {/* ── Header ── */}
      <header
        className="sticky top-0 z-50 w-full"
        style={{ backgroundColor: '#2874F0', height: '56px' }}
      >
        <div className="max-w-7xl mx-auto h-full flex items-center gap-3 px-3">
          {/* Logo + shop name */}
          <div className="flex items-center gap-2 shrink-0">
            {logoSrc ? (
              <div className="relative w-8 h-8 rounded overflow-hidden bg-white">
                <Image src={logoSrc} alt="logo" fill className="object-contain" sizes="32px" />
              </div>
            ) : (
              <span className="text-2xl">🛒</span>
            )}
            <div className="hidden sm:block">
              <p className="text-white font-bold text-sm leading-tight">{shop.shopName}</p>
              {shop.shopNameMl && (
                <p className="text-blue-200 text-xs leading-tight">{shop.shopNameMl}</p>
              )}
            </div>
          </div>

          {/* Search bar */}
          <div className="flex-1 flex items-center bg-white mx-2" style={{ borderRadius: 0 }}>
            <span className="px-2 text-gray-400 text-lg">🔍</span>
            <input
              type="text"
              placeholder="Search for products..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="flex-1 py-2 text-sm outline-none bg-transparent"
              style={{ color: '#212121' }}
            />
            {searchQuery && (
              <button
                onClick={() => setSearchQuery('')}
                className="px-2 text-gray-400 hover:text-gray-600"
              >
                ✕
              </button>
            )}
          </div>

          {/* Cart */}
          <button
            className="relative flex items-center gap-1 shrink-0"
            onClick={() => setCartCount((c) => c + 0)}
          >
            <span className="text-white text-xl">🛒</span>
            <span className="text-white text-sm font-medium hidden sm:inline">Cart</span>
            {cartCount > 0 && (
              <span
                className="absolute -top-2 -right-2 text-white text-xs rounded-full w-4 h-4 flex items-center justify-center font-bold"
                style={{ backgroundColor: '#FF9900', fontSize: '9px' }}
              >
                {cartCount}
              </span>
            )}
          </button>
        </div>
      </header>

      {/* ── Flash Sale Banner ── */}
      {hasFlashSale && (
        <div className="w-full" style={{ backgroundColor: '#fff', borderBottom: '1px solid #e0e0e0' }}>
          <div className="max-w-7xl mx-auto px-3 py-2">
            <div className="flex items-center gap-3 mb-2">
              <span className="text-xl font-extrabold" style={{ color: '#2874F0' }}>
                ⚡ Flash Sale
              </span>
              <span
                className="text-xs font-bold text-white px-2 py-0.5"
                style={{ backgroundColor: '#FB641B' }}
              >
                UP TO {Math.max(...flashProducts.map((p) => discountPercent(p.price, p.offerPrice)))}% OFF
              </span>
              <span className="text-xs font-medium ml-auto" style={{ color: '#212121' }}>
                Ends in{' '}
                <span className="font-bold" style={{ color: '#FB641B' }}>
                  {countdown}
                </span>
              </span>
            </div>

            {/* Flash sale products horizontal scroll */}
            <div className="flex gap-2 overflow-x-auto pb-1" style={{ scrollbarWidth: 'none' }}>
              {flashProducts.map((p) => {
                const pct = discountPercent(p.price, p.offerPrice);
                return (
                  <div
                    key={p.productId}
                    className="flex-shrink-0 flex flex-col items-center bg-white p-2 gap-1"
                    style={{ width: '90px', boxShadow: '0 1px 3px rgba(0,0,0,0.1)' }}
                  >
                    <div className="relative w-14 h-14">
                      {p.imageUrl ? (
                        <Image src={p.imageUrl} alt={p.name} fill className="object-contain" sizes="56px" />
                      ) : (
                        <span className="text-3xl">{getCategoryEmoji(p.category)}</span>
                      )}
                    </div>
                    <p className="text-xs text-center font-medium leading-tight line-clamp-1" style={{ color: '#212121' }}>
                      {p.name}
                    </p>
                    <span
                      className="text-xs font-bold text-white px-1"
                      style={{ backgroundColor: '#388E3C' }}
                    >
                      {pct}% off
                    </span>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      )}

      {/* ── Category Icons Row ── */}
      <div className="w-full bg-white" style={{ borderBottom: '1px solid #e0e0e0' }}>
        <div className="max-w-7xl mx-auto px-2 py-3">
          <div className="flex gap-4 overflow-x-auto pb-1" style={{ scrollbarWidth: 'none' }}>
            {categories.map((cat) => {
              const isActive = cat === activeCategory;
              return (
                <button
                  key={cat}
                  onClick={() => setActiveCategory(cat)}
                  className="flex-shrink-0 flex flex-col items-center gap-1"
                >
                  <div
                    className="w-12 h-12 rounded-full flex items-center justify-center text-2xl"
                    style={{
                      backgroundColor: isActive ? '#E3F2FD' : '#F1F3F6',
                      border: isActive ? '2px solid #2874F0' : '2px solid transparent',
                    }}
                  >
                    {cat === 'All' ? '🏪' : getCategoryEmoji(cat)}
                  </div>
                  <span
                    className="text-xs font-medium whitespace-nowrap"
                    style={{ color: isActive ? '#2874F0' : '#212121' }}
                  >
                    {cat}
                  </span>
                  {isActive && (
                    <div className="w-full h-0.5" style={{ backgroundColor: '#2874F0' }} />
                  )}
                </button>
              );
            })}
          </div>
        </div>
      </div>

      <div className="max-w-7xl mx-auto px-2 py-3">

        {/* ── Top Picks ── */}
        {topPicks.length > 0 && (
          <div className="mb-4">
            <div
              className="flex items-center justify-between px-3 py-2 mb-2"
              style={{ backgroundColor: '#2874F0' }}
            >
              <span className="text-white font-bold text-base">⭐ Top Picks</span>
              <span className="text-blue-200 text-sm">See all →</span>
            </div>

            <div className="flex gap-2 overflow-x-auto pb-2" style={{ scrollbarWidth: 'none' }}>
              {topPicks.map((p) => {
                const pct = discountPercent(p.price, p.offerPrice);
                const rating = simulatedRating(p.productId);
                const handleBuy = () => {
                  if (!config.whatsappEnabled || !config.whatsappNumber) return;
                  const phone = config.whatsappNumber.replace(/\D/g, '');
                  const msg = encodeURIComponent(`I want to buy ${p.name} from ${shop.shopName}`);
                  window.open(`https://wa.me/${phone}?text=${msg}`, '_blank');
                };
                return (
                  <div
                    key={p.productId}
                    className="flex-shrink-0 flex flex-col bg-white cursor-pointer"
                    style={{ width: '140px', boxShadow: '0 1px 4px rgba(0,0,0,0.12)' }}
                    onClick={() => setSelectedProduct(p)}
                  >
                    <div className="relative h-28 bg-white">
                      {p.imageUrl ? (
                        <Image src={p.imageUrl} alt={p.name} fill className="object-contain" sizes="140px" />
                      ) : (
                        <div className="w-full h-full flex items-center justify-center text-4xl">
                          {getCategoryEmoji(p.category)}
                        </div>
                      )}
                      {pct > 0 && (
                        <span
                          className="absolute top-1 left-1 text-white text-xs font-bold px-1"
                          style={{ backgroundColor: '#388E3C', fontSize: '9px' }}
                        >
                          {pct}% off
                        </span>
                      )}
                    </div>
                    <div className="p-1.5 flex flex-col gap-0.5">
                      <p
                        className="text-xs font-medium leading-tight"
                        style={{
                          color: '#212121',
                          display: '-webkit-box',
                          WebkitLineClamp: 2,
                          WebkitBoxOrient: 'vertical',
                          overflow: 'hidden',
                        }}
                      >
                        {p.name}
                      </p>
                      <span
                        className="inline-flex items-center gap-0.5 text-xs font-semibold w-fit"
                        style={{ color: '#2874F0', fontSize: '10px' }}
                      >
                        <span
                          className="inline-flex items-center justify-center w-3 h-3 rounded-full text-white"
                          style={{ backgroundColor: '#2874F0', fontSize: '8px' }}
                        >
                          ✓
                        </span>
                        Assured
                      </span>
                      <div className="flex items-center gap-1">
                        <span className="text-yellow-400 text-xs">{'★'.repeat(Math.floor(rating))}</span>
                        <span
                          className="text-xs font-semibold px-1 py-0.5 rounded"
                          style={{ backgroundColor: '#388E3C', color: '#fff', fontSize: '9px' }}
                        >
                          {rating.toFixed(1)}★
                        </span>
                      </div>
                      <div className="flex items-baseline gap-1 flex-wrap">
                        <span className="text-sm font-bold" style={{ color: '#212121' }}>
                          ₹{p.offerPrice > 0 ? p.offerPrice : p.price}
                        </span>
                        {pct > 0 && (
                          <span className="text-xs line-through" style={{ color: '#878787' }}>
                            ₹{p.price}
                          </span>
                        )}
                      </div>
                      <button
                        onClick={handleBuy}
                        disabled={p.isOutOfStock}
                        className="w-full h-7 text-white font-bold text-xs disabled:opacity-50"
                        style={{ backgroundColor: '#FB641B', borderRadius: 0, border: 'none' }}
                      >
                        BUY NOW
                      </button>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        )}

        {/* ── Sort + Filter bar ── */}
        <div
          className="flex items-center gap-2 px-3 py-2 mb-3 bg-white"
          style={{ boxShadow: '0 1px 3px rgba(0,0,0,0.08)' }}
        >
          <span className="text-sm font-medium" style={{ color: '#212121' }}>
            Sort:
          </span>
          {(
            [
              { value: 'default', label: 'Relevance' },
              { value: 'price_asc', label: 'Price ↑' },
              { value: 'price_desc', label: 'Price ↓' },
              { value: 'discount', label: 'Discount' },
            ] as { value: typeof sortOrder; label: string }[]
          ).map((opt) => (
            <button
              key={opt.value}
              onClick={() => setSortOrder(opt.value)}
              className="text-xs px-2 py-1 font-medium transition-colors"
              style={{
                backgroundColor: sortOrder === opt.value ? '#2874F0' : '#F1F3F6',
                color: sortOrder === opt.value ? '#fff' : '#212121',
                borderRadius: 0,
                border: 'none',
              }}
            >
              {opt.label}
            </button>
          ))}
          <span className="ml-auto text-xs" style={{ color: '#878787' }}>
            {filteredProducts.length} items
          </span>
        </div>

        {/* ── Product Grid ── */}
        {filteredProducts.length > 0 ? (
          <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-2">
            {filteredProducts.map((product) => (
              <ProductCard
                key={product.productId}
                product={product}
                shopName={shop.shopName}
                whatsappNumber={config.whatsappNumber}
                whatsappEnabled={config.whatsappEnabled}
                onProductClick={setSelectedProduct}
              />
            ))}
          </div>
        ) : (
          <div className="flex flex-col items-center justify-center py-20 bg-white">
            <span className="text-6xl mb-4">🔍</span>
            <p className="text-lg font-semibold" style={{ color: '#212121' }}>
              No products found
            </p>
            <p className="text-sm mt-1" style={{ color: '#878787' }}>
              Try a different search or category
            </p>
            <button
              onClick={() => {
                setSearchQuery('');
                setActiveCategory('All');
              }}
              className="mt-4 px-4 py-2 text-sm font-semibold text-white"
              style={{ backgroundColor: '#2874F0', borderRadius: 0 }}
            >
              Clear Filters
            </button>
          </div>
        )}

        {/* ── Store Hours ── */}
        {config.storeHoursEnabled && config.storeHoursText && (
          <div
            className="mt-4 px-4 py-3 flex items-center gap-2"
            style={{ backgroundColor: '#E8F5E9', borderLeft: '4px solid #388E3C' }}
          >
            <span className="text-lg">🕐</span>
            <p className="text-sm font-medium" style={{ color: '#212121' }}>
              {config.storeHoursText}
            </p>
          </div>
        )}

        {/* ── Delivery Info ── */}
        {(config.deliveryCharge >= 0 || config.freeDeliveryAbove > 0) && (
          <div
            className="mt-3 px-4 py-3 flex items-center gap-3"
            style={{ backgroundColor: '#E3F2FD' }}
          >
            <span className="text-lg">🚚</span>
            <div>
              {config.freeDeliveryAbove > 0 ? (
                <p className="text-sm font-medium" style={{ color: '#212121' }}>
                  Free delivery on orders above{' '}
                  <span className="font-bold">₹{config.freeDeliveryAbove}</span>
                </p>
              ) : (
                <p className="text-sm font-medium" style={{ color: '#212121' }}>
                  Delivery charge: <span className="font-bold">₹{config.deliveryCharge}</span>
                </p>
              )}
              {config.minOrderAmount > 0 && (
                <p className="text-xs" style={{ color: '#878787' }}>
                  Minimum order: ₹{config.minOrderAmount}
                </p>
              )}
            </div>
          </div>
        )}

        {/* ── Active Coupon Codes ── */}
        {config.couponCodes?.some((c) => c.active) && (
          <div className="mt-3 bg-white px-4 py-3" style={{ boxShadow: '0 1px 3px rgba(0,0,0,0.08)' }}>
            <p className="text-sm font-bold mb-2" style={{ color: '#212121' }}>
              🎫 Available Coupons
            </p>
            <div className="flex gap-2 flex-wrap">
              {config.couponCodes
                .filter((c) => c.active)
                .map((c) => (
                  <div
                    key={c.code}
                    className="flex items-center gap-1 px-2 py-1 text-xs font-bold"
                    style={{
                      border: '1.5px dashed #2874F0',
                      color: '#2874F0',
                    }}
                  >
                    <span>{c.code}</span>
                    <span
                      className="text-white px-1"
                      style={{ backgroundColor: '#FB641B', fontSize: '10px' }}
                    >
                      {c.discountPercent}% OFF
                    </span>
                  </div>
                ))}
            </div>
          </div>
        )}

        {/* ── About & Contact — order follows the builder's drag-to-reorder list ── */}
        {(() => {
          const aboutBlock = has('about') && config.aboutText && (
            <div key="about" className="mt-3 bg-white px-4 py-3" style={{ boxShadow: '0 1px 3px rgba(0,0,0,0.08)' }}>
              <p className="text-sm font-bold mb-1" style={{ color: '#2874F0' }}>
                About {shop.shopName}
              </p>
              <p className="text-sm" style={{ color: '#212121' }}>
                {config.aboutText}
              </p>
            </div>
          );
          const contactBlock = has('contact') && (
            <div key="contact" className="mt-3 bg-white px-4 py-3" style={{ boxShadow: '0 1px 3px rgba(0,0,0,0.08)' }}>
              <p className="text-sm font-bold mb-1" style={{ color: '#2874F0' }}>
                Contact
              </p>
              <p className="text-sm" style={{ color: '#212121' }}>
                {shop.district}, Kerala
              </p>
              {shop.ownerPhone && (
                <a href={`tel:${shop.ownerPhone}`} className="text-sm font-medium block mt-1" style={{ color: '#2874F0' }}>
                  📞 {shop.ownerPhone}
                </a>
              )}
            </div>
          );
          return aboutFirst ? <>{aboutBlock}{contactBlock}</> : <>{contactBlock}{aboutBlock}</>;
        })()}
      </div>

      {/* ── Product Detail Sheet ── */}
      {selectedProduct && (
        <ProductDetailSheet
          product={toAppProduct(selectedProduct)}
          language="en"
          onClose={() => setSelectedProduct(null)}
          allProducts={products.map(toAppProduct)}
          onProductClick={(p) => {
            const orig = products.find((x) => x.productId === p.id);
            if (orig) setSelectedProduct(orig);
          }}
        />
      )}

      {/* ── Footer ── */}
      <footer
        className="mt-8 bg-white px-4 py-6"
        style={{ borderTop: '3px solid #2874F0' }}
      >
        <div className="max-w-7xl mx-auto">
          <div className="flex flex-col md:flex-row md:items-start gap-6">
            {/* Brand */}
            <div className="flex-1">
              <div className="flex items-center gap-2 mb-2">
                {logoSrc && (
                  <div className="relative w-8 h-8">
                    <Image src={logoSrc} alt="logo" fill className="object-contain" sizes="32px" />
                  </div>
                )}
                <p className="text-base font-bold" style={{ color: '#2874F0' }}>
                  {shop.shopName}
                </p>
              </div>
              {shop.shopNameMl && (
                <p className="text-sm" style={{ color: '#878787' }}>
                  {shop.shopNameMl}
                </p>
              )}
              <p className="text-sm mt-1" style={{ color: '#878787' }}>
                {config.tagline}
              </p>
              <p className="text-xs mt-1" style={{ color: '#878787' }}>
                {shop.shopType} &bull; {shop.district}
              </p>
            </div>

            {/* Social Links */}
            {(config.socialLinks?.instagram ||
              config.socialLinks?.facebook ||
              config.socialLinks?.youtube ||
              config.socialLinks?.twitter) && (
              <div>
                <p className="text-sm font-bold mb-2" style={{ color: '#212121' }}>
                  Follow Us
                </p>
                <div className="flex gap-3">
                  {config.socialLinks.instagram && (
                    <a
                      href={config.socialLinks.instagram}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-xl hover:opacity-75 transition-opacity"
                      title="Instagram"
                    >
                      📸
                    </a>
                  )}
                  {config.socialLinks.facebook && (
                    <a
                      href={config.socialLinks.facebook}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-xl hover:opacity-75 transition-opacity"
                      title="Facebook"
                    >
                      👥
                    </a>
                  )}
                  {config.socialLinks.youtube && (
                    <a
                      href={config.socialLinks.youtube}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-xl hover:opacity-75 transition-opacity"
                      title="YouTube"
                    >
                      ▶️
                    </a>
                  )}
                  {config.socialLinks.twitter && (
                    <a
                      href={config.socialLinks.twitter}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-xl hover:opacity-75 transition-opacity"
                      title="Twitter / X"
                    >
                      🐦
                    </a>
                  )}
                </div>
              </div>
            )}
          </div>

          <div
            className="mt-4 pt-3 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-1"
            style={{ borderTop: '1px solid #e0e0e0' }}
          >
            <p className="text-xs" style={{ color: '#878787' }}>
              &copy; {new Date().getFullYear()} {shop.shopName}. All rights reserved.
            </p>
            <p className="text-xs font-semibold" style={{ color: '#2874F0' }}>
              Powered by wekerala
            </p>
          </div>
        </div>
      </footer>
    </div>
  );
}
