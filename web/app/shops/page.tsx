'use client';

import { useState, useEffect, Suspense } from 'react';
import { useSearchParams } from 'next/navigation';
import Link from 'next/link';
import { KERALA_DISTRICTS } from '@/lib/wk-constants';
import type { WkListing } from '@/app/api/listings/route';

const SHOP_TYPES = [
  'All', 'Grocery', 'Restaurant', 'Hotel', 'Pharmacy', 'Beauty',
  'Bakery', 'Electronics', 'Clothing', 'Supermarket', 'Stationery', 'Hardware',
];

function ShopCard({ shop }: { shop: WkListing }) {
  const phone = shop.phone?.replace(/\D/g, '');
  const waUrl = phone ? `https://wa.me/${phone}?text=${encodeURIComponent('Hi, I found your shop on wekerala!')}` : null;
  const callUrl = phone ? `tel:${phone}` : null;

  return (
    <div className="wk-shop-card"
      style={{
      background: '#fff',
      borderRadius: 16,
      overflow: 'hidden',
      boxShadow: '0 1px 4px rgba(0,0,0,0.10)',
      marginBottom: 14,
    }}>
      <Link href={shop.href ?? `/shop?shopId=${shop.id}`} style={{ textDecoration: 'none', display: 'block' }}>
        <div style={{ position: 'relative', width: '100%', paddingBottom: '62.5%', background: '#f0f0f0', overflow: 'hidden' }}>
          {shop.photoUrl ? (
            <img
              src={shop.photoUrl}
              alt={shop.name}
              style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover' }}
              loading="lazy"
            />
          ) : (
            <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', background: '#e8f0e8' }}>
              <span style={{ fontSize: 52 }}>🏪</span>
            </div>
          )}
          {shop.isOpen && (
            <span style={{
              position: 'absolute', top: 10, left: 10,
              background: '#22c55e', color: '#fff',
              borderRadius: 20, padding: '3px 10px',
              fontSize: 11, fontWeight: 700,
            }}>Open</span>
          )}
          {shop.rating && (
            <span style={{
              position: 'absolute', top: 10, right: 10,
              background: 'rgba(0,0,0,0.65)', color: '#fff',
              borderRadius: 20, padding: '3px 10px',
              fontSize: 12, fontWeight: 700,
            }}>⭐ {shop.rating.toFixed(1)}</span>
          )}
        </div>
      </Link>

      <div style={{ padding: '12px 14px 8px' }}>
        <Link href={shop.href ?? `/shop?shopId=${shop.id}`} style={{ textDecoration: 'none' }}>
          <h3 style={{ margin: 0, fontSize: 16, fontWeight: 700, color: '#111827', lineHeight: 1.3 }}>{shop.name}</h3>
        </Link>
        <p style={{ margin: '3px 0 0', fontSize: 13, color: '#6b7280' }}>
          {[shop.category, shop.district].filter(Boolean).join(' · ')}
        </p>
        {shop.description && (
          <p style={{ margin: '4px 0 0', fontSize: 12, color: '#9ca3af', lineHeight: 1.4 }}>{shop.description}</p>
        )}
      </div>

      <div style={{ display: 'flex', gap: 8, padding: '0 14px 14px' }}>
        {callUrl && (
          <a href={callUrl} style={{
            flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
            padding: '10px 0', borderRadius: 10, border: '1.5px solid #e5e7eb',
            textDecoration: 'none', color: '#374151', fontSize: 13, fontWeight: 600,
            background: '#f9fafb',
          }}>
            📞 Call
          </a>
        )}
        {waUrl && (
          <a href={waUrl} target="_blank" rel="noopener noreferrer" style={{
            flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
            padding: '10px 0', borderRadius: 10, border: 'none',
            textDecoration: 'none', color: '#fff', fontSize: 13, fontWeight: 600,
            background: '#22c55e',
          }}>
            💬 WhatsApp
          </a>
        )}
        {!callUrl && !waUrl && (
          <Link href={shop.href ?? `/shop?shopId=${shop.id}`} style={{
            flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center',
            padding: '10px 0', borderRadius: 10, border: 'none',
            textDecoration: 'none', color: '#fff', fontSize: 13, fontWeight: 600,
            background: '#283618',
          }}>
            View Shop →
          </Link>
        )}
      </div>
    </div>
  );
}

