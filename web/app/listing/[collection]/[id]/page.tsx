'use client';
import { useState, useEffect } from 'react';
import { useParams } from 'next/navigation';
import { WK } from '@/lib/wk-constants';
import { WkNav } from '@/components/wk/wk-nav';
import { useAuthStore } from '@/lib/auth-store';

const API_KEY = process.env.NEXT_PUBLIC_FIREBASE_API_KEY ?? 'AIzaSyCFB9YZL3_bXjvRMoWaYFv8nTs_ote52GQ';
const PROJECT_ID = (process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID ?? 'shoplink-prod').replace(/^﻿/, '');
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

type FVal =
  | { stringValue: string }
  | { integerValue: string }
  | { doubleValue: number }
  | { booleanValue: boolean }
  | { arrayValue: { values?: FVal[] } }
  | { nullValue: null };

function parseValue(v: FVal): unknown {
  if ('stringValue' in v) return v.stringValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return v.doubleValue;
  if ('booleanValue' in v) return v.booleanValue;
  if ('nullValue' in v) return null;
  if ('arrayValue' in v) return (v.arrayValue.values ?? []).map(parseValue);
  return null;
}

function parseFields(fields: Record<string, FVal>): Record<string, unknown> {
  return Object.fromEntries(Object.entries(fields).map(([k, v]) => [k, parseValue(v)]));
}

interface Business {
  name: string;
  category?: string;
  serviceType?: string;
  district?: string;
  address?: string;
  phone?: string;
  ownerWhatsApp?: string;
  about?: string;
  photoUrl?: string;
  bannerImageUrl?: string;
  avgRating?: number;
  ratingCount?: number;
  isVerified?: boolean;
  isFeatured?: boolean;
  serviceTypes?: string[];
  workingHours?: string;
  priceRange?: string;
}

