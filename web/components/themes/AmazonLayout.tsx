'use client';

import { useState, useEffect, useCallback } from 'react';
import { ProductDetailSheet } from '@/components/shop/product-detail-sheet';
import type { Product as AppProduct } from '@/lib/products';

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
  announcementBar: string;
  announcementBarEnabled: boolean;
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

function getDiscount(price: number, offerPrice: number): number {
  if (offerPrice > 0 && offerPrice < price) {
    return Math.round((1 - price / offerPrice) * 100);
  }
  return 0;
}

function getTimeUntilMidnight(): { h: string; m: string; s: string } {
  const now = new Date();
  const midnight = new Date();
  midnight.setHours(24, 0, 0, 0);
  const diff = Math.max(0, Math.floor((midnight.getTime() - now.getTime()) / 1000));
  const h = String(Math.floor(diff / 3600)).padStart(2, '0');
  const m = String(Math.floor((diff % 3600) / 60)).padStart(2, '0');
  const s = String(diff % 60).padStart(2, '0');
  return { h, m, s };
}

function StarRating({ rating = 4.2 }: { rating?: number }) {
  const full = Math.floor(rating);
  const hasHalf = rating - full >= 0.5;
  return (
    <span className="flex items-center gap-0.5 text-xs">
      {[1, 2, 3, 4, 5].map((i) => (
        <span key={i} className={i <= full ? 'text-yellow-400' : i === full + 1 && hasHalf ? 'text-yellow-300' : 'text-gray-300'}>
          ★
        </span>
      ))}
      <span className="text-gray-500 ml-1">{rating}</span>
    </span>
  );
}

