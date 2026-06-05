'use client';

import { useState, useEffect, useMemo } from 'react';
import { ArrowLeft, X, Search, SlidersHorizontal, Check } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { translations, type Language } from '@/lib/translations';
import { useFilterStore } from '@/lib/filter-store';
import { type Product } from '@/lib/products';
import { cn } from '@/lib/utils';

interface SearchOverlayProps {
  language: Language;
  onClose: () => void;
  onProductClick: (product: Product) => void;
  activeCategory: string;
  onApplyFilters: (searchQuery: string) => void;
  products: Product[];
}

export function SearchOverlay({
  language,
  onClose,
  onProductClick,
  activeCategory,
  onApplyFilters,
  products,
}: SearchOverlayProps) {
  const [searchQuery, setSearchQuery] = useState('');
  const [debouncedQuery, setDebouncedQuery] = useState('');
  const [showFilters, setShowFilters] = useState(true);

  // Debounce search input by 200ms to avoid filtering on every keystroke
  useEffect(() => {
    const timer = setTimeout(() => setDebouncedQuery(searchQuery), 200);
    return () => clearTimeout(timer);
  }, [searchQuery]);
  const t = translations[language];

  const {
    priceFilters,
    variantFilters,
    selectedPriceFilter,
    selectedVariants,
    setSelectedPriceFilter,
    toggleVariantOption,
    clearAllFilters,
    getActiveFilterCount,
  } = useFilterStore();

  const filterCount = getActiveFilterCount();

  // Get the selected price filter object
  const activePriceFilter = priceFilters.find((f) => f.id === selectedPriceFilter);

  // Filter products based on search, category, price, and variants
  const filteredProducts = useMemo(() => {
    return products.filter((product) => {
      // When a search query is active, search across ALL categories
      // so customers find products regardless of miscategorisation
      const matchesCategory = debouncedQuery
        ? true
        : activeCategory === 'all' || product.category === activeCategory;

      // Search filter (uses debounced value for performance)
      const q = debouncedQuery.toLowerCase();
      const matchesSearch =
        debouncedQuery === '' ||
        product.name.en.toLowerCase().includes(q) ||
        product.name.ml.toLowerCase().includes(q) ||
        (product.searchAlias ?? '').toLowerCase().includes(q);

      // Price filter
      let matchesPrice = true;
      if (activePriceFilter) {
        const { min, max } = activePriceFilter;
        matchesPrice = product.price >= min && (max === null || product.price <= max);
      }

      return matchesCategory && matchesSearch && matchesPrice;
    });
  }, [activeCategory, debouncedQuery, activePriceFilter]);

  const handleApply = () => {
    onApplyFilters(searchQuery);
    onClose();
  };

  const filterTranslations = {
    en: {
      filters: 'Filters',
      priceRange: 'Price Range',
      clearAll: 'Clear All',
      apply: 'Apply Filters',
      results: 'Results',
      noResults: 'No products found',
      searchProducts: 'Search products...',
    },
    ml: {
      filters: 'ഫിൽട്ടറുകൾ',
      priceRange: 'വില ശ്രേണി',
      clearAll: 'എല്ലാം മായ്ക്കുക',
      apply: 'ഫിൽട്ടറുകൾ പ്രയോഗിക്കുക',
      results: 'ഫലങ്ങൾ',
      noResults: 'ഉൽപ്പന്നങ്ങൾ കണ്ടെത്തിയില്ല',
      searchProducts: 'ഉൽപ്പന്നങ്ങൾ തിരയുക...',
    },
  };

  const ft = filterTranslations[language];

  return (
    <div className="fixed inset-0 z-50 flex flex-col bg-[#f0fdf4]">
      {/* Header */}
      <header className="sticky top-0 z-10 flex items-center gap-3 bg-[#22c55e] px-4 py-3 text-white shadow-md">
        <button
          onClick={onClose}
          className="flex h-10 w-10 items-center justify-center rounded-full hover:bg-white/10"
        >
          <ArrowLeft className="h-5 w-5" />
        </button>
        
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-400" />
          <input
            type="text"
            autoFocus
            placeholder={ft.searchProducts}
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full rounded-full bg-white py-2.5 pl-10 pr-4 text-sm italic text-gray-900 outline-none placeholder:text-gray-400"
          />
        </div>
        
        <button
          onClick={() => setShowFilters(!showFilters)}
          className={cn(
            'relative flex h-10 w-10 items-center justify-center rounded-full',
            showFilters ? 'bg-white/20' : 'hover:bg-white/10'
          )}
        >
          <SlidersHorizontal className="h-5 w-5" />
          {filterCount > 0 && (
            <span className="absolute -right-1 -top-1 flex h-5 w-5 items-center justify-center rounded-full bg-white text-xs font-bold text-[#22c55e]">
              {filterCount}
            </span>
          )}
        </button>
      </header>

      {/* Filter Section */}
      {showFilters && (
        <div className="border-b border-[#22c55e]/20 bg-white p-4">
          <div className="mb-4 flex items-center justify-between">
            <h2 className="font-semibold italic text-gray-800">{ft.filters}</h2>
            {filterCount > 0 && (
              <button
                onClick={clearAllFilters}
                className="text-sm italic text-[#22c55e] hover:underline"
              >
                {ft.clearAll}
              </button>
            )}
          </div>

          {/* Price Range Filters */}
          <div className="mb-4">
            <h3 className="mb-2 text-sm font-medium italic text-gray-600">{ft.priceRange}</h3>
            <div className="flex flex-wrap gap-2">
              {priceFilters.map((filter) => (
                <button
                  key={filter.id}
                  onClick={() =>
                    setSelectedPriceFilter(
                      selectedPriceFilter === filter.id ? null : filter.id
                    )
                  }
                  className={cn(
                    'flex items-center gap-1.5 rounded-full border px-3 py-1.5 text-sm italic transition-all',
                    selectedPriceFilter === filter.id
                      ? 'border-[#22c55e] bg-[#22c55e] text-white'
                      : 'border-gray-300 bg-white text-gray-700 hover:border-[#22c55e]'
                  )}
                >
                  {selectedPriceFilter === filter.id && <Check className="h-3 w-3" />}
                  {filter.label[language]}
                </button>
              ))}
            </div>
          </div>

          {/* Variant Filters */}
          {variantFilters.map((variant) => (
            <div key={variant.id} className="mb-4">
              <h3 className="mb-2 text-sm font-medium italic text-gray-600">
                {variant.name[language]}
              </h3>
              <div className="flex flex-wrap gap-2">
                {variant.options.map((option) => {
                  const isSelected = (selectedVariants[variant.id] || []).includes(option.id);
                  
                  if (variant.type === 'color') {
                    return (
                      <button
                        key={option.id}
                        onClick={() => toggleVariantOption(variant.id, option.id)}
                        className={cn(
                          'flex items-center gap-2 rounded-full border px-3 py-1.5 text-sm italic transition-all',
                          isSelected
                            ? 'border-[#22c55e] bg-[#dcfce7]'
                            : 'border-gray-300 bg-white hover:border-[#22c55e]'
                        )}
                      >
                        <span
                          className="h-4 w-4 rounded-full border border-gray-200"
                          style={{ backgroundColor: option.colorCode }}
                        />
                        {option.label[language]}
                        {isSelected && <Check className="h-3 w-3 text-[#22c55e]" />}
                      </button>
                    );
                  }
                  
                  return (
                    <button
                      key={option.id}
                      onClick={() => toggleVariantOption(variant.id, option.id)}
                      className={cn(
                        'flex items-center gap-1.5 rounded-full border px-3 py-1.5 text-sm italic transition-all',
                        isSelected
                          ? 'border-[#22c55e] bg-[#22c55e] text-white'
                          : 'border-gray-300 bg-white text-gray-700 hover:border-[#22c55e]'
                      )}
                    >
                      {isSelected && <Check className="h-3 w-3" />}
                      {option.label[language]}
                    </button>
                  );
                })}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Results Section */}
      <div className="flex-1 overflow-auto p-4">
        <p className="mb-3 text-sm italic text-gray-500">
          {filteredProducts.length} {ft.results}
        </p>
        
        {filteredProducts.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-12 text-gray-500">
            <Search className="mb-2 h-12 w-12 opacity-30" />
            <p className="italic">{ft.noResults}</p>
          </div>
        ) : (
          <div className="grid grid-cols-2 gap-3">
            {filteredProducts.map((product) => (
              <button
                key={product.id}
                onClick={() => {
                  onProductClick(product);
                  onClose();
                }}
                className="flex flex-col overflow-hidden rounded-xl bg-white shadow-sm transition-transform hover:scale-[1.02] active:scale-[0.98]"
              >
                <div className="relative aspect-square w-full overflow-hidden bg-gray-100">
                  {product.image ? (
                    <img
                      src={product.image}
                      alt={product.name[language]}
                      className="h-full w-full object-cover"
                      onError={(e) => { (e.target as HTMLImageElement).style.display = 'none'; }}
                    />
                  ) : (
                    <div className="flex h-full w-full items-center justify-center text-3xl">🛒</div>
                  )}
                  {product.isOutOfStock && (
                    <div className="absolute inset-0 flex items-center justify-center bg-black/40">
                      <span className="rounded-md bg-black/70 px-2 py-1 text-[10px] font-bold text-white uppercase tracking-wide">
                        Out of Stock
                      </span>
                    </div>
                  )}
                </div>
                <div className="p-2.5">
                  <h3 className={`line-clamp-1 text-left text-sm font-semibold italic ${product.isOutOfStock ? 'text-gray-400' : 'text-gray-800'}`}>
                    {product.name[language]}
                  </h3>
                  <p className={`mt-0.5 text-left text-sm italic ${product.isOutOfStock ? 'text-gray-400' : 'text-[#22c55e]'}`}>
                    ₹{product.price}
                  </p>
                </div>
              </button>
            ))}
          </div>
        )}
      </div>

      {/* Apply Button */}
      <div className="border-t border-gray-200 bg-white p-4">
        <Button
          onClick={handleApply}
          className="w-full py-6 text-lg font-semibold italic"
          size="lg"
        >
          {ft.apply} {filterCount > 0 && `(${filterCount})`}
        </Button>
      </div>
    </div>
  );
}
