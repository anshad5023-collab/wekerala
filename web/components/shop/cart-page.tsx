'use client';

import Image from 'next/image';
import { AnimatePresence, motion } from 'framer-motion';
import { ArrowLeft, Minus, Plus, ShoppingCart, Trash2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { useCartStore } from '@/lib/cart-store';
import { translations, type Language } from '@/lib/translations';

interface CartPageProps {
  language: Language;
  onBack: () => void;
  onCheckout: () => void;
  deliveryCharge?: number;
  freeDeliveryAbove?: number;
  minOrderAmount?: number;
  isOpen?: boolean;
}

export function CartPage({ language, onBack, onCheckout, deliveryCharge = 0, freeDeliveryAbove = 0, minOrderAmount = 0, isOpen = true }: CartPageProps) {
  const t = translations[language];
  const { items, updateQuantity, removeItem, getTotal } = useCartStore();
  const subtotal = getTotal();
  const isFreeDelivery = freeDeliveryAbove > 0 && subtotal >= freeDeliveryAbove;
  const actualDelivery = (deliveryCharge > 0 && !isFreeDelivery) ? deliveryCharge : 0;
  const total = subtotal + actualDelivery;
  const belowMin = minOrderAmount > 0 && subtotal < minOrderAmount;

  return (
    <div className="flex min-h-screen flex-col bg-[#f0fdf4]">
      {/* Header */}
      <header className="sticky top-0 z-50 flex items-center gap-3 bg-[#22c55e] px-4 py-4 text-white shadow-md">
        <Button
          variant="ghost"
          size="icon"
          onClick={onBack}
          className="text-white hover:bg-white/20 hover:text-white"
          aria-label="Go back"
        >
          <ArrowLeft className="h-5 w-5" />
        </Button>
        <h1 className="text-lg font-bold italic">{t.cart}</h1>
      </header>

      {/* Cart Items */}
      <div className="flex-1 overflow-auto">
        {items.length === 0 ? (
          <div className="flex flex-col items-center justify-center gap-4 py-20 text-center">
            <div className="flex h-20 w-20 items-center justify-center rounded-full bg-muted">
              <ShoppingCart className="h-10 w-10 text-muted-foreground" />
            </div>
            <div>
              <p className="text-lg font-semibold italic text-foreground">{t.emptyCart}</p>
              <p className="mt-1 text-sm italic text-muted-foreground">{t.startShopping}</p>
            </div>
            <Button onClick={onBack} className="mt-4">
              {t.backToShop}
            </Button>
          </div>
        ) : (
          <div className="divide-y divide-border">
            <AnimatePresence initial={false}>
            {items.map((item) => (
              <motion.div
                key={item.product.id}
                layout
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, height: 0, marginTop: 0, marginBottom: 0, overflow: 'hidden' }}
                transition={{ duration: 0.2, ease: 'easeOut' }}
                className="flex gap-3 bg-card p-4">
                <div className="relative h-20 w-20 flex-shrink-0 overflow-hidden rounded-lg bg-muted">
                  {item.product.image ? (
                    <Image
                      src={item.product.image}
                      alt={item.product.name[language]}
                      fill
                      className="object-cover"
                      sizes="80px"
                    />
                  ) : (
                    <div className="flex h-full w-full items-center justify-center text-3xl">📦</div>
                  )}
                </div>
                
                <div className="flex flex-1 flex-col">
                  <div className="flex items-start justify-between">
                    <div>
                      <h3 className="font-semibold italic text-card-foreground">
                        {item.product.name[language]}
                      </h3>
                      <p className="text-sm italic text-muted-foreground">
                        ₹{item.product.price} {t[item.product.unit]}
                      </p>
                    </div>
                    <Button
                      variant="ghost"
                      size="icon"
                      onClick={() => removeItem(item.product.id)}
                      className="h-8 w-8 text-destructive hover:bg-destructive/10 hover:text-destructive"
                      aria-label="Remove item"
                    >
                      <Trash2 className="h-4 w-4" />
                    </Button>
                  </div>
                  
                  <div className="mt-auto flex items-center justify-between">
                    <div className="flex items-center gap-2 rounded-lg border border-primary bg-primary/5 px-2">
                      <Button
                        variant="ghost"
                        size="icon"
                        onClick={() => updateQuantity(item.product.id, item.quantity - 1)}
                        className="h-7 w-7 text-primary hover:bg-primary/10 hover:text-primary"
                        aria-label="Decrease quantity"
                      >
                        <Minus className="h-3 w-3" />
                      </Button>
                      <span className="min-w-[1.5rem] text-center font-semibold italic text-primary">
                        {item.quantity}
                      </span>
                      <Button
                        variant="ghost"
                        size="icon"
                        onClick={() => updateQuantity(item.product.id, item.quantity + 1)}
                        className="h-7 w-7 text-primary hover:bg-primary/10 hover:text-primary"
                        aria-label="Increase quantity"
                      >
                        <Plus className="h-3 w-3" />
                      </Button>
                    </div>
                    
                    <span className="font-bold italic text-primary">
                      ₹{item.product.price * item.quantity}
                    </span>
                  </div>
                </div>
              </motion.div>
            ))}
            </AnimatePresence>
          </div>
        )}
      </div>

      {/* Checkout Bar */}
      {items.length > 0 && (
        <div className="sticky bottom-0 border-t border-border bg-card p-4 shadow-[0_-4px_20px_rgba(0,0,0,0.1)]">
          <div className="mb-2 space-y-1">
            <div className="flex items-center justify-between text-sm">
              <span className="italic text-muted-foreground">{t.cartTotal}</span>
              <span className="italic text-card-foreground">₹{subtotal}</span>
            </div>
            {deliveryCharge > 0 && (
              <div className="flex items-center justify-between text-sm">
                <span className="italic text-muted-foreground">
                  Delivery
                  {freeDeliveryAbove > 0 && !isFreeDelivery && (
                    <span className="ml-1 text-xs text-green-600">(free above ₹{freeDeliveryAbove})</span>
                  )}
                </span>
                <span className={`italic font-medium ${isFreeDelivery ? 'text-green-600 line-through' : 'text-card-foreground'}`}>
                  {isFreeDelivery ? 'Free' : `₹${deliveryCharge}`}
                </span>
              </div>
            )}
            {isFreeDelivery && (
              <p className="text-xs text-green-600 font-medium">🎉 You qualify for free delivery!</p>
            )}
            <div className="flex items-center justify-between border-t border-border pt-1 mt-1">
              <span className="italic text-muted-foreground font-semibold">Total</span>
              <span className="text-2xl font-bold italic text-primary">₹{total}</span>
            </div>
          </div>
          {!isOpen && (
            <p className="text-xs text-orange-600 mb-2 text-center font-medium">🔴 Shop is currently closed. Orders are not being accepted.</p>
          )}
          {belowMin && (
            <p className="text-xs text-red-500 mb-2">Minimum order ₹{minOrderAmount} (add ₹{minOrderAmount - subtotal} more)</p>
          )}
          <Button
            onClick={onCheckout}
            disabled={belowMin || !isOpen}
            className="w-full py-6 text-lg font-semibold italic disabled:opacity-50"
            size="lg"
          >
            {t.placeOrder}
          </Button>
        </div>
      )}
    </div>
  );
}
