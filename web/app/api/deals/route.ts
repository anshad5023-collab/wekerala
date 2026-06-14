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

export async function GET(req: NextRequest) {
  const collection = req.nextUrl.searchParams.get('collection');
  try {
    const res = await fetch(`${BASE}/deals?pageSize=200&key=${API_KEY}`);
    if (!res.ok) return NextResponse.json({ error: 'Firestore error' }, { status: 500 });
    const json = await res.json();
    const docs: Array<{ name: string; fields: Record<string, FVal> }> = json.documents ?? [];

    let deals: Array<Record<string, unknown>> = docs
      .map((doc): Record<string, unknown> => {
        const f = parseFields(doc.fields ?? {});
        return { id: (doc.name as string).split('/').pop() ?? '', ...f };
      })
      .filter((d) => (d['status'] as string) === 'approved');

    if (collection) {
      deals = deals.filter((d) => (d['collection'] as string) === collection);
    }

    deals.sort((a, b) => {
      const aDate = (a['createdAt'] as string) ?? '';
      const bDate = (b['createdAt'] as string) ?? '';
      return bDate.localeCompare(aDate);
    });

    return NextResponse.json({ deals });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ error: 'Internal error' }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  // --- Auth: verify Firebase ID token ---
  const authHeader = req.headers.get('authorization');
  if (!authHeader?.startsWith('Bearer ')) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }
  let verifiedUid: string;
  try {
    const decoded = await getAdminAuth().verifyIdToken(authHeader.slice(7));
    verifiedUid = decoded.uid;
  } catch {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  try {
    const body = await req.json() as {
      businessId?: string;
      businessName?: string;
      collection?: string;
      title?: string;
      description?: string;
      discount?: string;
      validUntil?: string;
      ownerId?: string;
    };

    const { businessId, businessName, collection, title, description, discount, validUntil } = body;
    // Always use the server-verified uid — never trust the client-supplied ownerId
    const ownerId = verifiedUid;

    if (!businessId || !title) {
      return NextResponse.json({ error: 'businessId and title are required' }, { status: 400 });
    }

    const now = new Date().toISOString();
    const fields: Record<string, FVal> = {
      businessId: { stringValue: businessId },
      businessName: { stringValue: businessName ?? '' },
      collection: { stringValue: collection ?? '' },
      title: { stringValue: title },
      description: { stringValue: description ?? '' },
      discount: { stringValue: discount ?? '' },
      validUntil: { stringValue: validUntil ?? '' },
      status: { stringValue: 'pending' },
      createdAt: { stringValue: now },
      ownerId: { stringValue: ownerId ?? '' },
    };

    const res = await fetch(`${BASE}/deals?key=${API_KEY}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ fields }),
    });

    if (!res.ok) return NextResponse.json({ error: 'Failed to create deal' }, { status: 500 });
    const json = await res.json();
    const id = (json.name as string).split('/').pop() ?? '';

    return NextResponse.json({ ok: true, id });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ error: 'Internal error' }, { status: 500 });
  }
}
