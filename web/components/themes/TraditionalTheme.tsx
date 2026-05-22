'use client';

import Image from "next/image";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";

interface ThemeProps {
  config: {
    siteName: string;
    tagline: string;
    aboutText: string;
    primaryColor: string;
    sections: string[];
    whatsappEnabled: boolean;
    whatsappNumber: string;
    customHtml?: string;
  };
  shop: {
    shopName: string;
    shopNameMl: string;
    shopType: string;
    district: string;
    ownerPhone: string;
    logoUrl: string;
    bannerImageUrl: string;
  };
  products: Array<{
    productId: string;
    name: string;
    nameMl?: string;
    price: number;
    imageUrl?: string;
    category?: string;
  }>;
}

export default function TraditionalTheme({ config, shop, products }: ThemeProps) {
  const { primaryColor, sections } = config;

  return (
    <div className="min-h-screen bg-[#fef9f0] text-gray-800">
      {sections.includes('hero') && (
        <section className="text-center p-6 border-b-4" style={{ borderColor: primaryColor }}>
          {shop.bannerImageUrl && (
            <div className="relative h-48 w-full mb-4">
              <Image src={shop.bannerImageUrl} alt="banner" fill className="object-cover rounded" />
            </div>
          )}
          <h1 className="text-3xl font-bold">{config.siteName}</h1>
          <p>{config.tagline}</p>
        </section>
      )}

      {sections.includes('products') && (
        <section className="p-6 grid grid-cols-2 gap-4">
          {products.map(p => (
            <Card key={p.productId} className="border-2 rounded-xl" style={{ borderColor: primaryColor }}>
              {p.imageUrl && (
                <Image src={p.imageUrl} alt={p.name} width={300} height={200} className="rounded-t-xl" />
              )}
              <CardContent>
                <h3>{p.name}</h3>
                <p style={{ color: primaryColor }}>₹{p.price}</p>
              </CardContent>
            </Card>
          ))}
        </section>
      )}

      {sections.includes('about') && (
        <section className="p-6 text-center">
          <p>{config.aboutText}</p>
          <p className="mt-2">{shop.shopName} - {shop.district}</p>
        </section>
      )}

      {sections.includes('contact') && (
        <section className="p-6 text-center">
          <p>{shop.ownerPhone}</p>
          {config.whatsappEnabled && (
            <Button asChild style={{ backgroundColor: primaryColor }}>
              <a href={`https://wa.me/${config.whatsappNumber}`}>WhatsApp</a>
            </Button>
          )}
        </section>
      )}

      {config.whatsappEnabled && (
        <a
          href={`https://wa.me/${config.whatsappNumber}`}
          className="fixed bottom-4 right-4 bg-green-600 text-white p-4 rounded-full"
        >
          WA
        </a>
      )}
    </div>
  );
}
