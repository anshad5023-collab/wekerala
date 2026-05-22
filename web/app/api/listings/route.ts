import { NextRequest, NextResponse } from 'next/server';

const PROJECT_ID = (process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID ?? 'shoplink-prod').replace(/^﻿/, '');
const API_KEY = process.env.NEXT_PUBLIC_FIREBASE_API_KEY ?? 'AIzaSyCFB9YZL3_bXjvRMoWaYFv8nTs_ote52GQ';
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

type FVal =
  | { stringValue: string }
  | { integerValue: string }
  | { doubleValue: number }
  | { booleanValue: boolean }
  | { arrayValue: { values?: FVal[] } }
  | { mapValue: { fields?: Record<string, FVal> } }
  | { nullValue: null };

function parseValue(v: FVal): unknown {
  if ('stringValue' in v) return v.stringValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return v.doubleValue;
  if ('booleanValue' in v) return v.booleanValue;
  if ('nullValue' in v) return null;
  if ('arrayValue' in v) return (v.arrayValue.values ?? []).map(parseValue);
  if ('mapValue' in v) {
    return Object.fromEntries(Object.entries(v.mapValue.fields ?? {}).map(([k, fv]) => [k, parseValue(fv)]));
  }
  return null;
}

function parseFields(fields: Record<string, FVal>): Record<string, unknown> {
  return Object.fromEntries(Object.entries(fields).map(([k, v]) => [k, parseValue(v)]));
}

export interface WkListing {
  id: string;
  name: string;
  category: string;
  rating?: number;
  reviews?: number;
  photoUrl?: string;
  tags: string[];
  district?: string;
  isOpen?: boolean;
  isVerified?: boolean;
  screens?: number;
  href?: string;
  // Phase 11 fields returned to Flutter
  location?: string;
  description?: string;
  externalUrl?: string;
  serviceType?: string;
  phone?: string;
  // Phase 16: type-specific fields
  priceRange?: string;
  availability?: string;
  serviceAreas?: string[];
  experience?: string;
  theaterType?: string;
  ticketPriceRange?: string;
  facilities?: string[];
  bookingUrl?: string;
  hotelCategory?: string;
  pricePerNight?: string;
  amenities?: string[];
  totalRooms?: number;
  checkIn?: string;
  checkOut?: string;
  cuisineTypes?: string[];
  diningOptions?: string[];
  isVeg?: string;
  avgCostForTwo?: string;
  specialities?: string[];
  serviceList?: string[];
  gender?: string;
  homeVisitAvailable?: boolean;
  appointmentRequired?: boolean;
}

// Compute isOpen from workingHours string (e.g. "9:00 AM - 9:00 PM") using IST
function computeIsOpen(manualIsOpen: boolean, workingHours?: string): boolean {
  if (!workingHours) return manualIsOpen;
  try {
    // Current time in IST (UTC+5:30)
    const now = new Date();
    const istOffset = 5.5 * 60 * 60 * 1000;
    const ist = new Date(now.getTime() + istOffset - now.getTimezoneOffset() * 60000);
    const h = ist.getHours(), m = ist.getMinutes();
    const totalMins = h * 60 + m;

    // Parse "H:MM AM/PM - H:MM AM/PM" or "HH:MM - HH:MM"
    const match = workingHours.match(/(\d{1,2}):(\d{2})\s*(AM|PM)?\s*[-–]\s*(\d{1,2}):(\d{2})\s*(AM|PM)?/i);
    if (!match) return manualIsOpen;
    let [, sh, sm, sap, eh, em, eap] = match;
    let startH = parseInt(sh), endH = parseInt(eh);
    if (sap?.toUpperCase() === 'PM' && startH !== 12) startH += 12;
    if (sap?.toUpperCase() === 'AM' && startH === 12) startH = 0;
    if (eap?.toUpperCase() === 'PM' && endH !== 12) endH += 12;
    if (eap?.toUpperCase() === 'AM' && endH === 12) endH = 0;
    const startMins = startH * 60 + parseInt(sm);
    const endMins = endH * 60 + parseInt(em);
    return totalMins >= startMins && totalMins < endMins;
  } catch { return manualIsOpen; }
}

