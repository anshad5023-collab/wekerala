'use client';

import { Suspense, useEffect, useState, useCallback } from 'react';
import { useSearchParams, useRouter } from 'next/navigation';
import Link from 'next/link';
import { useAuthStore } from '@/lib/auth-store';
import { LoginModal } from '@/components/wk/login-modal';
import { KERALA_DISTRICTS } from '@/lib/wk-constants';
import type { WkListing } from '@/app/api/listings/route';
import { TiltCard } from '@/components/ui/tilt-card';
import { FadeIn } from '@/components/ui/fade-in';

// Shop type categories for filtering
const SHOP_TYPES = [
  { label: 'All',         icon: '🏪', value: '' },
  { label: 'Grocery',     icon: '🛒', value: 'Grocery' },
  { label: 'Restaurant',  icon: '🍽', value: 'Restaurant' },
  { label: 'Hotel',       icon: '🏨', value: 'Hotel' },
  { label: 'Pharmacy',    icon: '💊', value: 'Pharmacy' },
  { label: 'Beauty',      icon: '💆', value: 'Beauty' },
  { label: 'Bakery',      icon: '🥐', value: 'Bakery' },
  { label: 'Electronics', icon: '📱', value: 'Electronics' },
  { label: 'Clothing',    icon: '👗', value: 'Clothing' },
  { label: 'Supermarket', icon: '🏬', value: 'Supermarket' },
  { label: 'Stationery',  icon: '📚', value: 'Stationery' },
  { label: 'Hardware',    icon: '🔧', value: 'Hardware' },
];

const DISTRICT_COORDS: Record<string, [number, number]> = {
  'Trivandrum': [8.5241, 76.9366], 'Kollam': [8.8932, 76.6141],
  'Pathanamthitta': [9.2648, 76.7870], 'Alappuzha': [9.4981, 76.3388],
  'Kottayam': [9.5916, 76.5222], 'Idukki': [9.8490, 77.0996],
  'Ernakulam': [9.9816, 76.2999], 'Kochi': [9.9312, 76.2673],
  'Thrissur': [10.5276, 76.2144], 'Palakkad': [10.7867, 76.6548],
  'Malappuram': [11.0510, 76.0711], 'Kozhikode': [11.2588, 75.7804],
  'Wayanad': [11.6854, 76.1320], 'Kannur': [11.8745, 75.3704],
  'Kasaragod': [12.4996, 74.9869],
};

function nearestDistrict(lat: number, lon: number): string {
  let nearest = 'Kochi';
  let minDist = Infinity;
  for (const [d, [dlat, dlon]] of Object.entries(DISTRICT_COORDS)) {
    const dist = Math.hypot(lat - dlat, lon - dlon);
    if (dist < minDist) { minDist = dist; nearest = d; }
  }
  return nearest;
}

