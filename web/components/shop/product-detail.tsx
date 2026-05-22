'use client';

import Image from 'next/image';
import { ArrowLeft, Minus, Plus } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { useCartStore } from '@/lib/cart-store';
import { translations, type Language } from '@/lib/translations';
import type { Product } from '@/lib/products';

interface ProductDetailProps {
  product: Product;
  language: Language;
  onBack: () => void;
}

export function ProductDetail({ product, language, onBack }: ProductDetailProps) {
  const t = translations[language];
  const { addItem, updateQuantity, getItemQuantity } = useCartStore();
  const quantity = getItemQuantity(product.id);

  const handleAddToCart = () => {
    if (quantity === 0) {
      addItem(product);
    }
  };

  return (
    <div className="min-h-screen bg-[#f0fdf4]">
      {/* Header */}
      <header className="sticky top-0 z-50 flex items-center gap-3 bg-[#22c55e] px-4 py-3 text-white shadow-md">
        <Button
          variant="ghost"
          size="icon"
          onClick={onBack}
          className="text-white hover:bg-white/20 hover:text-white"
          aria-label="Go back"
        >
          <ArrowLeft className="h-5 w-5" />
        </Button>
        <h1 className="text-lg font-bold italic">{t.productDetails}</h1>
      </header>

      {/* Product Image */}
      <div className="relative aspect-square w-full bg-white">
        <Image
          src={product.image}
          alt={product.name[language]}
          fill
          className="object-cover"
          sizes="100vw"
          priority
        />
      </div>

      {/* Product Info */}
      <div className="p-4">
        <h2 className="text-xl font-bold italic text-foreground">
          {product.name[language]}
        </h2>
        
        <p className="mt-2 italic text-muted-foreground">
          {language === 'en' ? 'Fresh from farm' : 'കൃഷിയിടത്തിൽ നിന്ന് പുതിയത്'}
        </p>
        
        <div className="mt-4 flex items-baseline gap-2">
          <span className="text-2xl font-bold italic text-primary">₹{product.price}</span>
          <span className="italic text-muted-foreground">{t[product.unit]}</span>
        </div>

        {/* Quantity Stepper */}
        <div className="mt-6">
          {quantity === 0 ? (
            <Button
              onClick={handleAddToCart}
              className="w-full rounded-xl bg-primary py-6 text-lg font-semibold italic text-primary-foreground hover:bg-primary/90"
            >
              {t.addToCart}
            </Button>
          ) : (
            <div className="flex items-center justify-center gap-4 rounded-xl border-2 border-primary bg-primary/5 py-3">
              <Button
                variant="ghost"
                size="icon"
                onClick={() => updateQuantity(product.id, quantity - 1)}
                className="h-10 w-10 rounded-full text-primary hover:bg-primary/10 hover:text-primary"
                aria-label="Decrease quantity"
              >
                <Minus className="h-5 w-5" />
              </Button>
              <span className="min-w-[3rem] text-center text-xl font-bold italic text-primary">
                {quantity}
              </span>
              <Button
                variant="ghost"
                size="icon"
                onClick={() => updateQuantity(product.id, quantity + 1)}
                className="h-10 w-10 rounded-full text-primary hover:bg-primary/10 hover:text-primary"
                aria-label="Increase quantity"
              >
                <Plus className="h-5 w-5" />
              </Button>
            </div>
          )}
        </div>

        {quantity > 0 && (
          <p className="mt-4 text-center italic text-muted-foreground">
            {language === 'en' ? 'Item added to cart' : 'ഇനം കാർട്ടിലേക്ക് ചേർത്തു'}
          </p>
        )}
      </div>
    </div>
  );
}
