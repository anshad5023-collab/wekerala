'use client';
import { ListingPage } from '@/components/wk/listing-page';
import { KERALA_DISTRICTS, RATING_OPTIONS } from '@/lib/wk-constants';
import type { FilterConfig } from '@/components/wk/wk-filter';

const FILTERS: FilterConfig[] = [
  { id: 'district', label: 'District', options: KERALA_DISTRICTS },
  { id: 'category', label: 'Type', options: ['Multispecialty Hospital', 'Government Hospital', 'Private Clinic', 'Diagnostic Lab', 'Nursing Home', 'Ayurveda Hospital', 'Blood Bank'] },
  { id: 'rating', label: 'Rating', options: RATING_OPTIONS },
];

export default function HospitalsPage() {
  return (
    <ListingPage
      title="Hospitals"
      collection="hospitals"
      searchLabel="search hospitals, clinics…"
      filters={FILTERS}
      resultLabel="hospitals"
    />
  );
}
