'use client';

import { useState, useMemo, useEffect } from 'react';
import { useSearchParams } from 'next/navigation';
import { Header } from '@/components/shop/header';
import { SearchBar } from '@/components/shop/search-bar';
import { CategoryFilter } from '@/components/shop/category-filter';
import { ProductGrid } from '@/components/shop/product-grid';
import { CartPage } from '@/components/shop/cart-page';
import { CheckoutPage, type CustomerDetails } from '@/components/shop/checkout-page';
import { OrderConfirmation } from '@/components/shop/order-confirmation';
import { OrderTracking } from '@/components/shop/order-tracking';
import { FloatingCartBar } from '@/components/shop/floating-cart-bar';
import { ShopBanner } from '@/components/shop/shop-banner';
import { ProductDetailSheet } from '@/components/shop/product-detail-sheet';
import { AnnouncementModal } from '@/components/shop/announcement-modal';
import { useCartStore } from '@/lib/cart-store';
import { useAuthStore } from '@/lib/auth-store';
import { type Language } from '@/lib/translations';
import { SearchOverlay } from '@/components/shop/search-overlay';
import { fetchShopData, type ShopData, type Product } from '@/lib/products';
import { ChatWidget } from '@/components/shop/chat-widget';

export function ShopSkeleton() {
  return (
    <div className="animate-pulse">
      <div className="h-16 bg-primary/80" />
      <div className="h-40 bg-gray-200" />
      <div className="flex gap-2 p-4">
        {[1, 2, 3, 4].map((i) => (
          <div key={i} className="h-8 w-20 rounded-full bg-gray-200" />
        ))}
      </div>
      <div className="grid grid-cols-2 gap-3 p-4">
        {[1, 2, 3, 4, 5, 6].map((i) => (
          <div key={i} className="h-48 rounded-lg bg-gray-200" />
        ))}
      </div>
    </div>
  );
}

