import { NextRequest, NextResponse } from 'next/server';

// ─── Firestore REST helpers for analytics cache ───────────────────────────────

const _PROJECT_ID = (process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID ?? 'shoplink-prod').replace(/^﻿/, '');
const _API_KEY = process.env.NEXT_PUBLIC_FIREBASE_API_KEY ?? 'AIzaSyCFB9YZL3_bXjvRMoWaYFv8nTs_ote52GQ';
const _FBASE = `https://firestore.googleapis.com/v1/projects/${_PROJECT_ID}/databases/(default)/documents`;

type FVal =
  | { stringValue: string }
  | { integerValue: string }
  | { doubleValue: number }
  | { booleanValue: boolean }
  | { nullValue: null }
  | { arrayValue: { values?: FVal[] } }
  | { mapValue: { fields?: Record<string, FVal> } };

function _parseValue(v: FVal): unknown {
  if ('stringValue' in v) return v.stringValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return v.doubleValue;
  if ('booleanValue' in v) return v.booleanValue;
  if ('nullValue' in v) return null;
  if ('arrayValue' in v) return (v.arrayValue.values ?? []).map(_parseValue);
  if ('mapValue' in v) return _parseFields(v.mapValue.fields ?? {});
  return null;
}

function _parseFields(fields: Record<string, FVal>): Record<string, unknown> {
  return Object.fromEntries(Object.entries(fields).map(([k, v]) => [k, _parseValue(v)]));
}

function _toFVal(v: unknown): FVal {
  if (v === null || v === undefined) return { nullValue: null };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (typeof v === 'number')
    return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  if (typeof v === 'string') return { stringValue: v };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(_toFVal) } };
  if (typeof v === 'object') {
    return {
      mapValue: {
        fields: Object.fromEntries(
          Object.entries(v as Record<string, unknown>).map(([k, val]) => [k, _toFVal(val)])
        ),
      },
    };
  }
  return { nullValue: null };
}

async function _getCacheDoc(path: string): Promise<Record<string, unknown> | null> {
  try {
    const res = await fetch(`${_FBASE}/${path}?key=${_API_KEY}`, { cache: 'no-store' });
    if (!res.ok) return null;
    const json = await res.json();
    if (!json.fields) return null;
    return _parseFields(json.fields as Record<string, FVal>);
  } catch {
    return null;
  }
}

function _writeCacheDoc(path: string, data: Record<string, unknown>): void {
  const fields = Object.fromEntries(Object.entries(data).map(([k, v]) => [k, _toFVal(v)]));
  fetch(`${_FBASE}/${path}?key=${_API_KEY}`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ fields }),
  }).catch(() => {});
}

// ─── Period helper ────────────────────────────────────────────────────────────

function periodStart(period: string): Date {
  const now = new Date();
  if (period === 'day') return new Date(now.getTime() - 24 * 60 * 60 * 1000);
  if (period === 'week') return new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
  return new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
}

// ─── GET /api/analytics ───────────────────────────────────────────────────────

