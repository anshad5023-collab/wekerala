'use client';
import { ListingPage } from '@/components/wk/listing-page';
import { KERALA_DISTRICTS, RATING_OPTIONS } from '@/lib/wk-constants';
import type { FilterConfig } from '@/components/wk/wk-filter';

const FILTERS: FilterConfig[] = [
  { id: 'district', label: 'District', options: KERALA_DISTRICTS },
  { id: 'category', label: 'Specialty', options: ['General Physician', 'Dentist', 'Pediatrician', 'Gynecologist', 'Orthopedic', 'Dermatologist', 'Cardiologist', 'Neurologist', 'Ayurveda Doctor', 'Homeopathy', 'Physiotherapy', 'Eye Specialist', 'ENT Specialist'] },
  { id: 'rating', label: 'Rating', options: RATING_OPTIONS },
];

export default function DoctorsPage() {
  return (
    <ListingPage
      title="Doctors"
      collection="doctors"
      searchLabel="search doctors, clinics…"
      filters={FILTERS}
      resultLabel="doctors"
    />
  );
}
