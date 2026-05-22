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

export async function GET(req: NextRequest) {
  const uid = req.nextUrl.searchParams.get('uid');
  if (!uid) return NextResponse.json({ error: 'uid required' }, { status: 400 });

  try {
    const res = await fetch(`${BASE}:runQuery?key=${API_KEY}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        structuredQuery: {
          from: [{ collectionId: 'orders', allDescendants: true }],
          where: {
            fieldFilter: {
              field: { fieldPath: 'customerUid' },
              op: 'EQUAL',
              value: { stringValue: uid },
            },
          },
          orderBy: [{ field: { fieldPath: 'createdAt' }, direction: 'DESCENDING' }],
          limit: 100,
        },
      }),
    });

    if (!res.ok) return NextResponse.json({ orders: [] });

    const rows = await res.json() as Array<{ document?: { name: string; fields: Record<string, FVal> } }>;
    const orders: Array<Record<string, unknown>> = rows
      .filter((r) => r.document)
      .map((r) => {
        const doc = r.document!;
        const parsed = Object.fromEntries(
          Object.entries(doc.fields ?? {}).map(([k, v]) => [k, parseValue(v)])
        );
        return { id: doc.name.split('/').pop()!, ...parsed };
      });

    return NextResponse.json({ orders });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ orders: [] });
  }
}
