'use client';

import Image from 'next/image';
import { Store, MapPin, ChevronRight } from 'lucide-react';
import type { ShopSummary } from '@/app/api/shops/route';

const SHOP_TYPE_EMOJI: Record<string, string> = {
  grocery: '🛒',
  supermarket: '🏪',
  vegetables: '🥦',
  fruits: '🍎',
  pharmacy: '💊',
  bakery: '🥐',
  meat: '🥩',
  dairy: '🥛',
  fish: '🐟',
  restaurant: '🍽️',
};

function shopTypeEmoji(type: string): string {
  return SHOP_TYPE_EMOJI[type?.toLowerCase()] ?? '🏬';
}

interface ShopCardProps {
  shop: ShopSummary;
}

export function ShopCard({ shop }: ShopCardProps) {
  const href = `/shop?shopId=${shop.shopId}`;
  const accent = shop.themeColor ?? '#22c55e';

  return (
    <a
      href={href}
      className="group flex flex-col rounded-2xl border border-gray-100 bg-white shadow-sm transition-all duration-200 hover:-translate-y-1 hover:shadow-lg overflow-hidden"
    >
      {/* Top accent bar */}
      <div className="h-1.5 w-full" style={{ backgroundColor: accent }} />

      <div className="flex flex-col gap-3 p-4">
        {/* Logo + open badge row */}
        <div className="flex items-start justify-between">
          <div
            className="flex h-14 w-14 items-center justify-center rounded-xl overflow-hidden border border-gray-100 bg-gray-50 text-2xl"
            style={{ borderColor: `${accent}30` }}
          >
            {shop.logoUrl ? (
              <Image
                src={shop.logoUrl}
                alt={shop.shopName}
                width={56}
                height={56}
                className="h-14 w-14 object-cover"
              />
            ) : (
              <span>{shopTypeEmoji(shop.shopType)}</span>
            )}
          </div>

          <span
            className={`mt-0.5 rounded-full px-2.5 py-0.5 text-xs font-semibold ${
              shop.isOpen
                ? 'bg-green-50 text-green-700'
                : 'bg-red-50 text-red-600'
            }`}
          >
            {shop.isOpen ? '● Open' : '○ Closed'}
          </span>
        </div>

        {/* Name */}
        <div>
          <h3 className="text-base font-bold text-gray-900 leading-tight group-hover:text-green-700 transition-colors line-clamp-1">
            {shop.shopName}
          </h3>
          {shop.shopNameMl && (
            <p className="mt-0.5 text-sm text-gray-500 line-clamp-1">
              {shop.shopNameMl}
            </p>
          )}
        </div>

        {/* Shop type + area */}
        <div className="flex flex-col gap-1">
          {shop.shopType && (
            <div className="flex items-center gap-1.5">
              <span className="text-base">{shopTypeEmoji(shop.shopType)}</span>
              <span className="text-sm font-medium capitalize text-gray-600">
                {shop.shopType}
              </span>
            </div>
          )}
          {shop.shopArea && (
            <div className="flex items-center gap-1.5 text-gray-500">
              <MapPin className="h-3.5 w-3.5 shrink-0" />
              <span className="text-xs line-clamp-1">{shop.shopArea}</span>
            </div>
          )}
        </div>

        {/* CTA */}
        <div
          className="mt-auto flex items-center justify-center gap-1.5 rounded-xl py-2.5 text-sm font-semibold text-white transition-opacity group-hover:opacity-90"
          style={{ backgroundColor: accent }}
        >
          <Store className="h-4 w-4" />
          Shop Now
          <ChevronRight className="h-3.5 w-3.5" />
        </div>
      </div>
    </a>
  );
}
