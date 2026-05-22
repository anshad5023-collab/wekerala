'use client';
import { ListingPage } from '@/components/wk/listing-page';
import { KERALA_DISTRICTS, RATING_OPTIONS } from '@/lib/wk-constants';
import type { FilterConfig } from '@/components/wk/wk-filter';

const FILTERS: FilterConfig[] = [
  { id: 'district',  label: 'District',  options: KERALA_DISTRICTS },
  { id: 'category',  label: 'Type',      options: ['Salon', 'Spa', 'Ayurveda', 'Massage', 'Yoga Studio', 'Fitness Center', 'Beauty Clinic'] },
  { id: 'rating',    label: 'Rating',    options: RATING_OPTIONS },
  { id: 'price',     label: 'Price',     options: ['₹ < 500', '₹ 500-1500', '₹ 1500-3000', '₹ 3000+'] },
];

export default function BeautyPage() {
  return (
    <ListingPage
      title="Beauty & Wellness"
      collection="beauty"
      searchLabel="search beauty & wellness…"
      filters={FILTERS}
      resultLabel="places"
    />
  );
}
