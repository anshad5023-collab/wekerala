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

// Lazy migration: if versions/published doesn't exist yet, seed it from shops/{shopId}.website
async function ensureMigrated(shopId: string, existingWebsite: Record<string, unknown> | null, apiKey: string) {
  const publishedUrl = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/shops/${shopId}/versions/published?key=${apiKey}`;
  const check = await fetch(publishedUrl);

  if (check.status === 404 && existingWebsite) {
    // Not yet migrated — copy existing website to versions/published and versions/draft
    const now = new Date().toISOString();

    // Write to versions/published
    await fetch(publishedUrl, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        fields: {
          config: toFirestoreValue(existingWebsite),
          publishedAt: toFirestoreValue(now),
          publishedBy: toFirestoreValue('migration'),
          version: toFirestoreValue(1),
        }
      })
    });

    // Write to versions/draft
    const draftUrl = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/shops/${shopId}/versions/draft?key=${apiKey}`;
    await fetch(draftUrl, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        fields: {
          config: toFirestoreValue(existingWebsite),
          savedAt: toFirestoreValue(now),
          savedBy: toFirestoreValue('migration'),
          hasPendingDraft: toFirestoreValue(false),
        }
      })
    });
  }
}

// GET /api/website?shopId=X — returns website config for a shop
export async function GET(req: NextRequest) {
  const shopId = req.nextUrl.searchParams.get('shopId');
  if (!shopId) return NextResponse.json({ error: 'Missing shopId' }, { status: 400 });

  const res = await fetch(`${BASE_REST}/shops/${shopId}?key=${API_KEY}`);
  if (!res.ok) return NextResponse.json({ error: 'Shop not found' }, { status: 404 });

  const json = await res.json();
  const fields = parseFields(json.fields ?? {}) as Record<string, unknown>;

  // Try versions/published first; fall back to shops/{shopId}.website
  let websiteConfig: unknown = null;
  try {
    const publishedRes = await fetch(
      `${BASE_REST}/shops/${shopId}/versions/published?key=${API_KEY}`
    );
    if (publishedRes.ok) {
      const publishedJson = await publishedRes.json();
      const publishedFields = parseFields(publishedJson.fields ?? {}) as Record<string, unknown>;
      websiteConfig = publishedFields['config'] ?? null;
    }
  } catch {
    // Ignore errors reading versions/published — fall through to legacy field
  }

  // Fall back to legacy shops/{shopId}.website field
  if (websiteConfig === null) {
    websiteConfig = fields['website'] ?? null;
  }

  return NextResponse.json({
    shopId,
    shopName: fields['shopName'] ?? '',
    shopNameMl: fields['shopNameMl'] ?? '',
    shopType: fields['shopType'] ?? '',
    district: fields['district'] ?? '',
    ownerPhone: fields['ownerPhone'] ?? fields['phone'] ?? fields['ownerWhatsApp'] ?? '',
    logoUrl: fields['logoUrl'] ?? '',
    bannerImageUrl: fields['bannerImageUrl'] ?? '',
    website: websiteConfig,
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

// POST /api/website — save + publish website config via Admin SDK (bypasses security rules)
// Body: { shopId, uid, config: WebsiteConfig, draft?: boolean }
export async function POST(req: NextRequest) {
  // Read raw text first so we can sanitize control chars Gemini/editors may embed
  const rawText = await req.text();
  const sanitized = rawText.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F]/g, '');
  let body: { shopId: string; uid: string; config: Record<string, unknown>; draft?: boolean };
  try {
    body = JSON.parse(sanitized);
  } catch (parseErr) {
    return NextResponse.json({ error: `Invalid request body: ${(parseErr as Error).message}` }, { status: 400 });
  }
  const { shopId, uid, config, draft } = body;

  if (!shopId || !uid || !config) {
    return NextResponse.json({ error: 'Missing shopId, uid, or config' }, { status: 400 });
  }

  try {
    const { getAdminDb } = await import('@/lib/firebase-admin');
    const db = getAdminDb();

    // Verify ownership
    const shopDoc = await db.collection('shops').doc(shopId).get();
    if (!shopDoc.exists) return NextResponse.json({ error: 'Shop not found' }, { status: 404 });
    const shopData = shopDoc.data()!;
    if (shopData['ownerId'] !== uid) {
      return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
    }

    const shopName = (shopData['shopName'] as string) || (shopData['name'] as string) || '';
    const existingSlug = (shopData['shopSlug'] as string) || '';
    const slug = toSlug(shopName, shopId);

    // Check slug uniqueness only when slug would change
    if (slug !== existingSlug) {
      const slugSnap = await db.collection('shops').where('shopSlug', '==', slug).limit(2).get();
      const conflict = slugSnap.docs.find((d) => d.id !== shopId);
      if (conflict) {
        return NextResponse.json(
          {
            error: `The site name "${slug}" is already taken. Try "${slug}-calicut" or "${slug}-ernakulam".`,
            code: 'SLUG_TAKEN',
          },
          { status: 409 }
        );
      }
    }

    const now = new Date().toISOString();
    const websiteData = draft
      ? { ...config, slug }
      : { ...config, isPublished: true, publishedAt: now, slug };

    const versionsRef = db.collection('shops').doc(shopId).collection('versions');

    if (draft) {
      // Auto-save: write to shops/{shopId}.website + versions/draft
      await Promise.all([
        db.collection('shops').doc(shopId).update({ website: websiteData, shopSlug: slug }),
        versionsRef.doc('draft').set(
          { config: websiteData, savedAt: now, savedBy: 'builder', hasPendingDraft: true },
          { merge: true }
        ),
      ]);
    } else {
      // Publish: get current version number
      let currentVersion = 1;
      try {
        const prevPublished = await versionsRef.doc('published').get();
        if (prevPublished.exists) {
          const v = prevPublished.data()?.version;
          if (typeof v === 'number') currentVersion = v + 1;
        }
      } catch { /* start at 1 */ }

      // Write all three destinations in parallel
      await Promise.all([
        db.collection('shops').doc(shopId).update({ website: websiteData, shopSlug: slug }),
        versionsRef.doc('published').set({
          config: websiteData,
          publishedAt: now,
          publishedBy: 'owner',
          version: currentVersion,
        }),
        versionsRef.doc('draft').set(
          { config: websiteData, savedAt: now, savedBy: 'owner', hasPendingDraft: false },
          { merge: true }
        ),
        versionsRef.doc(now).set({ config: websiteData, publishedAt: now, version: currentVersion }),
      ]);
    }

    const siteUrl = `https://wekerala.vercel.app/sites/${shopId}`;
    const slugUrl = slug ? `https://wekerala.vercel.app/sites/${slug}` : siteUrl;
    return NextResponse.json({ ok: true, siteUrl, slugUrl });
  } catch (e) {
    console.error('[website POST]', e);
    return NextResponse.json({ error: (e as Error).message ?? 'Failed to save website config' }, { status: 500 });
  }
}
