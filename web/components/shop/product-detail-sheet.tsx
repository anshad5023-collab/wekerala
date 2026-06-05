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
  allProducts?: Product[];
  onProductClick?: (product: Product) => void;
}

export function ProductDetailSheet({ product, language, onClose, allProducts, onProductClick }: ProductDetailSheetProps) {
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
      <div className="relative w-full rounded-t-2xl bg-white shadow-xl wk-sheet-enter flex flex-col" style={{ maxHeight: '88vh' }}>
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
        <div className="flex-1 overflow-y-auto p-5">
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
                      onClick={() => addItem(
                        { ...product, id: `${product.id}_${v.variantId}`, name: { en: `${product.name.en} (${v.name})`, ml: product.name.ml }, price: v.price, offerPrice: v.offerPrice ?? 0 },
                        { variantName: v.name, originalProductId: product.id }
                      )}
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

          {/* Similar products */}
          {(allProducts ?? []).length > 1 && (() => {
            const sameCat = (allProducts ?? []).filter(p => p.id !== product.id && p.category === product.category);
            const others = (allProducts ?? []).filter(p => p.id !== product.id && p.category !== product.category);
            const similar = [...sameCat, ...others].slice(0, 8);
            if (similar.length === 0) return null;
            return (
              <div className="mt-5 pt-5 border-t border-gray-100">
                <h3 className="text-sm font-bold text-gray-700 mb-3">
                  {language === 'ml' ? 'സമാനമായ ഉൽപ്പന്നങ്ങൾ' : 'More like this'}
                </h3>
                <div className="flex gap-2.5 overflow-x-auto pb-1" style={{ scrollbarWidth: 'none' }}>
                  {similar.map((sp) => {
                    const spDiscount = sp.offerPrice > 0 && sp.offerPrice < sp.price
                      ? sp.offerPrice : sp.price;
                    return (
                      <button
                        key={sp.id}
                        onClick={() => onProductClick?.(sp)}
                        className="shrink-0 w-24 rounded-xl overflow-hidden border border-gray-200 bg-white text-left shadow-sm hover:shadow-md transition-shadow active:scale-95"
                      >
                        <div className="relative h-20 bg-gray-100">
                          {sp.image ? (
                            <img
                              src={sp.image}
                              alt={sp.name[language]}
                              className="absolute inset-0 w-full h-full object-cover"
                            />
                          ) : (
                            <div className="absolute inset-0 flex items-center justify-center text-2xl">📦</div>
                          )}
                        </div>
                        <div className="p-1.5">
                          <p className="text-xs font-medium text-gray-800 truncate leading-tight">{sp.name[language]}</p>
                          <p className="text-xs font-bold text-primary mt-0.5">₹{spDiscount}</p>
                        </div>
                      </button>
                    );
                  })}
                </div>
              </div>
            );
          })()}
        </div>
      </div>
    </div>
  );
}
