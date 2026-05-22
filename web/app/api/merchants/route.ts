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

// Fields never returned to clients
const PRIVATE_FIELDS = new Set([
  '_migrationMeta', 'requiresPhoneLink', 'ownerId', 'upiId',
  'legacyShopId', 'trialStartDate', 'trialEndDate',
]);

function stripPrivate(raw: Record<string, unknown>): Partial<Merchant> {
  return Object.fromEntries(
    Object.entries(raw).filter(([k]) => !PRIVATE_FIELDS.has(k))
  ) as Partial<Merchant>;
}

type FieldFilter = {
  fieldFilter: {
    field: { fieldPath: string };
    op: string;
    value: Record<string, unknown>;
  };
};

function buildQuery(category: string | null, district: string | null, limit: number) {
  const filters: FieldFilter[] = [
    {
      fieldFilter: {
        field: { fieldPath: 'isApproved' },
        op: 'EQUAL',
        value: { booleanValue: true },
      },
    },
  ];
  if (category) {
    filters.push({
      fieldFilter: {
        field: { fieldPath: 'category' },
        op: 'EQUAL',
        value: { stringValue: category },
      },
    });
  }
  if (district) {
    filters.push({
      fieldFilter: {
        field: { fieldPath: 'district' },
        op: 'EQUAL',
        value: { stringValue: district },
      },
    });
  }

  const where =
    filters.length === 1
      ? filters[0]
      : { compositeFilter: { op: 'AND', filters } };

  return {
    structuredQuery: {
      from: [{ collectionId: 'merchants' }],
      where,
      orderBy: [{ field: { fieldPath: 'createdAt' }, direction: 'DESCENDING' }],
      limit,
    },
  };
}

export async function GET(req: NextRequest) {
  const p = req.nextUrl.searchParams;
  const category = p.get('category');
  const district = p.get('district');
  const search = p.get('search')?.toLowerCase().trim() ?? '';
  const limit = Math.min(Math.max(parseInt(p.get('limit') ?? '50', 10) || 50, 1), 100);

  try {
    const res = await fetch(`${BASE}:runQuery?key=${API_KEY}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(buildQuery(category, district, limit)),
    });

    if (!res.ok) return NextResponse.json({ error: 'Firestore error' }, { status: 500 });

    const rows = (await res.json()) as Array<{
      document?: { name: string; fields: Record<string, FVal> };
    }>;

    let merchants = rows
      .filter((r) => r.document)
      .map((r) => {
        const raw = parseFields(r.document!.fields ?? {});
        const id = r.document!.name.split('/').pop()!;
        return stripPrivate({ ...raw, merchantId: id });
      });

    if (search) {
      merchants = merchants.filter((m) => {
        const name = ((m.name ?? '') as string).toLowerCase();
        const nameMl = (m.nameMl ?? '') as string;
        const dist = ((m.district ?? '') as string).toLowerCase();
        const town = ((m.town ?? '') as string).toLowerCase();
        return (
          name.includes(search) ||
          nameMl.includes(search) ||
          dist.includes(search) ||
          town.includes(search)
        );
      });
    }

    return NextResponse.json(
      { merchants, count: merchants.length },
      { headers: { 'Cache-Control': 'public, s-maxage=30, stale-while-revalidate=120' } },
    );
  } catch (e) {
    console.error('[/api/merchants]', e);
    return NextResponse.json({ error: 'Internal error' }, { status: 500 });
  }
}
