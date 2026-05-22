'use client';

import { useState, useEffect, Suspense } from 'react';
import { useParams } from 'next/navigation';
import { ShopViewById, ShopSkeleton } from '@/components/shop/shop-view-by-id';

function SlugShopContent() {
  const params = useParams();
  const slug = params.slug as string;
  const [shopId, setShopId] = useState<string | null>(null);
  const [notFound, setNotFound] = useState(false);

  useEffect(() => {
    if (!slug) return;
    fetch(`/api/shop-by-slug?slug=${encodeURIComponent(slug)}`)
      .then((r) => {
        if (r.status === 404) { setNotFound(true); return null; }
        return r.json();
      })
      .then((data) => { if (data?.shopId) setShopId(data.shopId); })
      .catch(() => setNotFound(true));
  }, [slug]);

  if (notFound) return (
    <div style={{ padding: 40, textAlign: 'center', color: '#6b7280', fontSize: 15 }}>
      Shop not found.
    </div>
  );
  if (!shopId) return <ShopSkeleton />;
  return <ShopViewById shopId={shopId} />;
}

export default function ShopBySlugPage() {
  return (
    <Suspense fallback={<ShopSkeleton />}>
      <SlugShopContent />
    </Suspense>
  );
}
