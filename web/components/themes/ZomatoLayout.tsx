'use client';

import { useState, useMemo, useRef, useEffect } from 'react';
import Image from 'next/image';
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

type CartState = { [productId: string]: number };

// ─── Adapter ─────────────────────────────────────────────────────────────────

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
  };
}

// ─── VEG DETECTION ────────────────────────────────────────────────────────────
const VEG_KEYWORDS = [
  'veg', 'paneer', 'dal', 'chana', 'tofu', 'mushroom',
  'cauliflower', 'potato', 'palak',
];

function isVegItem(product: Product): boolean {
  const haystack = `${product.name} ${product.description ?? ''} ${product.category}`.toLowerCase();
  if (VEG_KEYWORDS.some((kw) => haystack.includes(kw))) return true;
  if (product.category.toLowerCase().includes('veg')) return true;
  return false;
}

// ─── HELPERS ──────────────────────────────────────────────────────────────────
function formatPrice(n: number) {
  return `₹${n.toFixed(0)}`;
}

function buildWhatsAppMessage(
  shop: ShopData,
  cartItems: { product: Product; qty: number }[],
  deliveryCharge: number,
): string {
  const itemLines = cartItems
    .map((ci) => {
      const price = ci.product.offerPrice > 0 ? ci.product.offerPrice : ci.product.price;
      return `• ${ci.product.name} x${ci.qty} — ₹${(price * ci.qty).toFixed(0)}`;
    })
    .join('\n');

  const subtotal = cartItems.reduce((sum, ci) => {
    const price = ci.product.offerPrice > 0 ? ci.product.offerPrice : ci.product.price;
    return sum + price * ci.qty;
  }, 0);

  const total = subtotal + deliveryCharge;

  return (
    `🍽 Order from ${shop.shopName}\n` +
    `Items:\n${itemLines}\n` +
    `Subtotal: ₹${subtotal.toFixed(0)}\n` +
    `Delivery: ₹${deliveryCharge.toFixed(0)}\n` +
    `Grand Total: ₹${total.toFixed(0)}`
  );
}

// ─── SUB-COMPONENTS ──────────────────────────────────────────────────────────

function VegIndicator({ product }: { product: Product }) {
  const veg = isVegItem(product);
  return (
    <span
      className="inline-block w-3.5 h-3.5 border-2 flex-shrink-0 mr-1.5 mt-0.5"
      style={{
        borderColor: veg ? '#0F8A65' : '#E23744',
        backgroundColor: 'transparent',
      }}
      title={veg ? 'Veg' : 'Non-Veg'}
    >
      <span
        className="block w-full h-full rounded-full"
        style={{ backgroundColor: veg ? '#0F8A65' : '#E23744' }}
      />
    </span>
  );
}

interface MenuItemCardProps {
  product: Product;
  qty: number;
  onAdd: () => void;
  onIncrease: () => void;
  onDecrease: () => void;
  onProductClick?: (product: Product) => void;
}

