'use client';
import { ListingPage } from '@/components/wk/listing-page';
import { KERALA_DISTRICTS, RATING_OPTIONS } from '@/lib/wk-constants';
import type { FilterConfig } from '@/components/wk/wk-filter';

const FILTERS: FilterConfig[] = [
  { id: 'district',  label: 'District',  options: KERALA_DISTRICTS },
  { id: 'category',  label: 'Cuisine',   options: ['Kerala', 'North Indian', 'Chinese', 'Continental', 'Seafood', 'Fast Food', 'Bakery & Cafe', 'Vegetarian'] },
  { id: 'rating',    label: 'Rating',    options: RATING_OPTIONS },
  { id: 'price',     label: 'Price',     options: ['₹ < 200', '₹ 200-500', '₹ 500-1000', '₹ 1000+'] },
];

export default function RestaurantsPage() {
  return (
    <ListingPage
      title="Restaurants"
      collection="restaurants"
      searchLabel="search restaurants…"
      filters={FILTERS}
      resultLabel="restaurants"
    />
  );
}
