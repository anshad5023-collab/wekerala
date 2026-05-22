import type { ActionMode } from './merchant';

export type CategoryId =
  | 'retail'
  | 'restaurant'
  | 'salon'
  | 'clinic'
  | 'service'
  | 'tuition'
  | 'hotel'
  | 'theater';

export interface CategoryDef {
  id: CategoryId;
  name: string;
  nameMl: string;
  defaultActionMode: ActionMode;
  icon: string;
  subcategories: string[];
}

export const CATEGORIES: Record<CategoryId, CategoryDef> = {
  retail: {
    id: 'retail',
    name: 'Retail Shop',
    nameMl: 'ചില്ലറ വ്യാപാരം',
    defaultActionMode: 'order',
    icon: 'store',
    subcategories: ['Grocery', 'Electronics', 'Clothing', 'Hardware', 'Medical', 'Other'],
  },
  restaurant: {
    id: 'restaurant',
    name: 'Restaurant / Food',
    nameMl: 'റെസ്റ്റോറന്റ്',
    defaultActionMode: 'order',
    icon: 'restaurant',
    subcategories: ['Restaurant', 'Bakery', 'Fast Food', 'Catering', 'Cloud Kitchen', 'Other'],
  },
  salon: {
    id: 'salon',
    name: 'Salon & Beauty',
    nameMl: 'സലൂൺ & ബ്യൂട്ടി',
    defaultActionMode: 'book',
    icon: 'content_cut',
    subcategories: ['Ladies Salon', 'Gents Salon', 'Spa', 'Bridal', 'Other'],
  },
  clinic: {
    id: 'clinic',
    name: 'Clinic / Hospital',
    nameMl: 'ക്ലിനിക്',
    defaultActionMode: 'book',
    icon: 'local_hospital',
    subcategories: ['General', 'Dental', 'Ayurveda', 'Homeopathy', 'Physiotherapy', 'Other'],
  },
  service: {
    id: 'service',
    name: 'Home Service',
    nameMl: 'ഹോം സർവ്വീസ്',
    defaultActionMode: 'inquire',
    icon: 'build',
    subcategories: ['Electrician', 'Plumber', 'Carpenter', 'AC Repair', 'Cleaning', 'Other'],
  },
  tuition: {
    id: 'tuition',
    name: 'Tuition / Classes',
    nameMl: 'ട്യൂഷൻ',
    defaultActionMode: 'inquire',
    icon: 'school',
    subcategories: ['School Tuition', 'Coaching', 'Music', 'Dance', 'Computer', 'Other'],
  },
  hotel: {
    id: 'hotel',
    name: 'Hotel / Homestay',
    nameMl: 'ഹോട്ടൽ',
    defaultActionMode: 'book',
    icon: 'hotel',
    subcategories: ['Hotel', 'Homestay', 'Resort', 'Guest House', 'Houseboat', 'Other'],
  },
  theater: {
    id: 'theater',
    name: 'Cinema / Theater',
    nameMl: 'തിയേറ്റർ',
    defaultActionMode: 'book',
    icon: 'movie',
    subcategories: ['Cinema', 'Multiplex', 'Drama', 'Other'],
  },
};

export const CATEGORY_IDS = Object.keys(CATEGORIES) as CategoryId[];

export const CATEGORY_FIRESTORE_SEED = CATEGORY_IDS.map((id) => ({
  categoryId: id,
  ...CATEGORIES[id],
}));