function SkeletonCard() {
  return (
    <div style={{ background: '#fff', borderRadius: 16, overflow: 'hidden', boxShadow: '0 1px 4px rgba(0,0,0,0.08)', marginBottom: 14 }}>
      <div style={{ height: 180, background: '#f3f4f6' }} />
      <div style={{ padding: '12px 14px 14px' }}>
        <div style={{ height: 16, background: '#f3f4f6', borderRadius: 4, marginBottom: 8, width: '65%' }} />
        <div style={{ height: 12, background: '#f3f4f6', borderRadius: 4, width: '40%' }} />
      </div>
    </div>
  );
}

function ShopsPageInner() {
  const searchParams = useSearchParams();
  const initialSearch = searchParams.get('search') ?? '';
  const initialDistrict = searchParams.get('district') ?? '';

  const [shops, setShops] = useState<WkListing[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState(initialSearch);
  const [district, setDistrict] = useState(initialDistrict);
  const [activeType, setActiveType] = useState('All');
  const [showDistrict, setShowDistrict] = useState(false);

  useEffect(() => {
    setLoading(true);
    fetch('/api/listings?collection=shops')
      .then(r => r.json())
      .then(d => setShops(d.listings ?? []))
      .catch(() => {})
      .finally(() => setLoading(false));
  }, []);

  const filtered = shops.filter(s => {
    if (district && !s.district?.toLowerCase().includes(district.toLowerCase())) return false;
    if (activeType !== 'All' && !s.category?.toLowerCase().includes(activeType.toLowerCase())) return false;
    if (search && !s.name.toLowerCase().includes(search.toLowerCase()) && !s.category?.toLowerCase().includes(search.toLowerCase())) return false;
    return true;
  });

  return (
    <div style={{ width: '100%', minHeight: '100dvh', background: '#f8f9fa', display: 'flex', flexDirection: 'column' }}>

      {/* Header */}
      <header style={{ background: '#283618', padding: '14px 16px', position: 'sticky', top: 0, zIndex: 50, flexShrink: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 10 }}>
          <Link href="/" style={{ color: '#fefae0', textDecoration: 'none', fontSize: 20, lineHeight: 1 }}>←</Link>
          <span style={{ fontFamily: 'Caveat, cursive', fontSize: 22, color: '#fefae0' }}>Browse Shops</span>
        </div>

        {/* Search bar */}
        <div style={{ display: 'flex', gap: 8 }}>
          <div style={{ flex: 1, background: '#fff', borderRadius: 10, display: 'flex', alignItems: 'center', padding: '0 12px' }}>
            <span style={{ fontSize: 14, marginRight: 8 }}>🔍</span>
            <input
              value={search}
              onChange={e => setSearch(e.target.value)}
              placeholder="Search shops…"
              style={{ flex: 1, border: 'none', outline: 'none', fontSize: 14, color: '#111827', padding: '10px 0', background: 'transparent' }}
            />
            {search && (
              <button onClick={() => setSearch('')} style={{ border: 'none', background: 'transparent', color: '#9ca3af', cursor: 'pointer', fontSize: 16, padding: '0 4px' }}>✕</button>
            )}
          </div>
          {/* District filter button */}
          <div style={{ position: 'relative' }}>
            <button
              onClick={() => setShowDistrict(v => !v)}
              style={{ background: 'rgba(254,250,224,0.15)', border: '1px solid rgba(254,250,224,0.3)', borderRadius: 10, padding: '0 12px', height: '100%', color: '#fefae0', fontSize: 12, cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 4, whiteSpace: 'nowrap' }}
            >
              📍 {district || 'All'} ▾
            </button>
            {showDistrict && (
              <div style={{ position: 'absolute', top: '100%', right: 0, background: '#fff', borderRadius: 12, boxShadow: '0 4px 20px rgba(0,0,0,0.15)', zIndex: 100, width: 200, padding: 8, maxHeight: 260, overflowY: 'auto', marginTop: 4 }}>
                <button
                  onClick={() => { setDistrict(''); setShowDistrict(false); }}
                  style={{ display: 'block', width: '100%', textAlign: 'left', padding: '8px 12px', border: 'none', background: district === '' ? '#f0fdf4' : 'transparent', borderRadius: 8, fontSize: 13, color: district === '' ? '#166534' : '#374151', cursor: 'pointer', fontWeight: district === '' ? 700 : 400 }}
                >
                  All districts
                </button>
                {KERALA_DISTRICTS.map(d => (
                  <button
                    key={d}
                    onClick={() => { setDistrict(d); setShowDistrict(false); }}
                    style={{ display: 'block', width: '100%', textAlign: 'left', padding: '8px 12px', border: 'none', background: district === d ? '#f0fdf4' : 'transparent', borderRadius: 8, fontSize: 13, color: district === d ? '#166534' : '#374151', cursor: 'pointer', fontWeight: district === d ? 700 : 400 }}
                  >
                    {d}
                  </button>
                ))}
              </div>
            )}
          </div>
        </div>
      </header>

      {/* Shop type filter chips */}
      <div style={{ background: '#fff', borderBottom: '1px solid #f3f4f6', padding: '10px 0', flexShrink: 0, overflowX: 'auto' }}>
        <div style={{ display: 'flex', gap: 8, padding: '0 14px', width: 'max-content' }}>
          {SHOP_TYPES.map(t => (
            <button
              key={t}
              onClick={() => setActiveType(t)}
              style={{
                padding: '6px 14px', borderRadius: 20,
                border: activeType === t ? 'none' : '1px solid #e5e7eb',
                background: activeType === t ? '#283618' : '#f9fafb',
                color: activeType === t ? '#fefae0' : '#374151',
                fontSize: 13, fontWeight: 600, cursor: 'pointer', whiteSpace: 'nowrap',
              }}
            >
              {t}
            </button>
          ))}
        </div>
      </div>

      {/* Results count */}
      <div style={{ padding: '10px 16px 4px', flexShrink: 0 }}>
        <p style={{ margin: 0, fontSize: 13, color: '#6b7280' }}>
          {loading ? 'Loading…' : `${filtered.length} shop${filtered.length !== 1 ? 's' : ''}${district ? ` in ${district}` : ''}${activeType !== 'All' ? ` · ${activeType}` : ''}`}
        </p>
      </div>

      {/* Shop grid */}
      <div style={{ flex: 1, overflowY: 'auto', padding: '8px 0 80px', maxWidth: 1280, width: '100%', margin: '0 auto' }}>
        <div style={{ padding: '0 14px' }}>
          {loading ? (
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(260px, 1fr))', gap: 16, paddingTop: 8 }}>
              <SkeletonCard /><SkeletonCard /><SkeletonCard /><SkeletonCard />
            </div>
          ) : filtered.length === 0 ? (
            <div style={{ textAlign: 'center', padding: '60px 20px' }}>
              <div style={{ fontSize: 48, marginBottom: 12 }}>🔍</div>
              <p style={{ fontSize: 15, color: '#6b7280', margin: 0 }}>
                {shops.length === 0 ? 'No shops listed yet.' : 'No shops match your filters.'}
              </p>
              <button
                onClick={() => { setSearch(''); setDistrict(''); setActiveType('All'); }}
                style={{ marginTop: 12, padding: '8px 20px', background: '#283618', color: '#fefae0', border: 'none', borderRadius: 20, fontSize: 13, cursor: 'pointer' }}
              >
                Clear filters
              </button>
            </div>
          ) : (
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(260px, 1fr))', gap: 16, paddingTop: 8 }}>
              {filtered.map(shop => <ShopCard key={shop.id} shop={shop} />)}
            </div>
          )}
        </div>
      </div>

      {/* Bottom nav */}
      <div style={{
        position: 'fixed', bottom: 0, left: 0,
        width: '100%',
        background: '#fff', borderTop: '1px solid #f3f4f6',
        padding: '12px 24px',
        display: 'flex', justifyContent: 'space-around',
        zIndex: 40,
      }}>
        <Link href="/" style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2, textDecoration: 'none', color: '#9ca3af' }}>
          <span style={{ fontSize: 20 }}>🏠</span>
          <span style={{ fontSize: 10 }}>Home</span>
        </Link>
        <Link href="/download" style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2, textDecoration: 'none', color: '#9ca3af' }}>
          <span style={{ fontSize: 20 }}>📲</span>
          <span style={{ fontSize: 10 }}>Download</span>
        </Link>
      </div>
    </div>
  );
}

export default function ShopsPage() {
  return (
    <Suspense fallback={<div style={{ minHeight: '100dvh', background: '#283618' }} />}>
      <ShopsPageInner />
    </Suspense>
  );
}
