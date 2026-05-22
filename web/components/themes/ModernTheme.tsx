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

export default function ModernTheme({ config, shop, products }: ThemeProps) {
  const { primaryColor, sections } = config;

  return (
    <div className="bg-white text-gray-900 min-h-screen">
      {sections.includes('hero') && (
        <section>
          {shop.bannerImageUrl && (
            <div className="relative h-64 w-full">
              <Image src={shop.bannerImageUrl} alt="banner" fill className="object-cover" />
            </div>
          )}
          <div className="p-6 text-center">
            {shop.logoUrl && (
              <Image src={shop.logoUrl} alt="logo" width={80} height={80} className="mx-auto rounded-full" />
            )}
            <h1 className="text-3xl font-semibold mt-4">{config.siteName}</h1>
            <p className="text-gray-500">{config.tagline}</p>
          </div>
        </section>
      )}

      {sections.includes('products') && (
        <section className="p-6 grid grid-cols-2 md:grid-cols-3 gap-4">
          {products.map(p => (
            <Card key={p.productId} className="shadow-sm">
              {p.imageUrl && (
                <Image src={p.imageUrl} alt={p.name} width={300} height={200} className="object-cover" />
              )}
              <CardContent>
                <h3 className="font-medium">{p.name}</h3>
                <p style={{ color: primaryColor }}>₹{p.price}</p>
              </CardContent>
            </Card>
          ))}
        </section>
      )}

      {sections.includes('about') && (
        <section className="p-6 text-center">
          <p>{config.aboutText}</p>
          <p className="mt-2 text-sm text-gray-500">{shop.shopName} • {shop.district}</p>
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
          className="fixed bottom-4 right-4 bg-green-500 text-white p-4 rounded-full"
        >
          WA
        </a>
      )}
    </div>
  );
}
