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

function checkAdmin(req: NextRequest): boolean {
  if (!ADMIN_PASSWORD) return false;
  return (req.headers.get('x-admin-password') ?? '') === ADMIN_PASSWORD;
}

export async function PATCH(req: NextRequest) {
  if (!checkAdmin(req)) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  try {
    const body = await req.json() as { businessId?: string; collection?: string; isFeatured?: boolean };
    const { businessId, collection, isFeatured } = body;

    if (!businessId || !collection || typeof isFeatured !== 'boolean') {
      return NextResponse.json({ error: 'businessId, collection, isFeatured required' }, { status: 400 });
    }

    const url = `${BASE}/${collection}/${businessId}?updateMask.fieldPaths=isFeatured&key=${API_KEY}`;
    const fields: Record<string, FVal> = { isFeatured: { booleanValue: isFeatured } };

    const res = await fetch(url, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ fields }),
    });

    if (!res.ok) return NextResponse.json({ error: 'Failed to update isFeatured' }, { status: 500 });
    return NextResponse.json({ ok: true });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ error: 'Internal error' }, { status: 500 });
  }
}
