import { NextRequest, NextResponse } from 'next/server';

const API_KEY = process.env.NEXT_PUBLIC_FIREBASE_API_KEY ?? 'AIzaSyCFB9YZL3_bXjvRMoWaYFv8nTs_ote52GQ';
const PROJECT_ID = (process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID ?? 'shoplink-prod').replace(/^﻿/, '');
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD ?? '';

function checkAuth(req: NextRequest): boolean {
  if (!ADMIN_PASSWORD) return false;
  const pw = req.headers.get('x-admin-password') ?? req.nextUrl.searchParams.get('password') ?? '';
  return pw === ADMIN_PASSWORD;
}

type FVal = Record<string, unknown>;

function parseValue(v: FVal): unknown {
  if ('stringValue' in v) return v.stringValue;
  if ('booleanValue' in v) return v.booleanValue;
  if ('nullValue' in v) return null;
  return null;
}

function parseFields(fields: Record<string, FVal>): Record<string, unknown> {
  return Object.fromEntries(Object.entries(fields).map(([k, v]) => [k, parseValue(v)]));
}

// GET /api/admin/announcements — fetch current announcement
export async function GET(req: NextRequest) {
  if (!checkAuth(req)) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const res = await fetch(`${BASE}/platformConfig/announcement?key=${API_KEY}`, { cache: 'no-store' });
  if (res.status === 404) return NextResponse.json({ announcement: null });
  if (!res.ok) return NextResponse.json({ error: 'Firestore error' }, { status: 500 });

  const json = await res.json();
  const fields = parseFields((json.fields ?? {}) as Record<string, FVal>);
  return NextResponse.json({ announcement: fields });
}

// POST /api/admin/announcements — save announcement
export async function POST(req: NextRequest) {
  if (!checkAuth(req)) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const body = (await req.json()) as { title: string; body: string; type: string; active: boolean };

  const fields = {
    title: { stringValue: body.title ?? '' },
    body: { stringValue: body.body ?? '' },
    type: { stringValue: body.type ?? 'info' },
    active: { booleanValue: body.active !== false },
    updatedAt: { stringValue: new Date().toISOString() },
  };

  const masks = ['title', 'body', 'type', 'active', 'updatedAt']
    .map((f) => `updateMask.fieldPaths=${f}`)
    .join('&');
  const url = `${BASE}/platformConfig/announcement?key=${API_KEY}&${masks}`;

  const res = await fetch(url, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ fields }),
  });

  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    const msg = (err as { error?: { message?: string } })?.error?.message ?? 'Firestore write failed';
    return NextResponse.json({ error: msg }, { status: 500 });
  }

  return NextResponse.json({ ok: true });
}
