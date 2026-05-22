'use client';
import { useState, useEffect } from 'react';
import { WkTopBar } from './wk-topbar';
import { WkSearch } from './wk-search';
import { WkFilter, FilterConfig, FilterState } from './wk-filter';
import { WkCard } from './wk-card';
import { WkNav } from './wk-nav';
import type { WkListing } from '@/app/api/listings/route';

function buildCardInfo(item: WkListing, collection: string): { extraInfo?: string; tags: string[] } {
  switch (collection) {
    case 'services':
      return {
        extraInfo: item.priceRange || (item.availability ? item.availability : undefined),
        tags: item.serviceAreas ?? item.tags,
      };
    case 'theaters':
      return {
        extraInfo: [item.theaterType, item.ticketPriceRange].filter(Boolean).join(' · ') || undefined,
        tags: item.facilities ?? item.tags,
      };
    case 'hotels':
      return {
        extraInfo: [item.hotelCategory, item.pricePerNight ? `${item.pricePerNight}/night` : undefined].filter(Boolean).join(' · ') || undefined,
        tags: item.amenities ?? item.tags,
      };
    case 'restaurants':
      return {
        extraInfo: [item.isVeg, item.avgCostForTwo ? `avg ₹${item.avgCostForTwo}/2` : undefined].filter(Boolean).join(' · ') || undefined,
        tags: item.cuisineTypes ?? item.diningOptions ?? item.tags,
      };
    case 'beauty':
      return {
        extraInfo: [item.gender, item.priceRange, item.homeVisitAvailable ? 'Home visit ✓' : undefined].filter(Boolean).join(' · ') || undefined,
        tags: item.serviceList ?? item.tags,
      };
    default:
      return { tags: item.tags };
  }
}
import { WK } from '@/lib/wk-constants';

interface ListingPageProps {
  title: string;
  collection: string;
  searchLabel: string;
  filters: FilterConfig[];
  resultLabel: string;
}

function initState(filters: FilterConfig[]): FilterState {
  const s: FilterState = {};
  for (const f of filters) s[f.id] = f.isToggle ? false : [];
  return s;
}

function matches(listing: WkListing, selected: FilterState, filters: FilterConfig[], search: string): boolean {
  if (search) {
    const q = search.toLowerCase();
    if (!listing.name.toLowerCase().includes(q) && !listing.category.toLowerCase().includes(q)) return false;
  }
  for (const f of filters) {
    if (f.isToggle) {
      if (!selected[f.id]) continue;
      if (f.id === 'open' && !listing.isOpen) return false;
      if (f.id === 'verified' && !listing.isVerified) return false;
    } else {
      const arr = (selected[f.id] as string[]) ?? [];
      if (arr.length === 0) continue;
      if (f.id === 'district') {
        if (!arr.some((d) => listing.district?.toLowerCase().includes(d.toLowerCase()))) return false;
      } else if (f.id === 'rating') {
        const min = Math.min(...arr.map((r) => parseFloat(r)));
        if (!listing.rating || listing.rating < min) return false;
      } else {
        if (!arr.some((v) => listing.category?.toLowerCase().includes(v.toLowerCase()))) return false;
      }
    }
  }
  return true;
}

export function ListingPage({ title, collection, searchLabel, filters, resultLabel }: ListingPageProps) {
  const [search, setSearch] = useState('');
  const [selected, setSelected] = useState<FilterState>(() => initState(filters));
  const [listings, setListings] = useState<WkListing[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    setLoading(true);
    fetch(`/api/listings?collection=${collection}`)
      .then((r) => r.json())
      .then((data) => setListings(data.listings ?? []))
      .catch(console.error)
      .finally(() => setLoading(false));
  }, [collection]);

  const filtered = listings.filter((l) => matches(l, selected, filters, search));

  return (
    <div style={{
      width: '100%',
      maxWidth: 480,
      margin: '0 auto',
      minHeight: '100dvh',
      background: WK.paper,
      display: 'flex',
      flexDirection: 'column',
      position: 'relative',
    }}>
      <WkTopBar title={title} backHref="/" />

      <div style={{ padding: '12px 14px', flexShrink: 0 }}>
        <WkSearch value={search} onChange={setSearch} placeholder={searchLabel} />
      </div>

      <WkFilter filters={filters} selected={selected} onChange={setSelected} />

      <div style={{ padding: '6px 14px 8px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexShrink: 0 }}>
        <span style={{ fontFamily: WK.mono, fontSize: 10, color: WK.muted }}>
          {loading ? 'loading…' : `${filtered.length} ${resultLabel} · sorted by rating`}
        </span>
        <span style={{ fontFamily: WK.mono, fontSize: 10, color: WK.ink }}>sort ▾</span>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: '4px 14px 14px' }}>
        {loading ? (
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
            {[1, 2, 3, 4].map((i) => (
              <div key={i} style={{ background: WK.muted, borderRadius: 14, aspectRatio: '2/3', opacity: 0.25 }} />
            ))}
          </div>
        ) : filtered.length === 0 ? (
          <div style={{ textAlign: 'center', padding: '60px 20px' }}>
            <div style={{ fontSize: 40 }}>🔍</div>
            <p style={{ fontFamily: WK.mono, fontSize: 11, color: WK.muted, marginTop: 12 }}>
              {listings.length === 0 ? `No ${resultLabel} listed yet. Check back soon.` : `No ${resultLabel} match your filters.`}
            </p>
          </div>
        ) : (
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
            {filtered.map((item) => {
              const { extraInfo, tags } = buildCardInfo(item, collection);
              return (
                <WkCard
                  key={item.id}
                  id={item.id}
                  name={item.name}
                  category={item.category}
                  rating={item.rating}
                  reviews={item.reviews}
                  photoUrl={item.photoUrl}
                  tags={tags}
                  screens={item.screens}
                  href={item.href}
                  extraInfo={extraInfo}
                />
              );
            })}
          </div>
        )}
      </div>

      <WkNav active="search" />
    </div>
  );
}
