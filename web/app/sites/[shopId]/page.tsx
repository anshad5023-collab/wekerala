import { notFound } from 'next/navigation';
import Script from 'next/script';
import type { Metadata } from 'next';
import ThemeRenderer from '@/components/ThemeRenderer';
import { SaveShopButton } from '@/components/SaveShopButton';
import { type WebsiteConfig } from '@/lib/theme-engine';

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
  return Object.fromEntries(Object.entries(fields).map(([k, v]) => [k, parseFirestoreValue(v)]));
}

const _PROJECT_ID = (process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID ?? 'shoplink-prod').replace(/^﻿/, '');
const _API_KEY = process.env.NEXT_PUBLIC_FIREBASE_API_KEY ?? 'AIzaSyCFB9YZL3_bXjvRMoWaYFv8nTs_ote52GQ';
const _BASE = `https://firestore.googleapis.com/v1/projects/${_PROJECT_ID}/databases/(default)/documents`;

export async function generateMetadata({ params }: { params: Promise<{ shopId: string }> }): Promise<Metadata> {
  const { shopId: param } = await params;
  const res = await fetch(`${_BASE}/shops/${param}?key=${_API_KEY}`, { cache: 'no-store' });
  if (!res.ok) return { title: 'wekerala' };
  const json = await res.json() as Record<string, unknown>;
  const parsed = parseFields(json.fields as Record<string, unknown> ?? {});
  const website = parsed.website as Record<string, unknown> | null ?? null;
  const shopName = (parsed.shopName as string) || 'wekerala Shop';
  const seoTitle = (website?.seoTitle as string) || shopName;
  const seoDescription = (website?.seoDescription as string) || (website?.tagline as string) || (parsed.shopType as string) || 'Shop online';
  const logoUrl = (parsed.logoUrl as string) || '';
  const banners = website?.banners as string[] | undefined;
  const bannerUrl = (banners && banners[0]) || (parsed.bannerImageUrl as string) || logoUrl;
  const faviconUrl = (website?.faviconUrl as string) || logoUrl;

  return {
    title: seoTitle,
    description: seoDescription,
    icons: faviconUrl ? { icon: faviconUrl, apple: faviconUrl } : undefined,
    openGraph: {
      title: seoTitle,
      description: seoDescription,
      images: bannerUrl ? [{ url: bannerUrl, width: 1200, height: 630 }] : [],
      type: 'website',
    },
    twitter: { card: 'summary_large_image', title: seoTitle, description: seoDescription },
  };
}

