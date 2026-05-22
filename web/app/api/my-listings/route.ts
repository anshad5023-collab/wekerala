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
  if ('mapValue' in v)
    return Object.fromEntries(Object.entries(v.mapValue.fields ?? {}).map(([k, fv]) => [k, parseValue(fv)]));
  return null;
}

function parseFields(fields: Record<string, FVal>): Record<string, unknown> {
  return Object.fromEntries(Object.entries(fields).map(([k, v]) => [k, parseValue(v)]));
}

async function queryByOwner(collection: string, uid: string): Promise<Record<string, unknown>[]> {
  const body = {
    structuredQuery: {
      from: [{ collectionId: collection }],
      where: {
        fieldFilter: {
          field: { fieldPath: 'ownerId' },
          op: 'EQUAL',
          value: { stringValue: uid },
        },
      },
    },
  };
  const res = await fetch(`${BASE}:runQuery?key=${API_KEY}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  if (!res.ok) return [];
  const results = (await res.json()) as Array<{ document?: { name: string; fields: Record<string, FVal> } }>;
  return results
    .filter((r) => r.document)
    .map((r) => ({
      id: r.document!.name.split('/').pop()!,
      ...parseFields(r.document!.fields ?? {}),
    }));
}

export async function GET(req: NextRequest) {
  const uid = req.nextUrl.searchParams.get('uid');
  const collection = req.nextUrl.searchParams.get('collection') ?? 'shops';

  if (!uid) return NextResponse.json({ error: 'Missing uid' }, { status: 400 });

  const allowed = ['shops', 'services', 'theaters', 'hotels', 'restaurants', 'beauty'];
  if (!allowed.includes(collection)) return NextResponse.json({ error: 'Invalid collection' }, { status: 400 });

  try {
    if (collection === 'shops') {
      const userRes = await fetch(`${BASE}/users/${uid}?key=${API_KEY}`);
      if (!userRes.ok) return NextResponse.json({ listings: [] });
      const userDoc = await userRes.json();
      const userData = parseFields(userDoc.fields ?? {});
      const shopIds = (userData.shopIds as string[]) ?? [];

      const shops = await Promise.all(
        shopIds.map(async (shopId: string) => {
          const shopRes = await fetch(`${BASE}/shops/${shopId}?key=${API_KEY}`);
          if (!shopRes.ok) return null;
          const shopDoc = await shopRes.json();
          return { id: shopId, ...parseFields(shopDoc.fields ?? {}) };
        })
      );
      return NextResponse.json({ listings: shops.filter(Boolean) });
    }

    const listings = await queryByOwner(collection, uid);
    return NextResponse.json({ listings });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ listings: [] });
  }
}
