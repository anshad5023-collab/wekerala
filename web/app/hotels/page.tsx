'use client';
import { ListingPage } from '@/components/wk/listing-page';
import { KERALA_DISTRICTS, RATING_OPTIONS } from '@/lib/wk-constants';
import type { FilterConfig } from '@/components/wk/wk-filter';

const FILTERS: FilterConfig[] = [
  { id: 'district',  label: 'District',  options: KERALA_DISTRICTS },
  { id: 'category',  label: 'Category',  options: ['Budget', 'Mid-range', 'Luxury', 'Resort', 'Heritage', 'Homestay'] },
  { id: 'rating',    label: 'Rating',    options: RATING_OPTIONS },
  { id: 'price',     label: 'Price',     options: ['₹ < 1000', '₹ 1000-2500', '₹ 2500-5000', '₹ 5000+'] },
];

export default function HotelsPage() {
  return (
    <ListingPage
      title="Hotels"
      collection="hotels"
      searchLabel="search hotels…"
      filters={FILTERS}
      resultLabel="hotels"
    />
  );
}
