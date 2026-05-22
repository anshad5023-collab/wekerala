'use client';
import { ListingPage } from '@/components/wk/listing-page';
import { KERALA_DISTRICTS, RATING_OPTIONS } from '@/lib/wk-constants';
import type { FilterConfig } from '@/components/wk/wk-filter';

const FILTERS: FilterConfig[] = [
  { id: 'district', label: 'District', options: KERALA_DISTRICTS },
  { id: 'category', label: 'Type', options: ['School', 'College', 'Engineering College', 'Coaching Center', 'NEET Coaching', 'JEE Coaching', 'PSC Coaching', 'IELTS Coaching', 'Computer Classes', 'Driving School', 'Music Classes', 'Dance Classes', 'Yoga Classes'] },
  { id: 'rating', label: 'Rating', options: RATING_OPTIONS },
];

export default function EducationPage() {
  return (
    <ListingPage
      title="Education"
      collection="education"
      searchLabel="search schools, coaching, classes…"
      filters={FILTERS}
      resultLabel="institutes"
    />
  );
}
