import { NextRequest, NextResponse } from 'next/server';
import { generatePreviewToken, validatePreviewToken } from '@/lib/preview-token';

// Re-export the validator so page.tsx can import it from this route if desired.
// The canonical implementation lives in lib/preview-token.ts.
export { validatePreviewToken };

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

function parseFields(fields: Record<string, FVal>): Record<string, unknown> {
  return Object.fromEntries(Object.entries(fields).map(([k, v]) => [k, parseValue(v)]));
}

// POST /api/website/preview-token
// Headers: Authorization: Bearer <session-token>
// Body: { shopId: string }
// Returns: { previewUrl: string, expiresAt: string }
export async function POST(req: NextRequest) {
  // Verify session token
  const { authFromRequest } = await import('@/lib/session-token');
  const session = authFromRequest(req);
  if (!session) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  let shopId: string;
  try {
    const body = (await req.json()) as { shopId?: string };
    shopId = body.shopId ?? '';
  } catch {
    return NextResponse.json({ error: 'Invalid JSON body' }, { status: 400 });
  }

  if (!shopId) {
    return NextResponse.json({ error: 'Missing shopId' }, { status: 400 });
  }

  if (session.shopId !== shopId) {
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
  }

  // Generate token
  const { token, expiresAt } = generatePreviewToken(shopId);

  const appUrl = (process.env.NEXT_PUBLIC_APP_URL ?? 'https://wekerala.vercel.app').replace(/\/$/, '');
  const previewUrl = `${appUrl}/sites/${shopId}?preview=${token}`;

  return NextResponse.json({
    previewUrl,
    expiresAt: new Date(expiresAt).toISOString(),
  });
}
