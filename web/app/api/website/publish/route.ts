import { NextRequest, NextResponse } from 'next/server';

const PROJECT_ID = (process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID ?? 'shoplink-prod').replace(/^﻿/, '');
const API_KEY = process.env.NEXT_PUBLIC_FIREBASE_API_KEY ?? '';
const BASE_REST = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

// ─── Firestore value types ────────────────────────────────────────────────────

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

function parseFields(fields: Record<string, FVal>): Record<string, unknown> {
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
        ),
      },
    };
  }
  return { nullValue: null };
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

/** GET a Firestore document. Returns parsed fields or null if not found. */
async function getDoc(path: string): Promise<Record<string, unknown> | null> {
  const res = await fetch(`${BASE_REST}/${path}?key=${API_KEY}`, { cache: 'no-store' });
  if (res.status === 404 || res.status === 403) return null;
  if (!res.ok) throw new Error(`Firestore GET ${path} failed: ${res.status}`);
  const json = await res.json();
  if (!json.fields) return null;
  return parseFields(json.fields as Record<string, FVal>);
}

/** PATCH (set) a Firestore document by full field replacement using updateMask. */
async function setDoc(
  path: string,
  data: Record<string, unknown>,
  fieldMask?: string[]
): Promise<void> {
  const fields = Object.fromEntries(
    Object.entries(data).map(([k, v]) => [k, toFirestoreValue(v)])
  );
  let url = `${BASE_REST}/${path}?key=${API_KEY}`;
  if (fieldMask && fieldMask.length > 0) {
    url += fieldMask.map((f) => `&updateMask.fieldPaths=${encodeURIComponent(f)}`).join('');
  }
  const res = await fetch(url, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ fields }),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    const msg = (err as { error?: { message?: string } })?.error?.message ?? `Firestore PATCH failed: ${res.status}`;
    throw new Error(msg);
  }
}

/** List all documents in a subcollection. Returns [{ id, fields }] */
async function listDocs(
  collectionPath: string
): Promise<Array<{ id: string; fields: Record<string, unknown> }>> {
  const res = await fetch(`${BASE_REST}/${collectionPath}?key=${API_KEY}&pageSize=200`, {
    cache: 'no-store',
  });
  if (!res.ok) return [];
  const json = await res.json();
  if (!Array.isArray(json.documents)) return [];
  return (json.documents as Array<{ name: string; fields: Record<string, FVal> }>).map((doc) => ({
    id: doc.name.split('/').pop() ?? '',
    fields: parseFields(doc.fields ?? {}),
  }));
}

/** DELETE a Firestore document. Ignores 404. */
async function deleteDoc(path: string): Promise<void> {
  const res = await fetch(`${BASE_REST}/${path}?key=${API_KEY}`, { method: 'DELETE' });
  if (!res.ok && res.status !== 404) {
    console.warn(`[publish] deleteDoc failed for ${path}: ${res.status}`);
  }
}

// ─── POST /api/website/publish ────────────────────────────────────────────────