export function ShopViewById({ shopId }: { shopId: string }) {
  const searchParams = useSearchParams();
  const view = searchParams.get('view');
  const orderId = searchParams.get('orderId');

  const [language, setLanguage] = useState<Language>('en');
  const [currentPage, setCurrentPage] = useState<'shop' | 'cart' | 'checkout' | 'confirmation' | 'tracking'>(
    view === 'cart' ? 'cart' : view === 'checkout' ? 'checkout' : view === 'tracking' ? 'tracking' : 'shop'
  );
  const [newOrderId, setNewOrderId] = useState<string>('');
  const [shopData, setShopData] = useState<ShopData | null>(null);
  const [products, setProducts] = useState<Product[]>([]);
  const [selectedProduct, setSelectedProduct] = useState<Product | null>(null);
  const [announcementText, setAnnouncementText] = useState<string>('');
  const [customerDetails, setCustomerDetails] = useState<CustomerDetails>({ name: '', phone: '', address: '', note: '' });

  const { items: cartItems, getTotal } = useCartStore();
  const { uid: customerUid } = useAuthStore();
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCategory, setSelectedCategory] = useState('all');
  const [showSearchOverlay, setShowSearchOverlay] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [orderError, setOrderError] = useState('');

  useEffect(() => {
    fetchShopData(shopId).then(({ shop, products }) => {
      setShopData(shop);
      setProducts(products);
      document.documentElement.style.setProperty('--primary', shop.themeColor || '#1B2838');
      if (shop.announcementText) setAnnouncementText(shop.announcementText);
    });
  }, [shopId]);

  const filteredProducts = useMemo(() => {
    // Only show products with a price (owner may have added products without setting price yet)
    // Sort by orderCount desc so most-popular products appear first
    let filtered = products
      .filter((p) => p.price > 0)
      .sort((a, b) => {
        // In-stock items first, then sort by popularity (orderCount desc)
        if (a.isOutOfStock !== b.isOutOfStock) return a.isOutOfStock ? 1 : -1;
        return (b.orderCount ?? 0) - (a.orderCount ?? 0);
      });
    if (selectedCategory && selectedCategory !== 'all') filtered = filtered.filter((p) => p.category === selectedCategory);
    if (searchQuery) {
      const q = searchQuery.toLowerCase();
      filtered = filtered.filter(
        (p) => p.name.en.toLowerCase().includes(q) ||
          p.name.ml.toLowerCase().includes(q) ||
          (p.searchAlias ?? '').toLowerCase().includes(q)
      );
    }
    return filtered;
  }, [products, selectedCategory, searchQuery]);

  const categories = useMemo(() => {
    const cats = new Set(products.map((p) => p.category).filter(Boolean));
    return ['all', ...Array.from(cats)];
  }, [products]);

  function normalizePhone(phone: string): string {
    const digits = phone.replace(/\D/g, '');
    if (digits.length === 10) return `91${digits}`;
    if (digits.length === 12 && digits.startsWith('91')) return digits;
    if (digits.length === 11 && digits.startsWith('0')) return `91${digits.slice(1)}`;
    if (digits.length === 13 && digits.startsWith('091')) return digits.slice(1);
    return digits.length >= 10 ? `91${digits.slice(-10)}` : digits;
  }

  const handleConfirmOrder = async (details: CustomerDetails) => {
    if (isSubmitting) return;
    setIsSubmitting(true);
    setCustomerDetails(details);

    if (shopData?.ownerWhatsApp) {
      const raw = shopData.ownerWhatsApp.replace(/\D/g, '');
      const phone = raw.length === 10 ? `91${raw}` : raw;
      const total = getTotal();
      const itemList = cartItems
        .map((i) => `• ${i.product.name.en} x${i.quantity} — ₹${i.product.price * i.quantity}`)
        .join('\n');
      const msg = encodeURIComponent(
        `🛒 *New Order*\n\n*Customer:* ${details.name}\n*Phone:* ${details.phone}\n*Address:* ${details.address}${details.note ? `\n*Note:* ${details.note}` : ''}\n\n*Items:*\n${itemList}\n\n*Total:* ₹${total}`
      );
      window.open(`https://wa.me/${phone}?text=${msg}`, '_blank');
    }

    try {
      const subtotal = getTotal();
      const discountAmount = details.discountPercent ? Math.round(subtotal * details.discountPercent / 100) : 0;
      const deliveryFee = details.deliveryCharge ?? 0;
      const finalTotal = subtotal - discountAmount + deliveryFee;
      const now = new Date().toISOString();
      const orderId = `ORD-${Date.now()}-${Math.random().toString(36).slice(2, 9).toUpperCase()}`;
      const normalizedPhone = normalizePhone(details.phone);
      const response = await fetch(`/api/orders?shopId=${shopId}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          shopId, shopName: shopData?.shopName ?? '',
          orderNumber: orderId, status: 'new',
          customerUid: customerUid ?? '',
          customerName: details.name, customerPhone: normalizedPhone,
          customerLocation: details.address, deliveryType: 'delivery',
          orderNote: details.note,
          couponCode: details.couponCode ?? '',
          discountPercent: details.discountPercent ?? 0,
          deliveryCharge: deliveryFee,
          items: cartItems.map((item) => ({
            productId: item.originalProductId ?? item.product.id,
            productName: item.product.name.en,
            variantName: item.variantName ?? '',
            qty: item.quantity, unit: item.product.unit,
            price: item.product.price, itemNote: item.note ?? '',
            subtotal: item.product.price * item.quantity,
          })),
          totalAmount: finalTotal,
          paymentMethod: details.paymentMethod ?? 'cash',
          paymentStatus: details.paymentMethod === 'upi' ? 'pending_verification' : 'pending',
          createdAt: now, updatedAt: now,
          ...(details.preferredDelivery ? { scheduledFor: new Date(details.preferredDelivery).toISOString() } : {}),
        }),
      });
      const resData = await response.json();
      if (resData.error === 'shop_closed') {
        setOrderError('This shop is currently closed. Please try again later.');
        setIsSubmitting(false);
        return;
      }
      if (resData.orderId) setNewOrderId(resData.orderId);
    } catch (e) {
      console.error('Failed to save order', e);
    } finally {
      setIsSubmitting(false);
    }
    setCurrentPage('confirmation');
  };

  if (!shopData) return <ShopSkeleton />;

  if (currentPage === 'cart') return (
    <>
      <Header shopName={shopData.shopName} shopNameMl={shopData.shopNameMl} logoUrl={shopData.logoUrl} language={language} onLanguageToggle={() => setLanguage(language === 'en' ? 'ml' : 'en')} onCartClick={() => setCurrentPage('cart')} />
      <CartPage language={language} onBack={() => setCurrentPage('shop')} onCheckout={() => setCurrentPage('checkout')} deliveryCharge={shopData.deliveryCharge} freeDeliveryAbove={0} minOrderAmount={shopData.minOrderAmount} isOpen={shopData.isOpen} />
    </>
  );

  if (currentPage === 'checkout') return (
    <CheckoutPage language={language} onBack={() => setCurrentPage('cart')} onConfirm={handleConfirmOrder} onLanguageToggle={() => setLanguage(language === 'en' ? 'ml' : 'en')} shopId={shopId} deliveryCharge={shopData.deliveryCharge} freeDeliveryAbove={0} upiId={shopData.upiId} isSubmitting={isSubmitting} errorMessage={orderError} />
  );

  if (currentPage === 'confirmation') return (
    <OrderConfirmation language={language} customerDetails={customerDetails} onBackToShop={() => setCurrentPage('shop')} whatsappNumber={shopData.ownerWhatsApp} orderId={newOrderId} />
  );

  if (currentPage === 'tracking' && orderId) return <OrderTracking orderId={orderId} shopId={shopId} />;

  return (
    <>
      {showSearchOverlay && (
        <SearchOverlay
          language={language}
          onClose={() => setShowSearchOverlay(false)}
          onProductClick={(p) => { setSelectedProduct(p); setShowSearchOverlay(false); }}
          activeCategory={selectedCategory}
          onApplyFilters={(q) => setSearchQuery(q)}
          products={products}
        />
      )}
      {announcementText && <AnnouncementModal text={announcementText} shopId={shopId} />}
      <Header shopName={shopData.shopName} shopNameMl={shopData.shopNameMl} logoUrl={shopData.logoUrl} language={language} onLanguageToggle={() => setLanguage(language === 'en' ? 'ml' : 'en')} onCartClick={() => setCurrentPage('cart')} />
      <div className="max-w-screen-xl mx-auto">
        <ShopBanner bannerImageUrl={shopData.bannerImageUrl} promotionalBanner={shopData.promotionalBanner} deliveryTimeEstimate={shopData.deliveryTimeEstimate} minOrderAmount={shopData.minOrderAmount} deliveryCharge={shopData.deliveryCharge} isOpen={shopData.isOpen} language={language} />
        {/* Shop contact bar — address, Maps link, WhatsApp contact */}
        {(shopData.address || shopData.ownerWhatsApp) && (
          <div className="flex items-center gap-1.5 px-4 py-2 text-xs text-muted-foreground border-b border-border bg-muted/30">
            {shopData.address && <><span>📍</span><span className="flex-1 truncate">{shopData.address}</span></>}
            {shopData.googleMapsLink && (
              <a href={shopData.googleMapsLink} target="_blank" rel="noopener noreferrer"
                 className="text-blue-600 underline font-medium whitespace-nowrap">
                Directions
              </a>
            )}
            {shopData.ownerWhatsApp && (
              <a href={`https://wa.me/${shopData.ownerWhatsApp.replace(/\D/g, '').replace(/^(\d{10})$/, '91$1')}?text=Hi, I have a question about your shop`}
                 target="_blank" rel="noopener noreferrer"
                 className="flex items-center gap-0.5 text-green-600 font-semibold whitespace-nowrap">
                <span>💬</span> Chat
              </a>
            )}
          </div>
        )}
        <div className="sticky top-16 z-40 bg-background px-4 py-2 shadow-sm">
          <SearchBar language={language} value={searchQuery} onSearchClick={() => setShowSearchOverlay(true)} />
        </div>
        <CategoryFilter language={language} categories={categories} selectedCategory={selectedCategory} onSelectCategory={setSelectedCategory} />
        <ProductGrid language={language} products={filteredProducts} onProductClick={setSelectedProduct} isFiltered={!!(searchQuery || selectedCategory !== 'all')} />
      </div>
      <FloatingCartBar language={language} onClick={() => setCurrentPage('cart')} isOpen={shopData.isOpen} />
      {/* Floating WhatsApp button — drives inbound conversations (free 24h service window) */}
      {shopData.ownerWhatsApp && (
        <a
          href={`https://wa.me/${shopData.ownerWhatsApp.replace(/\D/g, '').replace(/^(\d{10})$/, '91$1')}?text=${encodeURIComponent('Hi! I have a question about your products.')}`}
          target="_blank"
          rel="noopener noreferrer"
          className="fixed bottom-20 left-4 z-50 flex items-center gap-2 rounded-full bg-[#25D366] px-4 py-3 text-white shadow-lg transition-transform hover:scale-105 active:scale-95"
          aria-label="Chat on WhatsApp"
        >
          <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
            <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z"/>
          </svg>
          <span className="text-sm font-semibold">Chat with us</span>
        </a>
      )}
      <ChatWidget shopId={shopId} shopData={shopData} language={language} />
      {selectedProduct && (
        <ProductDetailSheet
          product={selectedProduct}
          language={language}
          onClose={() => setSelectedProduct(null)}
          allProducts={products}
          onProductClick={(p) => setSelectedProduct(p)}
        />
      )}
    </>
  );
}
