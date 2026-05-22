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

export async function GET(req: NextRequest) {
  if (!checkAdmin(req)) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const statusFilter = req.nextUrl.searchParams.get('status') ?? 'pending';

  try {
    const res = await fetch(`${BASE}/deals?pageSize=200&key=${API_KEY}`);
    if (!res.ok) return NextResponse.json({ error: 'Firestore error' }, { status: 500 });
    const json = await res.json();
    const docs: Array<{ name: string; fields: Record<string, FVal> }> = json.documents ?? [];

    let deals: Array<Record<string, unknown>> = docs.map((doc): Record<string, unknown> => {
      const f = parseFields(doc.fields ?? {});
      return { id: (doc.name as string).split('/').pop() ?? '', ...f };
    });

    if (statusFilter !== 'all') {
      deals = deals.filter((d) => (d['status'] as string) === statusFilter);
    }

    return NextResponse.json({ deals });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ error: 'Internal error' }, { status: 500 });
  }
}

export async function PATCH(req: NextRequest) {
  if (!checkAdmin(req)) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  try {
    const body = await req.json() as { id?: string; status?: 'approved' | 'rejected' };
    const { id, status } = body;

    if (!id || !status || !['approved', 'rejected'].includes(status)) {
      return NextResponse.json({ error: 'id and valid status required' }, { status: 400 });
    }

    const url = `${BASE}/deals/${id}?updateMask.fieldPaths=status&key=${API_KEY}`;
    const res = await fetch(url, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ fields: { status: { stringValue: status } } }),
    });

    if (!res.ok) return NextResponse.json({ error: 'Failed to update deal' }, { status: 500 });
    return NextResponse.json({ ok: true });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ error: 'Internal error' }, { status: 500 });
  }
}
