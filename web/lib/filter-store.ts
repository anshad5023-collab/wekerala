import { create } from 'zustand';

export interface PriceFilter {
  id: string;
  label: {
    en: string;
    ml: string;
  };
  min: number;
  max: number | null; // null means no upper limit
}

export interface VariantOption {
  id: string;
  label: {
    en: string;
    ml: string;
  };
  value: string;
  colorCode?: string; // For color variants
}

export interface VariantFilter {
  id: string;
  name: {
    en: string;
    ml: string;
  };
  type: 'color' | 'size' | 'weight' | 'custom';
  options: VariantOption[];
}

// Default price filters - owner can modify these
const defaultPriceFilters: PriceFilter[] = [
  { id: 'p1', label: { en: 'Under ₹50', ml: '₹50 ന് താഴെ' }, min: 0, max: 50 },
  { id: 'p2', label: { en: '₹50 - ₹100', ml: '₹50 - ₹100' }, min: 50, max: 100 },
  { id: 'p3', label: { en: '₹100 - ₹200', ml: '₹100 - ₹200' }, min: 100, max: 200 },
  { id: 'p4', label: { en: 'Above ₹200', ml: '₹200 ന് മുകളിൽ' }, min: 200, max: null },
];

// Default variant filters - owner can modify these
const defaultVariantFilters: VariantFilter[] = [
  {
    id: 'color',
    name: { en: 'Color', ml: 'നിറം' },
    type: 'color',
    options: [
      { id: 'c1', label: { en: 'Red', ml: 'ചുവപ്പ്' }, value: 'red', colorCode: '#ef4444' },
      { id: 'c2', label: { en: 'Green', ml: 'പച്ച' }, value: 'green', colorCode: '#22c55e' },
      { id: 'c3', label: { en: 'Yellow', ml: 'മഞ്ഞ' }, value: 'yellow', colorCode: '#eab308' },
      { id: 'c4', label: { en: 'Orange', ml: 'ഓറഞ്ച്' }, value: 'orange', colorCode: '#f97316' },
    ],
  },
  {
    id: 'size',
    name: { en: 'Size', ml: 'വലിപ്പം' },
    type: 'size',
    options: [
      { id: 's1', label: { en: 'Small', ml: 'ചെറുത്' }, value: 'small' },
      { id: 's2', label: { en: 'Medium', ml: 'ഇടത്തരം' }, value: 'medium' },
      { id: 's3', label: { en: 'Large', ml: 'വലുത്' }, value: 'large' },
    ],
  },
  {
    id: 'weight',
    name: { en: 'Weight', ml: 'ഭാരം' },
    type: 'weight',
    options: [
      { id: 'w1', label: { en: '250g', ml: '250ഗ്രാം' }, value: '250g' },
      { id: 'w2', label: { en: '500g', ml: '500ഗ്രാം' }, value: '500g' },
      { id: 'w3', label: { en: '1kg', ml: '1കി.ഗ്രാം' }, value: '1kg' },
    ],
  },
];

interface FilterState {
  // Filter configurations (owner can modify)
  priceFilters: PriceFilter[];
  variantFilters: VariantFilter[];
  
  // Active filter selections
  selectedPriceFilter: string | null;
  selectedVariants: Record<string, string[]>; // filterId -> selected option ids
  
  // Actions for owner to configure filters
  setPriceFilters: (filters: PriceFilter[]) => void;
  addPriceFilter: (filter: PriceFilter) => void;
  removePriceFilter: (id: string) => void;
  updatePriceFilter: (id: string, filter: Partial<PriceFilter>) => void;
  
  setVariantFilters: (filters: VariantFilter[]) => void;
  addVariantFilter: (filter: VariantFilter) => void;
  removeVariantFilter: (id: string) => void;
  updateVariantFilter: (id: string, filter: Partial<VariantFilter>) => void;
  addVariantOption: (filterId: string, option: VariantOption) => void;
  removeVariantOption: (filterId: string, optionId: string) => void;
  
  // Actions for user to select filters
  setSelectedPriceFilter: (id: string | null) => void;
  toggleVariantOption: (filterId: string, optionId: string) => void;
  clearAllFilters: () => void;
  
  // Get active filter count
  getActiveFilterCount: () => number;
}

export const useFilterStore = create<FilterState>((set, get) => ({
  priceFilters: defaultPriceFilters,
  variantFilters: defaultVariantFilters,
  selectedPriceFilter: null,
  selectedVariants: {},
  
  // Owner configuration actions
  setPriceFilters: (filters) => set({ priceFilters: filters }),
  
  addPriceFilter: (filter) => set((state) => ({
    priceFilters: [...state.priceFilters, filter],
  })),
  
  removePriceFilter: (id) => set((state) => ({
    priceFilters: state.priceFilters.filter((f) => f.id !== id),
  })),
  
  updatePriceFilter: (id, filter) => set((state) => ({
    priceFilters: state.priceFilters.map((f) =>
      f.id === id ? { ...f, ...filter } : f
    ),
  })),
  
  setVariantFilters: (filters) => set({ variantFilters: filters }),
  
  addVariantFilter: (filter) => set((state) => ({
    variantFilters: [...state.variantFilters, filter],
  })),
  
  removeVariantFilter: (id) => set((state) => ({
    variantFilters: state.variantFilters.filter((f) => f.id !== id),
  })),
  
  updateVariantFilter: (id, filter) => set((state) => ({
    variantFilters: state.variantFilters.map((f) =>
      f.id === id ? { ...f, ...filter } : f
    ),
  })),
  
  addVariantOption: (filterId, option) => set((state) => ({
    variantFilters: state.variantFilters.map((f) =>
      f.id === filterId ? { ...f, options: [...f.options, option] } : f
    ),
  })),
  
  removeVariantOption: (filterId, optionId) => set((state) => ({
    variantFilters: state.variantFilters.map((f) =>
      f.id === filterId
        ? { ...f, options: f.options.filter((o) => o.id !== optionId) }
        : f
    ),
  })),
  
  // User selection actions
  setSelectedPriceFilter: (id) => set({ selectedPriceFilter: id }),
  
  toggleVariantOption: (filterId, optionId) => set((state) => {
    const current = state.selectedVariants[filterId] || [];
    const updated = current.includes(optionId)
      ? current.filter((id) => id !== optionId)
      : [...current, optionId];
    
    return {
      selectedVariants: {
        ...state.selectedVariants,
        [filterId]: updated,
      },
    };
  }),
  
  clearAllFilters: () => set({
    selectedPriceFilter: null,
    selectedVariants: {},
  }),
  
  getActiveFilterCount: () => {
    const state = get();
    let count = state.selectedPriceFilter ? 1 : 0;
    Object.values(state.selectedVariants).forEach((options) => {
      count += options.length;
    });
    return count;
  },
}));
