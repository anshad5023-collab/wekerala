import { NextRequest, NextResponse } from 'next/server';

const API_KEY = process.env.NEXT_PUBLIC_FIREBASE_API_KEY ?? 'AIzaSyCFB9YZL3_bXjvRMoWaYFv8nTs_ote52GQ';
const PROJECT_ID = (process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID ?? 'shoplink-prod').replace(/^﻿/, '');
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

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

async function fetchRatingsForBusiness(businessId: string): Promise<number[]> {
  const res = await fetch(`${BASE}/ratings?pageSize=500&key=${API_KEY}`);
  if (!res.ok) return [];
  const json = await res.json();
  const docs: Array<{ name: string; fields: Record<string, FVal> }> = json.documents ?? [];
  return docs
    .map((doc) => parseFields(doc.fields ?? {}))
    .filter((f) => (f['businessId'] as string) === businessId)
    .map((f) => (f['stars'] as number) ?? 0)
    .filter((s) => s > 0);
}

export async function GET(req: NextRequest) {
  const businessId = req.nextUrl.searchParams.get('businessId');
  const collection = req.nextUrl.searchParams.get('collection');

  if (!businessId || !collection) {
    return NextResponse.json({ error: 'businessId and collection required' }, { status: 400 });
  }

  try {
    const stars = await fetchRatingsForBusiness(businessId);
    const ratingCount = stars.length;
    const avgRating = ratingCount > 0 ? stars.reduce((a, b) => a + b, 0) / ratingCount : 0;
    return NextResponse.json({ avgRating: Math.round(avgRating * 10) / 10, ratingCount });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ error: 'Internal error' }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json() as {
      businessId?: string;
      collection?: string;
      uid?: string;
      stars?: number;
    };

    const { businessId, collection, uid, stars } = body;

    if (!businessId || !uid || !stars) {
      return NextResponse.json({ error: 'businessId, uid, stars required' }, { status: 400 });
    }
    if (stars < 1 || stars > 5) {
      return NextResponse.json({ error: 'stars must be 1-5' }, { status: 400 });
    }
    if (!collection) {
      return NextResponse.json({ error: 'collection required' }, { status: 400 });
    }

    const now = new Date().toISOString();
    const docId = `${uid}__${businessId}`;
    const ratingFields: Record<string, FVal> = {
      businessId: { stringValue: businessId },
      collection: { stringValue: collection },
      uid: { stringValue: uid },
      stars: { integerValue: String(stars) },
      createdAt: { stringValue: now },
    };

    // PATCH with docId = uid__businessId ensures one rating per user per business
    const createRes = await fetch(
      `${BASE}/ratings/${docId}?key=${API_KEY}`,
      { method: 'PATCH', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ fields: ratingFields }) }
    );

    if (!createRes.ok) return NextResponse.json({ error: 'Failed to create rating' }, { status: 500 });

    const allStars = await fetchRatingsForBusiness(businessId);
    const ratingCount = allStars.length;
    const avgRating = ratingCount > 0 ? Math.round((allStars.reduce((a, b) => a + b, 0) / ratingCount) * 10) / 10 : 0;

    const patchUrl = `${BASE}/${collection}/${businessId}?updateMask.fieldPaths=avgRating&updateMask.fieldPaths=ratingCount&key=${API_KEY}`;
    await fetch(patchUrl, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        fields: {
          avgRating: { doubleValue: avgRating },
          ratingCount: { integerValue: String(ratingCount) },
        },
      }),
    });

    return NextResponse.json({ ok: true, avgRating, ratingCount });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ error: 'Internal error' }, { status: 500 });
  }
}
