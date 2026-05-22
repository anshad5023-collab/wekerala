'use client';

import { Suspense } from 'react';
import { useSearchParams } from 'next/navigation';
import { ShopViewById, ShopSkeleton } from '@/components/shop/shop-view-by-id';

function ShopContent() {
  const searchParams = useSearchParams();
  const shopId = searchParams.get('shopId');
  if (!shopId) return <div className="p-8 text-center">Missing shopId parameter</div>;
  return <ShopViewById shopId={shopId} />;
}

export default function ShopPage() {
  return (
    <Suspense fallback={<ShopSkeleton />}>
      <ShopContent />
    </Suspense>
  );
}
