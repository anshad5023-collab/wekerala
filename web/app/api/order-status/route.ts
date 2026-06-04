import { NextRequest, NextResponse } from 'next/server';
import { restGetDoc } from '@/lib/firestore-rest';

export async function GET(req: NextRequest) {
  const orderId = req.nextUrl.searchParams.get('orderId');
  const shopId = req.nextUrl.searchParams.get('shopId');
  if (!orderId || !shopId) {
    return NextResponse.json({ error: 'Missing params' }, { status: 400 });
  }
  const doc = await restGetDoc(`shops/${shopId}/orders/${orderId}`);
  if (!doc) return NextResponse.json({ status: 'not_found' });
  return NextResponse.json({
    status: (doc.data.status as string) || 'not_found',
    shopName: (doc.data.shopName as string) || '',
    totalAmount: (doc.data.totalAmount as number) || 0,
    customerName: (doc.data.customerName as string) || '',
    items: (doc.data.items as unknown[]) || [],
    createdAt: (doc.data.createdAt as string) || '',
    scheduledFor: (doc.data.scheduledFor as string | undefined) || undefined,
  });
}
