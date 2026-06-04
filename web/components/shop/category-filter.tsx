'use client';

import { cn } from '@/lib/utils';
import type { Language } from '@/lib/translations';

const CATEGORY_ICONS: Record<string, string> = {
  all: '🏪',
  vegetables: '🥦',
  fruits: '🍎',
  dairy: '🥛',
  grains: '🌾',
  rice: '🍚',
  spices: '🌶️',
  snacks: '🍿',
  beverages: '🧃',
  meat: '🥩',
  fish: '🐟',
  bakery: '🍞',
  cleaning: '🧹',
  personal: '🧴',
  baby: '🍼',
  frozen: '❄️',
  oil: '🫙',
  pulses: '🫘',
  eggs: '🥚',
  bread: '🥖',
};

function getCategoryIcon(cat: string): string {
  const lower = cat.toLowerCase();
  for (const key of Object.keys(CATEGORY_ICONS)) {
    if (lower.includes(key)) return CATEGORY_ICONS[key];
  }
  return '📦';
}

interface CategoryFilterProps {
  language: Language;
  categories: string[];
  selectedCategory: string;
  onSelectCategory: (category: string) => void;
}

export function CategoryFilter({
  categories,
  selectedCategory,
  onSelectCategory,
}: CategoryFilterProps) {
  // Hide category filter when there's only 'all' — no real filtering possible
  if (categories.length <= 1) return null;

  return (
    <div className="bg-white px-4 py-3 shadow-sm">
      <div className="flex gap-2 overflow-x-auto pb-1 scrollbar-hide">
        {categories.map((cat) => {
          const isActive = selectedCategory === cat || (!selectedCategory && cat === 'all');
          const label = cat === 'all' ? 'All' : cat.charAt(0).toUpperCase() + cat.slice(1);
          return (
            <button
              key={cat}
              onClick={() => onSelectCategory(cat)}
              className={cn(
                'flex flex-shrink-0 items-center gap-1.5 rounded-full border px-3 py-1.5 text-sm font-medium transition-all',
                isActive
                  ? 'border-primary bg-primary text-white shadow-sm'
                  : 'border-gray-200 bg-white text-gray-600 hover:border-primary/50 hover:bg-primary/5'
              )}
            >
              <span>{getCategoryIcon(cat)}</span>
              <span>{label}</span>
            </button>
          );
        })}
      </div>
    </div>
  );
}
