'use client';

import { useRef } from 'react';
import Image from 'next/image';
import { motion, useScroll, useTransform } from 'framer-motion';
import { Clock, ShoppingBag, Truck, CheckCircle, XCircle } from 'lucide-react';
import type { Language } from '@/lib/translations';

interface ShopBannerProps {
  bannerImageUrl?: string;
  promotionalBanner?: string;
  deliveryTimeEstimate?: string;
  minOrderAmount?: number;
  deliveryCharge?: number;
  isOpen: boolean;
  language: Language;
}

export function ShopBanner({
  bannerImageUrl,
  promotionalBanner,
  deliveryTimeEstimate,
  minOrderAmount,
  deliveryCharge,
  isOpen,
}: ShopBannerProps) {
  const bannerRef = useRef<HTMLDivElement>(null);
  const { scrollY } = useScroll();
  // Image drifts down at ~30% of scroll speed → parallax depth without leaving its frame.
  const y = useTransform(scrollY, [0, 300], [0, 45]);
  const scale = useTransform(scrollY, [0, 300], [1, 1.12]);

  return (
    <div>
      {/* Hero banner image — only rendered when a banner image exists */}
      {bannerImageUrl ? (
        <div ref={bannerRef} className="relative h-36 w-full overflow-hidden bg-gray-100">
          <motion.div style={{ y, scale }} className="absolute inset-0 -top-4 -bottom-4">
            <Image src={bannerImageUrl} alt="Shop banner" fill className="object-cover" priority />
          </motion.div>
          {/* subtle gradient for text legibility + depth */}
          <div className="absolute inset-0 bg-gradient-to-t from-black/25 to-transparent" />
          <div className="absolute right-3 top-3">
            {isOpen ? (
              <span className="flex items-center gap-1 rounded-full bg-green-500 px-2 py-0.5 text-xs font-bold text-white shadow">
                <CheckCircle className="h-3 w-3" /> Open
              </span>
            ) : (
              <span className="flex items-center gap-1 rounded-full bg-red-500 px-2 py-0.5 text-xs font-bold text-white shadow">
                <XCircle className="h-3 w-3" /> Closed
              </span>
            )}
          </div>
        </div>
      ) : (
        /* No banner — show a slim open/closed status row only */
        <div className="flex items-center justify-end px-4 py-2 bg-white border-b border-gray-100">
          {isOpen ? (
            <span className="flex items-center gap-1 rounded-full bg-green-100 px-2.5 py-1 text-xs font-bold text-green-700">
              <CheckCircle className="h-3 w-3" /> Open
            </span>
          ) : (
            <span className="flex items-center gap-1 rounded-full bg-red-100 px-2.5 py-1 text-xs font-bold text-red-600">
              <XCircle className="h-3 w-3" /> Closed
            </span>
          )}
        </div>
      )}

      {/* Promotional strip */}
      {promotionalBanner && (
        <div className="bg-amber-400 px-4 py-1.5 text-center text-sm font-semibold text-amber-900">
          🎉 {promotionalBanner}
        </div>
      )}

      {/* Delivery info bar — only rendered when at least one value exists */}
      {(deliveryTimeEstimate || (minOrderAmount != null && minOrderAmount > 0) || deliveryCharge != null) && (
        <div className="flex items-center gap-4 overflow-x-auto bg-gray-50 px-4 py-2 text-xs text-gray-600 scrollbar-hide">
          {deliveryTimeEstimate && (
            <span className="flex flex-shrink-0 items-center gap-1">
              <Clock className="h-3.5 w-3.5 text-primary" />
              {deliveryTimeEstimate}
            </span>
          )}
          {minOrderAmount != null && minOrderAmount > 0 && (
            <span className="flex flex-shrink-0 items-center gap-1">
              <ShoppingBag className="h-3.5 w-3.5 text-primary" />
              Min ₹{minOrderAmount}
            </span>
          )}
          {deliveryCharge != null && (
            <span className="flex flex-shrink-0 items-center gap-1">
              <Truck className="h-3.5 w-3.5 text-primary" />
              {deliveryCharge === 0 ? 'Free delivery' : `₹${deliveryCharge} delivery`}
            </span>
          )}
        </div>
      )}
    </div>
  );
}
