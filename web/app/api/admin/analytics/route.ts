import { NextRequest, NextResponse } from 'next/server';

const API_KEY = process.env.NEXT_PUBLIC_FIREBASE_API_KEY ?? 'AIzaSyCFB9YZL3_bXjvRMoWaYFv8nTs_ote52GQ';
const PROJECT_ID = (process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID ?? 'shoplink-prod').replace(/^﻿/, '');
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD ?? '';

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

function checkAdmin(req: NextRequest): boolean {
  if (!ADMIN_PASSWORD) return false;
  return (req.headers.get('x-admin-password') ?? '') === ADMIN_PASSWORD;
}

const LISTING_COLLECTIONS = ['shops', 'services', 'theaters', 'hotels', 'restaurants', 'beauty', 'doctors', 'hospitals', 'education', 'homeServices'];

export async function GET(req: NextRequest) {
  if (!checkAdmin(req)) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  try {
    const [listingResults, dealsRes, ratingsRes] = await Promise.all([
      Promise.all(
        LISTING_COLLECTIONS.map(async (col) => {
          const res = await fetch(`${BASE}/${col}?pageSize=500&key=${API_KEY}`);
          if (!res.ok) return { col, count: 0 };
          const json = await res.json();
          return { col, count: (json.documents ?? []).length };
        })
      ),
      fetch(`${BASE}/deals?pageSize=500&key=${API_KEY}`),
      fetch(`${BASE}/ratings?pageSize=500&key=${API_KEY}`),
    ]);

    const listings: Record<string, number> = {};
    let totalListings = 0;
    for (const { col, count } of listingResults) {
      listings[col] = count;
      totalListings += count;
    }

    let approvedDeals = 0;
    let pendingDeals = 0;
    if (dealsRes.ok) {
      const dealsJson = await dealsRes.json();
      const docs: Array<{ name: string; fields: Record<string, FVal> }> = dealsJson.documents ?? [];
      for (const doc of docs) {
        const f = parseFields(doc.fields ?? {});
        const status = (f['status'] as string) ?? '';
        if (status === 'approved') approvedDeals++;
        if (status === 'pending') pendingDeals++;
      }
    }

    let totalRatings = 0;
    if (ratingsRes.ok) {
      const ratingsJson = await ratingsRes.json();
      totalRatings = (ratingsJson.documents ?? []).length;
    }

    return NextResponse.json({ listings, totalListings, approvedDeals, pendingDeals, totalRatings });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ error: 'Internal error' }, { status: 500 });
  }
}