export default async function SitePage({
  params,
  searchParams,
}: {
  params: Promise<{ shopId: string }>;
  searchParams: Promise<{ preview?: string }>;
}) {
  const { shopId: param } = await params;
  const { preview } = await searchParams;
  const isPreview = preview === 'true';

  const API_KEY = _API_KEY;
  const BASE = _BASE;

  let shopId = param;
  let shopJson: Record<string, unknown> = {};

  const directRes = await fetch(`${BASE}/shops/${param}?key=${API_KEY}`, { cache: 'no-store' });
  if (directRes.ok) shopJson = await directRes.json() as Record<string, unknown>;

  if (!shopJson.fields) {
    const queryRes = await fetch(`${BASE}:runQuery?key=${API_KEY}`, {
      method: 'POST', cache: 'no-store',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        structuredQuery: {
          from: [{ collectionId: 'shops' }],
          where: { fieldFilter: { field: { fieldPath: 'shopSlug' }, op: 'EQUAL', value: { stringValue: param } } },
          limit: 1,
        },
      }),
    });
    if (queryRes.ok) {
      const q = await queryRes.json() as Array<{ document?: { name: string; fields: Record<string, unknown> } }>;
      if (Array.isArray(q) && q[0]?.document) {
        shopId = q[0].document.name.split('/').pop() ?? param;
        shopJson = { fields: q[0].document.fields };
      }
    }
  }

  if (!shopJson.fields) {
    return (
      <div className="min-h-screen bg-[#1a1a1a] flex flex-col items-center justify-center p-4">
        <p className="text-4xl mb-4">🔍</p>
        <h1 className="text-2xl font-bold text-white mb-2">Shop not found</h1>
        <p className="text-gray-400 text-sm mb-1">ID: {param}</p>
        <p className="text-gray-500 text-xs">Check the link and try again.</p>
      </div>
    );
  }

  const parsed = parseFields(shopJson.fields as Record<string, unknown>);
  const website = parsed.website as Record<string, unknown> | null ?? null;

  if (!website || website.isPublished !== true) {
    if (!isPreview) {
      return (
        <div className="min-h-screen bg-[#283618] flex flex-col items-center justify-center p-4">
          <h1 className="text-4xl font-bold text-[#fefae0] text-center mb-4">{(parsed.shopName as string) || 'Shop'}</h1>
          <p className="text-xl text-[#fefae0]/80">Website coming soon</p>
        </div>
      );
    }
    if (!website) {
      return (
        <div className="min-h-screen bg-[#283618] flex flex-col items-center justify-center p-4">
          <h1 className="text-4xl font-bold text-[#fefae0] text-center mb-4">{(parsed.shopName as string) || 'Shop'}</h1>
          <p className="text-xl text-[#fefae0]/80 mb-2">Website not set up yet</p>
          <p className="text-sm text-[#fefae0]/50">Open the Website Builder in the app to create your site.</p>
        </div>
      );
    }
  }

  // custom HTML theme
  if (website.themeId === 'custom' && website.customHtml) {
    const safeHtml = (website.customHtml as string).replace(/"/g, '&quot;');
    return (
      <div dangerouslySetInnerHTML={{
        __html: `<iframe srcdoc="${safeHtml}" style="width:100%;height:100vh;border:none;" sandbox="allow-scripts allow-same-origin allow-forms" />`
      }} />
    );
  }

  const productsRes = await fetch(`${BASE}/shops/${shopId}/products?pageSize=50&key=${API_KEY}`, { cache: 'no-store' });
  const productsData = await productsRes.json();
  const products = ((productsData.documents || []) as Array<{ name: string; fields: Record<string, unknown> }>).map((doc) => {
    const p = parseFields(doc.fields || {});
    return {
      productId: doc.name.split('/').pop() ?? '',
      name: (p.nameEn as string) || (p.name as string) || '',
      price: (p.price as number) || 0,
      offerPrice: (p.offerPrice as number) || 0,
      unit: (p.unit as string) || '',
      imageUrl: (p.imageUrl as string) || '',
      category: (p.category as string) || '',
      isOutOfStock: (p.isOutOfStock as boolean) || false,
      isFeatured: (p.isFeatured as boolean) || false,
      isNew: (p.isNew as boolean) || false,
      description: (p.description as string) || '',
    };
  });

  const shop = {
    shopName: (parsed.shopName as string) || '',
    shopNameMl: (parsed.shopNameMl as string) || '',
    shopType: (parsed.shopType as string) || '',
    district: (parsed.district as string) || '',
    ownerPhone: (parsed.ownerPhone as string) || '',
    logoUrl: (parsed.logoUrl as string) || '',
    bannerImageUrl: (parsed.bannerImageUrl as string) || '',
  };

  const rawSocial = (website.socialLinks as Record<string, unknown>) || {};
  const rawCoupons = (website.couponCodes as Array<Record<string, unknown>>) || [];

  const config: WebsiteConfig = {
    themeId: (website.themeId as string) || 'modern',
    siteName: (website.siteName as string) || '',
    tagline: (website.tagline as string) || '',
    aboutText: (website.aboutText as string) || '',
    primaryColor: (website.primaryColor as string) || '#283618',
    secondaryColor: (website.secondaryColor as string) || '#dda15e',
    fontFamily: (website.fontFamily as string) || 'Poppins',
    sections: (website.sections as string[]) || ['hero', 'products', 'about', 'contact'],
    whatsappEnabled: (website.whatsappEnabled as boolean) ?? true,
    whatsappNumber: (website.whatsappNumber as string) || '',
    customHtml: (website.customHtml as string) || '',
    banners: (website.banners as string[]) || [],
    storeHoursText: (website.storeHoursText as string) || '',
    storeHoursEnabled: (website.storeHoursEnabled as boolean) || false,
    customAbout: (website.customAbout as string) || '',
    customContact: (website.customContact as string) || '',
    customPrivacy: (website.customPrivacy as string) || '',
    customShipping: (website.customShipping as string) || '',
    customReturn: (website.customReturn as string) || '',
    showAboutPage: (website.showAboutPage as boolean) || false,
    showContactPage: (website.showContactPage as boolean) || false,
    showPrivacyPage: (website.showPrivacyPage as boolean) || false,
    showShippingPage: (website.showShippingPage as boolean) || false,
    showReturnPage: (website.showReturnPage as boolean) || false,
    socialLinks: {
      instagram: (rawSocial.instagram as string) || '',
      facebook: (rawSocial.facebook as string) || '',
      youtube: (rawSocial.youtube as string) || '',
      twitter: (rawSocial.twitter as string) || '',
    },
    announcementBar: (website.announcementBar as string) || '',
    announcementBarEnabled: (website.announcementBarEnabled as boolean) || false,
    announcementBarColor: (website.announcementBarColor as string) || '',
    seoTitle: (website.seoTitle as string) || '',
    seoDescription: (website.seoDescription as string) || '',
    couponCodes: rawCoupons.map((c) => ({
      code: (c.code as string) || '',
      discountPercent: (c.discountPercent as number) || 0,
      active: (c.active as boolean) ?? true,
    })),
    primaryButtonText: (website.primaryButtonText as string) || 'Order Now',
    deliveryCharge: (website.deliveryCharge as number) || 0,
    freeDeliveryAbove: (website.freeDeliveryAbove as number) || 0,
    minOrderAmount: (website.minOrderAmount as number) || 0,
    logoUrl: (website.logoUrl as string) || (parsed.logoUrl as string) || '',
    faviconUrl: (website.faviconUrl as string) || '',
    googleAnalyticsId: (website.googleAnalyticsId as string) || '',
    facebookPixelId: (website.facebookPixelId as string) || '',
    tawkPropertyId: (website.tawkPropertyId as string) || '',
    reviewsEnabled: (website.reviewsEnabled as boolean) || false,
    isPublished: (website.isPublished as boolean) || false,
    publishedAt: (website.publishedAt as string) || '',
  };

  const gaId = config.googleAnalyticsId;
  const pixelId = config.facebookPixelId;
  const tawkId = config.tawkPropertyId;

  return (
    <>
      {/* Google Analytics */}
      {gaId && <Script src={`https://www.googletagmanager.com/gtag/js?id=${gaId}`} strategy="afterInteractive" />}
      {gaId && (
        <Script id="ga-init" strategy="afterInteractive"
          dangerouslySetInnerHTML={{ __html: `window.dataLayer=window.dataLayer||[];function gtag(){dataLayer.push(arguments)}gtag('js',new Date());gtag('config','${gaId}');` }}
        />
      )}
      {/* Facebook Pixel */}
      {pixelId && (
        <Script id="fb-pixel" strategy="afterInteractive"
          dangerouslySetInnerHTML={{ __html: `!function(f,b,e,v,n,t,s){if(f.fbq)return;n=f.fbq=function(){n.callMethod?n.callMethod.apply(n,arguments):n.queue.push(arguments)};if(!f._fbq)f._fbq=n;n.push=n;n.loaded=!0;n.version='2.0';n.queue=[];t=b.createElement(e);t.async=!0;t.src=v;s=b.getElementsByTagName(e)[0];s.parentNode.insertBefore(t,s)}(window,document,'script','https://connect.facebook.net/en_US/fbevents.js');fbq('init','${pixelId}');fbq('track','PageView');` }}
        />
      )}
      {/* Tawk.To live chat */}
      {tawkId && (
        <Script id="tawk" strategy="afterInteractive"
          dangerouslySetInnerHTML={{ __html: `var Tawk_API=Tawk_API||{},Tawk_LoadStart=new Date();(function(){var s1=document.createElement("script"),s0=document.getElementsByTagName("script")[0];s1.async=true;s1.src='https://embed.tawk.to/${tawkId}/default';s1.charset='UTF-8';s1.setAttribute('crossorigin','*');s0.parentNode.insertBefore(s1,s0)})();` }}
        />
      )}
      <ThemeRenderer config={config} shop={shop} products={products} shopId={shopId} />
      {!isPreview && <SaveShopButton shopId={shopId} shopName={shop.shopName} bannerImageUrl={shop.bannerImageUrl} />}
    </>
  );
}
