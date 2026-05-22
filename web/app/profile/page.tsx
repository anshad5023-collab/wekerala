'use client';
import { useState, useEffect } from 'react';
import Link from 'next/link';
import { WK } from '@/lib/wk-constants';
import { WkNav } from '@/components/wk/wk-nav';
import { useAuthStore } from '@/lib/auth-store';

interface Bookmark { id: string; businessId: string; collection: string; name?: string; }
interface SavedAddress { id: string; label: string; address: string; isDefault: boolean; }

export default function ProfilePage() {
  const { uid, phone, logout } = useAuthStore();
  const [bookmarks, setBookmarks] = useState<Bookmark[]>([]);
  const [bookmarksLoading, setBookmarksLoading] = useState(false);
  const [addresses, setAddresses] = useState<SavedAddress[]>([]);
  const [addressesLoading, setAddressesLoading] = useState(false);

  useEffect(() => {
    if (!uid) return;
    setBookmarksLoading(true);
    fetch(`/api/bookmarks?uid=${uid}`)
      .then((r) => r.json())
      .then((data) => setBookmarks(data.bookmarks ?? []))
      .catch(() => setBookmarks([]))
      .finally(() => setBookmarksLoading(false));

    setAddressesLoading(true);
    fetch(`/api/customer/addresses?uid=${encodeURIComponent(uid)}`)
      .then((r) => r.json())
      .then((data) => setAddresses(data.addresses ?? []))
      .catch(() => setAddresses([]))
      .finally(() => setAddressesLoading(false));
  }, [uid]);

  async function deleteAddress(id: string) {
    if (!uid) return;
    await fetch(`/api/customer/addresses?uid=${encodeURIComponent(uid)}&id=${id}`, { method: 'DELETE' });
    setAddresses((prev) => prev.filter((a) => a.id !== id));
  }

  function handleLogout() {
    logout();
  }

  if (!uid) {
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
        <header style={{
          borderBottom: `1px solid rgba(254,250,224,0.15)`,
          padding: '12px 14px',
          display: 'flex',
          alignItems: 'center',
          gap: 10,
          flexShrink: 0,
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
            }}
          >
            <span style={{ fontFamily: WK.mono, fontSize: 14, color: WK.ink }}>←</span>
          </button>
          <span style={{ fontFamily: WK.hand, fontSize: 22, color: WK.ink }}>My Profile</span>
        </header>

        <div style={{
          flex: 1,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          padding: '40px 24px',
          textAlign: 'center',
        }}>
          <div style={{ fontSize: 56, marginBottom: 20 }}>👤</div>
          <h2 style={{ fontFamily: WK.hand, fontSize: 24, color: WK.ink, margin: '0 0 10px' }}>
            Not signed in
          </h2>
          <p style={{ fontFamily: WK.mono, fontSize: 11, color: WK.muted, margin: '0 0 28px', lineHeight: 1.6 }}>
            Sign in to see your saved bookmarks and ratings
          </p>
          <Link
            href="/auth"
            style={{
              display: 'inline-block',
              background: WK.ink,
              color: WK.paper,
              borderRadius: 14,
              padding: '13px 32px',
              fontFamily: WK.mono,
              fontSize: 13,
              textDecoration: 'none',
            }}
          >
            Sign in to wekerala
          </Link>
        </div>

        <WkNav active="home" />
      </div>
    );
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
        <span style={{ fontFamily: WK.hand, fontSize: 22, color: WK.ink, flex: 1 }}>My Profile</span>
      </header>

      {/* Content */}
      <div style={{ flex: 1, overflowY: 'auto', padding: '16px 14px 14px' }}>
        {/* User info card */}
        <div style={{
          background: WK.tile,
          borderRadius: 16,
          padding: '16px 18px',
          marginBottom: 20,
          display: 'flex',
          alignItems: 'center',
          gap: 14,
        }}>
          <div style={{
            width: 48,
            height: 48,
            background: WK.paper,
            borderRadius: 14,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            flexShrink: 0,
          }}>
            <span style={{ fontFamily: WK.hand, fontSize: 24, color: WK.ink }}>
              {(phone ?? uid ?? '?').charAt(0).toUpperCase()}
            </span>
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <p style={{
              fontFamily: WK.mono,
              fontSize: 12,
              color: WK.paper,
              margin: 0,
              overflow: 'hidden',
              textOverflow: 'ellipsis',
              whiteSpace: 'nowrap',
            }}>
              {phone || 'Signed in'}
            </p>
            <p style={{
              fontFamily: WK.mono,
              fontSize: 9,
              color: WK.paper,
              opacity: 0.5,
              margin: '3px 0 0',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
            }}>
              uid: {uid?.slice(0, 12)}…
            </p>
          </div>
          <button
            onClick={handleLogout}
            style={{
              border: `1px solid rgba(40,54,24,0.3)`,
              background: 'transparent',
              color: WK.paper,
              borderRadius: 10,
              padding: '6px 14px',
              fontFamily: WK.mono,
              fontSize: 10,
              cursor: 'pointer',
              flexShrink: 0,
              opacity: 0.8,
            }}
          >
            Logout
          </button>
        </div>

        {/* Bookmarks section */}
        <div style={{ marginBottom: 20 }}>
          <h2 style={{
            fontFamily: WK.hand,
            fontSize: 20,
            color: WK.ink,
            margin: '0 0 12px',
          }}>
            Saved Businesses
          </h2>

          {bookmarksLoading ? (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              {[1, 2, 3].map((i) => (
                <div
                  key={i}
                  style={{
                    background: 'rgba(254,250,224,0.08)',
                    borderRadius: 12,
                    height: 56,
                    opacity: 0.3,
                  }}
                />
              ))}
            </div>
          ) : bookmarks.length === 0 ? (
            <div style={{
              background: 'rgba(254,250,224,0.06)',
              borderRadius: 14,
              padding: '24px 18px',
              textAlign: 'center',
            }}>
              <div style={{ fontSize: 32, marginBottom: 10 }}>🔖</div>
              <p style={{ fontFamily: WK.mono, fontSize: 11, color: WK.muted, margin: 0 }}>
                No saved businesses yet
              </p>
              <p style={{ fontFamily: WK.mono, fontSize: 10, color: WK.muted, margin: '6px 0 0', opacity: 0.7 }}>
                Tap the Save button on any business to bookmark it
              </p>
            </div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              {bookmarks.map((bm) => (
                <Link
                  key={bm.id}
                  href={`/listing/${bm.collection}/${bm.businessId}`}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: 12,
                    background: WK.tile,
                    borderRadius: 12,
                    padding: '12px 16px',
                    textDecoration: 'none',
                  }}
                >
                  <div style={{
                    width: 36,
                    height: 36,
                    background: WK.paper,
                    borderRadius: 10,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    flexShrink: 0,
                  }}>
                    <span style={{ fontFamily: WK.mono, fontSize: 14, color: WK.ink }}>🔖</span>
                  </div>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <p style={{
                      fontFamily: WK.hand,
                      fontSize: 16,
                      color: WK.paper,
                      margin: 0,
                      overflow: 'hidden',
                      textOverflow: 'ellipsis',
                      whiteSpace: 'nowrap',
                    }}>
                      {bm.name || bm.businessId}
                    </p>
                    <p style={{
                      fontFamily: WK.mono,
                      fontSize: 9,
                      color: WK.paper,
                      opacity: 0.5,
                      margin: '2px 0 0',
                    }}>
                      {bm.collection}
                    </p>
                  </div>
                  <span style={{ fontFamily: WK.mono, fontSize: 12, color: WK.paper, opacity: 0.4 }}>→</span>
                </Link>
              ))}
            </div>
          )}
        </div>

        {/* My Orders quick link */}
        <Link
          href="/customer/orders"
          style={{
            display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            background: WK.tile, borderRadius: 14, padding: '14px 18px',
            textDecoration: 'none', marginBottom: 20,
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <span style={{ fontSize: 20 }}>🛍</span>
            <span style={{ fontFamily: WK.hand, fontSize: 18, color: WK.paper }}>My Orders</span>
          </div>
          <span style={{ fontFamily: WK.mono, fontSize: 12, color: WK.paper, opacity: 0.4 }}>→</span>
        </Link>

        {/* Saved Addresses */}
        <div style={{ marginBottom: 20 }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 12 }}>
            <h2 style={{ fontFamily: WK.hand, fontSize: 20, color: WK.ink, margin: 0 }}>
              Saved Addresses
            </h2>
            <Link
              href="/customer/addresses"
              style={{ fontFamily: WK.mono, fontSize: 10, color: WK.sticky, textDecoration: 'none', opacity: 0.9 }}
            >
              Manage →
            </Link>
          </div>
          {addressesLoading ? (
            <div style={{ background: 'rgba(254,250,224,0.06)', borderRadius: 12, height: 56, opacity: 0.3 }} />
          ) : addresses.length === 0 ? (
            <div style={{ background: 'rgba(254,250,224,0.06)', borderRadius: 14, padding: '20px 18px', textAlign: 'center' }}>
              <p style={{ fontFamily: WK.mono, fontSize: 11, color: WK.muted, margin: 0 }}>
                No saved addresses. After placing an order, tap &quot;Save this address&quot; on the confirmation screen.
              </p>
            </div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              {addresses.map((addr) => (
                <div key={addr.id} style={{
                  display: 'flex', alignItems: 'flex-start', gap: 12,
                  background: 'rgba(254,250,224,0.06)', borderRadius: 12, padding: '12px 14px',
                }}>
                  <span style={{ fontSize: 16, marginTop: 2 }}>📍</span>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <p style={{ fontFamily: WK.mono, fontSize: 10, color: WK.sticky, margin: '0 0 3px', textTransform: 'uppercase', letterSpacing: 0.4 }}>{addr.label}</p>
                    <p style={{ fontFamily: WK.mono, fontSize: 11, color: WK.ink, margin: 0, lineHeight: 1.5 }}>{addr.address}</p>
                  </div>
                  <button
                    onClick={() => deleteAddress(addr.id)}
                    style={{ border: 'none', background: 'transparent', cursor: 'pointer', color: '#f87171', fontFamily: WK.mono, fontSize: 10, flexShrink: 0 }}
                  >
                    ✕
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Ratings section */}
        <div style={{
          background: 'rgba(254,250,224,0.06)',
          borderRadius: 14,
          padding: '16px 18px',
          marginBottom: 20,
        }}>
          <h2 style={{
            fontFamily: WK.hand,
            fontSize: 20,
            color: WK.ink,
            margin: '0 0 8px',
          }}>
            My Ratings
          </h2>
          <p style={{
            fontFamily: WK.mono,
            fontSize: 11,
            color: WK.muted,
            margin: 0,
            lineHeight: 1.6,
          }}>
            Ratings you submit appear on individual business pages. Visit a business to see or update your rating.
          </p>
        </div>

        {/* Logout button (bottom) */}
        <button
          onClick={handleLogout}
          style={{
            width: '100%',
            background: 'transparent',
            border: `1px solid rgba(254,250,224,0.25)`,
            color: WK.muted,
            borderRadius: 12,
            padding: '12px 0',
            fontFamily: WK.mono,
            fontSize: 12,
            cursor: 'pointer',
          }}
        >
          Sign out of wekerala
        </button>
      </div>

      <WkNav active="home" />
    </div>
  );
}
