import type { Metadata } from 'next';

const PROJECT_ID = (process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID ?? 'shoplink-prod').replace(/^﻿/, '');
const API_KEY = process.env.NEXT_PUBLIC_FIREBASE_API_KEY ?? '';

async function getShopBySlug(slug: string) {
  try {
    const q = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents:runQuery?key=${API_KEY}`;
    const res = await fetch(q, {
      method: 'POST',
      next: { revalidate: 3600 },
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        structuredQuery: {
          from: [{ collectionId: 'shops' }],
          where: { fieldFilter: { field: { fieldPath: 'shopSlug' }, op: 'EQUAL', value: { stringValue: slug } } },
          limit: 1,
        },
      }),
    });
    const docs = await res.json() as Array<{ document?: { fields?: Record<string, { stringValue?: string }> } }>;
    const fields = docs[0]?.document?.fields;
    if (!fields) return null;
    return {
      name: fields.shopName?.stringValue ?? slug,
      type: fields.shopType?.stringValue ?? '',
      address: fields.address?.stringValue ?? '',
      banner: fields.bannerImageUrl?.stringValue ?? '',
    };
  } catch { return null; }
}

export async function generateMetadata({ params }: { params: { slug: string } }): Promise<Metadata> {
  const shop = await getShopBySlug(params.slug);
  const name = shop?.name ?? params.slug;
  const type = shop?.type ?? 'Shop';
  const description = shop?.address
    ? `${type} in ${shop.address} · Order online`
    : `${type} · Order online, get delivery or pickup`;

  return {
    title: `${name} | Order Online`,
    description,
    openGraph: {
      title: name,
      description,
      type: 'website',
      images: shop?.banner ? [{ url: shop.banner, width: 1200, height: 630 }] : [],
    },
    twitter: {
      card: 'summary_large_image',
      title: name,
      description,
      images: shop?.banner ? [shop.banner] : [],
    },
  };
}

export default function ShopLayout({ children }: { children: React.ReactNode }) {
  return children;
}
