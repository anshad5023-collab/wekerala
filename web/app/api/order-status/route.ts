import { NextRequest, NextResponse } from 'next/server';
import { restGetDoc } from '@/lib/firestore-rest';
import { getAdminAuth } from '@/lib/firebase-admin';

async function getVerifiedUid(request: Request): Promise<string | null> {
  const authHeader = request.headers.get('authorization');
  if (!authHeader?.startsWith('Bearer ')) return null;
  try {
    const decoded = await getAdminAuth().verifyIdToken(authHeader.slice(7));
    return decoded.uid;
  } catch {
    return null;
  }
}

export async function GET(req: NextRequest) {
  const orderId = req.nextUrl.searchParams.get('orderId');
  const shopId = req.nextUrl.searchParams.get('shopId');
  if (!orderId || !shopId) {
    return NextResponse.json({ error: 'Missing params' }, { status: 400 });
  }

  const doc = await restGetDoc(`shops/${shopId}/orders/${orderId}`);
  if (!doc) return NextResponse.json({ status: 'not_found' });

  // Public fields — returned to any caller without auth.
  const publicPayload = {
    status: (doc.data.status as string) || 'not_found',
    shopName: (doc.data.shopName as string) || '',
    scheduledFor: (doc.data.scheduledFor as string | undefined) || undefined,
  };

  // Attempt to verify the caller's identity.
  const tokenUid = await getVerifiedUid(req);
  const orderOwnerUid = (doc.data.customerUid as string) || '';

  // Return full PII only when the authenticated user is the order owner.
  if (tokenUid && orderOwnerUid && tokenUid === orderOwnerUid) {
    return NextResponse.json({
      ...publicPayload,
      totalAmount: (doc.data.totalAmount as number) || 0,
      customerName: (doc.data.customerName as string) || '',
      items: (doc.data.items as unknown[]) || [],
      createdAt: (doc.data.createdAt as string) || '',
    });
  }

  // Unauthenticated or mis-matched uid — return public fields only.
  return NextResponse.json(publicPayload);
}
