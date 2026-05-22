import { NextRequest, NextResponse } from 'next/server';

const API_KEY = process.env.NEXT_PUBLIC_FIREBASE_API_KEY ?? 'AIzaSyCFB9YZL3_bXjvRMoWaYFv8nTs_ote52GQ';
const PROJECT_ID = (process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID ?? 'shoplink-prod').replace(/^﻿/, '');
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

const COLLECTIONS = ['shops', 'services', 'theaters', 'hotels', 'restaurants', 'beauty', 'doctors', 'hospitals', 'education', 'homeServices', 'realestate'];

const SECTOR_MAP: Record<string, string[]> = {
  Healthcare: ['doctors', 'hospitals'],
  Food: ['restaurants', 'hotels'],
  Beauty: ['beauty'],
  Education: ['education'],
  Home: ['homeServices'],
  RealEstate: ['realestate'],
  Entertainment: ['theaters'],
  Shopping: ['shops', 'services'],
};

type FVal =
  | { stringValue: string }
  | { integerValue: string }
  | { doubleValue: number }
  | { booleanValue: boolean }
  | { arrayValue: { values?: FVal[] } }
  | { nullValue: null };

function parseValue(v: FVal): unknown {
  if ('stringValue' in v) return v.stringValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return v.doubleValue;
  if ('booleanValue' in v) return v.booleanValue;
  if ('nullValue' in v) return null;
  if ('arrayValue' in v) return (v.arrayValue.values ?? []).map(parseValue);
  return null;
}

function parseFields(fields: Record<string, FVal>): Record<string, unknown> {
  return Object.fromEntries(Object.entries(fields).map(([k, v]) => [k, parseValue(v)]));
}

export async function GET(req: NextRequest) {
  const { searchParams } = req.nextUrl;
  const q = searchParams.get('q')?.toLowerCase().trim();
  const district = searchParams.get('district')?.toLowerCase().trim();
  const sector = searchParams.get('sector')?.trim();
  const verified = searchParams.get('verified');
  const minRatingStr = searchParams.get('minRating');
  const minRating = minRatingStr ? parseFloat(minRatingStr) : null;

  const sectorCollections = sector ? (SECTOR_MAP[sector] ?? []) : null;

  try {
    const results = await Promise.all(
      COLLECTIONS.map(async (collection) => {
        const res = await fetch(`${BASE}/${collection}?pageSize=200&key=${API_KEY}`);
        if (!res.ok) return [];
        const json = await res.json();
        const docs: Array<{ name: string; fields: Record<string, FVal> }> = json.documents ?? [];
        return docs.map((doc) => {
          const f = parseFields(doc.fields ?? {});
          const id = (doc.name as string).split('/').pop() ?? '';
          const serviceTypes = (f['serviceTypes'] as string[]) ?? (f['tags'] as string[]) ?? [];
          return {
            id,
            name: (f['name'] as string) ?? (f['shopName'] as string) ?? (f['businessName'] as string) ?? '',
            category: (f['category'] as string) ?? (f['shopType'] as string) ?? '',
            district: ((f['district'] as string) ?? (f['shopArea'] as string) ?? '').toLowerCase(),
            avgRating: (f['avgRating'] as number) ?? 0,
            ratingCount: (f['ratingCount'] as number) ?? 0,
            isVerified: (f['isVerified'] as boolean) ?? false,
            isFeatured: (f['isFeatured'] as boolean) ?? false,
            photoUrl: (f['photoUrl'] as string) ?? (f['logoUrl'] as string) ?? '',
            serviceTypes: Array.isArray(serviceTypes) ? serviceTypes.map(String) : [],
            phone: (f['phone'] as string) ?? (f['ownerPhone'] as string) ?? (f['ownerWhatsApp'] as string) ?? '',
            about: (f['about'] as string) ?? (f['description'] as string) ?? '',
            collection,
            href: `/listing/${collection}/${id}`,
          };
        });
      })
    );

    let flat = results.flat();

    if (sectorCollections) {
      flat = flat.filter((item) => sectorCollections.includes(item.collection));
    }
    if (q) {
      flat = flat.filter(
        (item) =>
          item.name.toLowerCase().includes(q) ||
          item.district.includes(q) ||
          item.category.toLowerCase().includes(q) ||
          item.serviceTypes.some((t) => t.toLowerCase().includes(q))
      );
    }
    if (district) {
      flat = flat.filter((item) => item.district.includes(district));
    }
    if (verified === 'true') {
      flat = flat.filter((item) => item.isVerified === true);
    }
    if (minRating !== null && !isNaN(minRating)) {
      flat = flat.filter((item) => item.avgRating >= minRating);
    }

    flat.sort((a, b) => {
      if (b.isFeatured !== a.isFeatured) return b.isFeatured ? 1 : -1;
      if (b.isVerified !== a.isVerified) return b.isVerified ? 1 : -1;
      return b.avgRating - a.avgRating;
    });

    return NextResponse.json({ results: flat, total: flat.length });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ error: 'Internal error' }, { status: 500 });
  }
}