function normalizeShop(data: Record<string, unknown>, id: string): WkListing {
  const tags: string[] = [];
  if (data['shopArea']) tags.push(data['shopArea'] as string);
  const shopType = (data['shopType'] as string) ?? '';
  const manualIsOpen = (data['isOpen'] as boolean) ?? false;
  const workingHours = (data['workingHours'] as string) || undefined;
  return {
    id,
    name: (data['shopName'] as string) ?? '',
    category: shopType,
    rating: (data['avgRating'] as number) ?? undefined,
    reviews: (data['ratingCount'] as number) ?? undefined,
    photoUrl: (data['bannerImageUrl'] as string) || (data['logoUrl'] as string) || undefined,
    tags,
    district: (data['shopArea'] as string) ?? (data['district'] as string) ?? '',
    isOpen: computeIsOpen(manualIsOpen, workingHours),
    href: (data['shopSlug'] as string) ? `/shops/${data['shopSlug']}` : `/shop?shopId=${id}`,
    phone: (data['ownerWhatsApp'] as string) || (data['ownerPhone'] as string) || undefined,
    description: (data['shopNameMl'] as string) || (data['address'] as string) || undefined,
  };
}

function strArr(v: unknown): string[] | undefined {
  return Array.isArray(v) && v.length > 0 ? (v as string[]) : undefined;
}

function normalizeListing(data: Record<string, unknown>, id: string): WkListing {
  const tags = Array.isArray(data['tags']) ? (data['tags'] as string[]) : [];
  return {
    id,
    name: (data['name'] as string) ?? '',
    category: (data['category'] as string) ?? (data['serviceType'] as string) ?? '',
    rating: (data['rating'] as number) ?? undefined,
    reviews: (data['reviews'] as number) ?? undefined,
    photoUrl: (data['photoUrl'] as string) || undefined,
    tags,
    district: (data['district'] as string) ?? '',
    isOpen: (data['isOpen'] as boolean) ?? undefined,
    isVerified: (data['isVerified'] as boolean) ?? undefined,
    screens: (data['screens'] as number) ?? undefined,
    location: (data['location'] as string) || undefined,
    description: (data['description'] as string) || undefined,
    externalUrl: (data['externalUrl'] as string) || undefined,
    serviceType: (data['serviceType'] as string) || undefined,
    phone: (data['phone'] as string) || (data['ownerPhone'] as string) || (data['ownerWhatsApp'] as string) || undefined,
    // services
    priceRange: (data['priceRange'] as string) || undefined,
    availability: (data['availability'] as string) || undefined,
    serviceAreas: strArr(data['serviceAreas']),
    experience: (data['experience'] as string) || undefined,
    // theaters
    theaterType: (data['theaterType'] as string) || undefined,
    ticketPriceRange: (data['ticketPriceRange'] as string) || undefined,
    facilities: strArr(data['facilities']),
    bookingUrl: (data['bookingUrl'] as string) || undefined,
    // hotels
    hotelCategory: (data['hotelCategory'] as string) || undefined,
    pricePerNight: (data['pricePerNight'] as string) || undefined,
    amenities: strArr(data['amenities']),
    totalRooms: (data['totalRooms'] as number) || undefined,
    checkIn: (data['checkIn'] as string) || undefined,
    checkOut: (data['checkOut'] as string) || undefined,
    // restaurants
    cuisineTypes: strArr(data['cuisineTypes']),
    diningOptions: strArr(data['diningOptions']),
    isVeg: (data['isVeg'] as string) || undefined,
    avgCostForTwo: (data['avgCostForTwo'] as string) || undefined,
    specialities: strArr(data['specialities']),
    // beauty
    serviceList: strArr(data['serviceList']),
    gender: (data['gender'] as string) || undefined,
    homeVisitAvailable: (data['homeVisitAvailable'] as boolean) || undefined,
    appointmentRequired: (data['appointmentRequired'] as boolean) || undefined,
  };
}

export async function GET(req: NextRequest) {
  const collection = req.nextUrl.searchParams.get('collection') ?? 'shops';

  const allowed = ['shops', 'services', 'theaters', 'hotels', 'restaurants', 'beauty', 'doctors', 'hospitals', 'education', 'homeServices', 'realestate'];
  if (!allowed.includes(collection)) {
    return NextResponse.json({ error: 'Invalid collection' }, { status: 400 });
  }

  try {
    const res = await fetch(`${BASE}/${collection}?pageSize=200&key=${API_KEY}`);
    if (!res.ok) {
      return NextResponse.json({ listings: [] });
    }
    const json = await res.json();
    const docs: Array<{ name: string; fields: Record<string, FVal> }> = json.documents ?? [];

    const listings: WkListing[] = docs.map((doc) => {
      const id = (doc.name as string).split('/').pop() ?? '';
      const data = parseFields(doc.fields ?? {});
      return collection === 'shops' ? normalizeShop(data, id) : normalizeListing(data, id);
    }).filter((l) => l.name.trim() !== '');

    return NextResponse.json({ listings });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ listings: [] });
  }
}
