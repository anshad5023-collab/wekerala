'use client';

import React, { useState } from 'react';
import { Check, MessageCircle, Store } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { useCartStore } from '@/lib/cart-store';
import { useAuthStore } from '@/lib/auth-store';
import { translations, type Language } from '@/lib/translations';
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
  const { items, getTotal, clearCart } = useCartStore();
  const { uid } = useAuthStore();
  const total = getTotal();
  const shopId = typeof window !== 'undefined' ? new URLSearchParams(window.location.search).get('shopId') : '';
  const [addressSaved, setAddressSaved] = useState(false);

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

  // Clear cart after order
  React.useEffect(() => {
    clearCart();
  }, [clearCart]);

  return (
    <div className="flex min-h-screen flex-col bg-[#f0fdf4]">
      <header className="sticky top-0 z-50 flex items-center justify-center bg-[#22c55e] px-4 py-4 text-white shadow-md">
        <h1 className="text-lg font-bold italic">{t.shopName}</h1>
      </header>

      <div className="flex flex-1 flex-col items-center justify-center p-6 text-center">
        <div className="mb-6 flex h-24 w-24 animate-bounce items-center justify-center rounded-full bg-primary/10">
          <div className="flex h-16 w-16 items-center justify-center rounded-full bg-primary">
            <Check className="h-10 w-10 text-primary-foreground" strokeWidth={3} />
          </div>
        </div>

        <h2 className="mb-2 text-2xl font-bold italic text-foreground">{t.orderPlaced}</h2>
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