function ShopCard({ shop }: { shop: WkListing }) {
  const shopHref = shop.href ?? `/shop?shopId=${shop.id}`;
  const phone = shop.phone?.replace(/\D/g, '');
  const waUrl = phone ? `https://wa.me/${phone}?text=${encodeURIComponent(`Hi, I found your shop on wekerala!`)}` : null;
  const callUrl = phone ? `tel:${phone}` : null;

  return (
    <TiltCard
      maxTilt={6}
      className="rounded-2xl"
      style={{
        background: '#fff',
        borderRadius: 16,
        overflow: 'hidden',
        boxShadow: '0 1px 4px rgba(0,0,0,0.10)',
        marginBottom: 14,
        cursor: 'pointer',
      } as React.CSSProperties}
    >
      {/* Banner image — whole top area clicks to storefront */}
      <Link href={shopHref} style={{ textDecoration: 'none', display: 'block' }}>
        <div style={{ position: 'relative', width: '100%', height: 180, background: '#f0f0f0', overflow: 'hidden' }}>
          {shop.photoUrl ? (
            <img
              src={shop.photoUrl}
              alt={shop.name}
              style={{ width: '100%', height: '100%', objectFit: 'cover' }}
              loading="lazy"
            />
          ) : (
            <div style={{ width: '100%', height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', background: '#e8f0e8' }}>
              <span style={{ fontSize: 48 }}>🏪</span>
            </div>
          )}
          <span style={{
            position: 'absolute', top: 10, left: 10,
            background: shop.isOpen ? '#22c55e' : '#ef4444',
            color: '#fff',
            borderRadius: 20, padding: '3px 10px',
            fontSize: 11, fontWeight: 700,
          }}>{shop.isOpen ? 'Open' : 'Closed'}</span>
          {shop.rating && (
            <span style={{
              position: 'absolute', top: 10, right: 10,
              background: 'rgba(0,0,0,0.65)', color: '#fff',
              borderRadius: 20, padding: '3px 10px',
              fontSize: 12, fontWeight: 700,
            }}>⭐ {shop.rating.toFixed(1)}</span>
          )}
        </div>

        {/* Info */}
        <div style={{ padding: '12px 14px 10px' }}>
          <h3 style={{ margin: 0, fontSize: 16, fontWeight: 700, color: '#111827', lineHeight: 1.3 }}>{shop.name}</h3>
          <p style={{ margin: '3px 0 0', fontSize: 13, color: '#6b7280' }}>
            {[shop.category, shop.district].filter(Boolean).join(' · ')}
          </p>
          {shop.description && (
            <p style={{ margin: '4px 0 0', fontSize: 12, color: '#9ca3af', lineHeight: 1.4 }}>{shop.description}</p>
          )}
        </div>
      </Link>

      {/* Action buttons */}
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
          <Link href={shopHref} style={{
            flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center',
            padding: '10px 0', borderRadius: 10, border: 'none',
            textDecoration: 'none', color: '#fff', fontSize: 13, fontWeight: 600,
            background: '#283618',
          }}>
            View Shop →
          </Link>
        )}
      </div>
    </TiltCard>
  );
}

function HomeRedirect() {
  const searchParams = useSearchParams();
  const router = useRouter();
  useEffect(() => {
    const shopId = searchParams.get('shopId');
    if (shopId) router.replace(`/shop?shopId=${shopId}`);
  }, [searchParams, router]);
  return null;
}

