import { NextRequest, NextResponse } from 'next/server';

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
  if ('mapValue' in v)
    return Object.fromEntries(Object.entries(v.mapValue.fields ?? {}).map(([k, fv]) => [k, parseValue(fv)]));
  return null;
}

function toFVal(v: unknown): FVal {
  if (typeof v === 'string') return { stringValue: v };
  if (typeof v === 'number') return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (v === null || v === undefined) return { nullValue: null };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(toFVal) } };
  if (typeof v === 'object')
    return {
      mapValue: {
        fields: Object.fromEntries(
          Object.entries(v as Record<string, unknown>).map(([k, val]) => [k, toFVal(val)])
        ),
      },
    };
  return { nullValue: null };
}

async function sendOrderNotification(
  shopId: string,
  orderId: string,
  orderData: Record<string, unknown>
) {
  try {
    const { getAdminDb, getAdminMessaging } = await import('@/lib/firebase-admin');
    const shopDoc = await getAdminDb().collection('shops').doc(shopId).get();
    const fcmToken = shopDoc.data()?.fcmToken as string | undefined;
    if (!fcmToken) return;
    const amount = orderData.totalAmount ?? 0;
    const customer = (orderData.customerName as string) || 'Customer';
    await getAdminMessaging().send({
      token: fcmToken,
      notification: {
        title: 'New Order 🛒',
        body: `₹${amount} — ${customer}`,
      },
      data: { shopId, orderId, screen: 'orders' },
      android: { priority: 'high' },
    });
  } catch (e) {
    console.error('[FCM]', e);
  }
}

export async function GET(req: NextRequest) {
  const shopId = req.nextUrl.searchParams.get('shopId');
  if (!shopId) return NextResponse.json({ error: 'Missing shopId' }, { status: 400 });

  try {
    const res = await fetch(`${BASE}/shops/${shopId}/orders?key=${API_KEY}&orderBy=createdAt desc&pageSize=50`);
    if (!res.ok) return NextResponse.json({ orders: [] });
    const data = await res.json() as { documents?: Array<{ name: string; fields: Record<string, FVal> }> };
    const orders = (data.documents ?? []).map((doc) => ({
      id: doc.name.split('/').pop()!,
      ...Object.fromEntries(Object.entries(doc.fields ?? {}).map(([k, v]) => [k, parseValue(v)])),
    }));
    return NextResponse.json({ orders });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ orders: [] });
  }
}

export async function PATCH(req: NextRequest) {
  const shopId = req.nextUrl.searchParams.get('shopId');
  const orderId = req.nextUrl.searchParams.get('orderId');
  if (!shopId || !orderId) return NextResponse.json({ error: 'Missing params' }, { status: 400 });

  const VALID = ['confirmed', 'preparing', 'ready', 'out_for_delivery', 'delivered', 'cancelled'];
  const body = await req.json() as { status?: string };
  if (!body.status || !VALID.includes(body.status))
    return NextResponse.json({ error: 'Invalid status' }, { status: 400 });

  const url = `${BASE}/shops/${shopId}/orders/${orderId}?updateMask.fieldPaths=status&updateMask.fieldPaths=updatedAt&key=${API_KEY}`;
  const res = await fetch(url, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      fields: {
        status: { stringValue: body.status },
        updatedAt: { stringValue: new Date().toISOString() },
      },
    }),
  });
  if (!res.ok) return NextResponse.json({ error: 'Failed to update' }, { status: 500 });
  return NextResponse.json({ ok: true });
}

async function decrementStock(shopId: string, items: Array<{ productId?: string; qty?: number }>) {
  try {
    const { getAdminDb } = await import('@/lib/firebase-admin');
    const { FieldValue } = await import('firebase-admin/firestore');
    const db = getAdminDb();
    const batch = db.batch();
    for (const item of items) {
      if (!item.productId || !item.qty) continue;
      const ref = db.collection('shops').doc(shopId).collection('products').doc(item.productId);
      batch.update(ref, { stockQty: FieldValue.increment(-item.qty), orderCount: FieldValue.increment(item.qty) });
    }
    await batch.commit();
    // Auto-mark out of stock when stock hits zero
    for (const item of items) {
      if (!item.productId) continue;
      const ref = db.collection('shops').doc(shopId).collection('products').doc(item.productId);
      const snap = await ref.get();
      if (snap.exists) {
        const qty = (snap.data()?.stockQty as number) ?? 1;
        if (qty <= 0) await ref.update({ isOutOfStock: true });
      }
    }
  } catch (e) {
    console.error('[Stock] Decrement failed:', e);
  }
}

async function upsertCustomer(shopId: string, order: Record<string, unknown>) {
  const phone = (order.customerPhone as string) || '';
  const name = (order.customerName as string) || '';
  if (!phone || phone.length < 10) return;
  try {
    const { getAdminDb } = await import('@/lib/firebase-admin');
    const db = getAdminDb();
    const docId = phone.replace(/\D/g, '').slice(-10);
    const ref = db.collection('shops').doc(shopId).collection('customers').doc(docId);
    const snap = await ref.get();
    const now = new Date().toISOString();
    if (!snap.exists) {
      await ref.set({
        customerId: docId, name, phone: docId, shopId,
        totalOrders: 1, totalSpent: (order.totalAmount as number) || 0,
        lastOrderDate: now, firstOrderDate: now, createdAt: now,
      });
    } else {
      await ref.update({
        totalOrders: require('firebase-admin/firestore').FieldValue.increment(1),
        totalSpent: require('firebase-admin/firestore').FieldValue.increment((order.totalAmount as number) || 0),
        lastOrderDate: now,
        name,
      });
    }
  } catch (e) {
    console.error('[Customer] Upsert failed:', e);
  }
}

export async function POST(req: NextRequest) {
  const shopId = req.nextUrl.searchParams.get('shopId');
  if (!shopId) return NextResponse.json({ error: 'Missing shopId' }, { status: 400 });

  try {
    // Reject orders when shop is closed
    try {
      const { getAdminDb } = await import('@/lib/firebase-admin');
      const shopDoc = await getAdminDb().collection('shops').doc(shopId).get();
      const isOpen = shopDoc.data()?.isOpen;
      if (isOpen === false) {
        return NextResponse.json({ error: 'shop_closed', message: 'This shop is currently closed. Please try again later.' }, { status: 409 });
      }
    } catch { /* if admin check fails, allow the order through */ }

    const data = await req.json() as Record<string, unknown>;
    // Convert timestamp fields (ISO strings → Firestore timestampValue)
    const timestampFields = ['createdAt', 'updatedAt', 'scheduledFor'];
    const fields = Object.fromEntries(Object.entries(data).map(([k, v]) => {
      if (timestampFields.includes(k) && typeof v === 'string' && v) {
        return [k, { timestampValue: v }];
      }
      return [k, toFVal(v)];
    }));

    const res = await fetch(`${BASE}/shops/${shopId}/orders?key=${API_KEY}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ fields }),
    });

    if (!res.ok) {
      const err = await res.text();
      return NextResponse.json({ error: err }, { status: res.status });
    }

    const json = await res.json();
    const id = (json.name as string).split('/').pop();

    // Fire-and-forget side effects
    sendOrderNotification(shopId, id ?? '', data);
    decrementStock(shopId, (data.items as Array<{ productId?: string; qty?: number }>) || []);
    upsertCustomer(shopId, data);

    return NextResponse.json({ orderId: id });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ error: 'Internal error' }, { status: 500 });
  }
}
