import ModernTheme from '@/components/themes/ModernTheme';
import BoldTheme from '@/components/themes/BoldTheme';
import TraditionalTheme from '@/components/themes/TraditionalTheme';

const PROJECT_ID = (process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID ?? 'shoplink-prod').replace(/^﻿/, '');
const API_KEY = process.env.NEXT_PUBLIC_FIREBASE_API_KEY ?? 'AIzaSyCFB9YZL3_bXjvRMoWaYFv8nTs_ote52GQ';
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

function parseFirestoreValue(val: unknown): unknown {
  if (!val || typeof val !== 'object') return null;
  const v = val as Record<string, unknown>;
  if ('stringValue' in v) return v.stringValue;
  if ('integerValue' in v) return parseInt(v.integerValue as string, 10);
  if ('doubleValue' in v) return Number(v.doubleValue);
  if ('booleanValue' in v) return v.booleanValue;
  if ('nullValue' in v) return null;
  if ('arrayValue' in v) {
    const arr = v.arrayValue as { values?: unknown[] };
    return (arr.values || []).map(parseFirestoreValue);
  }
  if ('mapValue' in v) {
    const map = v.mapValue as { fields?: Record<string, unknown> };
    return parseFields(map.fields);
  }
  return v;
}

function parseFields(fields: Record<string, unknown> | undefined): Record<string, unknown> {
  if (!fields) return {};
  const result: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(fields)) {
    result[key] = parseFirestoreValue(value);
  }
  return result;
}

async function findShopBySlug(slug: string) {
  try {
    const res = await fetch(`${BASE}:runQuery?key=${API_KEY}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        structuredQuery: {
          from: [{ collectionId: 'shops' }],
          where: {
            fieldFilter: {
              field: { fieldPath: 'shopSlug' },
              op: 'EQUAL',
              value: { stringValue: slug },
            },
          },
          limit: 1,
        },
      }),
      next: { revalidate: 300 },
    });
    const results = await res.json() as Array<{ document?: { name: string; fields: Record<string, unknown> } }>;
    return results[0]?.document ?? null;
  } catch {
    return null;
  }
}

export default async function SlugPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;

  const shopDoc = await findShopBySlug(slug);

  if (!shopDoc) {
    return (
      <div
        className="min-h-screen flex flex-col items-center justify-center gap-4 p-8"
        style={{ background: '#fefae0', fontFamily: 'sans-serif' }}
      >
        <p style={{ fontSize: 48 }}>🔍</p>
        <h1 style={{ fontSize: 22, fontWeight: 800, color: '#283618' }}>Page not found</h1>
        <p style={{ color: '#a8a08a', textAlign: 'center' }}>
          This business doesn&apos;t exist on wekerala yet.
        </p>
        <a
          href="/"
          style={{
            marginTop: 16, padding: '12px 24px', background: '#283618',
            color: '#fefae0', borderRadius: 12, fontWeight: 700, textDecoration: 'none',
          }}
        >
          Back to wekerala
        </a>
      </div>
    );
  }

  const shopId = shopDoc.name.split('/').pop()!;
  const parsedShop = parseFields(shopDoc.fields as Record<string, unknown>);
  const website = parsedShop.website as Record<string, unknown> | null ?? null;

  if (!website || website.isPublished !== true) {
    return (
      <div className="min-h-screen bg-[#283618] flex flex-col items-center justify-center p-4">
        <h1 className="text-4xl font-bold text-[#fefae0] text-center mb-4">
          {(parsedShop.shopName as string) || 'Shop'}
        </h1>
        <p className="text-xl text-[#fefae0]/80">Website coming soon</p>
      </div>
    );
  }

  const productsRes = await fetch(
    `${BASE}/shops/${shopId}/products?pageSize=50&key=${API_KEY}`,
    { next: { revalidate: 60 } }
  );
  const productsData = await productsRes.json();
  const products = (
    (productsData.documents || []) as Array<{ name: string; fields: Record<string, unknown> }>
  ).map((doc) => {
    const parsed = parseFields(doc.fields);
    return {
      productId: doc.name.split('/').pop() ?? '',
      name: (parsed.name as string) || '',
      price: (parsed.price as number) || 0,
      imageUrl: (parsed.imageUrl as string) || '',
      category: (parsed.category as string) || '',
    };
  });

  const shop = {
    shopName: (parsedShop.shopName as string) || '',
    shopNameMl: (parsedShop.shopNameMl as string) || '',
    shopType: (parsedShop.shopType as string) || '',
    district: (parsedShop.district as string) || '',
    ownerPhone: (parsedShop.ownerPhone as string) || '',
    logoUrl: (parsedShop.logoUrl as string) || '',
    bannerImageUrl: (parsedShop.bannerImageUrl as string) || '',
  };

  const config = {
    siteName: (website.siteName as string) || '',
    tagline: (website.tagline as string) || '',
    aboutText: (website.aboutText as string) || '',
    primaryColor: (website.primaryColor as string) || '#dda15e',
    sections: (website.sections as string[]) || ['hero', 'products', 'about', 'contact'],
    whatsappEnabled: (website.whatsappEnabled as boolean) ?? true,
    whatsappNumber: (website.whatsappNumber as string) || '',
    customHtml: (website.customHtml as string) || '',
    themeId: (website.themeId as string) || 'modern',
  };

  if (config.themeId === 'custom') {
    const safeHtml = config.customHtml.replace(/"/g, '&quot;');
    return (
      <div
        dangerouslySetInnerHTML={{
          __html: `<iframe srcdoc="${safeHtml}" style="width:100%;height:100vh;border:none;" sandbox="allow-scripts allow-same-origin allow-forms" />`,
        }}
      />
    );
  }

  switch (config.themeId) {
    case 'bold':
      return <BoldTheme config={config} shop={shop} products={products} />;
    case 'traditional':
      return <TraditionalTheme config={config} shop={shop} products={products} />;
    default:
      return <ModernTheme config={config} shop={shop} products={products} />;
  }
}
