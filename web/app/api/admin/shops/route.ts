import { NextRequest, NextResponse } from 'next/server';

const PROJECT_ID = (process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID ?? 'shoplink-prod').replace(/^﻿/, '');
const API_KEY = process.env.NEXT_PUBLIC_FIREBASE_API_KEY ?? 'AIzaSyCFB9YZL3_bXjvRMoWaYFv8nTs_ote52GQ';
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD ?? '';

const ALL_COLLECTIONS = [
  'shops', 'services', 'theaters', 'hotels', 'restaurants',
  'beauty', 'doctors', 'hospitals', 'education', 'homeServices',
];

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

function checkAuth(req: NextRequest): boolean {
  if (!ADMIN_PASSWORD) return false;
  const pw = req.headers.get('x-admin-password') ?? req.nextUrl.searchParams.get('password') ?? '';
  return pw === ADMIN_PASSWORD;
}

async function fetchCollection(col: string) {
  const res = await fetch(`${BASE}/${col}?pageSize=200&key=${API_KEY}`);
  if (!res.ok) return [];
  const json = await res.json();
  const docs: Array<{ name: string; fields: Record<string, FVal> }> = json.documents ?? [];
  return docs.map((doc) => {
    const f = parseFields(doc.fields ?? {});
    const id = (doc.name as string).split('/').pop() ?? '';
    const websiteMap = f['website'] as Record<string, unknown> | null ?? null;
    const isShop = col === 'shops';
    return {
      shopId: id,
      collection: col,
      shopName: isShop ? ((f['shopName'] as string) ?? '—') : ((f['name'] as string) ?? '—'),
      shopNameMl: (f['shopNameMl'] as string) ?? '',
      logoUrl: (f['logoUrl'] as string) ?? (f['photoUrl'] as string) ?? '',
      shopType: isShop ? ((f['shopType'] as string) ?? '') : col,
      shopArea: (f['shopArea'] as string) ?? (f['district'] as string) ?? '',
      isOpen: (f['isOpen'] as boolean) ?? (f['isActive'] as boolean) ?? false,
      isApproved: isShop
        ? ((f['isApproved'] as boolean) ?? (f['linkActive'] as boolean) ?? false)
        : ((f['isActive'] as boolean) ?? true),
      ownerPhone: (f['ownerPhone'] as string) ?? (f['ownerWhatsApp'] as string) ?? (f['phone'] as string) ?? '',
      subscriptionStatus: (f['subscriptionStatus'] as string) ?? 'trial',
      createdAt: (f['createdAt'] as string) ?? '',
      websiteIsPublished: (websiteMap?.['isPublished'] as boolean) ?? false,
      websitePublishedAt: (websiteMap?.['publishedAt'] as string) ?? '',
      websiteThemeId: (websiteMap?.['themeId'] as string) ?? '',
    };
  });
}

// GET /api/admin/shops — list all shops (and optionally all other collections)
export async function GET(req: NextRequest) {
  if (!checkAuth(req)) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const allCollections = req.nextUrl.searchParams.get('all') === 'true';

  try {
    let allListings;
    if (allCollections) {
      const results = await Promise.all(ALL_COLLECTIONS.map(fetchCollection));
      allListings = results.flat();
    } else {
      allListings = await fetchCollection('shops');
    }

    const shops = allListings.filter(l => l.shopName.trim() !== '' && l.shopName !== '—');

    const stats = {
      total: shops.length,
      approved: shops.filter((s) => s.isApproved).length,
      pending: shops.filter((s) => !s.isApproved).length,
      openNow: shops.filter((s) => s.isOpen).length,
    };

    return NextResponse.json({ shops, stats });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ error: 'Internal error' }, { status: 500 });
  }
}

// PATCH /api/admin/shops — approve/block/unpublish via Firestore REST (no firebase-admin needed)
export async function PATCH(req: NextRequest) {
  if (!checkAuth(req)) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const body = (await req.json()) as {
    shopId: string;
    collection?: string;
    isApproved?: boolean;
    action?: string;
    reason?: string;
  };
  const { shopId, isApproved, action, reason } = body;
  const collection = body.collection ?? 'shops';

  if (!shopId) {
    return NextResponse.json({ error: 'Missing shopId' }, { status: 400 });
  }

  try {
    if (action === 'unpublish_website') {
      // Update only the nested website fields using dot-notation updateMask
      const now = new Date().toISOString();
      const url = `${BASE}/shops/${shopId}?key=${API_KEY}` +
        `&updateMask.fieldPaths=website.isPublished` +
        `&updateMask.fieldPaths=website.unpublishedAt` +
        `&updateMask.fieldPaths=website.unpublishReason`;

      const res = await fetch(url, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          fields: {
            website: {
              mapValue: {
                fields: {
                  isPublished: { booleanValue: false },
                  unpublishedAt: { stringValue: now },
                  unpublishReason: { stringValue: reason ?? '' },
                },
              },
            },
          },
        }),
      });

      if (!res.ok) {
        const err = await res.json().catch(() => ({}));
        console.error('[admin unpublish]', err);
        return NextResponse.json({ error: 'Failed to unpublish website' }, { status: 500 });
      }
      return NextResponse.json({ ok: true });
    }

    if (typeof isApproved !== 'boolean') {
      return NextResponse.json({ error: 'Missing isApproved or valid action' }, { status: 400 });
    }

    // For shops: update isApproved. For other collections: update isActive.
    const isShop = collection === 'shops';
    const fieldName = isShop ? 'isApproved' : 'isActive';
    const url = `${BASE}/${collection}/${shopId}?key=${API_KEY}&updateMask.fieldPaths=${fieldName}`;

    const res = await fetch(url, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        fields: {
          [fieldName]: { booleanValue: isApproved },
        },
      }),
    });

    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      console.error('[admin approve/block]', err);
      return NextResponse.json({ error: 'Failed to update listing' }, { status: 500 });
    }
    return NextResponse.json({ ok: true });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ error: 'Failed to update' }, { status: 500 });
  }
}
