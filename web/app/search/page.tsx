'use client';
import { useState, useEffect, useCallback, Suspense } from 'react';
import { useSearchParams, useRouter } from 'next/navigation';
import { WK, KERALA_DISTRICTS } from '@/lib/wk-constants';
import { WkNav } from '@/components/wk/wk-nav';
import { BusinessCard } from '@/components/marketplace/BusinessCard';

interface SearchResult {
  id: string;
  collection: string;
  name: string;
  category?: string;
  district?: string;
  avgRating?: number;
  ratingCount?: number;
  isVerified?: boolean;
  isFeatured?: boolean;
  photoUrl?: string;
  serviceTypes?: string[];
  phone?: string;
  about?: string;
}

const MIN_RATING_OPTIONS = ['3.5', '4.0', '4.5'];

function SearchContent() {
  const searchParams = useSearchParams();
  const router = useRouter();

  const initialQ = searchParams.get('q') ?? '';
  const initialDistrict = searchParams.get('district') ?? '';
  const initialVerified = searchParams.get('verified') === 'true';
  const initialMinRating = searchParams.get('minRating') ?? '';
  const initialSector = searchParams.get('sector') ?? '';

  const [q, setQ] = useState(initialQ);
  const [district, setDistrict] = useState(initialDistrict);
  const [verified, setVerified] = useState(initialVerified);
  const [minRating, setMinRating] = useState(initialMinRating);
  const [results, setResults] = useState<SearchResult[]>([]);
  const [loading, setLoading] = useState(false);
  const [searched, setSearched] = useState(false);

  const doSearch = useCallback(async (query: string, dist: string, ver: boolean, rating: string, sector: string) => {
    setLoading(true);
    setSearched(true);
    const params = new URLSearchParams();
    if (query) params.set('q', query);
    if (dist) params.set('district', dist);
    if (ver) params.set('verified', 'true');
    if (rating) params.set('minRating', rating);
    if (sector) params.set('sector', sector);
    try {
      const res = await fetch(`/api/search?${params.toString()}`);
      const data = await res.json();
      setResults(data.results ?? []);
    } catch {
      setResults([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    if (initialQ || initialDistrict || initialVerified || initialMinRating || initialSector) {
      doSearch(initialQ, initialDistrict, initialVerified, initialMinRating, initialSector);
    }
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  function handleSearch(e: React.FormEvent) {
    e.preventDefault();
    const params = new URLSearchParams();
    if (q) params.set('q', q);
    if (district) params.set('district', district);
    if (verified) params.set('verified', 'true');
    if (minRating) params.set('minRating', minRating);
    if (initialSector) params.set('sector', initialSector);
    router.push(`/search?${params.toString()}`);
    doSearch(q, district, verified, minRating, initialSector);
  }

  return (
    <div style={{
      width: '100%',
      maxWidth: 480,
      margin: '0 auto',
      minHeight: '100dvh',
      background: WK.paper,
      display: 'flex',
      flexDirection: 'column',
    }}>
      {/* Header + search input */}
      <header style={{
        borderBottom: `1px solid rgba(254,250,224,0.15)`,
        padding: '12px 14px',
        flexShrink: 0,
        background: WK.paper,
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 10 }}>
          <button
            onClick={() => window.history.back()}
            style={{
              border: `1px solid ${WK.ink}`,
              background: 'transparent',
              borderRadius: 8,
              width: 32,
              height: 32,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              cursor: 'pointer',
              flexShrink: 0,
            }}
          >
            <span style={{ fontFamily: WK.mono, fontSize: 14, color: WK.ink }}>←</span>
          </button>
          <span style={{ fontFamily: WK.hand, fontSize: 22, color: WK.ink }}>Search</span>
        </div>

        <form onSubmit={handleSearch} style={{ display: 'flex', gap: 8 }}>
          <input
            type="text"
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="Search businesses, services…"
            style={{
              flex: 1,
              background: `rgba(254,250,224,0.1)`,
              border: `1px solid rgba(254,250,224,0.3)`,
              borderRadius: 10,
              padding: '10px 12px',
              fontFamily: WK.mono,
              fontSize: 12,
              color: WK.ink,
              outline: 'none',
            }}
          />
          <button
            type="submit"
            style={{
              background: WK.ink,
              color: WK.paper,
              border: 'none',
              borderRadius: 10,
              padding: '10px 16px',
              fontFamily: WK.mono,
              fontSize: 12,
              cursor: 'pointer',
              flexShrink: 0,
            }}
          >
            Go
          </button>
        </form>
      </header>

      {/* Filter chips row */}
      <div style={{
        display: 'flex',
        gap: 8,
        padding: '10px 14px',
        overflowX: 'auto',
        flexShrink: 0,
        scrollbarWidth: 'none',
      }}>
        {/* Verified toggle */}
        <button
          onClick={() => {
            const next = !verified;
            setVerified(next);
            doSearch(q, district, next, minRating, initialSector);
          }}
          style={{
            border: `1px solid ${verified ? WK.sticky : 'rgba(254,250,224,0.3)'}`,
            background: verified ? WK.sticky : 'transparent',
            color: verified ? WK.paper : WK.ink,
            borderRadius: 20,
            padding: '6px 14px',
            fontFamily: WK.mono,
            fontSize: 10,
            cursor: 'pointer',
            whiteSpace: 'nowrap',
            flexShrink: 0,
          }}
        >
          ✓ Verified
        </button>

        {/* Min rating options */}
        {MIN_RATING_OPTIONS.map((r) => (
          <button
            key={r}
            onClick={() => {
              const next = minRating === r ? '' : r;
              setMinRating(next);
              doSearch(q, district, verified, next, initialSector);
            }}
            style={{
              border: `1px solid ${minRating === r ? WK.sticky : 'rgba(254,250,224,0.3)'}`,
              background: minRating === r ? WK.sticky : 'transparent',
              color: minRating === r ? WK.paper : WK.ink,
              borderRadius: 20,
              padding: '6px 14px',
              fontFamily: WK.mono,
              fontSize: 10,
              cursor: 'pointer',
              whiteSpace: 'nowrap',
              flexShrink: 0,
            }}
          >
            ★ {r}+
          </button>
        ))}

        {/* District pills */}
        {KERALA_DISTRICTS.slice(0, 5).map((d) => (
          <button
            key={d}
            onClick={() => {
              const next = district === d ? '' : d;
              setDistrict(next);
              doSearch(q, next, verified, minRating, initialSector);
            }}
            style={{
              border: `1px solid ${district === d ? WK.ink : 'rgba(254,250,224,0.2)'}`,
              background: district === d ? 'rgba(254,250,224,0.12)' : 'transparent',
              color: district === d ? WK.ink : WK.muted,
              borderRadius: 20,
              padding: '6px 14px',
              fontFamily: WK.mono,
              fontSize: 10,
              cursor: 'pointer',
              whiteSpace: 'nowrap',
              flexShrink: 0,
            }}
          >
            {d}
          </button>
        ))}
      </div>

      {/* Results count */}
      {searched && !loading && (
        <div style={{ padding: '4px 14px 8px', flexShrink: 0 }}>
          <span style={{ fontFamily: WK.mono, fontSize: 10, color: WK.muted }}>
            {results.length} result{results.length !== 1 ? 's' : ''}
            {q ? ` for "${q}"` : ''}
          </span>
        </div>
      )}

      {/* Results list */}
      <div style={{ flex: 1, overflowY: 'auto', padding: '4px 14px 14px' }}>
        {loading ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {[1, 2, 3, 4].map((i) => (
              <div
                key={i}
                style={{
                  background: 'rgba(254,250,224,0.08)',
                  borderRadius: 16,
                  height: 80,
                  opacity: 0.4,
                }}
              />
            ))}
          </div>
        ) : !searched ? (
          <div style={{ textAlign: 'center', padding: '60px 20px' }}>
            <div style={{ fontSize: 40, marginBottom: 12 }}>🔍</div>
            <p style={{ fontFamily: WK.mono, fontSize: 11, color: WK.muted }}>
              Search for local businesses in Kerala
            </p>
          </div>
        ) : results.length === 0 ? (
          <div style={{ textAlign: 'center', padding: '60px 20px' }}>
            <div style={{ fontSize: 40, marginBottom: 12 }}>😕</div>
            <p style={{ fontFamily: WK.mono, fontSize: 12, color: WK.muted }}>
              No results found{q ? ` for "${q}"` : ''}
            </p>
            <p style={{ fontFamily: WK.mono, fontSize: 10, color: WK.muted, marginTop: 8, opacity: 0.7 }}>
              Try different keywords or remove filters
            </p>
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {results.map((item) => (
              <BusinessCard
                key={`${item.collection}-${item.id}`}
                id={item.id}
                collection={item.collection}
                name={item.name}
                category={item.category}
                district={item.district}
                avgRating={item.avgRating}
                ratingCount={item.ratingCount}
                isVerified={item.isVerified}
                isFeatured={item.isFeatured}
                photoUrl={item.photoUrl}
                serviceTypes={item.serviceTypes}
                phone={item.phone}
                about={item.about}
              />
            ))}
          </div>
        )}
      </div>

      <WkNav active="search" />
    </div>
  );
}

export default function SearchPage() {
  return (
    <Suspense fallback={
      <div style={{
        width: '100%',
        maxWidth: 480,
        margin: '0 auto',
        minHeight: '100dvh',
        background: WK.paper,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
      }}>
        <span style={{ fontFamily: WK.mono, fontSize: 12, color: WK.muted }}>loading…</span>
      </div>
    }>
      <SearchContent />
    </Suspense>
  );
}
