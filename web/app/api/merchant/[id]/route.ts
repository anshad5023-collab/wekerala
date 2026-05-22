import { NextRequest, NextResponse } from 'next/server';
import type { Merchant } from '@/lib/types/merchant';

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

const PRIVATE_FIELDS = new Set([
  '_migrationMeta', 'requiresPhoneLink', 'ownerId', 'upiId',
  'legacyShopId', 'trialStartDate', 'trialEndDate',
]);

function stripPrivate(raw: Record<string, unknown>): Partial<Merchant> {
  return Object.fromEntries(
    Object.entries(raw).filter(([k]) => !PRIVATE_FIELDS.has(k))
  ) as Partial<Merchant>;
}

export async function GET(
  _req: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id } = await params;
  if (!id) return NextResponse.json({ error: 'Missing id' }, { status: 400 });

  try {
    const res = await fetch(`${BASE}/merchants/${id}?key=${API_KEY}`);

    if (res.status === 404 || res.status === 403) return NextResponse.json({ error: 'Not found' }, { status: 404 });
    if (!res.ok) return NextResponse.json({ error: 'Firestore error' }, { status: 500 });

    const json = await res.json();
    const raw = parseFields(json.fields ?? {});

    if (!raw['isApproved']) {
      return NextResponse.json({ error: 'Not found' }, { status: 404 });
    }

    const merchant = stripPrivate({ ...raw, merchantId: id });

    return NextResponse.json(
      { merchant },
      { headers: { 'Cache-Control': 'public, s-maxage=60, stale-while-revalidate=300' } },
    );
  } catch (e) {
    console.error('[/api/merchant/[id]]', e);
    return NextResponse.json({ error: 'Internal error' }, { status: 500 });
  }
}
