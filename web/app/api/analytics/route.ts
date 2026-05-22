import { NextRequest, NextResponse } from 'next/server';

function periodStart(period: string): Date {
  const now = new Date();
  if (period === 'day') return new Date(now.getTime() - 24 * 60 * 60 * 1000);
  if (period === 'week') return new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
  return new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
}

export async function GET(req: NextRequest) {
  const shopId = req.nextUrl.searchParams.get('shopId');
  const period = req.nextUrl.searchParams.get('period') ?? 'month';
  if (!shopId) return NextResponse.json({ error: 'Missing shopId' }, { status: 400 });

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

    return NextResponse.json({ totalRevenue: Math.round(totalRevenue), orderCount, avgOrderValue, topProducts, dailyRevenue });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ error: 'Internal error', detail: String(e) }, { status: 500 });
  }
}
