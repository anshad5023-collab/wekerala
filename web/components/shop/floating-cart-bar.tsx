'use client';

import { ShoppingBag } from 'lucide-react';
import { useCartStore } from '@/lib/cart-store';
import { translations, type Language } from '@/lib/translations';

interface FloatingCartBarProps {
  language: Language;
  onClick: () => void;
}

export function FloatingCartBar({ language, onClick }: FloatingCartBarProps) {
  const t = translations[language];
  const itemCount = useCartStore((state) => state.getItemCount());
  const total = useCartStore((state) => state.getTotal());

  if (itemCount === 0) return null;

  return (
    <button
      onClick={onClick}
      className="fixed inset-x-4 bottom-4 z-40 flex items-center justify-between rounded-xl bg-primary px-5 py-4 text-primary-foreground shadow-lg transition-transform active:scale-[0.98]"
    >
      <div className="flex items-center gap-3">
        <ShoppingBag className="h-5 w-5" />
        <span className="font-medium italic">
          {itemCount} {itemCount === 1 ? t.item : t.items}
        </span>
      </div>
      
      <span className="font-semibold italic">{t.viewCart}</span>
      
      <span className="font-bold italic">₹{total}</span>
    </button>
  );
}