export async function POST(req: NextRequest) {
  if (!API_KEY) {
    console.error('[publish] NEXT_PUBLIC_FIREBASE_API_KEY is not configured');
    return NextResponse.json({ error: 'Server configuration error' }, { status: 500 });
  }

  let shopId: string;
  let uid: string;

  try {
    const body = (await req.json()) as { shopId?: string; uid?: string };
    shopId = body.shopId ?? '';
    uid = body.uid ?? '';
  } catch {
    return NextResponse.json({ error: 'Invalid JSON body' }, { status: 400 });
  }

  if (!shopId || !uid) {
    return NextResponse.json({ error: 'Missing shopId or uid' }, { status: 400 });
  }

  // ── 1. Verify ownership ──────────────────────────────────────────────────────
  let shopFields: Record<string, unknown>;
  try {
    const sf = await getDoc(`shops/${shopId}`);
    if (!sf) return NextResponse.json({ error: 'Shop not found' }, { status: 404 });
    shopFields = sf;
  } catch (e) {
    console.error('[publish] shop lookup error:', e);
    return NextResponse.json({ error: 'Failed to fetch shop' }, { status: 500 });
  }

  if (shopFields['ownerId'] !== uid) {
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
  }

  // ── 2. Read draft config (with lazy-migration fallback) ──────────────────────
  let draftConfig: Record<string, unknown> | null = null;

  try {
    const draftDoc = await getDoc(`shops/${shopId}/versions/draft`);
    if (draftDoc && typeof draftDoc['config'] === 'object' && draftDoc['config'] !== null) {
      draftConfig = draftDoc['config'] as Record<string, unknown>;
    }
  } catch (e) {
    console.warn('[publish] could not read draft doc, will try legacy field:', e);
  }

  // Fallback: read from the old shops/{shopId}.website field
  if (!draftConfig) {
    const legacyWebsite = shopFields['website'];
    if (legacyWebsite && typeof legacyWebsite === 'object') {
      draftConfig = legacyWebsite as Record<string, unknown>;
    }
  }

  // ── 3. Validate config ───────────────────────────────────────────────────────
  if (!draftConfig) {
    return NextResponse.json(
      { error: 'No draft config found. Save your website settings first.' },
      { status: 422 }
    );
  }
  if (!draftConfig['themeId']) {
    return NextResponse.json(
      { error: 'Draft config is missing a themeId. Open the Website Builder to set a theme.' },
      { status: 422 }
    );
  }

  // ── 4. Read current published version to determine next version number ────────
  let nextVersion = 1;
  try {
    const publishedDoc = await getDoc(`shops/${shopId}/versions/published`);
    if (publishedDoc && typeof publishedDoc['version'] === 'number') {
      nextVersion = (publishedDoc['version'] as number) + 1;
    } else if (publishedDoc && typeof publishedDoc['version'] === 'string') {
      nextVersion = parseInt(publishedDoc['version'] as string, 10) + 1 || 1;
    }
  } catch {
    // No existing published doc — version stays 1
  }

  const now = new Date();
  const publishedAt = now.toISOString();

  const versionPayload: Record<string, unknown> = {
    config: draftConfig,
    publishedAt,
    publishedBy: 'owner',
    version: nextVersion,
  };

  // ── 5. Write published document ──────────────────────────────────────────────
  try {
    await setDoc(`shops/${shopId}/versions/published`, versionPayload);
  } catch (e) {
    console.error('[publish] failed to write published doc:', e);
    return NextResponse.json(
      { error: (e as Error).message ?? 'Failed to write published version' },
      { status: 500 }
    );
  }

  // ── 6. Write version snapshot ────────────────────────────────────────────────
  const snapshotId = publishedAt.replace(/[:.]/g, '-'); // safe Firestore doc ID
  try {
    await setDoc(`shops/${shopId}/versions/${snapshotId}`, {
      ...versionPayload,
      changeNote: `Published version ${nextVersion}`,
    });
  } catch (e) {
    // Non-fatal — snapshot write failure should not block the publish
    console.warn('[publish] snapshot write failed:', e);
  }

  // ── 6b. Keep only last 10 snapshots ─────────────────────────────────────────
  try {
    const allVersionDocs = await listDocs(`shops/${shopId}/versions`);
    // Snapshots are ISO-timestamp IDs (excluding 'draft' and 'published')
    const snapshots = allVersionDocs
      .map((d) => d.id)
      .filter((id) => id !== 'draft' && id !== 'published')
      .sort(); // ISO timestamps sort lexicographically = chronological

    if (snapshots.length > 10) {
      const toDelete = snapshots.slice(0, snapshots.length - 10);
      await Promise.all(toDelete.map((id) => deleteDoc(`shops/${shopId}/versions/${id}`)));
    }
  } catch (e) {
    console.warn('[publish] snapshot pruning failed (non-fatal):', e);
  }

  // ── 7. Update top-level shop document for backward compat ────────────────────
  try {
    // Merge isPublished + publishedAt into the existing website field
    const existingWebsite =
      typeof shopFields['website'] === 'object' && shopFields['website'] !== null
        ? (shopFields['website'] as Record<string, unknown>)
        : {};

    await setDoc(
      `shops/${shopId}`,
      {
        website: {
          ...existingWebsite,
          isPublished: true,
          publishedAt,
        },
      },
      ['website']
    );
  } catch (e) {
    // Non-fatal: backward-compat update failure doesn't block the publish
    console.warn('[publish] backward-compat shop update failed:', e);
  }

  // ── 8. Build and return URLs ─────────────────────────────────────────────────
  const appUrl = (process.env.NEXT_PUBLIC_APP_URL ?? 'https://wekerala.vercel.app').replace(/\/$/, '');
  const publishedUrl = `${appUrl}/sites/${shopId}`;

  const shopSlug = shopFields['shopSlug'] as string | undefined;
  const slugUrl = shopSlug ? `${appUrl}/sites/${shopSlug}` : undefined;

  return NextResponse.json({
    ok: true,
    publishedUrl,
    ...(slugUrl ? { slugUrl } : {}),
  });
}
