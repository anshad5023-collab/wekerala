'use client';
import { ListingPage } from '@/components/wk/listing-page';
import { KERALA_DISTRICTS } from '@/lib/wk-constants';
import type { FilterConfig } from '@/components/wk/wk-filter';

const FILTERS: FilterConfig[] = [
  { id: 'district',  label: 'District',  options: KERALA_DISTRICTS },
  { id: 'category',  label: 'Type',      options: ['Multiplex', 'Single Screen', 'IMAX', '4DX', 'Drive-in'] },
  { id: 'showtime',  label: 'Showtime',  options: ['Morning (6-12)', 'Afternoon (12-6)', 'Evening (6-9)', 'Night (9+)'] },
  { id: 'language',  label: 'Language',  options: ['Malayalam', 'Tamil', 'Hindi', 'English', 'Telugu', 'Kannada'] },
];

export default function TheatersPage() {
  return (
    <ListingPage
      title="Theaters"
      collection="theaters"
      searchLabel="search theaters…"
      filters={FILTERS}
      resultLabel="theaters"
    />
  );
}
