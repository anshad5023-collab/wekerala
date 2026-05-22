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
  if ('mapValue' in v) return parseFields(v.mapValue.fields ?? {});
  return null;
}

function parseFields(fields: Record<string, FVal>): Record<string, unknown> {
  return Object.fromEntries(Object.entries(fields).map(([k, v]) => [k, parseValue(v)]));
}

export interface ShopSummary {
  shopId: string;
  shopName: string;
  shopNameMl: string;
  logoUrl: string;
  shopType: string;
  shopArea: string;
  isOpen: boolean;
  themeColor?: string;
}

export async function GET(req: NextRequest) {
  const category = req.nextUrl.searchParams.get('category');
  const search = req.nextUrl.searchParams.get('search')?.toLowerCase().trim();

  try {
    const res = await fetch(`${BASE}/shops?pageSize=100&key=${API_KEY}`);
    if (!res.ok) {
      return NextResponse.json({ error: 'Failed to fetch shops' }, { status: 500 });
    }

    const json = await res.json();
    const docs: Array<{ name: string; fields: Record<string, FVal> }> = json.documents ?? [];

    let shops: ShopSummary[] = docs
      .map((doc) => {
        const f = parseFields(doc.fields ?? {});
        return {
          shopId: (doc.name as string).split('/').pop() ?? '',
          shopName: (f['shopName'] as string) ?? '',
          shopNameMl: (f['shopNameMl'] as string) ?? '',
          logoUrl: (f['logoUrl'] as string) ?? '',
          shopType: (f['shopType'] as string) ?? '',
          shopArea: (f['shopArea'] as string) ?? (f['district'] as string) ?? '',
          isOpen: (f['isOpen'] as boolean) ?? (f['isActive'] as boolean) ?? false,
          // Show shop if isApproved=true, or if isApproved is not set (default open)
          isApproved: (f['isApproved'] as boolean) ?? (f['linkActive'] as boolean) ?? true,
          themeColor: (f['themeColor'] as string) ?? undefined,
        };
      })
      .filter((s) => (s as ShopSummary & { isApproved: boolean }).isApproved !== false)
      .filter((s) => s.shopName.trim() !== '')
      .map(({ isApproved: _a, ...rest }) => rest) as ShopSummary[];

    if (category && category !== 'all') {
      shops = shops.filter(
        (s) => s.shopType?.toLowerCase() === category.toLowerCase()
      );
    }

    if (search) {
      shops = shops.filter(
        (s) =>
          s.shopName.toLowerCase().includes(search) ||
          s.shopNameMl.includes(search) ||
          s.shopArea.toLowerCase().includes(search) ||
          s.shopType.toLowerCase().includes(search)
      );
    }

    return NextResponse.json({ shops });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ error: 'Internal error' }, { status: 500 });
  }
}
