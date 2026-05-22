import { NextRequest, NextResponse } from 'next/server';

function parseFirestoreValue(val: unknown): unknown {
  if (!val || typeof val !== 'object') return null;
  const v = val as Record<string, unknown>;
  if ('stringValue' in v) return v.stringValue;
  if ('integerValue' in v) return parseInt(v.integerValue as string, 10);
  if ('doubleValue' in v) return Number(v.doubleValue);
  if ('booleanValue' in v) return v.booleanValue;
  if ('nullValue' in v) return null;
  if ('arrayValue' in v) {
    const arr = v.arrayValue as { values?: unknown[] };
    return (arr.values || []).map(parseFirestoreValue);
  }
  if ('mapValue' in v) {
    const map = v.mapValue as { fields?: Record<string, unknown> };
    return parseFields(map.fields);
  }
  return v;
}

function parseFields(fields: Record<string, unknown> | undefined): Record<string, unknown> {
  if (!fields) return {};
  return Object.fromEntries(Object.entries(fields).map(([k, v]) => [k, parseFirestoreValue(v)]));
}

export async function GET(req: NextRequest) {
  const shopId = req.nextUrl.searchParams.get('shopId');
  const code = req.nextUrl.searchParams.get('code')?.toUpperCase().trim();

  if (!shopId || !code) {
    return NextResponse.json({ error: 'Missing shopId or code' }, { status: 400 });
  }

  const API_KEY = process.env.NEXT_PUBLIC_FIREBASE_API_KEY;
  const PROJECT_ID = process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID;
  const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

  const res = await fetch(`${BASE}/shops/${shopId}?key=${API_KEY}`, { cache: 'no-store' });
  if (!res.ok) return NextResponse.json({ error: 'Shop not found' }, { status: 404 });

  const json = await res.json() as Record<string, unknown>;
  const parsed = parseFields(json.fields as Record<string, unknown> ?? {});
  const website = parsed.website as Record<string, unknown> | null ?? null;
  const rawCoupons = (website?.couponCodes as Array<Record<string, unknown>>) || [];

  const match = rawCoupons.find(
    (c) => (c.code as string)?.toUpperCase() === code && (c.active as boolean) !== false
  );

  if (!match) {
    return NextResponse.json({ valid: false, error: 'Invalid or expired coupon code' }, { status: 200 });
  }

  return NextResponse.json({
    valid: true,
    code: match.code as string,
    discountPercent: match.discountPercent as number,
  });
}
