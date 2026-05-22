import { NextRequest, NextResponse } from 'next/server';

const PROJECT_ID = (process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID ?? 'shoplink-prod').replace(/^﻿/, '');
const API_KEY = process.env.NEXT_PUBLIC_FIREBASE_API_KEY ?? 'AIzaSyCFB9YZL3_bXjvRMoWaYFv8nTs_ote52GQ';
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

type FVal =
  | { stringValue: string }
  | { integerValue: string }
  | { doubleValue: number }
  | { booleanValue: boolean }
  | { nullValue: null }
  | { arrayValue: { values?: FVal[] } }
  | { mapValue: { fields?: Record<string, FVal> } };

function parseValue(v: FVal): unknown {
  if ('stringValue' in v) return v.stringValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return v.doubleValue;
  if ('booleanValue' in v) return v.booleanValue;
  if ('nullValue' in v) return null;
  if ('arrayValue' in v) return (v.arrayValue.values ?? []).map(parseValue);
  if ('mapValue' in v)
    return Object.fromEntries(Object.entries(v.mapValue.fields ?? {}).map(([k, fv]) => [k, parseValue(fv)]));
  return null;
}

function couponToFVal(c: { code: string; discountPercent: number; minOrder: number; active: boolean }): FVal {
  return {
    mapValue: {
      fields: {
        code: { stringValue: c.code },
        discountPercent: { integerValue: String(c.discountPercent) },
        minOrder: { integerValue: String(c.minOrder) },
        active: { booleanValue: c.active },
      },
    },
  };
}

async function getShopAndCoupons(shopId: string): Promise<{
  ok: boolean;
  ownerId?: string;
  coupons?: Array<{ code: string; discountPercent: number; minOrder: number; active: boolean }>;
  error?: string;
}> {
  const res = await fetch(`${BASE}/shops/${shopId}?key=${API_KEY}`, { cache: 'no-store' });
  if (!res.ok) return { ok: false, error: 'Shop not found' };
  const json = await res.json() as { fields: Record<string, FVal> };
  const fields = Object.fromEntries(
    Object.entries(json.fields ?? {}).map(([k, v]) => [k, parseValue(v)])
  ) as Record<string, unknown>;
  const ownerId = fields['ownerId'] as string;
  const website = fields['website'] as Record<string, unknown> | null ?? {};
  const raw = (website?.couponCodes as Array<Record<string, unknown>>) ?? [];
  const coupons = raw.map((c) => ({
    code: (c.code as string) || '',
    discountPercent: (c.discountPercent as number) || 0,
    minOrder: (c.minOrder as number) || 0,
    active: (c.active as boolean) ?? true,
  }));
  return { ok: true, ownerId, coupons };
}

async function saveCoupons(
  shopId: string,
  coupons: Array<{ code: string; discountPercent: number; minOrder: number; active: boolean }>
): Promise<boolean> {
  const url = `${BASE}/shops/${shopId}?key=${API_KEY}&updateMask.fieldPaths=website.couponCodes`;
  const body = {
    fields: {
      website: {
        mapValue: {
          fields: {
            couponCodes: {
              arrayValue: {
                values: coupons.map(couponToFVal),
              },
            },
          },
        },
      },
    },
  };
  const res = await fetch(url, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  return res.ok;
}

// GET /api/coupons?shopId=X&uid=Y — list coupons for the shop
export async function GET(req: NextRequest) {
  const shopId = req.nextUrl.searchParams.get('shopId');
  const uid = req.nextUrl.searchParams.get('uid');
  if (!shopId || !uid) return NextResponse.json({ error: 'shopId and uid required' }, { status: 400 });

  const { ok, ownerId, coupons, error } = await getShopAndCoupons(shopId);
  if (!ok) return NextResponse.json({ error }, { status: 404 });
  if (ownerId !== uid) return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
  return NextResponse.json({ coupons });
}

// POST /api/coupons?shopId=X&uid=Y — add a coupon
export async function POST(req: NextRequest) {
  const shopId = req.nextUrl.searchParams.get('shopId');
  const uid = req.nextUrl.searchParams.get('uid');
  if (!shopId || !uid) return NextResponse.json({ error: 'shopId and uid required' }, { status: 400 });

  const body = await req.json() as { code?: string; discountPercent?: number; minOrder?: number };
  const code = body.code?.toUpperCase().trim();
  const discountPercent = Number(body.discountPercent) || 0;
  const minOrder = Number(body.minOrder) || 0;

  if (!code) return NextResponse.json({ error: 'code required' }, { status: 400 });
  if (discountPercent < 1 || discountPercent > 90)
    return NextResponse.json({ error: 'discountPercent must be 1–90' }, { status: 400 });

  const { ok, ownerId, coupons, error } = await getShopAndCoupons(shopId);
  if (!ok) return NextResponse.json({ error }, { status: 404 });
  if (ownerId !== uid) return NextResponse.json({ error: 'Forbidden' }, { status: 403 });

  if (coupons!.some((c) => c.code === code))
    return NextResponse.json({ error: 'Coupon code already exists' }, { status: 409 });
  if (coupons!.length >= 20)
    return NextResponse.json({ error: 'Max 20 coupons per shop' }, { status: 400 });

  const updated = [...coupons!, { code, discountPercent, minOrder, active: true }];
  const saved = await saveCoupons(shopId, updated);
  if (!saved) return NextResponse.json({ error: 'Failed to save coupon' }, { status: 500 });
  return NextResponse.json({ ok: true, coupons: updated });
}

// DELETE /api/coupons?shopId=X&uid=Y&code=Z — remove a coupon
export async function DELETE(req: NextRequest) {
  const shopId = req.nextUrl.searchParams.get('shopId');
  const uid = req.nextUrl.searchParams.get('uid');
  const code = req.nextUrl.searchParams.get('code')?.toUpperCase().trim();
  if (!shopId || !uid || !code) return NextResponse.json({ error: 'shopId, uid, and code required' }, { status: 400 });

  const { ok, ownerId, coupons, error } = await getShopAndCoupons(shopId);
  if (!ok) return NextResponse.json({ error }, { status: 404 });
  if (ownerId !== uid) return NextResponse.json({ error: 'Forbidden' }, { status: 403 });

  const updated = coupons!.filter((c) => c.code !== code);
  const saved = await saveCoupons(shopId, updated);
  if (!saved) return NextResponse.json({ error: 'Failed to delete coupon' }, { status: 500 });
  return NextResponse.json({ ok: true, coupons: updated });
}