export async function GET(req: NextRequest) {
  const shopId = req.nextUrl.searchParams.get('shopId');
  const period = req.nextUrl.searchParams.get('period') ?? 'month';
  if (!shopId) return NextResponse.json({ error: 'Missing shopId' }, { status: 400 });

  // ── Cache read: try shops/{shopId}/analytics/summary ────────────────────────
  // Cache is keyed by shopId + period so different periods are cached independently.
  const cacheDocPath = `shops/${shopId}/analytics/summary_${period}`;
  const CACHE_TTL_MS = 60 * 60 * 1000; // 60 minutes

  const cached = await _getCacheDoc(cacheDocPath);
  if (cached && typeof cached['computedAt'] === 'string') {
    const age = Date.now() - new Date(cached['computedAt'] as string).getTime();
    if (age < CACHE_TTL_MS) {
      // Return cached response directly — skip all order fetching
      const {
        computedAt: _ca,
        computedForDate: _cd,
        ...cachePayload
      } = cached as Record<string, unknown>;
      return NextResponse.json(cachePayload);
    }
  }
  // ── End cache read ──────────────────────────────────────────────────────────

  const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (!serviceAccountJson) {
    return NextResponse.json({ error: 'FIREBASE_SERVICE_ACCOUNT not set in Vercel env vars' }, { status: 503 });
  }

  try {
    const admin = await import('firebase-admin');
    if (!admin.default.apps.length) {
      admin.default.initializeApp({
        credential: admin.default.credential.cert(JSON.parse(serviceAccountJson)),
      });
    }
    const db = admin.default.firestore();
    const snap = await db.collection('shops').doc(shopId).collection('orders').get();

    const cutoff = periodStart(period);
    const orders = snap.docs
      .map((d) => d.data())
      .filter((o) => {
        if (o['status'] === 'cancelled') return false;
        const raw = o['createdAt'];
        if (!raw) return false;
        const date = typeof raw === 'string' ? new Date(raw) : raw.toDate?.() ?? new Date(0);
        return date >= cutoff;
      });

    const totalRevenue = orders.reduce((s, o) => s + (Number(o['totalAmount']) || 0), 0);
    const orderCount = orders.length;
    const avgOrderValue = orderCount > 0 ? Math.round(totalRevenue / orderCount) : 0;

    const productMap = new Map<string, { qty: number; revenue: number }>();
    for (const order of orders) {
      const items = order['items'] as Array<Record<string, unknown>> | undefined;
      if (!Array.isArray(items)) continue;
      for (const item of items) {
        const name = String(item['productName'] ?? 'Unknown');
        const qty = Number(item['qty']) || 0;
        const price = Number(item['price']) || 0;
        const cur = productMap.get(name) ?? { qty: 0, revenue: 0 };
        productMap.set(name, { qty: cur.qty + qty, revenue: cur.revenue + qty * price });
      }
    }
    const topProducts = Array.from(productMap.entries())
      .map(([name, v]) => ({ name, qty: v.qty, revenue: Math.round(v.revenue) }))
      .sort((a, b) => b.qty - a.qty).slice(0, 5);

    const dailyMap = new Map<string, { revenue: number; orders: number }>();
    for (const order of orders) {
      const raw = order['createdAt'];
      const date = typeof raw === 'string' ? raw.slice(0, 10) : raw?.toDate?.()?.toISOString().slice(0, 10);
      if (!date) continue;
      const cur = dailyMap.get(date) ?? { revenue: 0, orders: 0 };
      dailyMap.set(date, { revenue: cur.revenue + (Number(order['totalAmount']) || 0), orders: cur.orders + 1 });
    }
    const dailyRevenue = Array.from(dailyMap.entries())
      .map(([date, v]) => ({ date, revenue: Math.round(v.revenue), orders: v.orders }))
      .sort((a, b) => a.date.localeCompare(b.date));

    // Count pending orders across the full collection (not period-filtered)
    const allOrders = snap.docs.map((d) => d.data());
    const pendingOrders = allOrders.filter(
      (o) => o['status'] === 'new' || o['status'] === 'confirmed'
    ).length;

    const result = {
      totalRevenue: Math.round(totalRevenue),
      orderCount,
      avgOrderValue,
      topProducts,
      dailyRevenue,
    };

    // ── Cache write: fire-and-forget ─────────────────────────────────────────
    _writeCacheDoc(cacheDocPath, {
      ...result,
      pendingOrders,
      computedAt: new Date().toISOString(),
      computedForDate: new Date().toISOString().slice(0, 10),
    });
    // ── End cache write ──────────────────────────────────────────────────────

    return NextResponse.json(result);
  } catch (e) {
    console.error(e);
    return NextResponse.json({ error: 'Internal error', detail: String(e) }, { status: 500 });
  }
}
