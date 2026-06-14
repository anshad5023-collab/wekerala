import { NextRequest, NextResponse } from 'next/server';
import { createSessionToken } from '@/lib/session-token';

/**
 * POST /api/auth/session
 * Body: { shopId: string, uid: string }
 *
 * Verifies that `uid` is the owner of `shopId` via Firebase Admin SDK,
 * then returns a short-lived signed session token. The client sends this
 * token as `Authorization: Bearer <token>` on subsequent write requests.
 */
export async function POST(req: NextRequest) {
  let shopId: string;
  let uid: string;

  try {
    const body = (await req.json()) as { shopId?: string; uid?: string };
    shopId = body.shopId?.trim() ?? '';
    uid = body.uid?.trim() ?? '';
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  if (!shopId || !uid) {
    return NextResponse.json({ error: 'Missing shopId or uid' }, { status: 400 });
  }

  try {
    const { getAdminDb } = await import('@/lib/firebase-admin');
    const shopDoc = await getAdminDb().collection('shops').doc(shopId).get();
    if (!shopDoc.exists) {
      return NextResponse.json({ error: 'Shop not found' }, { status: 404 });
    }
    const ownerId = shopDoc.data()?.ownerId as string | undefined;
    if (!ownerId || ownerId !== uid) {
      return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
    }

    const token = createSessionToken(uid, shopId);
    return NextResponse.json({ token });
  } catch (e) {
    console.error('[session] error:', e);
    return NextResponse.json({ error: 'Internal error' }, { status: 500 });
  }
}
