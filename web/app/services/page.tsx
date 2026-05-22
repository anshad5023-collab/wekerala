'use client';
import { ListingPage } from '@/components/wk/listing-page';
import { KERALA_DISTRICTS, RATING_OPTIONS } from '@/lib/wk-constants';
import type { FilterConfig } from '@/components/wk/wk-filter';

const FILTERS: FilterConfig[] = [
  { id: 'district',  label: 'District',     options: KERALA_DISTRICTS },
  { id: 'category',  label: 'Service Type', options: ['Plumbing', 'Electrical', 'Carpentry', 'Painting', 'Cleaning', 'AC Repair', 'Appliance Repair', 'Pest Control', 'Moving'] },
  { id: 'rating',    label: 'Rating',       options: RATING_OPTIONS },
  { id: 'verified',  label: 'Verified',     isToggle: true },
];

export default function ServicesPage() {
  return (
    <ListingPage
      title="Services"
      collection="services"
      searchLabel="search services…"
      filters={FILTERS}
      resultLabel="services"
    />
  );
}