function MenuItemCard({ product, qty, onAdd, onIncrease, onDecrease, onProductClick }: MenuItemCardProps) {
  const displayPrice = product.offerPrice > 0 ? product.offerPrice : product.price;
  const hasDiscount = product.offerPrice > 0 && product.offerPrice < product.price;

  return (
    <div className="flex items-start gap-3 py-4 px-4 border-b border-gray-100 bg-white">
      {/* LEFT */}
      <div className="flex-1 min-w-0 cursor-pointer" onClick={() => onProductClick?.(product)}>
        <div className="flex items-start gap-1 mb-1">
          <VegIndicator product={product} />
          <span className="text-sm font-semibold text-gray-900 leading-tight">
            {product.name}
          </span>
        </div>

        {/* Price */}
        <div className="flex items-center gap-2 mb-1">
          <span className="text-sm font-bold" style={{ color: '#1C1C1C' }}>
            {formatPrice(displayPrice)}
          </span>
          {hasDiscount && (
            <span className="text-xs text-gray-400 line-through">
              {formatPrice(product.price)}
            </span>
          )}
          {product.unit && (
            <span className="text-xs text-gray-400">/ {product.unit}</span>
          )}
        </div>

        {/* Description */}
        {product.description && (
          <p className="text-xs text-gray-400 line-clamp-2 leading-relaxed">
            {product.description}
          </p>
        )}

        {product.isOutOfStock && (
          <span className="inline-block mt-1 text-xs font-medium text-red-500 bg-red-50 px-2 py-0.5 rounded">
            Out of Stock
          </span>
        )}
      </div>

      {/* RIGHT — image + ADD button */}
      <div className="relative flex-shrink-0 w-24 h-24">
        {product.imageUrl ? (
          <Image
            src={product.imageUrl}
            alt={product.name}
            fill
            className="object-cover rounded-lg"
            sizes="96px"
          />
        ) : (
          <div
            className="w-full h-full rounded-lg flex items-center justify-center"
            style={{ backgroundColor: '#F5F5F5' }}
          >
            <span className="text-2xl">🍽</span>
          </div>
        )}

        {/* ADD / quantity overlay */}
        {!product.isOutOfStock && (
          <div className="absolute -bottom-3 left-1/2 -translate-x-1/2">
            {qty === 0 ? (
              <button
                onClick={onAdd}
                className="flex items-center gap-0.5 px-3 py-1 text-xs font-bold rounded shadow-md border bg-white"
                style={{ color: '#E23744', borderColor: '#E23744' }}
              >
                <span>ADD</span>
                <span className="text-base leading-none ml-0.5">+</span>
              </button>
            ) : (
              <div
                className="flex items-center rounded shadow-md overflow-hidden border"
                style={{ borderColor: '#E23744' }}
              >
                <button
                  onClick={onDecrease}
                  className="w-7 h-7 flex items-center justify-center text-sm font-bold bg-white"
                  style={{ color: '#E23744' }}
                >
                  −
                </button>
                <span
                  className="w-7 h-7 flex items-center justify-center text-xs font-bold text-white"
                  style={{ backgroundColor: '#E23744' }}
                >
                  {qty}
                </span>
                <button
                  onClick={onIncrease}
                  className="w-7 h-7 flex items-center justify-center text-sm font-bold bg-white"
                  style={{ color: '#E23744' }}
                >
                  +
                </button>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}

// ─── MAIN COMPONENT ──────────────────────────────────────────────────────────

export default function ZomatoLayout({ config, shop, products, shopId }: Props) {
  const [cart, setCart] = useState<CartState>({});
  const [menuSearch, setMenuSearch] = useState('');
  const [selectedProduct, setSelectedProduct] = useState<Product | null>(null);
  const [globalSearch, setGlobalSearch] = useState('');
  const [pureVegOnly, setPureVegOnly] = useState(false);
  const [activeCategory, setActiveCategory] = useState('');
  const [cartExpanded, setCartExpanded] = useState(false);
  const categoryRefs = useRef<{ [cat: string]: HTMLDivElement | null }>({});

  // ── Derived data ──────────────────────────────────────────────────────────
  const categories = useMemo(() => {
    const seen = new Set<string>();
    const list: string[] = [];
    products.forEach((p) => {
      const cat = p.category || 'Other';
      if (!seen.has(cat)) { seen.add(cat); list.push(cat); }
    });
    return list;
  }, [products]);

  useEffect(() => {
    if (categories.length > 0 && !activeCategory) setActiveCategory(categories[0]);
  }, [categories, activeCategory]);

  const filteredProducts = useMemo(() => {
    let list = products;
    if (pureVegOnly) list = list.filter(isVegItem);
    const q = (menuSearch || globalSearch).trim().toLowerCase();
    if (q) list = list.filter((p) =>
      p.name.toLowerCase().includes(q) ||
      (p.description ?? '').toLowerCase().includes(q) ||
      p.category.toLowerCase().includes(q)
    );
    return list;
  }, [products, pureVegOnly, menuSearch, globalSearch]);

  const groupedProducts = useMemo(() => {
    const map: { [cat: string]: Product[] } = {};
    filteredProducts.forEach((p) => {
      const cat = p.category || 'Other';
      if (!map[cat]) map[cat] = [];
      map[cat].push(p);
    });
    return map;
  }, [filteredProducts]);

  // ── Cart helpers ───────────────────────────────────────────────────────────
  const addToCart = (id: string) => setCart((c) => ({ ...c, [id]: (c[id] ?? 0) + 1 }));
  const increase = (id: string) => setCart((c) => ({ ...c, [id]: (c[id] ?? 0) + 1 }));
  const decrease = (id: string) =>
    setCart((c) => {
      const n = (c[id] ?? 1) - 1;
      if (n <= 0) { const nc = { ...c }; delete nc[id]; return nc; }
      return { ...c, [id]: n };
    });

  const cartItems = useMemo(
    () =>
      Object.entries(cart)
        .map(([productId, qty]) => {
          const product = products.find((p) => p.productId === productId);
          return product ? { product, qty } : null;
        })
        .filter(Boolean) as { product: Product; qty: number }[],
    [cart, products],
  );

  const cartSubtotal = cartItems.reduce((sum, ci) => {
    const price = ci.product.offerPrice > 0 ? ci.product.offerPrice : ci.product.price;
    return sum + price * ci.qty;
  }, 0);
  const cartTotal = cartSubtotal + config.deliveryCharge;
  const cartCount = cartItems.reduce((s, ci) => s + ci.qty, 0);

  const activeCoupons = config.couponCodes.filter((c) => c.active);

  // ── WhatsApp order ─────────────────────────────────────────────────────────
  const placeOrder = () => {
    if (!config.whatsappEnabled || !config.whatsappNumber) return;
    const msg = buildWhatsAppMessage(shop, cartItems, config.deliveryCharge);
    const phone = config.whatsappNumber.replace(/\D/g, '');
    window.open(`https://wa.me/${phone}?text=${encodeURIComponent(msg)}`, '_blank');
  };

  // ── Category scroll ───────────────────────────────────────────────────────
  const scrollToCategory = (cat: string) => {
    setActiveCategory(cat);
    const el = categoryRefs.current[cat];
    if (el) {
      el.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
  };

  // ── Render ────────────────────────────────────────────────────────────────
  return (
    <div className="min-h-screen bg-gray-50 font-sans max-w-2xl mx-auto relative">

      {/* ══ HEADER ══════════════════════════════════════════════════════════ */}
      <header className="sticky top-0 z-30 bg-white shadow-sm">
        <div className="flex items-center gap-3 px-4 py-3">
          {/* Logo / Brand */}
          <span className="text-xl font-extrabold tracking-tight" style={{ color: '#E23744' }}>
            {config.siteName || shop.shopName}
          </span>
          <div className="flex-1" />
          {/* Pure Veg Toggle */}
          <div className="flex items-center gap-1.5">
            <span className="text-xs text-gray-500 font-medium">Pure Veg</span>
            <button
              onClick={() => setPureVegOnly((v) => !v)}
              className="relative inline-flex h-5 w-9 items-center rounded-full transition-colors focus:outline-none"
              style={{ backgroundColor: pureVegOnly ? '#0F8A65' : '#D1D5DB' }}
              aria-label="Toggle pure veg"
            >
              <span
                className="inline-block h-3.5 w-3.5 transform rounded-full bg-white shadow transition-transform"
                style={{ transform: pureVegOnly ? 'translateX(18px)' : 'translateX(3px)' }}
              />
            </button>
          </div>
        </div>
        {/* Search bar */}
        <div className="px-4 pb-3">
          <div className="flex items-center bg-gray-100 rounded-lg px-3 py-2 gap-2">
            <svg className="w-4 h-4 text-gray-400 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-4.35-4.35M17 11A6 6 0 1 1 5 11a6 6 0 0 1 12 0z" />
            </svg>
            <input
              type="text"
              placeholder="Search for dishes..."
              value={globalSearch}
              onChange={(e) => setGlobalSearch(e.target.value)}
              className="bg-transparent flex-1 text-sm outline-none text-gray-700 placeholder-gray-400"
            />
            {globalSearch && (
              <button onClick={() => setGlobalSearch('')} className="text-gray-400 hover:text-gray-600">
                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            )}
          </div>
        </div>
      </header>

      {/* ══ RESTAURANT HERO ═════════════════════════════════════════════════ */}
      <div className="relative h-52 sm:h-64 w-full overflow-hidden">
        {shop.bannerImageUrl ? (
          <Image
            src={shop.bannerImageUrl}
            alt={shop.shopName}
            fill
            className="object-cover"
            priority
            sizes="(max-width: 672px) 100vw, 672px"
          />
        ) : (
          <div
            className="w-full h-full"
            style={{ background: 'linear-gradient(135deg, #E23744 0%, #FF6B6B 50%, #c0392b 100%)' }}
          />
        )}
        {/* Gradient overlay */}
        <div
          className="absolute inset-0"
          style={{ background: 'linear-gradient(transparent 40%, rgba(0,0,0,0.85))' }}
        />
        {/* Text over bottom */}
        <div className="absolute bottom-0 left-0 right-0 p-4">
          <h1 className="text-2xl font-bold text-white leading-tight">{shop.shopName}</h1>
          {shop.shopNameMl && (
            <p className="text-sm text-white opacity-70 mt-0.5">{shop.shopNameMl}</p>
          )}
          <p className="text-sm text-white opacity-80 mt-1">{shop.shopType}</p>
          <p className="text-xs text-white opacity-70 mt-0.5">📍 {shop.district}</p>
        </div>
      </div>

      {/* ══ INFO STRIP ══════════════════════════════════════════════════════ */}
      <div className="bg-white mx-3 -mt-3 relative z-10 rounded-xl shadow-md px-4 py-3 flex items-center justify-between text-center">
        {/* Rating */}
        <div className="flex flex-col items-center gap-0.5">
          <span
            className="text-xs font-bold text-white px-1.5 py-0.5 rounded"
            style={{ backgroundColor: '#48C479' }}
          >
            4.1 ★
          </span>
          <span className="text-xs text-gray-500">Rating</span>
        </div>
        <div className="w-px h-8 bg-gray-200" />
        {/* Delivery */}
        <div className="flex flex-col items-center gap-0.5">
          <span className="text-xs font-bold text-gray-800">
            {config.storeHoursEnabled && config.storeHoursText ? config.storeHoursText : '30-40 mins'}
          </span>
          <span className="text-xs text-gray-500">Delivery</span>
        </div>
        <div className="w-px h-8 bg-gray-200" />
        {/* Area */}
        <div className="flex flex-col items-center gap-0.5">
          <span className="text-xs font-bold text-gray-800 max-w-[70px] truncate">{shop.district}</span>
          <span className="text-xs text-gray-500">Area</span>
        </div>
        <div className="w-px h-8 bg-gray-200" />
        {/* Cost */}
        <div className="flex flex-col items-center gap-0.5">
          <span className="text-xs font-bold text-gray-800">
            {formatPrice(config.minOrderAmount * 2)}
          </span>
          <span className="text-xs text-gray-500">For two</span>
        </div>
      </div>

      {/* ══ OFFERS BANNER ═══════════════════════════════════════════════════ */}
      {activeCoupons.length > 0 && (
        <div
          className="mx-3 mt-3 rounded-xl p-3"
          style={{ background: 'linear-gradient(135deg, #E23744 0%, #FF6B6B 100%)' }}
        >
          <div className="flex items-center gap-2 mb-2">
            <span className="text-base">🏷</span>
            <span className="text-white font-bold text-sm tracking-wide">OFFERS AVAILABLE</span>
          </div>
          <div className="flex flex-wrap gap-2">
            {activeCoupons.map((c) => (
              <span
                key={c.code}
                className="bg-white text-xs font-bold px-2 py-1 rounded-full"
                style={{ color: '#E23744' }}
              >
                {c.code} — {c.discountPercent}% OFF
              </span>
            ))}
          </div>
        </div>
      )}

      {/* ══ ABOUT / TAGLINE ═════════════════════════════════════════════════ */}
      {config.tagline && (
        <div className="mx-3 mt-3 bg-white rounded-xl px-4 py-3 shadow-sm">
          <p className="text-sm text-gray-500 italic">"{config.tagline}"</p>
        </div>
      )}

      {/* ══ MENU HEADER ═════════════════════════════════════════════════════ */}
      <div className="mt-4 px-4">
        <div className="flex items-center justify-between mb-3">
          <h2 className="text-base font-bold text-gray-900">MENU</h2>
          <span className="text-xs text-gray-400">{filteredProducts.length} items</span>
        </div>

        {/* Search in menu */}
        <div className="flex items-center bg-white border border-gray-200 rounded-lg px-3 py-2 gap-2 shadow-sm mb-3">
          <svg className="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-4.35-4.35M17 11A6 6 0 1 1 5 11a6 6 0 0 1 12 0z" />
          </svg>
          <input
            type="text"
            placeholder="Search in menu"
            value={menuSearch}
            onChange={(e) => setMenuSearch(e.target.value)}
            className="flex-1 text-sm outline-none text-gray-700 placeholder-gray-400"
          />
          {menuSearch && (
            <button onClick={() => setMenuSearch('')} className="text-gray-400">
              <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          )}
        </div>

        {/* Sort / Filter bar */}
        <div className="flex items-center gap-2 overflow-x-auto pb-1 scrollbar-hide">
          <button
            className="flex-shrink-0 flex items-center gap-1 text-xs font-semibold px-3 py-1.5 rounded-full border"
            style={{ color: '#E23744', borderColor: '#E23744' }}
          >
            Sort ▾
          </button>
          <button
            className="flex-shrink-0 flex items-center gap-1 text-xs font-semibold px-3 py-1.5 rounded-full border"
            style={{ color: '#E23744', borderColor: '#E23744' }}
          >
            Filter ▾
          </button>
          <div className="w-px h-5 bg-gray-200 mx-1 flex-shrink-0" />
          {categories.map((cat) => (
            <button
              key={cat}
              onClick={() => scrollToCategory(cat)}
              className="flex-shrink-0 text-xs font-medium px-3 py-1.5 rounded-full border transition-colors"
              style={
                activeCategory === cat
                  ? { backgroundColor: '#E23744', color: '#fff', borderColor: '#E23744' }
                  : { color: '#555', borderColor: '#D1D5DB', backgroundColor: '#fff' }
              }
            >
              {cat}
            </button>
          ))}
        </div>
      </div>

      {/* ══ MENU SECTIONS ═══════════════════════════════════════════════════ */}
      <div className="mt-4 pb-32">
        {Object.entries(groupedProducts).length === 0 ? (
          <div className="text-center py-16 text-gray-400">
            <p className="text-4xl mb-3">🔍</p>
            <p className="text-sm font-medium">No items found</p>
            <p className="text-xs mt-1">Try a different search or toggle the veg filter</p>
          </div>
        ) : (
          Object.entries(groupedProducts).map(([cat, items]) => (
            <div
              key={cat}
              ref={(el) => { categoryRefs.current[cat] = el; }}
            >
              {/* Sticky category header */}
              <div
                className="sticky top-[108px] z-20 px-4 py-2 flex items-center justify-between"
                style={{ backgroundColor: '#F5F5F5' }}
              >
                <span className="text-sm font-bold text-gray-700 uppercase tracking-wide">
                  {cat}
                </span>
                <span className="text-xs text-gray-400">{items.length} items</span>
              </div>

              {/* Items */}
              <div className="bg-white">
                {items.map((product) => (
                  <MenuItemCard
                    key={product.productId}
                    product={product}
                    qty={cart[product.productId] ?? 0}
                    onAdd={() => addToCart(product.productId)}
                    onIncrease={() => increase(product.productId)}
                    onDecrease={() => decrease(product.productId)}
                    onProductClick={setSelectedProduct}
                  />
                ))}
              </div>
            </div>
          ))
        )}
      </div>

      {/* ══ FOOTER ══════════════════════════════════════════════════════════ */}
      <footer className="bg-white border-t border-gray-100 py-4 text-center pb-36">
        <p className="text-xs text-gray-400">
          Powered by{' '}
          <span className="font-bold" style={{ color: '#E23744' }}>
            wekerala
          </span>
        </p>
      </footer>

      {/* ══ PRODUCT DETAIL SHEET ════════════════════════════════════════════ */}
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

      {/* ══ CART BOTTOM SHEET ═══════════════════════════════════════════════ */}
      {cartCount > 0 && (
        <>
          {/* Expanded cart drawer */}
          {cartExpanded && (
            <div
              className="fixed inset-0 z-40 flex flex-col justify-end"
              onClick={(e) => { if (e.target === e.currentTarget) setCartExpanded(false); }}
              style={{ backgroundColor: 'rgba(0,0,0,0.5)' }}
            >
              <div className="bg-white rounded-t-2xl max-h-[70vh] flex flex-col max-w-2xl mx-auto w-full">
                {/* Drawer header */}
                <div className="flex items-center justify-between px-4 py-3 border-b border-gray-100">
                  <span className="font-bold text-gray-900">Your Order</span>
                  <button
                    onClick={() => setCartExpanded(false)}
                    className="text-gray-400 hover:text-gray-600 p-1"
                  >
                    <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  </button>
                </div>

                {/* Cart items */}
                <div className="overflow-y-auto flex-1 px-4 py-2">
                  {cartItems.map((ci) => {
                    const price = ci.product.offerPrice > 0 ? ci.product.offerPrice : ci.product.price;
                    return (
                      <div key={ci.product.productId} className="flex items-center gap-3 py-3 border-b border-gray-50">
                        <div className="flex-1 min-w-0">
                          <p className="text-sm font-medium text-gray-800 truncate">{ci.product.name}</p>
                          <p className="text-xs text-gray-500 mt-0.5">{formatPrice(price)} × {ci.qty}</p>
                        </div>
                        <div className="flex items-center gap-1">
                          <button
                            onClick={() => decrease(ci.product.productId)}
                            className="w-7 h-7 rounded-full border flex items-center justify-center text-sm font-bold"
                            style={{ borderColor: '#E23744', color: '#E23744' }}
                          >
                            −
                          </button>
                          <span className="w-6 text-center text-sm font-semibold">{ci.qty}</span>
                          <button
                            onClick={() => increase(ci.product.productId)}
                            className="w-7 h-7 rounded-full border flex items-center justify-center text-sm font-bold"
                            style={{ borderColor: '#E23744', color: '#E23744' }}
                          >
                            +
                          </button>
                        </div>
                        <span className="text-sm font-bold text-gray-800 w-14 text-right">
                          {formatPrice(price * ci.qty)}
                        </span>
                      </div>
                    );
                  })}
                </div>

                {/* Bill summary */}
                <div className="px-4 py-3 border-t border-gray-100 bg-gray-50">
                  <div className="flex justify-between text-sm text-gray-600 mb-1">
                    <span>Subtotal</span>
                    <span>{formatPrice(cartSubtotal)}</span>
                  </div>
                  <div className="flex justify-between text-sm text-gray-600 mb-2">
                    <span>Delivery charge</span>
                    <span>{formatPrice(config.deliveryCharge)}</span>
                  </div>
                  <div className="flex justify-between text-sm font-bold text-gray-900 border-t border-gray-200 pt-2">
                    <span>Total</span>
                    <span>{formatPrice(cartTotal)}</span>
                  </div>
                </div>

                {/* Place order button */}
                {config.whatsappEnabled && (
                  <div className="px-4 pb-4 pt-2">
                    <button
                      onClick={() => { placeOrder(); setCartExpanded(false); }}
                      className="w-full py-3 rounded-xl text-white font-bold text-sm flex items-center justify-center gap-2 shadow-lg active:scale-95 transition-transform"
                      style={{ backgroundColor: '#E23744' }}
                    >
                      <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor">
                        <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z" />
                      </svg>
                      Place Order via WhatsApp
                    </button>
                  </div>
                )}
              </div>
            </div>
          )}

          {/* Floating cart bar */}
          <div className="fixed bottom-0 left-0 right-0 z-30 px-3 pb-3 max-w-2xl mx-auto">
            <button
              onClick={() => setCartExpanded((v) => !v)}
              className="w-full flex items-center justify-between px-4 py-3.5 rounded-2xl text-white shadow-2xl active:scale-95 transition-transform"
              style={{ backgroundColor: '#E23744' }}
            >
              <div className="flex items-center gap-2">
                <span
                  className="bg-white text-xs font-bold px-1.5 py-0.5 rounded"
                  style={{ color: '#E23744' }}
                >
                  {cartCount}
                </span>
                <span className="text-sm font-medium">
                  {cartCount} item{cartCount !== 1 ? 's' : ''}
                </span>
              </div>
              <span className="text-sm font-bold">{formatPrice(cartTotal)}</span>
              <div className="flex items-center gap-1 text-sm font-bold">
                <span>Place Order</span>
                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M9 5l7 7-7 7" />
                </svg>
              </div>
            </button>
          </div>
        </>
      )}
    </div>
  );
}
