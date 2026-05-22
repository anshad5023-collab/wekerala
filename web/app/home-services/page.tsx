'use client';
import { ListingPage } from '@/components/wk/listing-page';
import { KERALA_DISTRICTS, RATING_OPTIONS } from '@/lib/wk-constants';
import type { FilterConfig } from '@/components/wk/wk-filter';

const FILTERS: FilterConfig[] = [
  { id: 'district', label: 'District', options: KERALA_DISTRICTS },
  { id: 'category', label: 'Service', options: ['Electrician', 'Plumber', 'Carpenter', 'Painter', 'Welder', 'AC Repair', 'AC Installation', 'Refrigerator Repair', 'Washing Machine Repair', 'TV Repair', 'Solar Panel Installation', 'CCTV Installation', 'Pest Control', 'Housekeeping', 'Packers & Movers'] },
  { id: 'rating', label: 'Rating', options: RATING_OPTIONS },
];

export default function HomeServicesPage() {
  return (
    <ListingPage
      title="Home Services"
      collection="homeServices"
      searchLabel="search electrician, plumber…"
      filters={FILTERS}
      resultLabel="providers"
    />
  );
}
