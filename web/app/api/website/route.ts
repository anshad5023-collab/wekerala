import { NextRequest, NextResponse } from 'next/server';

const PROJECT_ID = (process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID ?? 'shoplink-prod').replace(/^﻿/, '');
const API_KEY = process.env.NEXT_PUBLIC_FIREBASE_API_KEY ?? 'AIzaSyCFB9YZL3_bXjvRMoWaYFv8nTs_ote52GQ';
const BASE_REST = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

type FVal =
  | { stringValue: string }
  | { integerValue: string }
  | { booleanValue: boolean }
  | { nullValue: null }
  | { arrayValue: { values?: FVal[] } }
  | { mapValue: { fields?: Record<string, FVal> } };

function parseValue(v: FVal): unknown {
  if ('stringValue' in v) return v.stringValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('booleanValue' in v) return v.booleanValue;
  if ('nullValue' in v) return null;
  if ('arrayValue' in v) return (v.arrayValue.values ?? []).map(parseValue);
  if ('mapValue' in v) return parseFields(v.mapValue.fields ?? {});
  return null;
}

function parseFields(fields: Record<string, FVal>) {
  return Object.fromEntries(Object.entries(fields).map(([k, v]) => [k, parseValue(v)]));
}

function toFirestoreValue(v: unknown): FVal {
  if (v === null || v === undefined) return { nullValue: null };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (typeof v === 'number') return { stringValue: String(v) };
  if (typeof v === 'string') return { stringValue: v };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(toFirestoreValue) } };
  if (typeof v === 'object') {
    return {
      mapValue: {
        fields: Object.fromEntries(
          Object.entries(v as Record<string, unknown>).map(([k, val]) => [k, toFirestoreValue(val)])
        )
      }
    };
  }
  return { nullValue: null };
}

// GET /api/website?shopId=X — returns website config for a shop
export async function GET(req: NextRequest) {
  const shopId = req.nextUrl.searchParams.get('shopId');
  if (!shopId) return NextResponse.json({ error: 'Missing shopId' }, { status: 400 });

  const res = await fetch(`${BASE_REST}/shops/${shopId}?key=${API_KEY}`);
  if (!res.ok) return NextResponse.json({ error: 'Shop not found' }, { status: 404 });

  const json = await res.json();
  const fields = parseFields(json.fields ?? {}) as Record<string, unknown>;

  return NextResponse.json({
    shopId,
    shopName: fields['shopName'] ?? '',
    shopNameMl: fields['shopNameMl'] ?? '',
    shopType: fields['shopType'] ?? '',
    district: fields['district'] ?? '',
    ownerPhone: fields['ownerPhone'] ?? fields['phone'] ?? fields['ownerWhatsApp'] ?? '',
    logoUrl: fields['logoUrl'] ?? '',
    bannerImageUrl: fields['bannerImageUrl'] ?? '',
    website: fields['website'] ?? null,
  });
}

function toSlug(name: string, fallback: string): string {
  const slug = name.toLowerCase()
    .replace(/[^a-z0-9\s-]/g, '')
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '');
  return slug || fallback.slice(0, 8);
}

// POST /api/website — save + publish website config via Firestore REST PATCH
// Body: { shopId, uid, config: WebsiteConfig, draft?: boolean }
export async function POST(req: NextRequest) {
  const body = (await req.json()) as {
    shopId: string;
    uid: string;
    config: Record<string, unknown>;
    draft?: boolean;
  };
  const { shopId, uid, config, draft } = body;

  if (!shopId || !uid || !config) {
    return NextResponse.json({ error: 'Missing shopId, uid, or config' }, { status: 400 });
  }

  // Verify ownership via REST
  const shopRes = await fetch(`${BASE_REST}/shops/${shopId}?key=${API_KEY}`, { cache: 'no-store' });
  if (!shopRes.ok) return NextResponse.json({ error: 'Shop not found' }, { status: 404 });
  const shopJson = await shopRes.json();
  const shopFields = parseFields(shopJson.fields ?? {}) as Record<string, unknown>;
  if (shopFields['ownerId'] !== uid) {
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
  }

  const shopName = (shopFields['shopName'] as string) || (shopFields['name'] as string) || '';
  const existingSlug = (shopFields['shopSlug'] as string) || '';
  const slug = toSlug(shopName, shopId);

  // Check slug uniqueness only when slug would change
  if (slug !== existingSlug) {
    const queryUrl = `${BASE_REST}/shops?key=${API_KEY}&pageSize=2` +
      `&structuredQuery.from[0].collectionId=shops` +
      `&structuredQuery.where.fieldFilter.field.fieldPath=shopSlug` +
      `&structuredQuery.where.fieldFilter.op=EQUAL` +
      `&structuredQuery.where.fieldFilter.value.stringValue=${encodeURIComponent(slug)}`;
    // Use simpler Firestore REST query
    const slugCheckUrl = `${BASE_REST}:runQuery?key=${API_KEY}`;
    const slugCheckBody = {
      structuredQuery: {
        from: [{ collectionId: 'shops' }],
        where: {
          fieldFilter: {
            field: { fieldPath: 'shopSlug' },
            op: 'EQUAL',
            value: { stringValue: slug },
          },
        },
        limit: 2,
      },
    };
    const slugCheckRes = await fetch(slugCheckUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(slugCheckBody),
    });
    if (slugCheckRes.ok) {
      const slugDocs = (await slugCheckRes.json()) as Array<{ document?: { name?: string } }>;
      const conflict = slugDocs.find(
        (d) => d.document && !d.document.name?.endsWith(`/shops/${shopId}`)
      );
      if (conflict) {
        return NextResponse.json(
          {
            error: `The site name "${slug}" is already taken. Try adding your city or area name — for example: "${slug}-calicut" or "${slug}-ernakulam".`,
            code: 'SLUG_TAKEN',
          },
          { status: 409 }
        );
      }
    }
  }

  const websiteData = draft
    ? { ...config, slug }
    : { ...config, isPublished: true, publishedAt: new Date().toISOString(), slug };

  // PATCH website + shopSlug fields using updateMask
  const patchUrl = `${BASE_REST}/shops/${shopId}?key=${API_KEY}&updateMask.fieldPaths=website&updateMask.fieldPaths=shopSlug`;
  try {
    const patchRes = await fetch(patchUrl, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        fields: {
          website: toFirestoreValue(websiteData),
          shopSlug: toFirestoreValue(slug),
        },
      }),
    });

    if (!patchRes.ok) {
      const errJson = await patchRes.json().catch(() => ({}));
      const msg = (errJson as { error?: { message?: string } })?.error?.message ?? 'Firestore write failed';
      console.error('[website POST] Firestore PATCH failed:', msg, 'shopId:', shopId);
      return NextResponse.json({ error: msg }, { status: 500 });
    }

    // Use shopId (direct doc lookup) as primary URL — always works even if slug isn't saved yet
    const siteUrl = `https://wekerala.vercel.app/sites/${shopId}`;
    const slugUrl = slug ? `https://wekerala.vercel.app/sites/${slug}` : siteUrl;
    return NextResponse.json({ ok: true, siteUrl, slugUrl });
  } catch (e) {
    console.error('[website POST]', e);
    return NextResponse.json({ error: (e as Error).message ?? 'Failed to save website config' }, { status: 500 });
  }
}
