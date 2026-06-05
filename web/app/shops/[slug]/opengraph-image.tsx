import { ImageResponse } from 'next/og';

export const runtime = 'edge';
export const size = { width: 1200, height: 630 };
export const contentType = 'image/png';

const PROJECT_ID = (process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID ?? 'shoplink-prod').replace(/^﻿/, '');
const API_KEY = process.env.NEXT_PUBLIC_FIREBASE_API_KEY ?? '';

async function getShopBySlug(slug: string) {
  try {
    const q = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents:runQuery?key=${API_KEY}`;
    const res = await fetch(q, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        structuredQuery: {
          from: [{ collectionId: 'shops' }],
          where: { fieldFilter: { field: { fieldPath: 'shopSlug' }, op: 'EQUAL', value: { stringValue: slug } } },
          limit: 1,
        },
      }),
    });
    const docs = await res.json() as Array<{ document?: { fields?: Record<string, { stringValue?: string; booleanValue?: boolean }> } }>;
    const fields = docs[0]?.document?.fields;
    if (!fields) return null;
    return {
      name: fields.shopName?.stringValue ?? slug,
      type: fields.shopType?.stringValue ?? '',
      banner: fields.bannerImageUrl?.stringValue ?? '',
    };
  } catch { return null; }
}

export default async function Image({ params }: { params: { slug: string } }) {
  const shop = await getShopBySlug(params.slug);
  const name = shop?.name ?? params.slug;
  const type = shop?.type ?? 'Shop';

  return new ImageResponse(
    (
      <div
        style={{
          width: '100%', height: '100%',
          background: 'linear-gradient(135deg, #16a34a 0%, #065f46 100%)',
          display: 'flex', flexDirection: 'column',
          alignItems: 'center', justifyContent: 'center',
          fontFamily: 'sans-serif',
        }}
      >
        <div style={{ fontSize: 80, marginBottom: 16 }}>🛒</div>
        <div style={{ color: 'white', fontSize: 56, fontWeight: 700, textAlign: 'center', padding: '0 40px' }}>
          {name}
        </div>
        <div style={{ color: 'rgba(255,255,255,0.8)', fontSize: 28, marginTop: 12 }}>
          {type} · Order online, pick up or get delivery
        </div>
        <div style={{ color: 'rgba(255,255,255,0.6)', fontSize: 20, marginTop: 24 }}>
          Powered by weKerala
        </div>
      </div>
    ),
    size,
  );
}
