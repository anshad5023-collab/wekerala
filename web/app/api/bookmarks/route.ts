import { NextRequest, NextResponse } from 'next/server';
import { getAdminAuth } from '@/lib/firebase-admin';

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

async function verifyAuth(req: NextRequest): Promise<{ uid: string } | NextResponse> {
  const authHeader = req.headers.get('authorization');
  if (!authHeader?.startsWith('Bearer ')) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }
  try {
    const decoded = await getAdminAuth().verifyIdToken(authHeader.slice(7));
    return { uid: decoded.uid };
  } catch {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }
}

export async function GET(req: NextRequest) {
  const authResult = await verifyAuth(req);
  if (authResult instanceof NextResponse) return authResult;
  const { uid: verifiedUid } = authResult;

  try {
    // Use a structured query to fetch only this user's bookmarks server-side
    const queryBody = {
      structuredQuery: {
        from: [{ collectionId: 'bookmarks' }],
        where: {
          fieldFilter: {
            field: { fieldPath: 'uid' },
            op: 'EQUAL',
            value: { stringValue: verifiedUid },
          },
        },
      },
    };

    const res = await fetch(
      `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents:runQuery?key=${API_KEY}`,
      { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(queryBody) }
    );
    if (!res.ok) return NextResponse.json({ error: 'Firestore error' }, { status: 500 });
    const json = await res.json() as Array<{ document?: { name: string; fields: Record<string, FVal> } }>;

    const bookmarks: Array<Record<string, unknown>> = json
      .filter((row) => row.document)
      .map((row): Record<string, unknown> => {
        const f = parseFields(row.document!.fields ?? {});
        return { id: (row.document!.name as string).split('/').pop() ?? '', ...f };
      });

    return NextResponse.json({ bookmarks });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ error: 'Internal error' }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  const authResult = await verifyAuth(req);
  if (authResult instanceof NextResponse) return authResult;
  const { uid: verifiedUid } = authResult;

  try {
    const body = await req.json() as {
      businessId?: string;
      collection?: string;
      businessName?: string;
      photoUrl?: string;
    };

    const { businessId, collection, businessName, photoUrl } = body;

    if (!businessId) {
      return NextResponse.json({ error: 'businessId required' }, { status: 400 });
    }

    const docId = `${verifiedUid}__${businessId}`;
    const now = new Date().toISOString();
    const fields: Record<string, FVal> = {
      uid: { stringValue: verifiedUid },
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
  const authResult = await verifyAuth(req);
  if (authResult instanceof NextResponse) return authResult;
  const { uid: verifiedUid } = authResult;

  const businessId = req.nextUrl.searchParams.get('businessId');

  if (!businessId) {
    return NextResponse.json({ error: 'businessId required' }, { status: 400 });
  }

  try {
    const docId = `${verifiedUid}__${businessId}`;
    const res = await fetch(`${BASE}/bookmarks/${docId}?key=${API_KEY}`, { method: 'DELETE' });
    if (!res.ok) return NextResponse.json({ error: 'Failed to delete bookmark' }, { status: 500 });
    return NextResponse.json({ ok: true });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ error: 'Internal error' }, { status: 500 });
  }
}
