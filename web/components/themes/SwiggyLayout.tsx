'use client';

import { useState, useEffect, useRef, useCallback } from 'react';
import Image from 'next/image';

// ─── Interfaces ───────────────────────────────────────────────────────────────

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
  description?: string;
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
  minOrderAmount: number;
  logoUrl: string;
  socialLinks: { instagram: string; facebook: string; youtube: string; twitter: string };
}

interface Props {
  config: WebsiteConfig;
  shop: ShopData;
  products: Product[];
  shopId?: string;
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

const CATEGORY_BG_COLORS = ['#FCE4B5', '#D4E9FF', '#FFE0D6', '#D5F5E3'];

const CATEGORY_EMOJIS: Record<string, string> = {
  biryani: '🍚',
  rice: '🍚',
  chicken: '🍗',
  beef: '🥩',
  mutton: '🥩',
  fish: '🐟',
  seafood: '🦐',
  veg: '🥦',
  vegetarian: '🥗',
  salad: '🥗',
  snacks: '🍟',
  starters: '🍢',
  soup: '🍜',
  bread: '🍞',
  roti: '🫓',
  naan: '🫓',
  dessert: '🍰',
  sweet: '🍮',
  drinks: '🥤',
  beverages: '☕',
  juice: '🍹',
  tea: '🍵',
  coffee: '☕',
  pizza: '🍕',
  burger: '🍔',
  sandwich: '🥪',
  pasta: '🍝',
  noodles: '🍜',
  curry: '🍛',
  dal: '🍲',
  paneer: '🧀',
  egg: '🥚',
  breakfast: '🍳',
  lunch: '🍱',
  dinner: '🌙',
  default: '🍽',
};

function getCategoryEmoji(category: string): string {
  const lower = category.toLowerCase();
  for (const key of Object.keys(CATEGORY_EMOJIS)) {
    if (lower.includes(key)) return CATEGORY_EMOJIS[key];
  }
  return CATEGORY_EMOJIS.default;
}

const VEG_KEYWORDS = [
  'veg', 'paneer', 'dal', 'aloo', 'potato', 'mushroom', 'palak', 'gobi',
  'cauliflower', 'peas', 'corn', 'salad', 'fruit', 'juice', 'tea', 'coffee',
  'sweet', 'dessert', 'bread', 'roti', 'naan', 'idli', 'dosa', 'upma',
  'poha', 'pasta', 'pizza', 'sandwich', 'tofu', 'soya',
];

function isVegItem(name: string, category: string): boolean {
  const text = (name + ' ' + category).toLowerCase();
  return VEG_KEYWORDS.some((kw) => text.includes(kw));
}

function formatWhatsAppOrder(
  shop: ShopData,
  config: WebsiteConfig,
  cart: Record<string, number>,
  products: Product[]
): string {
  const lines: string[] = [`🍽 Order from ${shop.shopName}`, ''];
  let total = 0;
  for (const [id, qty] of Object.entries(cart)) {
    if (qty === 0) continue;
    const p = products.find((x) => x.productId === id);
    if (!p) continue;
    const price = p.offerPrice > 0 ? p.offerPrice : p.price;
    const subtotal = price * qty;
    total += subtotal;
    lines.push(`${p.name} x${qty} - ₹${subtotal}`);
  }
  lines.push('');
  lines.push(`Total: ₹${total}`);
  lines.push(`Delivery: ₹${config.deliveryCharge}`);
  if (config.minOrderAmount > 0) {
    lines.push(`Min Order: ₹${config.minOrderAmount}`);
  }
  return lines.join('\n');
}

// ─── Sub-components ───────────────────────────────────────────────────────────

function VegDot({ isVeg }: { isVeg: boolean }) {
  return (
    <span
      className="inline-flex items-center justify-center w-4 h-4 border-2 flex-shrink-0"
      style={{
        borderColor: isVeg ? '#0F8A65' : '#E43B4F',
      }}
    >
      <span
        className="w-2 h-2 rounded-full"
        style={{ backgroundColor: isVeg ? '#0F8A65' : '#E43B4F' }}
      />
    </span>
  );
}

function AddButton({
  product,
  quantity,
  onAdd,
  onIncrease,
  onDecrease,
}: {
  product: Product;
  quantity: number;
  onAdd: () => void;
  onIncrease: () => void;
  onDecrease: () => void;
}) {
  if (product.isOutOfStock) {
    return (
      <button
        disabled
        className="text-xs font-bold px-3 py-1.5 rounded border border-gray-300 text-gray-400 bg-gray-50 cursor-not-allowed"
      >
        SOLD OUT
      </button>
    );
  }

  if (quantity === 0) {
    return (
      <button
        onClick={onAdd}
        className="text-sm font-bold px-4 py-1.5 rounded border-2 bg-white transition-all active:scale-95"
        style={{ borderColor: '#FC8019', color: '#FC8019' }}
      >
        ADD +
      </button>
    );
  }

  return (
    <div
      className="flex items-center rounded overflow-hidden border-2"
      style={{ borderColor: '#FC8019' }}
    >
      <button
        onClick={onDecrease}
        className="w-8 h-8 flex items-center justify-center font-bold text-white transition-colors"
        style={{ backgroundColor: '#FC8019' }}
      >
        −
      </button>
      <span
        className="w-8 h-8 flex items-center justify-center text-sm font-bold"
        style={{ color: '#FC8019' }}
      >
        {quantity}
      </span>
      <button
        onClick={onIncrease}
        className="w-8 h-8 flex items-center justify-center font-bold text-white transition-colors"
        style={{ backgroundColor: '#FC8019' }}
      >
        +
      </button>
    </div>
  );
}

function MenuItemCard({
  product,
  quantity,
  onAdd,
  onIncrease,
  onDecrease,
}: {
  product: Product;
  quantity: number;
  onAdd: () => void;
  onIncrease: () => void;
  onDecrease: () => void;
}) {
  const isVeg = isVegItem(product.name, product.category);
  const displayPrice = product.offerPrice > 0 ? product.offerPrice : product.price;
  const hasDiscount = product.offerPrice > 0 && product.offerPrice < product.price;

  return (
    <div
      className={`flex items-start gap-3 py-4 border-b border-gray-100 relative ${
        product.isOutOfStock ? 'opacity-60' : ''
      }`}
    >
      {/* Left: info */}
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-1.5 mb-1">
          <VegDot isVeg={isVeg} />
          {hasDiscount && (
            <span
              className="text-xs font-bold px-1.5 py-0.5 rounded"
              style={{ backgroundColor: '#E8F5E9', color: '#0F8A65' }}
            >
              BESTSELLER
            </span>
          )}
        </div>
        <p className="text-sm font-medium leading-snug mb-0.5 truncate" style={{ color: '#3D4152' }}>
          {product.name}
        </p>
        <div className="flex items-center gap-2 mb-1">
          <span className="text-sm font-bold" style={{ color: '#3D4152' }}>
            ₹{displayPrice}
          </span>
          {hasDiscount && (
            <span className="text-xs line-through" style={{ color: '#93959F' }}>
              ₹{product.price}
            </span>
          )}
          {product.unit && (
            <span className="text-xs" style={{ color: '#93959F' }}>
              / {product.unit}
            </span>
          )}
        </div>
        {product.description && (
          <p
            className="text-xs leading-relaxed line-clamp-2"
            style={{ color: '#686B78' }}
          >
            {product.description}
          </p>
        )}
      </div>

      {/* Right: image + button */}
      <div className="flex flex-col items-center gap-2 flex-shrink-0">
        <div className="relative w-24 h-24 rounded-xl overflow-hidden bg-gray-100">
          {product.imageUrl ? (
            <Image
              src={product.imageUrl}
              alt={product.name}
              fill
              className="object-cover"
              sizes="96px"
            />
          ) : (
            <div className="w-full h-full flex items-center justify-center text-3xl">
              {getCategoryEmoji(product.category)}
            </div>
          )}
          {product.isOutOfStock && (
            <div className="absolute inset-0 bg-white/70 flex items-end justify-center pb-1">
              <span className="text-xs font-bold text-gray-500 tracking-wide">SOLD OUT</span>
            </div>
          )}
        </div>
        <AddButton
          product={product}
          quantity={quantity}
          onAdd={onAdd}
          onIncrease={onIncrease}
          onDecrease={onDecrease}
        />
      </div>
    </div>
  );
}

// ─── Main Component ───────────────────────────────────────────────────────────

export default function SwiggyLayout({ config, shop, products, shopId }: Props) {
  const [cart, setCart] = useState<Record<string, number>>({});
  const [activeCategory, setActiveCategory] = useState<string>('');
  const [copiedCoupon, setCopiedCoupon] = useState<string>('');
  const categoryRefs = useRef<Record<string, HTMLDivElement | null>>({});
  const contentRef = useRef<HTMLDivElement>(null);

  // Derive unique categories in order
  const categories = Array.from(new Set(products.map((p) => p.category).filter(Boolean)));

  useEffect(() => {
    if (categories.length > 0 && !activeCategory) {
      setActiveCategory(categories[0]);
    }
  }, [categories, activeCategory]);

  // Cart calculations
  const cartItemCount = Object.values(cart).reduce((s, q) => s + q, 0);
  const cartTotal = Object.entries(cart).reduce((sum, [id, qty]) => {
    const p = products.find((x) => x.productId === id);
    if (!p || qty === 0) return sum;
    return sum + (p.offerPrice > 0 ? p.offerPrice : p.price) * qty;
  }, 0);

  // Cart actions
  const addToCart = useCallback((productId: string) => {
    setCart((c) => ({ ...c, [productId]: 1 }));
  }, []);

  const increaseQty = useCallback((productId: string) => {
    setCart((c) => ({ ...c, [productId]: (c[productId] || 0) + 1 }));
  }, []);

  const decreaseQty = useCallback((productId: string) => {
    setCart((c) => {
      const next = (c[productId] || 0) - 1;
      if (next <= 0) {
        const { [productId]: _, ...rest } = c;
        return rest;
      }
      return { ...c, [productId]: next };
    });
  }, []);

  // Scroll to category section
  const scrollToCategory = (cat: string) => {
    setActiveCategory(cat);
    const el = categoryRefs.current[cat];
    if (el) {
      const offset = 120;
      const top = el.getBoundingClientRect().top + window.scrollY - offset;
      window.scrollTo({ top, behavior: 'smooth' });
    }
  };

  // Intersection observer for active category on scroll
  useEffect(() => {
    if (categories.length === 0) return;
    const observers: IntersectionObserver[] = [];

    categories.forEach((cat) => {
      const el = categoryRefs.current[cat];
      if (!el) return;
      const obs = new IntersectionObserver(
        ([entry]) => {
          if (entry.isIntersecting) setActiveCategory(cat);
        },
        { rootMargin: '-30% 0px -60% 0px', threshold: 0 }
      );
      obs.observe(el);
      observers.push(obs);
    });

    return () => observers.forEach((o) => o.disconnect());
  }, [categories]);

  // WhatsApp order
  const handleWhatsAppOrder = () => {
    const number = config.whatsappNumber || shop.ownerPhone;
    const message = formatWhatsAppOrder(shop, config, cart, products);
    const url = `https://wa.me/${number.replace(/\D/g, '')}?text=${encodeURIComponent(message)}`;
    window.open(url, '_blank');
  };

  // Copy coupon
  const copyCoupon = (code: string) => {
    navigator.clipboard.writeText(code).catch(() => {});
    setCopiedCoupon(code);
    setTimeout(() => setCopiedCoupon(''), 2000);
  };

  const activeCoupons = config.couponCodes?.filter((c) => c.active) || [];

  // ── Render ─────────────────────────────────────────────────────────────────

  return (
    <div className="min-h-screen bg-gray-50 font-sans" style={{ fontFamily: "'Okra', 'Inter', sans-serif" }}>

      {/* ── HERO SECTION ── */}
      <section className="relative overflow-hidden" style={{ backgroundColor: '#FC8019' }}>
        {/* Background banner image */}
        {shop.bannerImageUrl && (
          <>
            <div className="absolute inset-0">
              <Image
                src={shop.bannerImageUrl}
                alt="banner"
                fill
                className="object-cover"
                priority
              />
            </div>
            <div className="absolute inset-0" style={{ backgroundColor: 'rgba(252, 128, 25, 0.82)' }} />
          </>
        )}

        <div className="relative z-10 px-4 pt-8 pb-6 md:px-8 md:pt-12 md:pb-10 max-w-5xl mx-auto">
          {/* Logo */}
          {(config.logoUrl || shop.logoUrl) && (
            <div className="mb-4">
              <div className="w-16 h-16 md:w-20 md:h-20 rounded-2xl overflow-hidden border-2 border-white/30 shadow-lg bg-white">
                <Image
                  src={config.logoUrl || shop.logoUrl}
                  alt="logo"
                  width={80}
                  height={80}
                  className="w-full h-full object-cover"
                />
              </div>
            </div>
          )}

          <h1 className="text-3xl md:text-5xl font-extrabold text-white leading-tight mb-2 drop-shadow-sm">
            {config.siteName || shop.shopName}
          </h1>
          {shop.shopNameMl && (
            <p className="text-xl font-bold mb-1" style={{ color: 'rgba(255,255,255,0.85)' }}>
              {shop.shopNameMl}
            </p>
          )}
          <p className="text-base md:text-lg mb-6" style={{ color: 'rgba(255,255,255,0.82)' }}>
            {config.tagline}
          </p>

          {/* Info chips */}
          <div className="flex flex-wrap gap-2">
            {config.storeHoursEnabled && config.storeHoursText && (
              <span className="flex items-center gap-1.5 bg-white text-sm font-semibold px-3 py-1.5 rounded-full shadow-sm"
                style={{ color: '#3D4152' }}>
                <svg className="w-4 h-4" style={{ color: '#FC8019' }} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <circle cx="12" cy="12" r="10" strokeWidth="2" />
                  <polyline points="12 6 12 12 16 14" strokeWidth="2" />
                </svg>
                {config.storeHoursText}
              </span>
            )}
            {config.minOrderAmount > 0 && (
              <span className="flex items-center gap-1.5 bg-white text-sm font-semibold px-3 py-1.5 rounded-full shadow-sm"
                style={{ color: '#3D4152' }}>
                <svg className="w-4 h-4" style={{ color: '#FC8019' }} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5" strokeWidth="2" />
                </svg>
                Min ₹{config.minOrderAmount}
              </span>
            )}
            {config.deliveryCharge === 0 ? (
              <span className="flex items-center gap-1.5 bg-white text-sm font-semibold px-3 py-1.5 rounded-full shadow-sm"
                style={{ color: '#0F8A65' }}>
                🚴 Free Delivery
              </span>
            ) : (
              <span className="flex items-center gap-1.5 bg-white text-sm font-semibold px-3 py-1.5 rounded-full shadow-sm"
                style={{ color: '#3D4152' }}>
                🚴 Delivery ₹{config.deliveryCharge}
              </span>
            )}
            <span className="flex items-center gap-1.5 bg-white text-sm font-semibold px-3 py-1.5 rounded-full shadow-sm"
              style={{ color: '#3D4152' }}>
              📍 {shop.district}
            </span>
          </div>
        </div>
      </section>

      {/* ── RESTAURANT INFO BAR ── */}
      <section className="bg-white shadow-sm px-4 py-4 md:px-8 max-w-5xl mx-auto -mt-1">
        <div className="flex items-center gap-3">
          {shop.logoUrl && (
            <div className="w-14 h-14 rounded-full overflow-hidden border-2 flex-shrink-0"
              style={{ borderColor: '#FC8019' }}>
              <Image
                src={shop.logoUrl}
                alt={shop.shopName}
                width={56}
                height={56}
                className="w-full h-full object-cover"
              />
            </div>
          )}
          <div className="flex-1 min-w-0">
            <h2 className="font-bold text-base truncate" style={{ color: '#3D4152' }}>
              {shop.shopName}
            </h2>
            <p className="text-xs truncate" style={{ color: '#686B78' }}>
              {shop.shopType} · {shop.district}
            </p>
          </div>
          <div className="flex flex-col items-end gap-1">
            <span
              className="flex items-center gap-1 text-white text-xs font-bold px-2 py-1 rounded"
              style={{ backgroundColor: '#48C479' }}
            >
              ★ 4.2
            </span>
            <span className="text-xs" style={{ color: '#93959F' }}>
              {products.length} items
            </span>
          </div>
        </div>
      </section>

      {/* ── WHAT'S ON YOUR MIND ── */}
      {categories.length > 0 && (
        <section className="bg-white mt-2 px-4 py-5 md:px-8 max-w-5xl mx-auto">
          <h2 className="font-bold text-lg mb-4" style={{ color: '#3D4152', fontSize: '18px' }}>
            What&apos;s on your mind?
          </h2>
          <div className="flex gap-4 overflow-x-auto pb-2 scrollbar-hide"
            style={{ scrollbarWidth: 'none', msOverflowStyle: 'none' }}>
            {categories.map((cat, i) => (
              <button
                key={cat}
                onClick={() => scrollToCategory(cat)}
                className="flex flex-col items-center gap-2 flex-shrink-0 group"
              >
                <div
                  className="w-20 h-20 rounded-full flex items-center justify-center text-3xl transition-all"
                  style={{
                    backgroundColor: CATEGORY_BG_COLORS[i % CATEGORY_BG_COLORS.length],
                    boxShadow: activeCategory === cat
                      ? `0 0 0 3px #FC8019`
                      : '0 2px 8px rgba(0,0,0,0.08)',
                    outline: activeCategory === cat ? '2px solid #FC8019' : 'none',
                    outlineOffset: '2px',
                  }}
                >
                  <span style={{ fontSize: '2rem' }}>{getCategoryEmoji(cat)}</span>
                </div>
                <span
                  className="text-xs text-center max-w-[80px] leading-tight"
                  style={{
                    color: activeCategory === cat ? '#FC8019' : '#686B78',
                    fontSize: '12px',
                    fontWeight: activeCategory === cat ? 600 : 400,
                  }}
                >
                  {cat}
                </span>
              </button>
            ))}
          </div>
        </section>
      )}

      {/* ── OFFERS / COUPONS ── */}
      {activeCoupons.length > 0 && (
        <section className="mt-2 px-4 py-4 md:px-8 max-w-5xl mx-auto">
          <h2 className="font-bold text-base mb-3" style={{ color: '#3D4152' }}>
            🏷 Offers for you
          </h2>
          <div className="flex gap-3 overflow-x-auto pb-1" style={{ scrollbarWidth: 'none' }}>
            {activeCoupons.map((coupon) => (
              <div
                key={coupon.code}
                className="flex-shrink-0 rounded-xl p-4 min-w-[200px] relative overflow-hidden"
                style={{ backgroundColor: '#FC8019' }}
              >
                {/* Decorative circles */}
                <div className="absolute -right-4 -top-4 w-16 h-16 rounded-full opacity-20 bg-white" />
                <div className="absolute -right-2 bottom-2 w-10 h-10 rounded-full opacity-10 bg-white" />

                <p className="text-white font-extrabold text-2xl mb-0.5">
                  {coupon.discountPercent}% OFF
                </p>
                <p className="text-white/80 text-xs mb-3">Use code at checkout</p>
                <button
                  onClick={() => copyCoupon(coupon.code)}
                  className="flex items-center gap-2 bg-white/20 hover:bg-white/30 rounded-lg px-3 py-1.5 transition-colors"
                >
                  <span className="font-bold text-white text-sm tracking-wider">
                    {coupon.code}
                  </span>
                  <span className="text-white/80 text-xs">
                    {copiedCoupon === coupon.code ? '✓ Copied' : 'COPY'}
                  </span>
                </button>
              </div>
            ))}
          </div>
        </section>
      )}

      {/* ── MENU SECTION ── */}
      <section className="mt-2 max-w-5xl mx-auto">
        {/* Mobile: sticky horizontal category tabs */}
        {categories.length > 1 && (
          <div
            className="md:hidden sticky top-0 z-30 bg-white border-b px-4 overflow-x-auto flex gap-0"
            style={{ scrollbarWidth: 'none', borderColor: '#E9ECEE' }}
          >
            {categories.map((cat) => (
              <button
                key={cat}
                onClick={() => scrollToCategory(cat)}
                className="flex-shrink-0 px-4 py-3 text-sm font-medium transition-colors whitespace-nowrap"
                style={{
                  color: activeCategory === cat ? '#FC8019' : '#686B78',
                  borderBottom: activeCategory === cat ? '2px solid #FC8019' : '2px solid transparent',
                  fontWeight: activeCategory === cat ? 700 : 500,
                }}
              >
                {cat}
              </button>
            ))}
          </div>
        )}

        {/* Desktop: sidebar + content */}
        <div className="flex" ref={contentRef}>
          {/* Desktop sidebar */}
          {categories.length > 1 && (
            <aside
              className="hidden md:block w-52 flex-shrink-0 bg-white border-r sticky top-0 h-screen overflow-y-auto"
              style={{ borderColor: '#E9ECEE' }}
            >
              <div className="py-2">
                <p className="text-xs font-bold px-4 py-2 uppercase tracking-widest"
                  style={{ color: '#93959F' }}>
                  Menu
                </p>
                {categories.map((cat) => (
                  <button
                    key={cat}
                    onClick={() => scrollToCategory(cat)}
                    className="w-full text-left px-4 py-3 text-sm transition-colors"
                    style={{
                      backgroundColor: activeCategory === cat ? '#FFF3E7' : 'transparent',
                      color: activeCategory === cat ? '#FC8019' : '#3D4152',
                      borderRight: activeCategory === cat ? `3px solid #FC8019` : '3px solid transparent',
                      fontWeight: activeCategory === cat ? 700 : 500,
                    }}
                  >
                    {cat}
                    <span className="ml-1 text-xs" style={{ color: '#93959F' }}>
                      ({products.filter((p) => p.category === cat).length})
                    </span>
                  </button>
                ))}
              </div>
            </aside>
          )}

          {/* Main menu content */}
          <div className="flex-1 bg-white md:mx-0">
            {categories.map((cat) => {
              const catProducts = products.filter((p) => p.category === cat);
              return (
                <div
                  key={cat}
                  ref={(el) => { categoryRefs.current[cat] = el; }}
                >
                  <div
                    className="px-4 md:px-6 pt-5 pb-2 border-b"
                    style={{ borderColor: '#E9ECEE' }}
                  >
                    <h3 className="text-base font-bold" style={{ color: '#3D4152' }}>
                      {cat}
                    </h3>
                    <p className="text-xs mt-0.5" style={{ color: '#93959F' }}>
                      {catProducts.length} item{catProducts.length !== 1 ? 's' : ''}
                    </p>
                  </div>

                  <div className="px-4 md:px-6">
                    {catProducts.map((product) => (
                      <MenuItemCard
                        key={product.productId}
                        product={product}
                        quantity={cart[product.productId] || 0}
                        onAdd={() => addToCart(product.productId)}
                        onIncrease={() => increaseQty(product.productId)}
                        onDecrease={() => decreaseQty(product.productId)}
                      />
                    ))}
                  </div>
                </div>
              );
            })}

            {products.length === 0 && (
              <div className="flex flex-col items-center justify-center py-20 text-center px-8">
                <span className="text-6xl mb-4">🍽</span>
                <p className="text-lg font-bold" style={{ color: '#3D4152' }}>
                  Menu coming soon!
                </p>
                <p className="text-sm mt-1" style={{ color: '#686B78' }}>
                  Check back shortly for our delicious offerings.
                </p>
              </div>
            )}
          </div>
        </div>
      </section>

      {/* ── ABOUT SECTION ── */}
      {config.aboutText && config.sections?.includes('about') && (
        <section className="bg-white mt-2 px-4 py-6 md:px-8 max-w-5xl mx-auto">
          <h2 className="font-bold text-base mb-2" style={{ color: '#3D4152' }}>About Us</h2>
          <p className="text-sm leading-relaxed" style={{ color: '#686B78' }}>
            {config.aboutText}
          </p>
        </section>
      )}

      {/* ── FOOTER ── */}
      <footer className="mt-4 bg-white border-t px-4 py-6 md:px-8 max-w-5xl mx-auto"
        style={{ borderColor: '#E9ECEE' }}>
        <div className="flex flex-col md:flex-row md:items-start md:justify-between gap-4">
          <div>
            <div className="flex items-center gap-2 mb-2">
              {shop.logoUrl && (
                <div className="w-8 h-8 rounded-full overflow-hidden">
                  <Image src={shop.logoUrl} alt={shop.shopName} width={32} height={32} className="object-cover" />
                </div>
              )}
              <span className="font-bold text-base" style={{ color: '#3D4152' }}>
                {shop.shopName}
              </span>
            </div>
            <p className="text-xs" style={{ color: '#686B78' }}>
              {shop.shopType} · {shop.district}
            </p>
            {config.storeHoursEnabled && config.storeHoursText && (
              <p className="text-xs mt-1" style={{ color: '#686B78' }}>
                ⏰ {config.storeHoursText}
              </p>
            )}
            {shop.ownerPhone && (
              <a
                href={`tel:${shop.ownerPhone}`}
                className="text-xs mt-1 block"
                style={{ color: '#FC8019' }}
              >
                📞 {shop.ownerPhone}
              </a>
            )}
          </div>

          {/* Social links */}
          {config.socialLinks && Object.values(config.socialLinks).some(Boolean) && (
            <div>
              <p className="text-xs font-semibold mb-2" style={{ color: '#3D4152' }}>
                Follow Us
              </p>
              <div className="flex gap-3">
                {config.socialLinks.instagram && (
                  <a href={config.socialLinks.instagram} target="_blank" rel="noopener noreferrer"
                    className="text-xs px-3 py-1.5 rounded-full border font-medium transition-colors hover:bg-pink-50"
                    style={{ borderColor: '#E9ECEE', color: '#686B78' }}>
                    Instagram
                  </a>
                )}
                {config.socialLinks.facebook && (
                  <a href={config.socialLinks.facebook} target="_blank" rel="noopener noreferrer"
                    className="text-xs px-3 py-1.5 rounded-full border font-medium transition-colors hover:bg-blue-50"
                    style={{ borderColor: '#E9ECEE', color: '#686B78' }}>
                    Facebook
                  </a>
                )}
                {config.socialLinks.youtube && (
                  <a href={config.socialLinks.youtube} target="_blank" rel="noopener noreferrer"
                    className="text-xs px-3 py-1.5 rounded-full border font-medium transition-colors hover:bg-red-50"
                    style={{ borderColor: '#E9ECEE', color: '#686B78' }}>
                    YouTube
                  </a>
                )}
                {config.socialLinks.twitter && (
                  <a href={config.socialLinks.twitter} target="_blank" rel="noopener noreferrer"
                    className="text-xs px-3 py-1.5 rounded-full border font-medium transition-colors hover:bg-sky-50"
                    style={{ borderColor: '#E9ECEE', color: '#686B78' }}>
                    Twitter / X
                  </a>
                )}
              </div>
            </div>
          )}
        </div>

        <div className="mt-6 pt-4 border-t text-center" style={{ borderColor: '#E9ECEE' }}>
          <p className="text-xs" style={{ color: '#93959F' }}>
            Powered by{' '}
            <span className="font-bold" style={{ color: '#FC8019' }}>
              Wekerala
            </span>{' '}
            · {new Date().getFullYear()}
          </p>
        </div>
      </footer>

      {/* ── FLOATING CART BAR ── */}
      <div
        className="fixed bottom-0 left-0 right-0 z-50 flex justify-center transition-all duration-300 ease-in-out"
        style={{
          transform: cartItemCount > 0 ? 'translateY(0)' : 'translateY(100%)',
          pointerEvents: cartItemCount > 0 ? 'auto' : 'none',
        }}
      >
        <button
          onClick={handleWhatsAppOrder}
          className="w-full max-w-lg mx-4 mb-4 flex items-center justify-between px-5 py-4 rounded-2xl shadow-2xl transition-transform active:scale-95"
          style={{ backgroundColor: '#FC8019' }}
          aria-label="View cart and order via WhatsApp"
        >
          <div className="flex items-center gap-2">
            <span
              className="bg-white/20 text-white text-xs font-bold px-2 py-0.5 rounded-md"
            >
              {cartItemCount} item{cartItemCount !== 1 ? 's' : ''}
            </span>
            <span className="text-white font-bold text-sm">View cart</span>
          </div>
          <div className="flex items-center gap-2">
            <span className="text-white font-bold text-base">₹{cartTotal}</span>
            <span className="text-white/80 text-lg">→</span>
          </div>
        </button>
      </div>

      {/* Bottom spacer when cart is visible */}
      {cartItemCount > 0 && <div className="h-24" />}
    </div>
  );
}
