'use client';

import Image from 'next/image';
import { Minus, Plus } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { useCartStore } from '@/lib/cart-store';
import { translations, type Language } from '@/lib/translations';
import { haptic } from '@/lib/haptics';
import type { Product } from '@/lib/products';

interface ProductCardProps {
  product: Product;
  language: Language;
  onProductClick: (product: Product) => void;
}

export function ProductCard({ product, language, onProductClick }: ProductCardProps) {
  const t = translations[language];
  const { addItem, updateQuantity, getItemQuantity } = useCartStore();
  const quantity = getItemQuantity(product.id);

  const discountPct =
    product.offerPrice > 0 && product.offerPrice < product.price
      ? Math.round(((product.price - product.offerPrice) / product.price) * 100)
      : 0;

  const displayPrice = discountPct > 0 ? product.offerPrice : product.price;

  const handleAddClick = (e: React.MouseEvent) => {
    e.stopPropagation();
    haptic('medium');
    addItem(product);
  };

  const handleQuantityChange = (e: React.MouseEvent, newQuantity: number) => {
    e.stopPropagation();
    haptic('light');
    updateQuantity(product.id, newQuantity);
  };

  return (
    <div
      className="group relative flex cursor-pointer flex-col overflow-hidden rounded-xl border border-border bg-card shadow-sm transition-all duration-200 hover:-translate-y-1 hover:shadow-lg active:scale-[0.98]"
      onClick={() => onProductClick(product)}
    >
      {/* Discount badge */}
      {discountPct > 0 && (
        <span className="absolute left-2 top-2 z-10 rounded-md bg-red-500 px-1.5 py-0.5 text-[10px] font-bold text-white shadow-sm">
          {discountPct}% OFF
        </span>
      )}

      {/* Out of stock overlay */}
      {product.isOutOfStock && (
        <div className="absolute inset-0 z-10 flex items-center justify-center rounded-xl bg-black/40">
          <span className="rounded-md bg-white px-2 py-1 text-xs font-semibold text-gray-700">
            Out of Stock
          </span>
        </div>
      )}

      {/* Product image */}
      <div className="relative h-[120px] w-full overflow-hidden bg-muted">
        {product.image ? (
          <Image
            src={product.image}
            alt={product.name[language]}
            fill
            className="object-cover transition-transform duration-300 group-hover:scale-110"
            sizes="(max-width: 768px) 50vw, 25vw"
            quality={55}
          />
        ) : (
          <div className="flex h-full items-center justify-center text-4xl bg-muted/60">
            {(() => {
              const c = (product.category ?? '').toLowerCase();
              if (c.includes('grocery') || c.includes('staple')) return '🌾';
              if (c.includes('chicken') || c.includes('poultry')) return '🍗';
              if (c.includes('fish') || c.includes('seafood') || c.includes('prawn')) return '🐟';
              if (c.includes('beef') || c.includes('mutton') || c.includes('pork')) return '🥩';
              if (c.includes('dairy') || c.includes('egg')) return '🥛';
              if (c.includes('vegetable') || c.includes('vegs')) return '🥦';
              if (c.includes('fruit')) return '🍎';
              if (c.includes('beverage') || c.includes('drink')) return '🥤';
              if (c.includes('snack') || c.includes('biscuit')) return '🍪';
              if (c.includes('bread') || c.includes('bakery')) return '🥐';
              if (c.includes('medicine') || c.includes('pharma')) return '💊';
              if (c.includes('cleaning') || c.includes('detergent')) return '🧹';
              if (c.includes('personal') || c.includes('beauty')) return '🧴';
              if (c.includes('shoe') || c.includes('footwear') || c.includes('sandal')) return '👟';
              if (c.includes('cloth') || c.includes('textile') || c.includes('dress')) return '👗';
              if (c.includes('baby')) return '🍼';
              return '📦';
            })()}
          </div>
        )}
      </div>

      {/* Info */}
      <div className="flex flex-1 flex-col p-2">
        <h3 className="line-clamp-2 text-sm font-bold leading-tight text-card-foreground">
          {product.name[language]}
        </h3>

        {/* Price row */}
        {product.hasVariants && product.variants && product.variants.length > 0 ? (
          <div className="mt-1">
            <span className="text-sm font-semibold text-primary">
              From ₹{Math.min(...product.variants.map(v => v.offerPrice && v.offerPrice > 0 ? v.offerPrice : v.price))}
            </span>
            <span className="ml-1 text-xs text-muted-foreground italic">{product.variants.length} options</span>
          </div>
        ) : (
          <div className="mt-1 flex items-baseline gap-1.5 flex-wrap">
            <span className="text-base font-bold text-primary">₹{displayPrice}</span>
            {discountPct > 0 && (
              <span className="text-xs text-muted-foreground line-through">₹{product.price}</span>
            )}
            <span className="text-xs text-muted-foreground">/{t[product.unit]}</span>
          </div>
        )}

        {/* Add / stepper — for variant products, tap opens detail sheet */}
        <div className="mt-2">
          {product.hasVariants && product.variants && product.variants.length > 0 ? (
            <Button
              size="sm"
              variant="outline"
              className="h-8 w-full rounded-lg text-xs font-semibold border-primary text-primary"
            >
              Select Option
            </Button>
          ) : quantity === 0 ? (
            <Button
              onClick={handleAddClick}
              disabled={product.isOutOfStock}
              size="sm"
              className="h-8 w-full rounded-lg bg-primary text-xs font-semibold text-primary-foreground hover:bg-primary/90"
            >
              + {t.addButton}
            </Button>
          ) : (
            <div className="flex h-8 items-center justify-between rounded-lg border border-primary bg-primary/5">
              <Button
                variant="ghost"
                size="icon"
                onClick={(e) => handleQuantityChange(e, quantity - 1)}
                className="h-8 w-8 text-primary hover:bg-primary/10 hover:text-primary"
                aria-label="Decrease"
              >
                <Minus className="h-3 w-3" />
              </Button>
              <span className="min-w-[1.5rem] text-center text-sm font-bold text-primary">
                {quantity}
              </span>
              <Button
                variant="ghost"
                size="icon"
                onClick={(e) => handleQuantityChange(e, quantity + 1)}
                className="h-8 w-8 text-primary hover:bg-primary/10 hover:text-primary"
                aria-label="Increase"
              >
                <Plus className="h-3 w-3" />
              </Button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
