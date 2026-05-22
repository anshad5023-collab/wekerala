'use client';

import { useState, useEffect } from 'react';
import { getTheme, type WebsiteConfig } from '@/lib/theme-engine';

interface ShopData {
  shopName: string; shopNameMl: string; shopType: string;
  district: string; ownerPhone: string; logoUrl: string; bannerImageUrl: string;
}
interface Product {
  productId: string; name: string; price: number; offerPrice: number;
  unit: string; imageUrl: string; category: string; isOutOfStock: boolean;
  isFeatured?: boolean; isNew?: boolean; description?: string;
}
interface Props { config: WebsiteConfig; shop: ShopData; products: Product[]; shopId?: string }

function WAFloat({ config, shop }: { config: WebsiteConfig; shop: ShopData }) {
  if (!config.whatsappEnabled) return null;
  const num = config.whatsappNumber || shop.ownerPhone;
  return (
    <a href={`https://wa.me/${num}`} target="_blank" rel="noreferrer"
      className="fixed bottom-6 right-4 w-14 h-14 bg-green-500 rounded-full flex items-center justify-center shadow-xl text-2xl z-50 hover:scale-110 transition-transform">
      💬
    </a>
  );
}

function WABtn({ config, shop, className = '', style = {} }: { config: WebsiteConfig; shop: ShopData; className?: string; style?: React.CSSProperties }) {
  if (!config.whatsappEnabled) return null;
  const num = config.whatsappNumber || shop.ownerPhone;
  const label = config.primaryButtonText || 'Order Now';
  return (
    <a href={`https://wa.me/${num}`} target="_blank" rel="noreferrer"
      className={`inline-block px-6 py-2.5 rounded-full text-white font-semibold ${className}`}
      style={{ backgroundColor: '#25D366', ...style }}>
      💬 {label}
    </a>
  );
}

function OrderBtn({ waNum, primaryColor, label = 'Order Now' }: { waNum: string; primaryColor: string; label?: string }) {
  if (!waNum) return null;
  return (
    <a href={`https://wa.me/${waNum}`} target="_blank" rel="noreferrer"
      className="inline-block px-6 py-2.5 rounded-full text-white font-semibold"
      style={{ backgroundColor: primaryColor }}>
      🛒 {label}
    </a>
  );
}

function ProductOrderBtn({ waNum, productName, price, primaryColor, className = '' }: {
  waNum: string; productName: string; price: number; primaryColor: string; className?: string;
}) {
  if (!waNum) return null;
  const msg = encodeURIComponent(`Hi, I'd like to order: ${productName} (₹${price})`);
  return (
    <a href={`https://wa.me/${waNum}?text=${msg}`} target="_blank" rel="noreferrer"
      className={`mt-2 block text-center text-xs font-semibold py-1.5 rounded-lg text-white ${className}`}
      style={{ backgroundColor: primaryColor }}>
      Order
    </a>
  );
}

function BannerCarousel({ banners }: { banners: string[] }) {
  const [slide, setSlide] = useState(0);
  useEffect(() => {
    if (banners.length < 2) return;
    const t = setInterval(() => setSlide(i => (i + 1) % banners.length), 3500);
    return () => clearInterval(t);
  }, [banners.length]);
  if (banners.length === 0) return null;
  return (
    <div className="relative w-full h-52 overflow-hidden">
      <img src={banners[slide] || ''} alt="banner" className="w-full h-full object-cover" />
      {banners.length > 1 && (
        <div className="absolute bottom-2 left-0 right-0 flex justify-center gap-1.5">
          {banners.map((_, i) => (
            <button key={i} onClick={() => setSlide(i)}
              className="w-2 h-2 rounded-full transition-all"
              style={{ backgroundColor: i === slide ? '#fff' : 'rgba(255,255,255,0.5)' }} />
          ))}
        </div>
      )}
    </div>
  );
}

function CouponPromo({ config }: { config: WebsiteConfig }) {
  const active = (config.couponCodes ?? []).filter(c => c.active);
  if (active.length === 0) return null;
  const c = active[0];
  return (
    <div className="mx-4 my-3 rounded-xl border-2 border-dashed px-4 py-3 flex items-center gap-3"
      style={{ borderColor: config.primaryColor, backgroundColor: `${config.primaryColor}10` }}>
      <span className="text-xl">🎟</span>
      <div>
        <p className="text-sm font-bold" style={{ color: config.primaryColor }}>
          Use code <span className="font-mono tracking-widest">{c.code}</span> for {c.discountPercent}% off!
        </p>
        {active.length > 1 && <p className="text-xs opacity-60">{active.length} offers available</p>}
      </div>
    </div>
  );
}

function CategoryTabs({ cats, active, onSelect, primaryColor }: { cats: string[]; active: string; onSelect: (c: string) => void; primaryColor: string }) {
  if (cats.length <= 1) return null;
  return (
    <div className="flex gap-2 px-4 py-3 overflow-x-auto" style={{ scrollbarWidth: 'none' }}>
      {cats.map(c => (
        <button key={c} onClick={() => onSelect(c)}
          className="shrink-0 px-4 py-1.5 rounded-full text-sm font-medium transition-colors"
          style={active === c ? { backgroundColor: primaryColor, color: '#fff' } : { backgroundColor: '#f3f4f6', color: '#374151' }}>
          {c}
        </button>
      ))}
    </div>
  );
}

function ProductSearch({ value, onChange, primaryColor }: { value: string; onChange: (v: string) => void; primaryColor: string }) {
  return (
    <div className="px-4 pt-3 pb-1">
      <div className="flex items-center gap-2 rounded-xl border bg-white px-3 py-2" style={{ borderColor: `${primaryColor}30` }}>
        <span className="text-gray-400 text-sm">🔍</span>
        <input
          type="text"
          value={value}
          onChange={e => onChange(e.target.value)}
          placeholder="Search products…"
          className="flex-1 text-sm outline-none bg-transparent text-gray-700 placeholder-gray-400"
        />
        {value && (
          <button onClick={() => onChange('')} className="text-gray-400 text-xs">✕</button>
        )}
      </div>
    </div>
  );
}

