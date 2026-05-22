import { NextRequest, NextResponse } from 'next/server';

const API_KEY = process.env.NEXT_PUBLIC_FIREBASE_API_KEY ?? 'AIzaSyCFB9YZL3_bXjvRMoWaYFv8nTs_ote52GQ';
const PROJECT_ID = (process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID ?? 'shoplink-prod').replace(/^﻿/, '');
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD ?? '';

type FVal =
  | { stringValue: string }
  | { booleanValue: boolean }
  | { nullValue: null };

function parseValue(v: FVal): unknown {
  if ('stringValue' in v) return v.stringValue;
  if ('booleanValue' in v) return v.booleanValue;
  return null;
}

function parseFields(fields: Record<string, FVal>): Record<string, unknown> {
  return Object.fromEntries(Object.entries(fields).map(([k, v]) => [k, parseValue(v)]));
}

function checkAdmin(req: NextRequest): boolean {
  if (!ADMIN_PASSWORD) return false;
  return (req.headers.get('x-admin-password') ?? '') === ADMIN_PASSWORD;
}

// GET /api/service-tags
// ?adminAll=true + x-admin-password → all tags (including inactive)
// Otherwise → active tags only, sorted by sector then name
export async function GET(req: NextRequest) {
  const adminAll = req.nextUrl.searchParams.get('adminAll') === 'true';
  if (adminAll && !checkAdmin(req)) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }
  try {
    const res = await fetch(`${BASE}/serviceTags?pageSize=500&key=${API_KEY}`);
    if (!res.ok) return NextResponse.json({ tags: [] });
    const json = await res.json();
    if (!Array.isArray(json.documents)) return NextResponse.json({ tags: [] });

    type RawTag = { id: string; name: string; nameMl: string; sector: string; isActive: boolean; createdAt: string };
    const tags = (json.documents as Array<{ name: string; fields: Record<string, FVal> }>)
      .map((doc) => ({
        id: doc.name.split('/').pop()!,
        ...(parseFields(doc.fields ?? {}) as Omit<RawTag, 'id'>),
      }))
      .filter((tag) => adminAll || tag.isActive !== false);

    tags.sort((a, b) => {
      const s = (a.sector ?? '').localeCompare(b.sector ?? '');
      return s !== 0 ? s : (a.name ?? '').localeCompare(b.name ?? '');
    });

    return NextResponse.json({ tags });
  } catch {
    return NextResponse.json({ tags: [] });
  }
}

// POST /api/service-tags — create tag (admin only)
export async function POST(req: NextRequest) {
  if (!checkAdmin(req)) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const body = (await req.json()) as { name: string; nameMl?: string; sector: string };
  const { name, nameMl = '', sector } = body;
  if (!name?.trim() || !sector?.trim()) {
    return NextResponse.json({ error: 'name and sector are required' }, { status: 400 });
  }

  const fields = {
    name: { stringValue: name.trim() },
    nameMl: { stringValue: nameMl.trim() },
    sector: { stringValue: sector.trim() },
    isActive: { booleanValue: true },
    createdAt: { stringValue: new Date().toISOString() },
  };

  const res = await fetch(`${BASE}/serviceTags?key=${API_KEY}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ fields }),
  });
  if (!res.ok) return NextResponse.json({ error: 'Failed to create tag' }, { status: 500 });
  const json = await res.json();
  return NextResponse.json({ ok: true, id: (json.name as string).split('/').pop()! });
}

// PATCH /api/service-tags — update tag (admin only)
export async function PATCH(req: NextRequest) {
  if (!checkAdmin(req)) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const body = (await req.json()) as {
    id: string;
    name?: string;
    nameMl?: string;
    sector?: string;
    isActive?: boolean;
  };
  const { id, name, nameMl, sector, isActive } = body;
  if (!id) return NextResponse.json({ error: 'id required' }, { status: 400 });

  const fields: Record<string, unknown> = {};
  const fieldPaths: string[] = [];
  if (name !== undefined) { fields.name = { stringValue: name }; fieldPaths.push('name'); }
  if (nameMl !== undefined) { fields.nameMl = { stringValue: nameMl }; fieldPaths.push('nameMl'); }
  if (sector !== undefined) { fields.sector = { stringValue: sector }; fieldPaths.push('sector'); }
  if (isActive !== undefined) { fields.isActive = { booleanValue: isActive }; fieldPaths.push('isActive'); }
  if (!fieldPaths.length) return NextResponse.json({ error: 'Nothing to update' }, { status: 400 });

  const mask = fieldPaths.map((f) => `updateMask.fieldPaths=${encodeURIComponent(f)}`).join('&');
  const res = await fetch(`${BASE}/serviceTags/${id}?${mask}&key=${API_KEY}`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ fields }),
  });
  if (!res.ok) return NextResponse.json({ error: 'Failed to update tag' }, { status: 500 });
  return NextResponse.json({ ok: true });
}

// DELETE /api/service-tags?id=xxx — delete tag (admin only)
export async function DELETE(req: NextRequest) {
  if (!checkAdmin(req)) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const id = req.nextUrl.searchParams.get('id');
  if (!id) return NextResponse.json({ error: 'id required' }, { status: 400 });

  const res = await fetch(`${BASE}/serviceTags/${id}?key=${API_KEY}`, { method: 'DELETE' });
  if (!res.ok) return NextResponse.json({ error: 'Failed to delete tag' }, { status: 500 });
  return NextResponse.json({ ok: true });
}