function HomePageContent() {
  const [search, setSearch] = useState('');
  const [district, setDistrict] = useState('');
  const [activeType, setActiveType] = useState('');
  const [shops, setShops] = useState<WkListing[]>([]);
  const [loading, setLoading] = useState(true);
  const [showLogin, setShowLogin] = useState(false);
  const [showDistrictPicker, setShowDistrictPicker] = useState(false);
  const { uid, phone, logout } = useAuthStore();
  const router = useRouter();

  const loadShops = useCallback(() => {
    setLoading(true);
    fetch('/api/listings?collection=shops')
      .then(r => r.json())
      .then(d => setShops(d.listings ?? []))
      .catch(() => {})
      .finally(() => setLoading(false));
  }, []);

  useEffect(() => { loadShops(); }, [loadShops]);

  const handleNearMe = () => {
    if (!navigator.geolocation) return;
    navigator.geolocation.getCurrentPosition(
      (pos) => setDistrict(nearestDistrict(pos.coords.latitude, pos.coords.longitude)),
      () => {}
    );
  };

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    if (search.trim()) router.push(`/shops?search=${encodeURIComponent(search.trim())}`);
  };

  const filtered = shops.filter(s => {
    if (district && !s.district?.toLowerCase().includes(district.toLowerCase())) return false;
    if (activeType && !s.category?.toLowerCase().includes(activeType.toLowerCase())) return false;
    if (search && !s.name.toLowerCase().includes(search.toLowerCase())) return false;
    return true;
  });

  return (
    <div style={{ width: '100%', minHeight: '100dvh', background: '#f8f9fa', display: 'flex', flexDirection: 'column' }}>

      {/* Header */}
      <header style={{ background: '#283618', padding: '14px 16px', position: 'sticky', top: 0, zIndex: 50, flexShrink: 0 }}>
        <div style={{ maxWidth: 1280, margin: '0 auto', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <span style={{ fontFamily: 'Caveat, cursive', fontSize: 24, color: '#fefae0', lineHeight: 1 }}>wekerala</span>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <button
              onClick={handleNearMe}
              style={{ background: 'rgba(254,250,224,0.15)', border: '1px solid rgba(254,250,224,0.3)', borderRadius: 20, padding: '5px 12px', color: '#fefae0', fontSize: 11, cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 4 }}
            >
              📍 {district || 'Near me'}
            </button>
            {uid ? (
              <button onClick={logout} style={{ background: 'transparent', border: '1px solid rgba(254,250,224,0.3)', borderRadius: 20, padding: '5px 12px', color: '#fefae0', fontSize: 11, cursor: 'pointer' }}>
                {phone?.replace('+91', '') ?? 'me'}
              </button>
            ) : (
              <button onClick={() => setShowLogin(true)} style={{ background: '#dda15e', border: 'none', borderRadius: 20, padding: '6px 14px', color: '#fff', fontSize: 12, fontWeight: 700, cursor: 'pointer' }}>
                Login
              </button>
            )}
          </div>
        </div>
      </header>

      {/* Hero search */}
      <div style={{ background: '#283618', padding: '0 16px 20px', flexShrink: 0, position: 'relative', overflow: 'hidden' }}>
        <div className="wk-orb" style={{ width: 220, height: 220, background: '#dda15e', top: -100, left: -60 }} />
        <div className="wk-orb" style={{ width: 180, height: 180, background: '#606c38', top: -40, right: -50, animationDelay: '3s' }} />
      <div style={{ maxWidth: 1280, margin: '0 auto', position: 'relative' }}>
        <p style={{ fontFamily: 'Caveat, cursive', fontSize: 20, color: '#fefae0', margin: '0 0 12px', opacity: 0.85 }}>
          Discover local shops near you
        </p>
        <form onSubmit={handleSearch} style={{ display: 'flex', gap: 8 }}>
          <div style={{ flex: 1, background: '#fff', borderRadius: 12, display: 'flex', alignItems: 'center', padding: '0 12px' }}>
            <span style={{ fontSize: 16, marginRight: 8 }}>🔍</span>
            <input
              value={search}
              onChange={e => setSearch(e.target.value)}
              placeholder="Search shops by name or type…"
              style={{ flex: 1, border: 'none', outline: 'none', fontSize: 14, color: '#111827', padding: '12px 0', background: 'transparent' }}
            />
          </div>
          <button type="submit" style={{ background: '#dda15e', border: 'none', borderRadius: 12, padding: '0 18px', color: '#fff', fontSize: 14, fontWeight: 700, cursor: 'pointer' }}>
            Go
          </button>
        </form>

        {/* District selector */}
        <div style={{ marginTop: 10, position: 'relative' }}>
          <button
            onClick={() => setShowDistrictPicker(v => !v)}
            style={{ background: 'rgba(254,250,224,0.1)', border: '1px solid rgba(254,250,224,0.2)', borderRadius: 10, padding: '8px 14px', color: '#fefae0', fontSize: 12, cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 6 }}
          >
            📍 {district || 'All districts'} ▾
          </button>
          {showDistrictPicker && (
            <div style={{ position: 'absolute', top: '100%', left: 0, background: '#fff', borderRadius: 12, boxShadow: '0 4px 20px rgba(0,0,0,0.15)', zIndex: 100, width: 220, padding: 8, maxHeight: 260, overflowY: 'auto', marginTop: 4 }}>
              <button
                onClick={() => { setDistrict(''); setShowDistrictPicker(false); }}
                style={{ display: 'block', width: '100%', textAlign: 'left', padding: '8px 12px', border: 'none', background: district === '' ? '#f0fdf4' : 'transparent', borderRadius: 8, fontSize: 13, color: district === '' ? '#166534' : '#374151', cursor: 'pointer', fontWeight: district === '' ? 700 : 400 }}
              >
                All districts
              </button>
              {KERALA_DISTRICTS.map(d => (
                <button
                  key={d}
                  onClick={() => { setDistrict(d); setShowDistrictPicker(false); }}
                  style={{ display: 'block', width: '100%', textAlign: 'left', padding: '8px 12px', border: 'none', background: district === d ? '#f0fdf4' : 'transparent', borderRadius: 8, fontSize: 13, color: district === d ? '#166534' : '#374151', cursor: 'pointer', fontWeight: district === d ? 700 : 400 }}
                >
                  {d}
                </button>
              ))}
            </div>
          )}
        </div>
        </div>{/* end max-width wrapper */}
      </div>

      {/* Category type chips */}
      <div style={{ background: '#fff', borderBottom: '1px solid #f3f4f6', padding: '12px 0', flexShrink: 0, overflowX: 'auto' }}>
        <div style={{ display: 'flex', gap: 8, padding: '0 16px', width: 'max-content' }}>
          {SHOP_TYPES.map(t => (
            <button
              key={t.value}
              onClick={() => setActiveType(t.value)}
              style={{
                display: 'flex', alignItems: 'center', gap: 6,
                padding: '7px 14px', borderRadius: 20,
                border: activeType === t.value ? 'none' : '1px solid #e5e7eb',
                background: activeType === t.value ? '#283618' : '#f9fafb',
                color: activeType === t.value ? '#fefae0' : '#374151',
                fontSize: 13, fontWeight: 600, cursor: 'pointer', whiteSpace: 'nowrap',
              }}
            >
              <span>{t.icon}</span> {t.label}
            </button>
          ))}
        </div>
      </div>

      {/* Results */}
      <div style={{ flex: 1, overflowY: 'auto', padding: '14px 14px 80px', maxWidth: 1280, width: '100%', margin: '0 auto', alignSelf: 'center', boxSizing: 'border-box' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 12 }}>
          <p style={{ margin: 0, fontSize: 13, color: '#6b7280' }}>
            {loading ? 'Loading shops…' : `${filtered.length} shop${filtered.length !== 1 ? 's' : ''}${district ? ` in ${district}` : ''}`}
          </p>
          <Link href="/shops" style={{ fontSize: 13, color: '#283618', fontWeight: 600, textDecoration: 'none' }}>
            View all →
          </Link>
        </div>

        {loading ? (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(260px, 1fr))', gap: 16 }}>
            {[1, 2, 3, 4, 5, 6].map(i => (
              <div key={i} style={{ background: '#fff', borderRadius: 16, overflow: 'hidden', boxShadow: '0 1px 4px rgba(0,0,0,0.08)' }}>
                <div style={{ height: 180, background: '#f3f4f6' }} />
                <div style={{ padding: '12px 14px 14px' }}>
                  <div style={{ height: 16, background: '#f3f4f6', borderRadius: 4, marginBottom: 8, width: '60%' }} />
                  <div style={{ height: 12, background: '#f3f4f6', borderRadius: 4, width: '40%' }} />
                </div>
              </div>
            ))}
          </div>
        ) : filtered.length === 0 ? (
          <div style={{ textAlign: 'center', padding: '60px 20px' }}>
            <div style={{ fontSize: 48, marginBottom: 12 }}>🔍</div>
            <p style={{ fontSize: 15, color: '#6b7280', margin: 0 }}>
              {shops.length === 0 ? 'No shops listed yet. Check back soon!' : 'No shops match your search.'}
            </p>
            {(search || district || activeType) && (
              <button
                onClick={() => { setSearch(''); setDistrict(''); setActiveType(''); }}
                style={{ marginTop: 12, padding: '8px 20px', background: '#283618', color: '#fefae0', border: 'none', borderRadius: 20, fontSize: 13, cursor: 'pointer' }}
              >
                Clear filters
              </button>
            )}
          </div>
        ) : (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(260px, 1fr))', gap: 16 }}>
            {filtered.map((shop, i) => (
              <FadeIn key={shop.id} delay={Math.min(i, 8) * 0.05}>
                <ShopCard shop={shop} />
              </FadeIn>
            ))}
          </div>
        )}
      </div>

      {/* Bottom bar */}
      <div style={{
        position: 'fixed', bottom: 0, left: 0,
        width: '100%',
        background: '#fff', borderTop: '1px solid #f3f4f6',
        padding: '12px 24px',
        display: 'flex', justifyContent: 'space-around',
        zIndex: 40,
      }}>
        <Link href="/" style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2, textDecoration: 'none', color: '#283618' }}>
          <span style={{ fontSize: 20 }}>🏠</span>
          <span style={{ fontSize: 10, fontWeight: 700 }}>Home</span>
        </Link>
        <Link href="/download" style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2, textDecoration: 'none', color: '#9ca3af' }}>
          <span style={{ fontSize: 20 }}>📲</span>
          <span style={{ fontSize: 10 }}>Download</span>
        </Link>
      </div>

      <LoginModal open={showLogin} onClose={() => setShowLogin(false)} />
    </div>
  );
}

export default function Home() {
  return (
    <Suspense fallback={<div style={{ minHeight: '100dvh', background: '#283618' }} />}>
      <HomeRedirect />
      <HomePageContent />
    </Suspense>
  );
}
