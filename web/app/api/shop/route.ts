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

export async function GET(req: NextRequest) {
  const shopId = req.nextUrl.searchParams.get('shopId');
  if (!shopId) return NextResponse.json({ error: 'Missing shopId' }, { status: 400 });

  try {
    const [shopRes, productsRes] = await Promise.all([
      fetch(`${BASE}/shops/${shopId}?key=${API_KEY}`),
      fetch(`${BASE}/shops/${shopId}/products?key=${API_KEY}&pageSize=300&orderBy=orderCount desc`),
    ]);

    if (!shopRes.ok) {
      const body = await shopRes.text();
      console.error('Firestore shop fetch failed:', shopRes.status, body);
      return NextResponse.json({ error: 'Shop not found', status: shopRes.status, detail: body }, { status: 404 });
    }

    const shopJson = await shopRes.json();
    const shop = parseFields(shopJson.fields ?? {});

    const productsJson = productsRes.ok ? await productsRes.json() : { documents: [] };
    const products = (productsJson.documents ?? [])
      .map((doc: { name: string; fields: Record<string, FVal> }) => ({
        id: (doc.name as string).split('/').pop(),
        ...parseFields(doc.fields ?? {}),
      }))
      .filter((p: Record<string, unknown>) => p['isHidden'] !== true);

    return NextResponse.json({ shop: { ...shop, shopId }, products });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ error: 'Internal error' }, { status: 500 });
  }
}