// ── CLEAN (Modern) — fully responsive mobile + desktop ──────────────────────────
function CleanLayout({ config, shop, products, shopId }: Props) {
  const p = config.primaryColor;
  const waNum = config.whatsappEnabled !== false ? (config.whatsappNumber || shop.ownerPhone) : '';
  const banners = [shop.bannerImageUrl, ...(config.banners ?? [])].filter(Boolean);
  const has = (s: string) => config.sections.includes(s);
  const [activeCat, setActiveCat] = useState('All');
  const [search, setSearch] = useState('');
  const cats = ['All', ...Array.from(new Set(products.map(pr => pr.category).filter(Boolean)))];
  const visible = products.filter(pr =>
    (activeCat === 'All' || pr.category === activeCat) &&
    (!search || pr.name.toLowerCase().includes(search.toLowerCase()))
  );
  const hasCats = cats.length > 1;

  return (
    <div className="min-h-screen bg-gray-50 text-gray-900">
      {/* ── Top header bar (desktop) ── */}
      <header className="sticky top-0 z-40 bg-white border-b border-gray-200 shadow-sm">
        <div className="max-w-7xl mx-auto px-4 py-3 flex items-center gap-4">
          {shop.logoUrl
            ? <img src={shop.logoUrl} alt="logo" className="w-10 h-10 rounded-full object-cover border-2 shrink-0" style={{ borderColor: p }} />
            : <div className="w-10 h-10 rounded-full flex items-center justify-center text-white font-bold text-lg shrink-0" style={{ backgroundColor: p }}>{(config.siteName || shop.shopName).charAt(0)}</div>
          }
          <div className="flex-1 min-w-0">
            <p className="font-bold text-base leading-tight truncate">{config.siteName || shop.shopName}</p>
            <p className="text-xs text-gray-400 truncate">{shop.shopType}{shop.district ? ` · ${shop.district}` : ''}</p>
          </div>
          {/* Search bar — grows in header on desktop */}
          <div className="hidden md:flex flex-1 max-w-md items-center gap-2 rounded-xl border bg-gray-50 px-3 py-2" style={{ borderColor: `${p}30` }}>
            <span className="text-gray-400 text-sm">🔍</span>
            <input
              type="text"
              value={search}
              onChange={e => setSearch(e.target.value)}
              placeholder="Search products…"
              className="flex-1 text-sm outline-none bg-transparent text-gray-700 placeholder-gray-400"
            />
            {search && <button onClick={() => setSearch('')} className="text-gray-400 text-xs">✕</button>}
          </div>
          {waNum && (
            <a href={`https://wa.me/${waNum}`} target="_blank" rel="noreferrer"
              className="hidden md:inline-flex items-center gap-1.5 px-4 py-2 rounded-full text-white text-sm font-semibold shrink-0"
              style={{ backgroundColor: '#25D366' }}>
              💬 {config.primaryButtonText || 'Order Now'}
            </a>
          )}
        </div>
        {/* Announcement bar */}
        {config.announcementBarEnabled && config.announcementBar && (
          <div className="text-center text-xs py-1.5 text-white font-medium" style={{ backgroundColor: config.announcementBarColor || p }}>
            🔔 {config.announcementBar}
          </div>
        )}
      </header>

      {/* ── Banner (full width, below header) ── */}
      {has('hero') && banners.length > 0 && (
        <div className="max-w-7xl mx-auto">
          <BannerCarousel banners={banners} />
        </div>
      )}

      <CouponPromo config={config} />

      {/* ── Main content: sidebar + products ── */}
      <div className="max-w-7xl mx-auto flex gap-0 md:gap-6 px-0 md:px-4 pb-12 mt-2">

        {/* Category sidebar — desktop only */}
        {hasCats && (
          <aside className="hidden md:block w-48 shrink-0">
            <div className="bg-white rounded-xl border border-gray-200 overflow-hidden sticky top-20">
              <p className="px-4 py-3 text-xs font-bold text-gray-500 uppercase tracking-wider border-b border-gray-100">Categories</p>
              {cats.map(c => (
                <button key={c} onClick={() => setActiveCat(c)}
                  className="w-full text-left px-4 py-2.5 text-sm transition-colors hover:bg-gray-50"
                  style={activeCat === c ? { backgroundColor: `${p}15`, color: p, fontWeight: 700 } : { color: '#374151' }}>
                  {c === 'All' ? '🏪 All Products' : c}
                </button>
              ))}
            </div>
          </aside>
        )}

        {/* Product area */}
        <main className="flex-1 min-w-0">
          {/* Mobile search */}
          <div className="md:hidden px-4 pt-3 pb-1">
            <div className="flex items-center gap-2 rounded-xl border bg-white px-3 py-2" style={{ borderColor: `${p}30` }}>
              <span className="text-gray-400 text-sm">🔍</span>
              <input type="text" value={search} onChange={e => setSearch(e.target.value)}
                placeholder="Search products…"
                className="flex-1 text-sm outline-none bg-transparent text-gray-700 placeholder-gray-400" />
              {search && <button onClick={() => setSearch('')} className="text-gray-400 text-xs">✕</button>}
            </div>
          </div>

          {/* Mobile category tabs */}
          {hasCats && (
            <div className="md:hidden flex gap-2 px-4 py-2 overflow-x-auto" style={{ scrollbarWidth: 'none' }}>
              {cats.map(c => (
                <button key={c} onClick={() => setActiveCat(c)}
                  className="shrink-0 px-4 py-1.5 rounded-full text-sm font-medium transition-colors"
                  style={activeCat === c ? { backgroundColor: p, color: '#fff' } : { backgroundColor: '#f3f4f6', color: '#374151' }}>
                  {c}
                </button>
              ))}
            </div>
          )}

          {/* Bestsellers row */}
          {has('products') && products.some(pr => pr.isFeatured) && !search && activeCat === 'All' && (
            <div className="px-4 pt-3 pb-2">
              <h3 className="font-bold text-sm mb-3" style={{ color: p }}>⭐ Bestsellers</h3>
              <div className="flex gap-3 overflow-x-auto pb-1" style={{ scrollbarWidth: 'none' }}>
                {products.filter(pr => pr.isFeatured).map(pr => (
                  <div key={pr.productId} className="shrink-0 w-28 border border-gray-100 rounded-xl overflow-hidden bg-white shadow-sm">
                    {pr.imageUrl && <img src={pr.imageUrl} alt={pr.name} className="w-full h-20 object-cover" />}
                    <div className="p-1.5">
                      <p className="text-xs font-medium line-clamp-2">{pr.name}</p>
                      <p className="text-xs font-bold mt-0.5" style={{ color: p }}>₹{pr.price}</p>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Product grid */}
          {has('products') && (
            <div className="px-4 pt-2">
              {visible.length === 0 ? (
                <div className="text-center py-16">
                  <p className="text-4xl mb-3">🛒</p>
                  <p className="text-gray-400 font-medium">No products found</p>
                  {search && <button onClick={() => setSearch('')} className="text-sm mt-2 underline" style={{ color: p }}>Clear search</button>}
                </div>
              ) : (
                <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-3">
                  {visible.map(pr => {
                    const hasOffer = pr.offerPrice > 0 && pr.offerPrice < pr.price;
                    const discPct = hasOffer ? Math.round((1 - pr.price / pr.offerPrice) * 100) : 0;
                    return (
                      <div key={pr.productId} className="bg-white border border-gray-100 rounded-xl shadow-sm overflow-hidden hover:shadow-md transition-shadow">
                        <div className="relative">
                          {pr.imageUrl
                            ? <img src={pr.imageUrl} alt={pr.name} className="w-full h-36 object-cover" />
                            : <div className="w-full h-36 bg-gray-100 flex items-center justify-center text-3xl">🛍</div>
                          }
                          {pr.isNew && <span className="absolute top-1.5 left-1.5 text-xs font-bold bg-blue-500 text-white px-1.5 py-0.5 rounded-full">New</span>}
                          {pr.isFeatured && <span className="absolute top-1.5 right-1.5 text-xs font-bold bg-amber-400 text-white px-1.5 py-0.5 rounded-full">⭐</span>}
                          {hasOffer && <span className="absolute bottom-1.5 left-1.5 text-xs font-bold bg-red-500 text-white px-1.5 py-0.5 rounded-full">{discPct}% OFF</span>}
                          {pr.isOutOfStock && (
                            <div className="absolute inset-0 bg-black/40 flex items-center justify-center">
                              <span className="text-white text-xs font-bold bg-black/60 px-2 py-1 rounded">Out of Stock</span>
                            </div>
                          )}
                        </div>
                        <div className="p-2.5">
                          <p className="text-sm font-medium line-clamp-2 leading-snug">{pr.name}</p>
                          {pr.unit && <p className="text-xs text-gray-400 mt-0.5">{pr.unit}</p>}
                          <div className="flex items-center gap-1.5 mt-1.5">
                            <p className="text-sm font-bold" style={{ color: p }}>₹{pr.price}</p>
                            {hasOffer && <p className="text-xs text-gray-400 line-through">₹{pr.offerPrice}</p>}
                          </div>
                          {!pr.isOutOfStock && <ProductOrderBtn waNum={waNum} productName={pr.name} price={pr.price} primaryColor={p} />}
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          )}

          {/* About & Contact sections */}
          {has('about') && (
            <section className="mx-4 mt-6 px-6 py-8 bg-white rounded-xl border border-gray-100">
              <h2 className="font-semibold text-lg mb-2" style={{ color: p }}>About Us</h2>
              <p className="text-gray-600">{config.aboutText || `Welcome to ${config.siteName || shop.shopName}!`}</p>
              {config.storeHoursEnabled && config.storeHoursText && (
                <p className="text-sm text-gray-500 mt-3">🕐 {config.storeHoursText}</p>
              )}
            </section>
          )}
          {has('contact') && (
            <section className="mx-4 mt-4 px-6 py-8 bg-white rounded-xl border border-gray-100">
              <h2 className="font-semibold text-lg mb-3" style={{ color: p }}>Contact</h2>
              <p className="text-gray-600">{shop.district}, Kerala</p>
              {shop.ownerPhone && <p className="text-gray-600 mt-1">📞 {shop.ownerPhone}</p>}
              <div className="mt-4"><WABtn config={config} shop={shop} /></div>
            </section>
          )}
        </main>
      </div>

      <WAFloat config={config} shop={shop} />
    </div>
  );
}

// ── DARK (Bold) ─────────────────────────────────────────────────────────────────
function DarkLayout({ config, shop, products, shopId }: Props) {
  const p = config.primaryColor; const bg = '#1a1a2e';
  const waNum = config.whatsappEnabled !== false ? (config.whatsappNumber || shop.ownerPhone) : '';
  const banners = [shop.bannerImageUrl, ...(config.banners ?? [])].filter(Boolean);
  const has = (s: string) => config.sections.includes(s);
  const [activeCat, setActiveCat] = useState('All');
  const cats = ['All', ...Array.from(new Set(products.map(pr => pr.category).filter(Boolean)))];
  const visible = activeCat === 'All' ? products : products.filter(pr => pr.category === activeCat);
  return (
    <div className="min-h-screen text-white" style={{ backgroundColor: bg }}>
      {has('hero') && (
        <section className="relative">
          {banners.length > 0 && (
            <div className="relative h-60 overflow-hidden">
              <BannerCarousel banners={banners} />
              <div className="absolute inset-0 bg-gradient-to-b from-transparent to-[#1a1a2e] pointer-events-none" />
            </div>
          )}
          <div className="px-6 py-6 text-center">
            {shop.logoUrl && <img src={shop.logoUrl} alt="logo" className="w-14 h-14 rounded-full mx-auto mb-2 object-cover border-2" style={{ borderColor: p }} />}
            <h1 className="text-3xl font-bold" style={{ color: p }}>{config.siteName || shop.shopName}</h1>
            {config.tagline && <p className="text-gray-400 mt-1">{config.tagline}</p>}
            {shopId && <div className="mt-4"><OrderBtn waNum={waNum} primaryColor={p} label={config.primaryButtonText} /></div>}
          </div>
        </section>
      )}
      <CouponPromo config={config} />
      {has('products') && products.length > 0 && (
        <section className="pb-6 max-w-7xl mx-auto">
          <CategoryTabs cats={cats} active={activeCat} onSelect={setActiveCat} primaryColor={p} />
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-3 px-4">
            {visible.map(pr => (
              <div key={pr.productId} className="rounded-xl overflow-hidden border-l-4" style={{ backgroundColor: '#0d0d1f', borderColor: p }}>
                {pr.imageUrl && <img src={pr.imageUrl} alt={pr.name} className="w-full h-24 object-cover opacity-80" />}
                <div className="p-2">
                  <p className="text-sm font-medium text-white line-clamp-2">{pr.name}</p>
                  <p className="text-sm font-bold mt-1" style={{ color: p }}>₹{pr.price}</p>
                  {pr.isOutOfStock && <p className="text-xs text-red-400">Out of stock</p>}
                  {!pr.isOutOfStock && <ProductOrderBtn waNum={waNum} productName={pr.name} price={pr.price} primaryColor={p} className="rounded" />}
                </div>
              </div>
            ))}
          </div>
        </section>
      )}
      {has('about') && (
        <section className="px-6 py-8" style={{ backgroundColor: '#0d0d1f' }}>
          <h2 className="font-bold text-lg mb-2" style={{ color: p }}>About</h2>
          <p className="text-gray-400">{config.aboutText || `Welcome to ${config.siteName || shop.shopName}!`}</p>
          {config.storeHoursEnabled && config.storeHoursText && (
            <p className="text-sm text-gray-500 mt-3">🕐 {config.storeHoursText}</p>
          )}
        </section>
      )}
      {has('contact') && (
        <section className="px-6 py-8 text-center">
          <p className="text-gray-400">{shop.district}, Kerala</p>
          {shop.ownerPhone && <p className="text-gray-400 mt-1">📞 {shop.ownerPhone}</p>}
          <div className="mt-4"><WABtn config={config} shop={shop} /></div>
        </section>
      )}
      <WAFloat config={config} shop={shop} />
    </div>
  );
}

// ── WARM (Traditional) ──────────────────────────────────────────────────────────
function WarmLayout({ config, shop, products, shopId }: Props) {
  const p = config.primaryColor; const bg = '#fef9f0';
  const waNum = config.whatsappEnabled !== false ? (config.whatsappNumber || shop.ownerPhone) : '';
  const banners = [shop.bannerImageUrl, ...(config.banners ?? [])].filter(Boolean);
  const has = (s: string) => config.sections.includes(s);
  const [activeCat, setActiveCat] = useState('All');
  const cats = ['All', ...Array.from(new Set(products.map(pr => pr.category).filter(Boolean)))];
  const visible = activeCat === 'All' ? products : products.filter(pr => pr.category === activeCat);
  return (
    <div className="min-h-screen" style={{ backgroundColor: bg, color: p }}>
      <div className="h-1.5 w-full" style={{ backgroundColor: p }} />
      {has('hero') && (
        <section>
          <BannerCarousel banners={banners} />
          <div className="p-6 text-center border-b-4" style={{ borderColor: config.secondaryColor }}>
            {shop.logoUrl && <img src={shop.logoUrl} alt="logo" className="w-16 h-16 rounded-full mx-auto mb-3 object-cover border-4" style={{ borderColor: config.secondaryColor }} />}
            <h1 className="text-2xl font-bold" style={{ color: p }}>{config.siteName || shop.shopName}</h1>
            {config.tagline && <p className="mt-1" style={{ color: config.secondaryColor }}>{config.tagline}</p>}
            <p className="text-xs opacity-60 mt-1">{shop.shopType} · {shop.district}</p>
            {shopId && <div className="mt-4"><OrderBtn waNum={waNum} primaryColor={p} label={config.primaryButtonText} /></div>}
          </div>
        </section>
      )}
      <CouponPromo config={config} />
      {has('products') && products.length > 0 && (
        <section className="py-4 max-w-7xl mx-auto">
          <CategoryTabs cats={cats} active={activeCat} onSelect={setActiveCat} primaryColor={p} />
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-3 px-4">
            {visible.map(pr => {
              const hasOffer = pr.offerPrice > 0 && pr.offerPrice < pr.price;
              const discPct = hasOffer ? Math.round((1 - pr.price / pr.offerPrice) * 100) : 0;
              return (
                <div key={pr.productId} className="rounded-xl overflow-hidden border-2 relative" style={{ borderColor: config.secondaryColor, backgroundColor: '#fffbf5' }}>
                  <div className="relative">
                    {pr.imageUrl && <img src={pr.imageUrl} alt={pr.name} className="w-full h-28 object-cover rounded-t-xl" />}
                    {hasOffer && <span className="absolute top-1 left-1 text-xs font-bold bg-red-500 text-white px-1.5 py-0.5 rounded-full">{discPct}% OFF</span>}
                  </div>
                  <div className="p-2">
                    <p className="text-sm font-medium line-clamp-2" style={{ color: p }}>{pr.name}</p>
                    <div className="flex items-center gap-1 mt-0.5">
                      <p className="text-sm font-bold" style={{ color: config.secondaryColor }}>₹{pr.price}</p>
                      {hasOffer && <p className="text-xs text-gray-400 line-through">₹{pr.offerPrice}</p>}
                    </div>
                    {pr.isOutOfStock && <p className="text-xs text-red-500">Out of stock</p>}
                    {!pr.isOutOfStock && <ProductOrderBtn waNum={waNum} productName={pr.name} price={pr.price} primaryColor={p} />}
                  </div>
                </div>
              );
            })}
          </div>
        </section>
      )}
      {has('about') && (
        <section className="px-6 py-8 text-center" style={{ backgroundColor: '#fdf5e6' }}>
          <h2 className="font-bold text-lg mb-2" style={{ color: p }}>About Us</h2>
          <p style={{ color: '#5a4a3a' }}>{config.aboutText || `Welcome to ${config.siteName || shop.shopName}!`}</p>
          {config.storeHoursEnabled && config.storeHoursText && (
            <p className="text-sm mt-3 opacity-70">🕐 {config.storeHoursText}</p>
          )}
        </section>
      )}
      {has('contact') && (
        <section className="px-6 py-8 text-center">
          <p style={{ color: '#5a4a3a' }}>{shop.district}, Kerala</p>
          {shop.ownerPhone && <p className="mt-1" style={{ color: '#5a4a3a' }}>📞 {shop.ownerPhone}</p>}
          <div className="mt-4"><WABtn config={config} shop={shop} style={{ backgroundColor: p }} /></div>
        </section>
      )}
      <WAFloat config={config} shop={shop} />
    </div>
  );
}

// ── NEOPOP (Amaze) ──────────────────────────────────────────────────────────────
function NeopopLayout({ config, shop, products, shopId }: Props) {
  const p = config.primaryColor; const s = config.secondaryColor;
  const waNum = config.whatsappEnabled !== false ? (config.whatsappNumber || shop.ownerPhone) : '';
  const banners = [shop.bannerImageUrl, ...(config.banners ?? [])].filter(Boolean);
  const has = (sec: string) => config.sections.includes(sec);
  const [activeCat, setActiveCat] = useState('All');
  const cats = ['All', ...Array.from(new Set(products.map(pr => pr.category).filter(Boolean)))];
  const visible = activeCat === 'All' ? products : products.filter(pr => pr.category === activeCat);
  return (
    <div className="min-h-screen text-white" style={{ backgroundColor: '#0a0a0a' }}>
      {has('hero') && (
        <section className="relative overflow-hidden">
          <div className="h-64 flex items-end pb-6 px-6 relative" style={{ background: `linear-gradient(135deg, ${p}, ${s})` }}>
            {banners[0] && <img src={banners[0]} alt="banner" className="absolute inset-0 w-full h-full object-cover mix-blend-overlay opacity-30" />}
            <div className="relative z-10">
              {shop.logoUrl && <img src={shop.logoUrl} alt="logo" className="w-12 h-12 rounded-full mb-2 object-cover border-2 border-white" />}
              <h1 className="text-3xl font-black text-white leading-tight">{config.siteName || shop.shopName}</h1>
              {config.tagline && <p className="text-white/80 mt-1 text-sm">{config.tagline}</p>}
              {shopId && <div className="mt-3"><OrderBtn waNum={waNum} primaryColor={p} label={config.primaryButtonText} /></div>}
            </div>
          </div>
        </section>
      )}
      <CouponPromo config={config} />
      {has('products') && products.length > 0 && (
        <section className="py-6 max-w-7xl mx-auto">
          <CategoryTabs cats={cats} active={activeCat} onSelect={setActiveCat} primaryColor={p} />
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-3 px-4">
            {visible.map(pr => (
              <div key={pr.productId} className="rounded-xl overflow-hidden border-2" style={{ backgroundColor: '#151515', borderColor: p, boxShadow: `0 0 16px ${p}30` }}>
                {pr.imageUrl && <img src={pr.imageUrl} alt={pr.name} className="w-full h-28 object-cover" />}
                <div className="p-2">
                  <p className="text-sm font-semibold text-white line-clamp-2">{pr.name}</p>
                  <p className="font-black mt-1" style={{ color: p }}>₹{pr.price}</p>
                  {pr.isOutOfStock && <p className="text-xs text-red-400">Out of stock</p>}
                  {!pr.isOutOfStock && <ProductOrderBtn waNum={waNum} productName={pr.name} price={pr.price} primaryColor={p} className="rounded font-black" />}
                </div>
              </div>
            ))}
          </div>
        </section>
      )}
      {has('about') && (
        <section className="px-6 py-8 border-t border-white/10">
          <h2 className="font-black text-xl mb-2" style={{ color: p }}>About</h2>
          <p className="text-gray-400">{config.aboutText || `Welcome to ${config.siteName || shop.shopName}!`}</p>
          {config.storeHoursEnabled && config.storeHoursText && (
            <p className="text-sm text-gray-500 mt-3">🕐 {config.storeHoursText}</p>
          )}
        </section>
      )}
      {has('contact') && (
        <section className="px-6 py-8 text-center">
          <p className="text-gray-500">{shop.district}, Kerala · {shop.ownerPhone}</p>
          <div className="mt-4">
            <WABtn config={config} shop={shop} className="font-black" style={{ background: `linear-gradient(135deg, ${p}, ${s})`, boxShadow: `0 0 20px ${p}50` }} />
          </div>
        </section>
      )}
      <WAFloat config={config} shop={shop} />
    </div>
  );
}

// ── EDITORIAL (Helsinki + Mana) ─────────────────────────────────────────────────
function EditorialLayout({ config, shop, products, shopId }: Props) {
  const p = config.primaryColor;
  const waNum = config.whatsappEnabled !== false ? (config.whatsappNumber || shop.ownerPhone) : '';
  const banners = [shop.bannerImageUrl, ...(config.banners ?? [])].filter(Boolean);
  const has = (s: string) => config.sections.includes(s);
  const isLight = config.secondaryColor.startsWith('#8') || config.secondaryColor.startsWith('#9');
  return (
    <div className="min-h-screen" style={{ backgroundColor: config.themeId === 'mana' ? '#ffffff' : '#f5f5f5', color: '#1a1a1a' }}>
      {has('hero') && (
        <section>
          {banners[0] ? (
            <div className="relative h-72">
              <img src={banners[0]} alt="banner" className="w-full h-full object-cover" />
              <div className="absolute inset-0 bg-black/20 flex flex-col items-center justify-center px-6 text-center">
                <h1 className="text-4xl font-bold text-white leading-tight">{config.siteName || shop.shopName}</h1>
                {config.tagline && <p className="text-white/80 mt-2">{config.tagline}</p>}
              </div>
            </div>
          ) : (
            <div className="px-6 py-12 text-center border-b">
              {shop.logoUrl && <img src={shop.logoUrl} alt="logo" className="w-16 h-16 rounded-full mx-auto mb-4 object-cover" />}
              <h1 className="text-3xl font-bold">{config.siteName || shop.shopName}</h1>
              {config.tagline && <p className="mt-2" style={{ color: isLight ? config.secondaryColor : '#888' }}>{config.tagline}</p>}
            </div>
          )}
          <div className="px-6 py-2 flex items-center gap-4 text-sm border-b">
            <span style={{ color: p }}>{shop.shopType}</span>
            <span className="text-gray-400">·</span>
            <span className="text-gray-500">{shop.district}</span>
          </div>
        </section>
      )}
      <CouponPromo config={config} />
      {has('products') && products.length > 0 && (
        <section className="px-4 py-6 max-w-7xl mx-auto">
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-4">
            {products.map(pr => (
              <div key={pr.productId} className="bg-white rounded-lg overflow-hidden">
                {pr.imageUrl && <img src={pr.imageUrl} alt={pr.name} className="w-full h-36 object-cover" />}
                <div className="p-3">
                  <p className="text-sm font-semibold line-clamp-2">{pr.name}</p>
                  <div className="flex items-baseline gap-2 mt-1">
                    <p className="font-bold" style={{ color: p }}>₹{pr.price}</p>
                    {pr.unit && <p className="text-xs text-gray-400">{pr.unit}</p>}
                  </div>
                  {pr.isOutOfStock && <p className="text-xs text-red-500 mt-1">Out of stock</p>}
                  {!pr.isOutOfStock && <ProductOrderBtn waNum={waNum} productName={pr.name} price={pr.price} primaryColor={p} className="rounded" />}
                </div>
              </div>
            ))}
          </div>
        </section>
      )}
      {has('about') && (
        <section className="px-8 py-10 text-center max-w-lg mx-auto">
          <h2 className="text-2xl font-bold mb-3" style={{ color: p }}>About Us</h2>
          <p className="text-gray-600 leading-relaxed">{config.aboutText || `Welcome to ${config.siteName || shop.shopName}!`}</p>
          {config.storeHoursEnabled && config.storeHoursText && (
            <p className="text-sm text-gray-400 mt-4">🕐 {config.storeHoursText}</p>
          )}
        </section>
      )}
      {has('contact') && (
        <section className="px-6 py-8 text-center border-t">
          <p className="text-gray-500">{shop.district}, Kerala</p>
          {shop.ownerPhone && <p className="text-gray-600 mt-1">📞 {shop.ownerPhone}</p>}
          <div className="mt-4"><WABtn config={config} shop={shop} style={{ backgroundColor: p }} /></div>
        </section>
      )}
      <WAFloat config={config} shop={shop} />
    </div>
  );
}

// ── CAROUSEL (Catalyst) ─────────────────────────────────────────────────────────
function CarouselLayout({ config, shop, products, shopId }: Props) {
  const p = config.primaryColor;
  const waNum = config.whatsappEnabled !== false ? (config.whatsappNumber || shop.ownerPhone) : '';
  const banners = [shop.bannerImageUrl, ...(config.banners ?? [])].filter(Boolean);
  const [activeCat, setActiveCat] = useState('All');
  const [search, setSearch] = useState('');
  const has = (s: string) => config.sections.includes(s);

  const cats = ['All', ...Array.from(new Set(products.map(pr => pr.category).filter(Boolean)))];
  const visible = products.filter(pr =>
    (activeCat === 'All' || pr.category === activeCat) &&
    (!search || pr.name.toLowerCase().includes(search.toLowerCase()))
  );

  return (
    <div className="min-h-screen bg-white text-gray-900">
      {has('hero') && (
        <section>
          {banners.length > 0 && (
            <div className="relative">
              <BannerCarousel banners={banners} />
              <div className="absolute inset-0 flex flex-col justify-end p-6 bg-gradient-to-t from-black/50 pointer-events-none">
                <h1 className="text-2xl font-bold text-white">{config.siteName || shop.shopName}</h1>
                {config.tagline && <p className="text-white/80 text-sm">{config.tagline}</p>}
              </div>
            </div>
          )}
          {!banners.length && (
            <div className="px-6 py-8 text-center">
              <h1 className="text-2xl font-bold" style={{ color: p }}>{config.siteName || shop.shopName}</h1>
              {config.tagline && <p className="text-gray-500 mt-1">{config.tagline}</p>}
            </div>
          )}
          {shopId && <div className="px-4 py-3 text-center"><OrderBtn waNum={waNum} primaryColor={p} label={config.primaryButtonText} /></div>}
        </section>
      )}
      <CouponPromo config={config} />
      {has('products') && products.length > 0 && (
        <section className="pb-6">
          <ProductSearch value={search} onChange={setSearch} primaryColor={p} />
          <CategoryTabs cats={cats} active={activeCat} onSelect={setActiveCat} primaryColor={p} />
          <div className="grid grid-cols-2 md:grid-cols-3 gap-3 px-4">
            {visible.length === 0 && (
              <p className="col-span-2 text-center text-sm text-gray-400 py-8">No products found</p>
            )}
            {visible.map(pr => (
              <div key={pr.productId} className="bg-white border border-gray-100 rounded-xl shadow-sm overflow-hidden">
                {pr.imageUrl && <img src={pr.imageUrl} alt={pr.name} className="w-full h-28 object-cover" />}
                <div className="p-2">
                  <p className="text-sm font-medium line-clamp-2">{pr.name}</p>
                  <p className="text-sm font-bold mt-1" style={{ color: p }}>₹{pr.price}</p>
                  {pr.isOutOfStock && <p className="text-xs text-red-500">Out of stock</p>}
                  {!pr.isOutOfStock && <ProductOrderBtn waNum={waNum} productName={pr.name} price={pr.price} primaryColor={p} />}
                </div>
              </div>
            ))}
          </div>
        </section>
      )}
      {has('about') && (
        <section className="px-6 py-8 bg-gray-50 text-center">
          <h2 className="font-bold text-lg mb-2" style={{ color: p }}>About</h2>
          <p className="text-gray-600">{config.aboutText || `Welcome to ${config.siteName || shop.shopName}!`}</p>
          {config.storeHoursEnabled && config.storeHoursText && (
            <p className="text-sm text-gray-400 mt-3">🕐 {config.storeHoursText}</p>
          )}
        </section>
      )}
      {has('contact') && (
        <section className="px-6 py-8 text-center">
          <p className="text-gray-500">{shop.district} · {shop.ownerPhone}</p>
          <div className="mt-4"><WABtn config={config} shop={shop} style={{ backgroundColor: p }} /></div>
        </section>
      )}
      <WAFloat config={config} shop={shop} />
    </div>
  );
}

// ── LUXURY (Oxford) ─────────────────────────────────────────────────────────────
function LuxuryLayout({ config, shop, products, shopId }: Props) {
  const p = config.primaryColor;
  const waNum = config.whatsappEnabled !== false ? (config.whatsappNumber || shop.ownerPhone) : '';
  const banners = [shop.bannerImageUrl, ...(config.banners ?? [])].filter(Boolean);
  const has = (s: string) => config.sections.includes(s);
  return (
    <div className="min-h-screen text-white" style={{ backgroundColor: '#0d0d0d' }}>
      <div className="h-0.5 w-full" style={{ backgroundColor: p }} />
      {has('hero') && (
        <section className="relative">
          {banners[0] && <img src={banners[0]} alt="banner" className="w-full h-56 object-cover opacity-20" />}
          <div className="px-6 py-8 text-center" style={{ marginTop: banners[0] ? '-56px' : '0' }}>
            {shop.logoUrl && <img src={shop.logoUrl} alt="logo" className="w-16 h-16 rounded-full mx-auto mb-4 object-cover border-2" style={{ borderColor: p }} />}
            <h1 className="text-3xl font-bold tracking-widest uppercase" style={{ color: p }}>{config.siteName || shop.shopName}</h1>
            {config.tagline && <p className="mt-2 tracking-wider text-sm opacity-60">{config.tagline}</p>}
          </div>
          <div className="h-px mx-6" style={{ backgroundColor: p }} />
        </section>
      )}
      <CouponPromo config={config} />
      {has('products') && products.length > 0 && (
        <section className="px-4 py-6 space-y-3">
          <h2 className="font-bold tracking-widest text-sm uppercase mb-4" style={{ color: p }}>Collection</h2>
          {products.map(pr => (
            <div key={pr.productId} className="flex gap-3 border rounded-xl overflow-hidden" style={{ borderColor: `${p}30`, backgroundColor: '#111' }}>
              {pr.imageUrl ? (
                <img src={pr.imageUrl} alt={pr.name} className="w-24 h-24 object-cover shrink-0" />
              ) : (
                <div className="w-24 h-24 shrink-0" style={{ backgroundColor: `${p}20` }} />
              )}
              <div className="flex-1 p-3">
                <p className="font-semibold text-sm line-clamp-2 text-white">{pr.name}</p>
                {pr.unit && <p className="text-xs opacity-40 mt-0.5">{pr.unit}</p>}
                <p className="font-bold mt-1" style={{ color: p }}>₹{pr.price}</p>
                {pr.isOutOfStock && <p className="text-xs text-red-400 mt-1">Out of stock</p>}
                {!pr.isOutOfStock && <ProductOrderBtn waNum={waNum} productName={pr.name} price={pr.price} primaryColor={p} className="inline-block rounded px-3 py-1 text-black" />}
              </div>
            </div>
          ))}
        </section>
      )}
      {has('about') && (
        <section className="px-6 py-8 border-t" style={{ borderColor: `${p}20` }}>
          <h2 className="font-bold tracking-widest text-sm uppercase mb-3" style={{ color: p }}>Our Story</h2>
          <p className="text-gray-400 leading-relaxed">{config.aboutText || `Welcome to ${config.siteName || shop.shopName}!`}</p>
          {config.storeHoursEnabled && config.storeHoursText && (
            <p className="text-sm opacity-50 mt-3">🕐 {config.storeHoursText}</p>
          )}
        </section>
      )}
      {has('contact') && (
        <section className="px-6 py-8 text-center border-t" style={{ borderColor: `${p}20` }}>
          <p className="opacity-50 text-sm tracking-wider">{shop.district}, Kerala</p>
          {shop.ownerPhone && <p className="opacity-50 text-sm mt-1">{shop.ownerPhone}</p>}
          <div className="mt-4">
            <WABtn config={config} shop={shop} className="tracking-wider text-sm" style={{ backgroundColor: p, color: '#0d0d0d' }} />
          </div>
        </section>
      )}
      <WAFloat config={config} shop={shop} />
    </div>
  );
}

// ── FESTIVAL (Festival + Zenith) ────────────────────────────────────────────────
function FestivalLayout({ config, shop, products, shopId }: Props) {
  const p = config.primaryColor; const s = config.secondaryColor;
  const waNum = config.whatsappEnabled !== false ? (config.whatsappNumber || shop.ownerPhone) : '';
  const banners = [shop.bannerImageUrl, ...(config.banners ?? [])].filter(Boolean);
  const has = (sec: string) => config.sections.includes(sec);
  const [activeCat, setActiveCat] = useState('All');
  const cats = ['All', ...Array.from(new Set(products.map(pr => pr.category).filter(Boolean)))];
  const visible = activeCat === 'All' ? products : products.filter(pr => pr.category === activeCat);
  return (
    <div className="min-h-screen" style={{ backgroundColor: config.themeId === 'zenith' ? '#f0fdf4' : '#fff8e7', color: '#1a1a1a' }}>
      <div className="h-2 w-full" style={{ background: `linear-gradient(to right, ${p}, ${s}, ${p})` }} />
      {has('hero') && (
        <section>
          <BannerCarousel banners={banners} />
          <div className="px-6 py-5 text-center" style={{ borderBottom: `3px solid ${s}` }}>
            {shop.logoUrl && <img src={shop.logoUrl} alt="logo" className="w-16 h-16 rounded-full mx-auto mb-3 object-cover border-4" style={{ borderColor: p }} />}
            <h1 className="text-2xl font-bold" style={{ color: p }}>{config.siteName || shop.shopName}</h1>
            {config.tagline && <p className="mt-1 text-sm" style={{ color: s }}>{config.tagline}</p>}
            <p className="text-xs opacity-50 mt-1">{shop.shopType} · {shop.district}</p>
            {shopId && <div className="mt-4"><OrderBtn waNum={waNum} primaryColor={p} label={config.primaryButtonText} /></div>}
          </div>
        </section>
      )}
      <CouponPromo config={config} />
      {has('products') && products.length > 0 && (
        <section className="py-4">
          <CategoryTabs cats={cats} active={activeCat} onSelect={setActiveCat} primaryColor={p} />
          <div className="grid grid-cols-2 md:grid-cols-3 gap-3 px-4">
            {visible.map(pr => (
              <div key={pr.productId} className="bg-white rounded-xl overflow-hidden border-2" style={{ borderColor: `${s}60` }}>
                {pr.imageUrl && <img src={pr.imageUrl} alt={pr.name} className="w-full h-28 object-cover" />}
                <div className="p-2">
                  <p className="text-sm font-semibold line-clamp-2">{pr.name}</p>
                  <p className="font-bold mt-1" style={{ color: p }}>₹{pr.price}</p>
                  {pr.unit && <p className="text-xs opacity-50">{pr.unit}</p>}
                  {pr.isOutOfStock && <p className="text-xs text-red-500">Out of stock</p>}
                  {!pr.isOutOfStock && <ProductOrderBtn waNum={waNum} productName={pr.name} price={pr.price} primaryColor={p} />}
                </div>
              </div>
            ))}
          </div>
        </section>
      )}
      {has('about') && (
        <section className="px-6 py-8 text-center" style={{ backgroundColor: `${s}15` }}>
          <h2 className="font-bold text-lg mb-2" style={{ color: p }}>About Us</h2>
          <p className="text-gray-700">{config.aboutText || `Welcome to ${config.siteName || shop.shopName}!`}</p>
          {config.storeHoursEnabled && config.storeHoursText && (
            <p className="text-sm text-gray-500 mt-3">🕐 {config.storeHoursText}</p>
          )}
        </section>
      )}
      {has('contact') && (
        <section className="px-6 py-8 text-center">
          <p className="text-gray-600">{shop.district}, Kerala · {shop.ownerPhone}</p>
          <div className="mt-4"><WABtn config={config} shop={shop} style={{ backgroundColor: p }} /></div>
        </section>
      )}
      <WAFloat config={config} shop={shop} />
    </div>
  );
}

// ── ANNOUNCEMENT BAR ─────────────────────────────────────────────────────────────
function AnnouncementBar({ config }: { config: WebsiteConfig }) {
  if (!config.announcementBarEnabled || !config.announcementBar) return null;
  const bg = config.announcementBarColor || config.primaryColor;
  return (
    <div style={{ backgroundColor: bg }} className="w-full py-2 px-4 text-center text-white text-xs font-semibold tracking-wide sticky top-0 z-50">
      {config.announcementBar}
    </div>
  );
}

// ── POLICY FOOTER ─────────────────────────────────────────────────────────────────
function PolicyFooter({ config, shopId }: { config: WebsiteConfig; shopId?: string }) {
  const [openPage, setOpenPage] = useState<string | null>(null);

  const pages = [
    { key: 'about', label: 'About Us', show: config.showAboutPage, content: config.customAbout },
    { key: 'contact', label: 'Contact', show: config.showContactPage, content: config.customContact },
    { key: 'privacy', label: 'Privacy Policy', show: config.showPrivacyPage, content: config.customPrivacy },
    { key: 'shipping', label: 'Shipping Policy', show: config.showShippingPage, content: config.customShipping },
    { key: 'return', label: 'Return Policy', show: config.showReturnPage, content: config.customReturn },
  ].filter(p => p.show && p.content);

  const links = config.socialLinks;
  const { instagram, facebook, youtube, twitter } = links ?? {};
  const socialActive = Object.entries({ instagram, facebook, youtube, twitter }).filter(([, v]) => v);
  const ICONS: Record<string, string> = { instagram: '📸', facebook: '📘', youtube: '📺', twitter: '🐦' };

  const hasSocial = socialActive.length > 0;
  const hasPages = pages.length > 0;
  if (!hasSocial && !hasPages) return <p className="text-center text-xs text-gray-300 py-6">Powered by wekerala</p>;

  return (
    <footer className="border-t border-gray-200 bg-gray-50">
      {hasPages && (
        <div className="px-4 py-4 flex flex-wrap gap-2">
          {pages.map(p => (
            <div key={p.key} className="w-full">
              <button
                onClick={() => setOpenPage(openPage === p.key ? null : p.key)}
                className="text-sm text-gray-600 underline text-left w-full flex justify-between"
              >
                {p.label}
                <span>{openPage === p.key ? '▲' : '▼'}</span>
              </button>
              {openPage === p.key && p.content && (
                <div className="mt-2 p-3 bg-white rounded-lg text-sm text-gray-600 leading-relaxed whitespace-pre-line">
                  {p.content}
                </div>
              )}
            </div>
          ))}
        </div>
      )}
      {hasSocial && (
        <div className="px-4 py-4 flex flex-col items-center gap-3 border-t border-gray-100">
          <p className="text-xs text-gray-400 uppercase tracking-widest font-medium">Follow Us</p>
          <div className="flex gap-5">
            {socialActive.map(([key, url]) => (
              <a key={key} href={url as string} target="_blank" rel="noreferrer"
                className="text-2xl hover:opacity-60 transition-opacity" title={key}>
                {ICONS[key]}
              </a>
            ))}
          </div>
        </div>
      )}
      <p className="text-center text-xs text-gray-300 py-4">Powered by wekerala</p>
    </footer>
  );
}

// ── MAIN RENDERER ────────────────────────────────────────────────────────────────
export default function ThemeRenderer({ config, shop, products, shopId }: Props) {
  const theme = getTheme(config.themeId);
  const font = config.fontFamily || theme.defaults.fontFamily;
  const fontUrl = `https://fonts.googleapis.com/css2?family=${encodeURIComponent(font).replace(/%20/g, '+')}:wght@400;500;600;700&display=swap`;

  const layoutProps = { config, shop, products, shopId };

  return (
    <>
      <style dangerouslySetInnerHTML={{ __html: `@import url('${fontUrl}'); * { font-family: '${font}', sans-serif; }` }} />
      <AnnouncementBar config={config} />
      {theme.layout === 'clean' && <CleanLayout {...layoutProps} />}
      {theme.layout === 'dark' && <DarkLayout {...layoutProps} />}
      {theme.layout === 'warm' && <WarmLayout {...layoutProps} />}
      {theme.layout === 'neopop' && <NeopopLayout {...layoutProps} />}
      {theme.layout === 'editorial' && <EditorialLayout {...layoutProps} />}
      {theme.layout === 'carousel' && <CarouselLayout {...layoutProps} />}
      {theme.layout === 'luxury' && <LuxuryLayout {...layoutProps} />}
      {theme.layout === 'festival' && <FestivalLayout {...layoutProps} />}
      <PolicyFooter config={config} shopId={shopId} />
    </>
  );
}
