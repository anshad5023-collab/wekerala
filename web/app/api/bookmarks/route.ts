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

export async function GET(req: NextRequest) {
  const uid = req.nextUrl.searchParams.get('uid');
  if (!uid) return NextResponse.json({ error: 'uid required' }, { status: 400 });

  try {
    const res = await fetch(`${BASE}/bookmarks?pageSize=200&key=${API_KEY}`);
    if (!res.ok) return NextResponse.json({ error: 'Firestore error' }, { status: 500 });
    const json = await res.json();
    const docs: Array<{ name: string; fields: Record<string, FVal> }> = json.documents ?? [];

    const bookmarks: Array<Record<string, unknown>> = docs
      .map((doc): Record<string, unknown> => {
        const f = parseFields(doc.fields ?? {});
        return { id: (doc.name as string).split('/').pop() ?? '', ...f };
      })
      .filter((b) => (b['uid'] as string) === uid);

    return NextResponse.json({ bookmarks });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ error: 'Internal error' }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json() as {
      uid?: string;
      businessId?: string;
      collection?: string;
      businessName?: string;
      photoUrl?: string;
    };

    const { uid, businessId, collection, businessName, photoUrl } = body;

    if (!uid || !businessId) {
      return NextResponse.json({ error: 'uid and businessId required' }, { status: 400 });
    }

    const docId = `${uid}__${businessId}`;
    const now = new Date().toISOString();
    const fields: Record<string, FVal> = {
      uid: { stringValue: uid },
      businessId: { stringValue: businessId },
      collection: { stringValue: collection ?? '' },
      businessName: { stringValue: businessName ?? '' },
      photoUrl: { stringValue: photoUrl ?? '' },
      savedAt: { stringValue: now },
    };

    const res = await fetch(`${BASE}/bookmarks/${docId}?key=${API_KEY}`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ fields }),
    });

    if (!res.ok) return NextResponse.json({ error: 'Failed to save bookmark' }, { status: 500 });
    return NextResponse.json({ ok: true });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ error: 'Internal error' }, { status: 500 });
  }
}

export async function DELETE(req: NextRequest) {
  const uid = req.nextUrl.searchParams.get('uid');
  const businessId = req.nextUrl.searchParams.get('businessId');

  if (!uid || !businessId) {
    return NextResponse.json({ error: 'uid and businessId required' }, { status: 400 });
  }

  try {
    const docId = `${uid}__${businessId}`;
    const res = await fetch(`${BASE}/bookmarks/${docId}?key=${API_KEY}`, { method: 'DELETE' });
    if (!res.ok) return NextResponse.json({ error: 'Failed to delete bookmark' }, { status: 500 });
    return NextResponse.json({ ok: true });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ error: 'Internal error' }, { status: 500 });
  }
}
