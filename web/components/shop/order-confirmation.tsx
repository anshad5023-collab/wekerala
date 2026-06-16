'use client';

import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { Bell, BellOff, Check, MessageCircle, Store } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { useCartStore } from '@/lib/cart-store';
import { useAuthStore } from '@/lib/auth-store';
import { translations, type Language } from '@/lib/translations';
import { subscribeOrderToPush } from '@/lib/push-notifications';
import type { CustomerDetails } from './checkout-page';

interface OrderConfirmationProps {
  language: Language;
  customerDetails: CustomerDetails;
  onBackToShop: () => void;
  whatsappNumber: string;
  orderId: string;      // added
}

export function OrderConfirmation({ language, customerDetails, onBackToShop, whatsappNumber, orderId }: OrderConfirmationProps) {
  const t = translations[language];
  const { items: currentItems, getTotal, clearCart } = useCartStore();
  const { uid } = useAuthStore();
  const total = getTotal();
  const shopId = typeof window !== 'undefined' ? new URLSearchParams(window.location.search).get('shopId') : '';
  const [addressSaved, setAddressSaved] = useState(false);
  const [pushState, setPushState] = useState<'idle' | 'loading' | 'subscribed' | 'denied'>('idle');
  // Snapshot items before cart is cleared — needed for copy/WhatsApp functions
  const [items] = useState(currentItems);

  const saveAddress = async () => {
    if (!uid || !customerDetails.address) return;
    try {
      await fetch(`/api/customer/addresses?uid=${encodeURIComponent(uid)}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ label: 'Home', address: customerDetails.address }),
      });
      setAddressSaved(true);
    } catch { /* fail silently */ }
  };

  const generateWhatsAppMessage = () => {
    const itemList = items
      .map((item) => `• ${item.product.name[language]} x${item.quantity} - ₹${item.product.price * item.quantity}`)
      .join('\n');

    const message = `🛒 *New Order*\n\n*Customer:* ${customerDetails.name}\n*Phone:* ${customerDetails.phone}\n*Address:* ${customerDetails.address}${customerDetails.note ? `\n*Note:* ${customerDetails.note}` : ''}\n\n*Order Items:*\n${itemList}\n\n*Total:* ₹${total}`;

    return encodeURIComponent(message);
  };

  const handleWhatsApp = () => {
    const phoneNumber = whatsappNumber.replace(/\D/g, '');
    window.open(`https://wa.me/${phoneNumber}?text=${generateWhatsAppMessage()}`, '_blank');
  };

  const handleCopyOrder = async () => {
    const itemList = items
      .map((i) => `• ${i.product.name[language]} x${i.quantity} — ₹${i.product.price * i.quantity}`)
      .join('\n');
    const text = `📦 My Order\nOrder ID: ${orderId}\n\n${itemList}\n\nTotal: ₹${total}\nPhone: ${customerDetails.phone}`;
    await navigator.clipboard.writeText(text).catch(() => {});
    alert('Order details copied!');
  };

  const handleEnableNotifications = async () => {
    if (!orderId || !shopId) return;
    setPushState('loading');
    const success = await subscribeOrderToPush(shopId, orderId);
    setPushState(success ? 'subscribed' : 'denied');
  };

  // Clear cart after order
  React.useEffect(() => {
    clearCart();
  }, [clearCart]);

  return (
    <div className="flex min-h-screen flex-col bg-background">
      <header className="sticky top-0 z-50 flex items-center justify-center bg-primary px-4 py-4 text-primary-foreground shadow-md">
        <h1 className="text-lg font-bold italic">{t.shopName}</h1>
      </header>

      <div className="mx-auto flex w-full max-w-md flex-1 flex-col items-center justify-center p-6 text-center">
        <motion.div
          initial={{ scale: 0, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          transition={{ type: 'spring', stiffness: 260, damping: 18 }}
          className="mb-6 flex h-24 w-24 items-center justify-center rounded-full bg-primary/10"
        >
          <motion.div
            initial={{ scale: 0.6 }}
            animate={{ scale: 1 }}
            transition={{ delay: 0.15, type: 'spring', stiffness: 300, damping: 14 }}
            className="flex h-16 w-16 items-center justify-center rounded-full bg-primary"
          >
            <Check className="h-10 w-10 text-primary-foreground" strokeWidth={3} />
          </motion.div>
        </motion.div>

        <motion.h2
          initial={{ opacity: 0, y: 8 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.25 }}
          className="mb-2 text-2xl font-bold italic text-foreground"
        >
          {t.orderPlaced}
        </motion.h2>
        <p className="mb-8 italic text-muted-foreground">{t.orderSuccess}</p>

        <div className="mb-8 w-full rounded-xl border border-border bg-card p-4 text-left shadow-sm">
          <h3 className="mb-4 font-semibold italic text-card-foreground">{t.orderSummary}</h3>
          <div className="space-y-2 text-sm">
            {items.map((item) => (
              <div key={item.product.id} className="flex justify-between">
                <span className="italic text-muted-foreground">
                  {item.product.name[language]} x{item.quantity}
                </span>
                <span className="font-medium italic text-card-foreground">
                  ₹{item.product.price * item.quantity}
                </span>
              </div>
            ))}
            <div className="mt-3 border-t border-border pt-3">
              <div className="flex justify-between">
                <span className="font-semibold italic text-card-foreground">{t.total}</span>
                <span className="text-lg font-bold italic text-primary">₹{total}</span>
              </div>
            </div>
          </div>
        </div>

        <div className="w-full space-y-3">
          {/* Push notification opt-in — only show if browser supports it and not yet subscribed */}
          {typeof window !== 'undefined' && 'Notification' in window && pushState !== 'subscribed' && (
            <Button
              onClick={handleEnableNotifications}
              disabled={pushState === 'loading' || pushState === 'denied'}
              variant="outline"
              className="w-full gap-2 border-primary py-5 text-primary"
              size="lg"
            >
              {pushState === 'denied' ? (
                <><BellOff className="h-4 w-4" /> Notifications blocked</>
              ) : pushState === 'loading' ? (
                <><Bell className="h-4 w-4 animate-pulse" /> Enabling…</>
              ) : (
                <><Bell className="h-4 w-4" /> Get order status updates</>
              )}
            </Button>
          )}
          {pushState === 'subscribed' && (
            <p className="text-center text-xs text-green-600">
              You&apos;ll get browser notifications when your order status changes.
            </p>
          )}

          <Button
            onClick={handleWhatsApp}
            className="w-full gap-2 bg-[#25D366] py-6 text-lg font-semibold italic text-white hover:bg-[#20BD5A]"
            size="lg"
          >
            <MessageCircle className="h-5 w-5" />
            {t.whatsappUs}
          </Button>

          {orderId && shopId && (
            <a
              href={`/shop?shopId=${shopId}&view=tracking&orderId=${orderId}`}
              className="inline-block w-full text-center text-sm text-blue-600 underline mt-2"
            >
              Track Order
            </a>
          )}

          <button
            onClick={handleCopyOrder}
            className="mt-2 w-full rounded-lg border border-gray-200 py-2 text-sm text-gray-500 hover:bg-gray-50"
          >
            📋 Copy Order Details
          </button>

          <a
            href="/customer/orders"
            className="inline-block w-full text-center text-sm text-muted-foreground underline mt-1"
          >
            View all my orders
          </a>

          {uid && customerDetails.address && !addressSaved && (
            <button
              onClick={saveAddress}
              className="inline-block w-full text-center text-xs text-primary underline mt-1"
            >
              Save &quot;{customerDetails.address.slice(0, 40)}{customerDetails.address.length > 40 ? '…' : ''}&quot; as my address
            </button>
          )}
          {addressSaved && (
            <p className="text-center text-xs text-green-600 mt-1">✓ Address saved</p>
          )}

          <Button
            onClick={onBackToShop}
            variant="outline"
            className="w-full gap-2 py-6 text-lg font-semibold italic"
            size="lg"
          >
            <Store className="h-5 w-5" />
            {t.backToShop}
          </Button>
        </div>
      </div>
    </div>
  );
}