export default function ListingProfilePage() {
  const params = useParams();
  const collection = params.collection as string;
  const id = params.id as string;

  const { uid } = useAuthStore();
  const [business, setBusiness] = useState<Business | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [userRating, setUserRating] = useState<number>(0);
  const [ratingSubmitting, setRatingSubmitting] = useState(false);
  const [bookmarkSaving, setBookmarkSaving] = useState(false);
  const [bookmarkDone, setBookmarkDone] = useState(false);

  useEffect(() => {
    if (!collection || !id) return;
    setLoading(true);
    fetch(`${BASE}/${collection}/${id}?key=${API_KEY}`)
      .then((r) => {
        if (!r.ok) throw new Error('Not found');
        return r.json();
      })
      .then((data) => {
        const fields = parseFields(data.fields ?? {}) as Record<string, unknown>;
        const serviceTypes = fields['serviceTypes'];
        setBusiness({
          name: (fields['name'] as string) ?? (fields['shopName'] as string) ?? (fields['businessName'] as string) ?? 'Unknown',
          category: (fields['category'] as string) ?? (fields['shopType'] as string) ?? undefined,
          serviceType: (fields['serviceType'] as string) ?? undefined,
          district: (fields['district'] as string) ?? (fields['shopArea'] as string) ?? undefined,
          address: (fields['address'] as string) ?? undefined,
          phone: (fields['phone'] as string) ?? (fields['ownerPhone'] as string) ?? undefined,
          ownerWhatsApp: (fields['ownerWhatsApp'] as string) ?? undefined,
          about: (fields['about'] as string) ?? (fields['description'] as string) ?? undefined,
          photoUrl: (fields['photoUrl'] as string) ?? (fields['logoUrl'] as string) ?? undefined,
          bannerImageUrl: (fields['bannerImageUrl'] as string) ?? undefined,
          avgRating: (fields['avgRating'] as number) ?? 0,
          ratingCount: (fields['ratingCount'] as number) ?? 0,
          isVerified: (fields['isVerified'] as boolean) ?? false,
          isFeatured: (fields['isFeatured'] as boolean) ?? false,
          serviceTypes: Array.isArray(serviceTypes) ? (serviceTypes as unknown[]).map(String) : [],
          workingHours: (fields['workingHours'] as string) ?? undefined,
          priceRange: (fields['priceRange'] as string) ?? undefined,
        });
      })
      .catch(() => setError('Could not load business details.'))
      .finally(() => setLoading(false));
  }, [collection, id]);

  async function handleSaveBookmark() {
    if (!uid) {
      window.location.href = '/auth';
      return;
    }
    setBookmarkSaving(true);
    try {
      await fetch('/api/bookmarks', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ uid, businessId: id, collection, name: business?.name }),
      });
      setBookmarkDone(true);
    } catch {
      // silently fail
    } finally {
      setBookmarkSaving(false);
    }
  }

  async function handleRating(stars: number) {
    if (!uid) {
      window.location.href = '/auth';
      return;
    }
    setRatingSubmitting(true);
    try {
      await fetch('/api/ratings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ businessId: id, collection, uid, stars }),
      });
      setUserRating(stars);
    } catch {
      // silently fail
    } finally {
      setRatingSubmitting(false);
    }
  }

  const heroImage = business?.bannerImageUrl || business?.photoUrl;
  const displayPhone = business?.phone || business?.ownerWhatsApp;
  const categoryLabel = business?.category || business?.serviceType;

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
        <span style={{ fontFamily: WK.hand, fontSize: 20, color: WK.ink, flex: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
          {loading ? 'Loading…' : (business?.name ?? 'Business')}
        </span>
      </header>

      {/* Main content */}
      <div style={{ flex: 1, overflowY: 'auto' }}>
        {loading ? (
          <div style={{ padding: 24, textAlign: 'center' }}>
            <div style={{ background: WK.muted, borderRadius: 14, height: 200, opacity: 0.2, marginBottom: 16 }} />
            <div style={{ background: WK.muted, borderRadius: 8, height: 24, width: '60%', margin: '0 auto 8px', opacity: 0.2 }} />
            <div style={{ background: WK.muted, borderRadius: 8, height: 16, width: '40%', margin: '0 auto', opacity: 0.15 }} />
          </div>
        ) : error ? (
          <div style={{ padding: 40, textAlign: 'center' }}>
            <div style={{ fontSize: 40, marginBottom: 12 }}>⚠️</div>
            <p style={{ fontFamily: WK.mono, fontSize: 12, color: WK.muted }}>{error}</p>
          </div>
        ) : business ? (
          <>
            {/* Hero image */}
            {heroImage ? (
              <div style={{ width: '100%', aspectRatio: '16/9', overflow: 'hidden', background: WK.muted }}>
                <img
                  src={heroImage}
                  alt={business.name}
                  style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                />
              </div>
            ) : (
              <div style={{
                width: '100%',
                aspectRatio: '16/9',
                background: `rgba(254,250,224,0.08)`,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
              }}>
                <span style={{ fontFamily: WK.mono, fontSize: 11, color: WK.muted }}>no photo</span>
              </div>
            )}

            {/* Content card */}
            <div style={{
              background: WK.tile,
              borderRadius: '20px 20px 0 0',
              marginTop: -16,
              padding: '20px 18px',
              position: 'relative',
            }}>
              {/* Name + badges */}
              <div style={{ marginBottom: 10 }}>
                <h1 style={{
                  fontFamily: WK.hand,
                  fontSize: 28,
                  color: WK.paper,
                  margin: 0,
                  lineHeight: 1.2,
                }}>
                  {business.name}
                </h1>
                <div style={{ display: 'flex', gap: 8, marginTop: 8, flexWrap: 'wrap' }}>
                  {business.isVerified && (
                    <span style={{
                      background: '#2d6a4f',
                      color: '#fff',
                      borderRadius: 20,
                      padding: '3px 10px',
                      fontFamily: WK.mono,
                      fontSize: 10,
                      letterSpacing: 0.3,
                    }}>
                      ✓ Verified
                    </span>
                  )}
                  {business.isFeatured && (
                    <span style={{
                      background: WK.sticky,
                      color: WK.paper,
                      borderRadius: 20,
                      padding: '3px 10px',
                      fontFamily: WK.mono,
                      fontSize: 10,
                      letterSpacing: 0.3,
                    }}>
                      ⭐ Featured
                    </span>
                  )}
                </div>
              </div>

              {/* Rating */}
              {(business.avgRating ?? 0) > 0 && (
                <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 10 }}>
                  <span style={{ fontFamily: WK.mono, fontSize: 12, color: '#d97706' }}>
                    ⭐ {business.avgRating!.toFixed(1)}
                  </span>
                  <span style={{ fontFamily: WK.mono, fontSize: 11, color: WK.muted }}>
                    · {business.ratingCount} rating{(business.ratingCount ?? 0) !== 1 ? 's' : ''}
                  </span>
                </div>
              )}

              {/* Category + district */}
              <div style={{ marginBottom: 10 }}>
                {categoryLabel && (
                  <span style={{
                    fontFamily: WK.mono,
                    fontSize: 11,
                    color: WK.paper,
                    opacity: 0.7,
                    display: 'block',
                  }}>
                    {categoryLabel}
                  </span>
                )}
                {(business.district || business.address) && (
                  <span style={{
                    fontFamily: WK.mono,
                    fontSize: 11,
                    color: WK.paper,
                    opacity: 0.6,
                    display: 'block',
                    marginTop: 2,
                  }}>
                    📍 {[business.district, business.address].filter(Boolean).join(', ')}
                  </span>
                )}
              </div>

              {/* Service type chips */}
              {(business.serviceTypes?.length ?? 0) > 0 && (
                <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginBottom: 12 }}>
                  {business.serviceTypes!.map((tag, i) => (
                    <span key={i} style={{
                      border: `1px solid ${WK.paper}`,
                      borderRadius: 20,
                      padding: '3px 10px',
                      fontFamily: WK.mono,
                      fontSize: 9,
                      color: WK.paper,
                      opacity: 0.8,
                    }}>
                      {tag}
                    </span>
                  ))}
                </div>
              )}

              {/* Working hours */}
              {business.workingHours && (
                <div style={{ marginBottom: 8 }}>
                  <span style={{ fontFamily: WK.mono, fontSize: 11, color: WK.paper, opacity: 0.75 }}>
                    🕐 {business.workingHours}
                  </span>
                </div>
              )}

              {/* Price range */}
              {business.priceRange && (
                <div style={{ marginBottom: 8 }}>
                  <span style={{ fontFamily: WK.mono, fontSize: 11, color: WK.paper, opacity: 0.75 }}>
                    ₹ {business.priceRange}
                  </span>
                </div>
              )}

              {/* About */}
              {business.about && (
                <div style={{
                  background: `rgba(40,54,24,0.06)`,
                  borderRadius: 12,
                  padding: '12px 14px',
                  marginBottom: 16,
                  marginTop: 8,
                }}>
                  <p style={{
                    fontFamily: WK.mono,
                    fontSize: 11,
                    color: WK.paper,
                    opacity: 0.8,
                    margin: 0,
                    lineHeight: 1.6,
                  }}>
                    {business.about}
                  </p>
                </div>
              )}

              {/* Action buttons */}
              <div style={{ display: 'flex', gap: 8, marginBottom: 20 }}>
                {displayPhone && (
                  <a
                    href={`tel:+91${displayPhone}`}
                    style={{
                      flex: 1,
                      background: WK.paper,
                      color: WK.ink,
                      borderRadius: 12,
                      padding: '12px 0',
                      textAlign: 'center',
                      fontFamily: WK.mono,
                      fontSize: 12,
                      textDecoration: 'none',
                      display: 'block',
                    }}
                  >
                    📞 Call
                  </a>
                )}
                {displayPhone && (
                  <a
                    href={`https://wa.me/91${displayPhone}?text=Hi%2C%20I%20found%20you%20on%20wekerala`}
                    target="_blank"
                    rel="noopener noreferrer"
                    style={{
                      flex: 1,
                      background: '#25D366',
                      color: '#fff',
                      borderRadius: 12,
                      padding: '12px 0',
                      textAlign: 'center',
                      fontFamily: WK.mono,
                      fontSize: 12,
                      textDecoration: 'none',
                      display: 'block',
                    }}
                  >
                    💬 WhatsApp
                  </a>
                )}
                <button
                  onClick={handleSaveBookmark}
                  disabled={bookmarkSaving || bookmarkDone}
                  style={{
                    flex: 1,
                    background: bookmarkDone ? '#2d6a4f' : WK.sticky,
                    color: bookmarkDone ? '#fff' : WK.paper,
                    border: 'none',
                    borderRadius: 12,
                    padding: '12px 0',
                    fontFamily: WK.mono,
                    fontSize: 12,
                    cursor: bookmarkDone ? 'default' : 'pointer',
                  }}
                >
                  {bookmarkDone ? '✓ Saved' : '🔖 Save'}
                </button>
              </div>

              {/* Rating section */}
              <div style={{
                borderTop: `1px solid rgba(40,54,24,0.12)`,
                paddingTop: 16,
              }}>
                <p style={{ fontFamily: WK.mono, fontSize: 11, color: WK.paper, opacity: 0.7, margin: '0 0 10px' }}>
                  Rate this business
                </p>
                {uid ? (
                  <div style={{ display: 'flex', gap: 8 }}>
                    {[1, 2, 3, 4, 5].map((star) => (
                      <button
                        key={star}
                        onClick={() => handleRating(star)}
                        disabled={ratingSubmitting}
                        style={{
                          flex: 1,
                          background: userRating >= star ? '#d97706' : 'rgba(40,54,24,0.08)',
                          border: `1px solid ${userRating >= star ? '#d97706' : 'rgba(40,54,24,0.15)'}`,
                          borderRadius: 10,
                          padding: '10px 0',
                          fontFamily: WK.mono,
                          fontSize: 16,
                          cursor: ratingSubmitting ? 'default' : 'pointer',
                          color: WK.paper,
                        }}
                      >
                        ★
                      </button>
                    ))}
                  </div>
                ) : (
                  <a
                    href="/auth"
                    style={{
                      display: 'block',
                      textAlign: 'center',
                      fontFamily: WK.mono,
                      fontSize: 11,
                      color: WK.paper,
                      opacity: 0.6,
                      textDecoration: 'underline',
                      padding: '8px 0',
                    }}
                  >
                    Sign in to rate this business
                  </a>
                )}
                {userRating > 0 && (
                  <p style={{ fontFamily: WK.mono, fontSize: 10, color: '#2d6a4f', marginTop: 8 }}>
                    You rated this {userRating} star{userRating !== 1 ? 's' : ''}. Thank you!
                  </p>
                )}
              </div>
            </div>
          </>
        ) : null}
      </div>

      <WkNav active="home" />
    </div>
  );
}