export default function AmazonLayout({ config, shop, products, shopId }: Props) {
  const [search, setSearch] = useState('');
  const [activeCat, setActiveCat] = useState('All');
  const [cartCount, setCartCount] = useState(0);
  const [selectedProduct, setSelectedProduct] = useState<Product | null>(null);
  const [slide, setSlide] = useState(0);
  const [countdown, setCountdown] = useState(getTimeUntilMidnight());

  const banners = config.banners?.filter(Boolean) ?? [];
  const hasBanners = banners.length > 0;
  const totalSlides = hasBanners ? banners.length : 1;

  // Carousel auto-play
  const nextSlide = useCallback(() => {
    setSlide((prev) => (prev + 1) % totalSlides);
  }, [totalSlides]);

  useEffect(() => {
    const timer = setInterval(nextSlide, 3500);
    return () => clearInterval(timer);
  }, [nextSlide]);

  // Countdown timer
  useEffect(() => {
    const timer = setInterval(() => {
      setCountdown(getTimeUntilMidnight());
    }, 1000);
    return () => clearInterval(timer);
  }, []);

  // Categories
  const categories = ['All', ...Array.from(new Set(products.map((p) => p.category).filter(Boolean)))];

  // Filtered products
  const filtered = products.filter((p) => {
    const matchCat = activeCat === 'All' || p.category === activeCat;
    const matchSearch =
      search.trim() === '' ||
      p.name.toLowerCase().includes(search.toLowerCase()) ||
      (p.description ?? '').toLowerCase().includes(search.toLowerCase());
    return matchCat && matchSearch;
  });

  // Featured / deal products
  const dealProducts = products.filter((p) => p.isFeatured || (p.offerPrice > 0 && p.offerPrice < p.price));

  function handleAddToCart(product: Product) {
    setCartCount((c) => c + 1);
    if (config.whatsappEnabled && config.whatsappNumber) {
      const phone = config.whatsappNumber.replace(/\D/g, '');
      const text = encodeURIComponent(`Hi, I want to order: ${product.name} (₹${product.price})`);
      window.open(`https://wa.me/${phone}?text=${text}`, '_blank');
    }
  }

  const displayName = config.siteName || shop.shopName;

  return (
    <div className="min-h-screen bg-gray-100 font-sans">
      {/* Announcement Bar */}
      {config.announcementBarEnabled && config.announcementBar && (
        <div className="bg-yellow-400 text-black text-center text-xs py-1 px-4 font-medium">
          {config.announcementBar}
        </div>
      )}

      {/* ===== HEADER ===== */}
      <header className="sticky top-0 z-50" style={{ backgroundColor: '#131921' }}>
        <div className="max-w-7xl mx-auto px-3 py-2 flex items-center gap-3">
          {/* Logo + Shop Name */}
          <div className="flex items-center gap-2 min-w-0 flex-shrink-0">
            {(config.logoUrl || shop.logoUrl) ? (
              <img
                src={config.logoUrl || shop.logoUrl}
                alt={displayName}
                className="h-10 w-10 rounded object-cover border-2 border-yellow-400"
              />
            ) : (
              <div className="h-10 w-10 rounded flex items-center justify-center text-black font-bold text-lg" style={{ backgroundColor: '#FF9900' }}>
                {displayName.charAt(0)}
              </div>
            )}
            <div className="hidden sm:block">
              <p className="text-white font-bold text-sm leading-tight truncate max-w-[120px]">{displayName}</p>
              <p className="text-xs leading-tight" style={{ color: '#CCCCCC' }}>
                📍 {shop.district}
              </p>
            </div>
          </div>

          {/* Search Bar (desktop) */}
          <div className="hidden md:flex flex-1 mx-4">
            <input
              type="text"
              placeholder={`Search ${displayName}...`}
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-full rounded-full px-4 py-2 text-sm text-gray-900 bg-white outline-none border-2 focus:border-yellow-400 transition-colors"
            />
          </div>

          {/* Cart */}
          <div className="ml-auto flex items-center gap-3">
            {config.storeHoursEnabled && config.storeHoursText && (
              <span className="hidden lg:block text-xs" style={{ color: '#CCCCCC' }}>
                🕒 {config.storeHoursText}
              </span>
            )}
            <button
              className="relative flex items-center gap-1 text-white hover:text-yellow-400 transition-colors"
              aria-label="Cart"
            >
              <svg xmlns="http://www.w3.org/2000/svg" className="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 11-4 0 2 2 0 014 0z" />
              </svg>
              {cartCount > 0 && (
                <span className="absolute -top-2 -right-2 rounded-full text-xs font-bold h-5 w-5 flex items-center justify-center text-black" style={{ backgroundColor: '#FF9900' }}>
                  {cartCount}
                </span>
              )}
              <span className="hidden sm:inline text-sm font-semibold">Cart</span>
            </button>
          </div>
        </div>

        {/* Mobile Search Bar */}
        <div className="md:hidden px-3 pb-2">
          <input
            type="text"
            placeholder={`Search products...`}
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full rounded-full px-4 py-2 text-sm text-gray-900 bg-white outline-none border-2 focus:border-yellow-400 transition-colors"
          />
        </div>
      </header>

      {/* ===== SUB-HEADER CATEGORY STRIP ===== */}
      <nav className="sticky top-[64px] md:top-[56px] z-40 overflow-x-auto scrollbar-hide" style={{ backgroundColor: '#232F3E' }}>
        <div className="flex items-center gap-1 px-3 py-2 w-max min-w-full">
          {categories.map((cat) => (
            <button
              key={cat}
              onClick={() => setActiveCat(cat)}
              className={`px-3 py-1 rounded-full text-xs font-medium whitespace-nowrap transition-all border ${
                activeCat === cat
                  ? 'text-black border-yellow-400'
                  : 'text-white border-transparent hover:border-gray-500'
              }`}
              style={activeCat === cat ? { backgroundColor: '#FF9900' } : {}}
            >
              {cat}
            </button>
          ))}
        </div>
      </nav>

      {/* ===== HERO BANNER CAROUSEL ===== */}
      <div className="relative w-full overflow-hidden" style={{ height: '220px' }}>
        {hasBanners ? (
          <>
            {banners.map((banner, i) => (
              <div
                key={i}
                className="absolute inset-0 transition-opacity duration-700"
                style={{ opacity: i === slide ? 1 : 0 }}
              >
                <img src={banner} alt={`Banner ${i + 1}`} className="w-full h-full object-cover" />
              </div>
            ))}
          </>
        ) : (
          <div
            className="w-full h-full flex flex-col items-center justify-center text-white text-center px-6"
            style={{ background: 'linear-gradient(135deg, #FF9900 0%, #FF6B00 50%, #131921 100%)' }}
          >
            <h1 className="text-2xl md:text-4xl font-extrabold drop-shadow-lg">{displayName}</h1>
            {config.tagline && <p className="mt-2 text-sm md:text-base opacity-90">{config.tagline}</p>}
          </div>
        )}

        {/* Dot indicators */}
        {totalSlides > 1 && (
          <div className="absolute bottom-3 left-1/2 -translate-x-1/2 flex gap-2">
            {Array.from({ length: totalSlides }).map((_, i) => (
              <button
                key={i}
                onClick={() => setSlide(i)}
                className="h-2 rounded-full transition-all"
                style={{
                  width: i === slide ? '20px' : '8px',
                  backgroundColor: i === slide ? '#FF9900' : 'rgba(255,255,255,0.6)',
                }}
                aria-label={`Go to slide ${i + 1}`}
              />
            ))}
          </div>
        )}

        {/* Arrow buttons */}
        {totalSlides > 1 && (
          <>
            <button
              onClick={() => setSlide((prev) => (prev - 1 + totalSlides) % totalSlides)}
              className="absolute left-2 top-1/2 -translate-y-1/2 bg-black bg-opacity-40 hover:bg-opacity-70 text-white rounded-full h-8 w-8 flex items-center justify-center transition-all"
              aria-label="Previous banner"
            >
              ‹
            </button>
            <button
              onClick={() => setSlide((prev) => (prev + 1) % totalSlides)}
              className="absolute right-2 top-1/2 -translate-y-1/2 bg-black bg-opacity-40 hover:bg-opacity-70 text-white rounded-full h-8 w-8 flex items-center justify-center transition-all"
              aria-label="Next banner"
            >
              ›
            </button>
          </>
        )}
      </div>

      <main className="max-w-7xl mx-auto px-3 py-4 space-y-6">
        {/* ===== DEALS SECTION ===== */}
        {dealProducts.length > 0 && (
          <section>
            {/* Section header with countdown */}
            <div className="flex items-center justify-between rounded-t-lg px-4 py-2" style={{ backgroundColor: '#FF9900' }}>
              <span className="text-black font-extrabold text-base md:text-lg">🔥 Today's Deals</span>
              <div className="flex items-center gap-1 text-black">
                <span className="text-xs font-medium">Ends in:</span>
                {[countdown.h, countdown.m, countdown.s].map((val, i) => (
                  <span key={i} className="flex items-center">
                    <span className="bg-black text-white text-xs font-mono font-bold px-1.5 py-0.5 rounded">
                      {val}
                    </span>
                    {i < 2 && <span className="font-bold mx-0.5">:</span>}
                  </span>
                ))}
              </div>
            </div>

            {/* Horizontal scroll of deal products */}
            <div className="bg-white rounded-b-lg p-3 overflow-x-auto scrollbar-hide">
              <div className="flex gap-3 w-max">
                {dealProducts.map((product) => {
                  const discount = getDiscount(product.price, product.offerPrice);
                  return (
                    <div
                      key={product.productId}
                      className="relative w-36 flex-shrink-0 border border-gray-200 rounded-md overflow-hidden hover:shadow-md transition-shadow bg-white cursor-pointer"
                      onClick={() => setSelectedProduct(product)}
                    >
                      {product.isOutOfStock && (
                        <div className="absolute top-0 left-0 right-0 bg-red-600 text-white text-center text-xs font-bold py-0.5 z-10">
                          OUT OF STOCK
                        </div>
                      )}
                      {discount > 0 && (
                        <span className="absolute top-1 right-1 bg-red-600 text-white text-xs font-bold px-1 py-0.5 rounded z-10">
                          -{discount}%
                        </span>
                      )}
                      <div className="h-28 bg-gray-50 flex items-center justify-center overflow-hidden">
                        {product.imageUrl ? (
                          <img src={product.imageUrl} alt={product.name} className="h-full w-full object-cover" />
                        ) : (
                          <div className="text-4xl">🛒</div>
                        )}
                      </div>
                      <div className="p-2">
                        <p className="text-xs text-gray-800 font-medium line-clamp-2 leading-tight mb-1">{product.name}</p>
                        <p className="text-sm font-bold text-gray-900">₹{product.price}</p>
                        {product.offerPrice > 0 && product.offerPrice < product.price && (
                          <p className="text-xs text-gray-400 line-through">₹{product.offerPrice}</p>
                        )}
                        <button
                          disabled={product.isOutOfStock}
                          onClick={() => !product.isOutOfStock && handleAddToCart(product)}
                          className="mt-1.5 w-full text-xs font-bold py-1 rounded disabled:opacity-50 disabled:cursor-not-allowed transition-opacity hover:opacity-90 text-black"
                          style={{ backgroundColor: '#FF9900' }}
                        >
                          {product.isOutOfStock ? 'Unavailable' : 'Add to Cart'}
                        </button>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          </section>
        )}

        {/* ===== MAIN PRODUCT GRID ===== */}
        <section>
          <div className="flex items-center justify-between mb-3">
            <h2 className="text-base md:text-lg font-bold text-gray-800">
              {activeCat === 'All' ? 'All Products' : activeCat}
              <span className="ml-2 text-sm font-normal text-gray-500">({filtered.length})</span>
            </h2>
          </div>

          {filtered.length === 0 ? (
            <div className="text-center py-16 text-gray-500">
              <div className="text-5xl mb-4">🔍</div>
              <p className="text-lg font-medium">No products found</p>
              <p className="text-sm">Try a different search or category</p>
            </div>
          ) : (
            <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-3">
              {filtered.map((product) => {
                const discount = getDiscount(product.price, product.offerPrice);
                return (
                  <div
                    key={product.productId}
                    className="relative bg-white rounded border border-gray-200 overflow-hidden hover:shadow-lg transition-shadow flex flex-col cursor-pointer"
                    style={{ borderRadius: '4px' }}
                    onClick={() => setSelectedProduct(product)}
                  >
                    {/* OUT OF STOCK ribbon */}
                    {product.isOutOfStock && (
                      <div className="absolute top-0 left-0 right-0 bg-red-600 text-white text-center text-xs font-bold py-0.5 z-10">
                        OUT OF STOCK
                      </div>
                    )}

                    {/* NEW badge */}
                    {product.isNew && !product.isOutOfStock && (
                      <span className="absolute top-1 left-1 bg-green-500 text-white text-xs font-bold px-1.5 py-0.5 rounded z-10">
                        NEW
                      </span>
                    )}

                    {/* Discount badge */}
                    {discount > 0 && (
                      <span className="absolute top-1 right-1 bg-red-600 text-white text-xs font-bold px-1.5 py-0.5 rounded z-10">
                        -{discount}%
                      </span>
                    )}

                    {/* Product Image */}
                    <div className="h-36 bg-gray-50 flex items-center justify-center overflow-hidden">
                      {product.imageUrl ? (
                        <img
                          src={product.imageUrl}
                          alt={product.name}
                          className="h-full w-full object-cover"
                        />
                      ) : (
                        <div className="text-5xl">🛍️</div>
                      )}
                    </div>

                    {/* Product Details */}
                    <div className="p-2 flex flex-col flex-1">
                      <p className="text-xs text-gray-800 font-medium line-clamp-2 leading-tight mb-1 flex-1">
                        {product.name}
                      </p>
                      {product.unit && (
                        <p className="text-xs text-gray-400 mb-1">{product.unit}</p>
                      )}
                      <StarRating rating={4.2} />

                      {/* Price */}
                      <div className="mt-1 flex items-baseline gap-1 flex-wrap">
                        <span className="text-sm font-bold text-gray-900">₹{product.price}</span>
                        {product.offerPrice > 0 && product.offerPrice < product.price && (
                          <span className="text-xs text-gray-400 line-through">₹{product.offerPrice}</span>
                        )}
                      </div>

                      {/* Add to Cart */}
                      <button
                        disabled={product.isOutOfStock}
                        onClick={() => !product.isOutOfStock && handleAddToCart(product)}
                        className="mt-2 w-full text-xs font-bold py-1.5 rounded disabled:opacity-50 disabled:cursor-not-allowed hover:opacity-90 transition-opacity text-black"
                        style={{ backgroundColor: product.isOutOfStock ? '#ccc' : '#FF9900' }}
                      >
                        {product.isOutOfStock ? 'Out of Stock' : (config.primaryButtonText || 'Add to Cart')}
                      </button>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </section>

        {/* Delivery Info */}
        {(config.freeDeliveryAbove > 0 || config.minOrderAmount > 0) && (
          <div className="rounded-lg p-4 border border-yellow-300 bg-yellow-50 text-sm text-gray-700 flex flex-wrap gap-4">
            {config.freeDeliveryAbove > 0 && (
              <span>🚚 <strong>Free delivery</strong> on orders above ₹{config.freeDeliveryAbove}</span>
            )}
            {config.deliveryCharge > 0 && (
              <span>📦 Delivery charge: ₹{config.deliveryCharge}</span>
            )}
            {config.minOrderAmount > 0 && (
              <span>🛒 Minimum order: ₹{config.minOrderAmount}</span>
            )}
          </div>
        )}

        {/* About */}
        {config.aboutText && (
          <section className="bg-white rounded-lg p-4 border border-gray-200">
            <h3 className="font-bold text-gray-800 mb-2 text-sm">About {displayName}</h3>
            <p className="text-xs text-gray-600 leading-relaxed">{config.aboutText}</p>
          </section>
        )}
      </main>

      {/* ===== FOOTER ===== */}
      <footer className="mt-8 text-white" style={{ backgroundColor: '#131921' }}>
        <div className="max-w-7xl mx-auto px-4 py-8">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            {/* Shop Info */}
            <div>
              <h4 className="font-bold text-sm mb-3" style={{ color: '#FF9900' }}>{displayName}</h4>
              <p className="text-xs text-gray-400">{shop.shopType}</p>
              <p className="text-xs text-gray-400 mt-1">📍 {shop.district}, Kerala</p>
              <p className="text-xs text-gray-400 mt-1">📞 {shop.ownerPhone}</p>
              {config.storeHoursEnabled && config.storeHoursText && (
                <p className="text-xs text-gray-400 mt-1">🕒 {config.storeHoursText}</p>
              )}
            </div>

            {/* Quick Links */}
            <div>
              <h4 className="font-bold text-sm mb-3" style={{ color: '#FF9900' }}>Quick Links</h4>
              <ul className="space-y-1">
                {categories.slice(0, 6).map((cat) => (
                  <li key={cat}>
                    <button
                      onClick={() => setActiveCat(cat)}
                      className="text-xs text-gray-400 hover:text-yellow-400 transition-colors"
                    >
                      {cat}
                    </button>
                  </li>
                ))}
              </ul>
            </div>

            {/* Social + Contact */}
            <div>
              <h4 className="font-bold text-sm mb-3" style={{ color: '#FF9900' }}>Connect With Us</h4>
              <div className="flex gap-3 flex-wrap">
                {config.socialLinks?.instagram && (
                  <a href={config.socialLinks.instagram} target="_blank" rel="noopener noreferrer"
                     className="text-xs text-gray-400 hover:text-pink-400 transition-colors">
                    📸 Instagram
                  </a>
                )}
                {config.socialLinks?.facebook && (
                  <a href={config.socialLinks.facebook} target="_blank" rel="noopener noreferrer"
                     className="text-xs text-gray-400 hover:text-blue-400 transition-colors">
                    👍 Facebook
                  </a>
                )}
                {config.socialLinks?.youtube && (
                  <a href={config.socialLinks.youtube} target="_blank" rel="noopener noreferrer"
                     className="text-xs text-gray-400 hover:text-red-400 transition-colors">
                    ▶️ YouTube
                  </a>
                )}
                {config.socialLinks?.twitter && (
                  <a href={config.socialLinks.twitter} target="_blank" rel="noopener noreferrer"
                     className="text-xs text-gray-400 hover:text-sky-400 transition-colors">
                    🐦 Twitter
                  </a>
                )}
              </div>
              {config.whatsappEnabled && config.whatsappNumber && (
                <a
                  href={`https://wa.me/${config.whatsappNumber.replace(/\D/g, '')}`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center gap-2 mt-3 text-xs bg-green-600 hover:bg-green-500 text-white px-3 py-1.5 rounded-full transition-colors"
                >
                  💬 Chat on WhatsApp
                </a>
              )}
            </div>
          </div>

          <div className="border-t border-gray-700 mt-6 pt-4 text-center">
            <p className="text-xs text-gray-500">
              © {new Date().getFullYear()} {displayName}. All rights reserved. Powered by{' '}
              <span style={{ color: '#FF9900' }}>Wekerala</span>
            </p>
          </div>
        </div>
      </footer>

      {/* ===== WHATSAPP FLOATING BUTTON ===== */}
      {config.whatsappEnabled && config.whatsappNumber && (
        <a
          href={`https://wa.me/${config.whatsappNumber.replace(/\D/g, '')}`}
          target="_blank"
          rel="noopener noreferrer"
          className="fixed bottom-6 right-4 z-50 h-14 w-14 rounded-full bg-green-500 hover:bg-green-400 text-white flex items-center justify-center shadow-2xl transition-transform hover:scale-110"
          aria-label="Chat on WhatsApp"
        >
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className="h-7 w-7">
            <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347z"/>
            <path d="M12 0C5.373 0 0 5.373 0 12c0 2.123.554 4.118 1.528 5.852L0 24l6.362-1.488A11.945 11.945 0 0012 24c6.627 0 12-5.373 12-12S18.627 0 12 0zm0 22c-1.959 0-3.8-.535-5.378-1.465l-.385-.228-3.977.93.976-3.88-.252-.399A9.956 9.956 0 012 12C2 6.477 6.477 2 12 2s10 4.477 10 10-4.477 10-10 10z"/>
          </svg>
        </a>
      )}

      {/* ===== PRODUCT DETAIL SHEET ===== */}
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
    </div>
  );
}
