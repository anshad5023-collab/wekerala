'use client';

import { ProductCard } from './product-card';
import type { Product } from '@/lib/products';
import type { Language } from '@/lib/translations';

interface ProductGridProps {
  products: Product[];
  language: Language;
  onProductClick: (product: Product) => void;
}

export function ProductGrid({ products, language, onProductClick }: ProductGridProps) {
  if (products.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-12 text-muted-foreground">
        <p className="text-lg italic">{language === 'en' ? 'No products found' : 'ഉൽപ്പന്നങ്ങൾ കണ്ടെത്തിയില്ല'}</p>
      </div>
    );
  }

  return (
    <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-3 p-4">
      {products.map((product) => (
        <ProductCard 
          key={product.id} 
          product={product} 
          language={language} 
          onProductClick={onProductClick}
        />
      ))}
    </div>
  );
}
