'use client';

import { Search, SlidersHorizontal } from 'lucide-react';
import { translations, type Language } from '@/lib/translations';
import { useFilterStore } from '@/lib/filter-store';

interface SearchBarProps {
  language: Language;
  value: string;
  onSearchClick: () => void;
}

export function SearchBar({ language, value, onSearchClick }: SearchBarProps) {
  const t = translations[language];
  const filterCount = useFilterStore((state) => state.getActiveFilterCount());

  return (
    <div className="bg-white px-4 py-3 shadow-sm">
      <button
        onClick={onSearchClick}
        className="relative flex w-full items-center rounded-full border border-border bg-muted py-2.5 pl-10 pr-12 text-left text-sm italic text-muted-foreground transition-colors hover:border-primary"
      >
        <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
        <span className="flex-1 truncate">
          {value || t.searchPlaceholder}
        </span>
        <div className="absolute right-3 top-1/2 -translate-y-1/2">
          <div className="relative">
            <SlidersHorizontal className="h-4 w-4 text-muted-foreground" />
            {filterCount > 0 && (
              <span className="absolute -right-1.5 -top-1.5 flex h-4 w-4 items-center justify-center rounded-full bg-[#22c55e] text-[10px] font-bold text-white">
                {filterCount}
              </span>
            )}
          </div>
        </div>
      </button>
    </div>
  );
}
