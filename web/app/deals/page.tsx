'use client';
import { useState, useEffect } from 'react';
import Link from 'next/link';
import { WK } from '@/lib/wk-constants';
import { WkNav } from '@/components/wk/wk-nav';

interface Deal {
  id: string;
  title: string;
  businessName?: string;
  category?: string;
  discount?: string;
  validUntil?: string;
  collection: string;
  businessId: string;
}

export default function DealsPage() {
  const [deals, setDeals] = useState<Deal[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetch('/api/deals')
      .then((r) => r.json())
      .then((data) => setDeals(data.deals ?? []))
      .catch(() => setDeals([]))
      .finally(() => setLoading(false));
  }, []);

  function formatDate(dateStr?: string) {
    if (!dateStr) return null;
    try {
      return new Date(dateStr).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' });
    } catch {
      return dateStr;
    }
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
      {/* Header */}
      <header style={{
        borderBottom: `1px solid rgba(254,250,224,0.15)`,
        padding: '12px 14px',
        display: 'flex',
        alignItems: 'center',
        gap: 10,
        flexShrink: 0,
        background: WK.paper,
      }}>
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
        <span style={{ fontFamily: WK.hand, fontSize: 24, color: WK.ink }}>Deals & Offers</span>
      </header>

      {/* Content */}
      <div style={{ flex: 1, overflowY: 'auto', padding: '12px 14px 14px' }}>
        {loading ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            {[1, 2, 3].map((i) => (
              <div
                key={i}
                style={{
                  background: 'rgba(254,250,224,0.08)',
                  borderRadius: 16,
                  height: 100,
                  opacity: 0.35,
                }}
              />
            ))}
          </div>
        ) : deals.length === 0 ? (
          <div style={{ textAlign: 'center', padding: '80px 20px' }}>
            <div style={{ fontSize: 48, marginBottom: 14 }}>🏷️</div>
            <p style={{ fontFamily: WK.hand, fontSize: 20, color: WK.ink, margin: '0 0 8px' }}>
              No active deals right now
            </p>
            <p style={{ fontFamily: WK.mono, fontSize: 11, color: WK.muted }}>
              Check back soon. Businesses add deals regularly!
            </p>
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            {deals.map((deal) => (
              <div
                key={deal.id}
                style={{
                  background: WK.tile,
                  borderRadius: 16,
                  padding: '14px 16px',
                  position: 'relative',
                  overflow: 'hidden',
                }}
              >
                {/* Discount badge */}
                {deal.discount && (
                  <div style={{
                    position: 'absolute',
                    top: 12,
                    right: 12,
                    background: WK.sticky,
                    color: WK.paper,
                    borderRadius: 20,
                    padding: '4px 10px',
                    fontFamily: WK.mono,
                    fontSize: 11,
                    fontWeight: 600,
                  }}>
                    {deal.discount}
                  </div>
                )}

                {/* Deal title */}
                <h3 style={{
                  fontFamily: WK.hand,
                  fontSize: 20,
                  color: WK.paper,
                  margin: '0 0 6px',
                  paddingRight: deal.discount ? 70 : 0,
                }}>
                  {deal.title}
                </h3>

                {/* Business name + category */}
                {(deal.businessName || deal.category) && (
                  <p style={{
                    fontFamily: WK.mono,
                    fontSize: 11,
                    color: WK.paper,
                    opacity: 0.65,
                    margin: '0 0 8px',
                  }}>
                    {[deal.businessName, deal.category].filter(Boolean).join(' · ')}
                  </p>
                )}

                {/* Valid until */}
                {deal.validUntil && (
                  <p style={{
                    fontFamily: WK.mono,
                    fontSize: 10,
                    color: WK.paper,
                    opacity: 0.5,
                    margin: '0 0 12px',
                  }}>
                    Valid until {formatDate(deal.validUntil)}
                  </p>
                )}

                {/* View business link */}
                <Link
                  href={`/listing/${deal.collection}/${deal.businessId}`}
                  style={{
                    display: 'inline-block',
                    background: WK.paper,
                    color: WK.ink,
                    borderRadius: 10,
                    padding: '8px 16px',
                    fontFamily: WK.mono,
                    fontSize: 11,
                    textDecoration: 'none',
                  }}
                >
                  View Business →
                </Link>
              </div>
            ))}
          </div>
        )}
      </div>

      <WkNav active="home" />
    </div>
  );
}
