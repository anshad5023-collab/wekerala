'use client';

import { ProductCard } from './product-card';
import type { Product } from '@/lib/products';
import type { Language } from '@/lib/translations';

interface ProductGridProps {
  products: Product[];
  language: Language;
  onProductClick: (product: Product) => void;
  isFiltered?: boolean;
}

export function ProductGrid({ products, language, onProductClick, isFiltered }: ProductGridProps) {
  if (products.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-16 px-4 text-center">
        <div className="mb-4 text-5xl">{isFiltered ? '🔍' : '🛒'}</div>
        <p className="text-base font-semibold italic text-foreground mb-1">
          {isFiltered
            ? (language === 'en' ? 'No matching products' : 'പൊരുത്തപ്പെടുന്ന ഉൽപ്പന്നങ്ങൾ ഇല്ല')
            : (language === 'en' ? 'No products yet' : 'ഉൽപ്പന്നങ്ങൾ ഇല്ല')}
        </p>
        <p className="text-sm italic text-muted-foreground">
          {isFiltered
            ? (language === 'en' ? 'Try a different search or category' : 'മറ്റൊരു തിരയൽ ശ്രമിക്കുക')
            : (language === 'en' ? 'Check back soon!' : 'ഉടൻ തിരികെ വരൂ!')}
        </p>
      </div>
    );
  }

  return (
    <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-3 p-4">
      {products.map((product, i) => (
        <div
          key={product.id}
          className="wk-fade-up"
          // Stagger only the first dozen so above-the-fold cards cascade in;
          // later cards appear instantly to avoid a long wait on big catalogs.
          style={{ animationDelay: `${Math.min(i, 11) * 0.04}s` }}
        >
          <ProductCard
            product={product}
            language={language}
            onProductClick={onProductClick}
          />
        </div>
      ))}
    </div>
  );
}
