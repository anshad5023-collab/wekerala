'use client';

import { useEffect } from 'react';
import Image from 'next/image';
import { X, Minus, Plus } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { useCartStore } from '@/lib/cart-store';
import { translations, type Language } from '@/lib/translations';
import type { Product } from '@/lib/products';

interface ProductDetailSheetProps {
  product: Product;
  language: Language;
  onClose: () => void;
}

export function ProductDetailSheet({ product, language, onClose }: ProductDetailSheetProps) {
  const t = translations[language];
  const { addItem, updateQuantity, getItemQuantity } = useCartStore();
  const quantity = getItemQuantity(product.id);

  const discountPct =
    product.offerPrice > 0 && product.offerPrice < product.price
      ? Math.round(((product.price - product.offerPrice) / product.price) * 100)
      : 0;
  const displayPrice = discountPct > 0 ? product.offerPrice : product.price;

  // Close on backdrop click or Escape key
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    document.addEventListener('keydown', onKey);
    document.body.style.overflow = 'hidden';
    return () => {
      document.removeEventListener('keydown', onKey);
      document.body.style.overflow = '';
    };
  }, [onClose]);

  return (
    <div className="fixed inset-0 z-50 flex items-end">
      {/* Backdrop */}
      <div className="absolute inset-0 bg-black/50" onClick={onClose} />

      {/* Sheet */}
      <div className="relative w-full rounded-t-2xl bg-white shadow-xl animate-in slide-in-from-bottom duration-300">
        {/* Close button */}
        <button
          onClick={onClose}
          className="absolute right-4 top-4 z-10 rounded-full bg-gray-100 p-1.5 text-gray-500 hover:bg-gray-200"
        >
          <X className="h-4 w-4" />
        </button>

        {/* Product image */}
        <div className="relative h-56 w-full overflow-hidden rounded-t-2xl bg-gray-100">
          {product.image ? (
            <Image
              src={product.image}
              alt={product.name[language]}
              fill
              className="object-cover"
              sizes="100vw"
            />
          ) : (
            <div className="flex h-full items-center justify-center text-6xl">🛒</div>
          )}
          {discountPct > 0 && (
            <span className="absolute left-3 top-3 rounded-md bg-green-500 px-2 py-0.5 text-xs font-bold text-white">
              {discountPct}% OFF
            </span>
          )}
        </div>

        {/* Content */}
        <div className="p-5">
          <h2 className="text-xl font-bold text-gray-900">{product.name.en}</h2>
          {product.name.ml && (
            <p className="mt-0.5 text-sm text-gray-500">{product.name.ml}</p>
          )}

          {/* Price */}
          <div className="mt-3 flex items-baseline gap-2">
            <span className="text-2xl font-bold text-primary">₹{displayPrice}</span>
            {discountPct > 0 && (
              <span className="text-base text-gray-400 line-through">₹{product.price}</span>
            )}
            <span className="text-sm text-gray-400">/ {t[product.unit]}</span>
          </div>

          <div className="mt-1 text-xs text-gray-400 capitalize">
            Category: {product.category}
          </div>

          {/* Product description — shown if owner has added one */}
          {product.description && (
            <div className="mt-3 rounded-lg bg-gray-50 px-3 py-2">
              <p className="text-sm text-gray-600 leading-relaxed">{product.description}</p>
            </div>
          )}

          {/* Variants — for textile/clothing shops with color/size options */}
          {product.hasVariants && product.variants && product.variants.length > 0 && (
            <div className="mt-3">
              <p className="text-xs font-semibold text-gray-500 mb-2">SELECT OPTION</p>
              <div className="flex flex-wrap gap-2">
                {product.variants
                  .filter((v) => (v.stockQty === undefined || v.stockQty > 0))
                  .map((v) => (
                    <button
                      key={v.variantId}
                      onClick={() => addItem({ ...product, id: `${product.id}_${v.variantId}`, name: { en: `${product.name.en} (${v.name})`, ml: product.name.ml }, price: v.price, offerPrice: v.offerPrice ?? 0 })}
                      className="rounded-lg border border-primary/40 px-3 py-1.5 text-sm font-medium text-primary hover:bg-primary/10"
                    >
                      {v.name} — ₹{v.price}
                    </button>
                  ))}
              </div>
            </div>
          )}

          {product.isOutOfStock && (
            <div className="mt-3 rounded-lg bg-red-50 px-3 py-2 text-sm font-medium text-red-600">
              This item is currently out of stock
            </div>
          )}

          {/* Add / stepper — hidden for variant products (user picks via variant buttons) */}
          <div className="mt-5">
            {quantity === 0 ? (
              !(product.hasVariants && product.variants && product.variants.length > 0) && (
                <Button
                  onClick={() => addItem(product)}
                  disabled={product.isOutOfStock}
                  className="h-12 w-full rounded-xl text-base font-semibold"
                  size="lg"
                >
                  + {t.addButton}
                </Button>
              )
            ) : (
              <div className="flex h-12 items-center justify-between rounded-xl border-2 border-primary bg-primary/5">
                <Button
                  variant="ghost"
                  size="icon"
                  onClick={() => updateQuantity(product.id, quantity - 1)}
                  className="h-12 w-14 text-primary hover:bg-primary/10"
                  aria-label="Decrease"
                >
                  <Minus className="h-5 w-5" />
                </Button>
                <span className="text-xl font-bold text-primary">{quantity}</span>
                <Button
                  variant="ghost"
                  size="icon"
                  onClick={() => updateQuantity(product.id, quantity + 1)}
                  className="h-12 w-14 text-primary hover:bg-primary/10"
                  aria-label="Increase"
                >
                  <Plus className="h-5 w-5" />
                </Button>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
