'use client';

import { AnimatePresence, motion } from 'framer-motion';
import { ShoppingBag } from 'lucide-react';
import { useCartStore } from '@/lib/cart-store';
import { translations, type Language } from '@/lib/translations';

interface FloatingCartBarProps {
  language: Language;
  onClick: () => void;
  isOpen?: boolean;
}

export function FloatingCartBar({ language, onClick, isOpen = true }: FloatingCartBarProps) {
  const t = translations[language];
  const itemCount = useCartStore((state) => state.getItemCount());
  const total = useCartStore((state) => state.getTotal());

  return (
    <AnimatePresence>
      {itemCount > 0 && (
        <motion.button
          onClick={onClick}
          initial={{ y: 80, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          exit={{ y: 80, opacity: 0 }}
          transition={{ type: 'spring', stiffness: 400, damping: 30 }}
          className={`fixed inset-x-4 bottom-4 z-40 flex items-center justify-between rounded-xl px-5 py-4 shadow-lg transition-colors active:scale-[0.98] ${isOpen ? 'bg-primary text-primary-foreground' : 'bg-gray-400 text-white'}`}
        >
          <div className="flex items-center gap-3">
            <ShoppingBag className="h-5 w-5" />
            <span className="font-medium italic">
              {/* key change makes the count pop when items are added/removed */}
              <motion.span
                key={itemCount}
                initial={{ scale: 1.4 }}
                animate={{ scale: 1 }}
                transition={{ type: 'spring', stiffness: 500, damping: 15 }}
                className="inline-block"
              >
                {itemCount}
              </motion.span>{' '}
              {itemCount === 1 ? t.item : t.items}
            </span>
          </div>

          <span className="font-semibold italic">{isOpen ? t.viewCart : '🔴 Closed'}</span>

          <span className="font-bold italic">₹{total}</span>
        </motion.button>
      )}
    </AnimatePresence>
  );
}
