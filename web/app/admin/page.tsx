'use client';

import { useEffect, useState, useCallback } from 'react';
import Image from 'next/image';
import { DealsTab } from './DealsTab';
import { AnalyticsTab } from './AnalyticsTab';

/* ─── Types ─── */
interface ShopRow {
  shopId: string;
  collection: string;
  shopName: string;
  shopNameMl: string;
  logoUrl: string;
  shopType: string;
  shopArea: string;
  isOpen: boolean;
  isApproved: boolean;
  ownerPhone: string;
  subscriptionStatus: string;
  createdAt: string;
  websiteIsPublished: boolean;
  websitePublishedAt: string;
  websiteThemeId: string;
}

interface Stats { total: number; approved: number; pending: number; openNow: number; }

/* ─── Helpers ─── */
function Badge({ label, color }: { label: string; color: 'green' | 'amber' | 'red' | 'gray' }) {
  const map = {
    green: { bg: '#f0fdf4', text: '#166534', dot: '#22c55e' },
    amber: { bg: '#fffbeb', text: '#92400e', dot: '#f59e0b' },
    red:   { bg: '#fef2f2', text: '#991b1b', dot: '#ef4444' },
    gray:  { bg: '#f9fafb', text: '#374151', dot: '#9ca3af' },
  };
  const c = map[color];
  return (
    <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, padding: '2px 10px', borderRadius: 20, background: c.bg, color: c.text, fontSize: 11, fontWeight: 700 }}>
      <span style={{ width: 6, height: 6, borderRadius: '50%', background: c.dot, flexShrink: 0 }} />
      {label}
    </span>
  );
}

function StatCard({ icon, label, value, bg }: { icon: string; label: string; value: number; bg: string }) {
  return (
    <div style={{ background: '#fff', borderRadius: 14, padding: '16px', boxShadow: '0 1px 3px rgba(0,0,0,0.07)', border: '1px solid #f3f4f6', display: 'flex', alignItems: 'center', gap: 12 }}>
      <div style={{ width: 42, height: 42, borderRadius: 12, background: bg, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 20, flexShrink: 0 }}>{icon}</div>
      <div>
        <p style={{ margin: 0, fontSize: 22, fontWeight: 900, color: '#111827', lineHeight: 1 }}>{value}</p>
        <p style={{ margin: '2px 0 0', fontSize: 12, color: '#6b7280' }}>{label}</p>
      </div>
    </div>
  );
}

/* ─── Admin login gate ─── */
function LoginGate({ onLogin, error }: { onLogin: (pw: string) => void; error: string }) {
  const [pw, setPw] = useState('');
  const [show, setShow] = useState(false);
  return (
    <div style={{ minHeight: '100vh', background: '#f8f9fa', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 24 }}>
      <div style={{ width: '100%', maxWidth: 380, background: '#fff', borderRadius: 20, padding: 32, boxShadow: '0 4px 24px rgba(0,0,0,0.08)' }}>
        <div style={{ textAlign: 'center', marginBottom: 28 }}>
          <div style={{ width: 56, height: 56, borderRadius: 16, background: '#283618', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 16px', fontSize: 24 }}>🛡</div>
          <h1 style={{ margin: 0, fontSize: 22, fontWeight: 900, color: '#111827' }}>wekerala Admin</h1>
          <p style={{ margin: '6px 0 0', fontSize: 14, color: '#6b7280' }}>Founder access only</p>
        </div>
        <form onSubmit={e => { e.preventDefault(); onLogin(pw); }} style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          <div style={{ position: 'relative' }}>
            <input
              type={show ? 'text' : 'password'}
              value={pw}
              onChange={e => setPw(e.target.value)}
              placeholder="Admin password"
              style={{ width: '100%', padding: '12px 44px 12px 16px', borderRadius: 12, border: '1.5px solid #e5e7eb', fontSize: 14, outline: 'none', boxSizing: 'border-box', color: '#111827' }}
            />
            <button type="button" onClick={() => setShow(v => !v)} style={{ position: 'absolute', right: 12, top: '50%', transform: 'translateY(-50%)', background: 'none', border: 'none', cursor: 'pointer', fontSize: 16 }}>
              {show ? '🙈' : '👁'}
            </button>
          </div>
          {error && <p style={{ margin: 0, color: '#dc2626', fontSize: 13 }}>{error}</p>}
          <button type="submit" style={{ padding: '13px', background: '#283618', color: '#fefae0', border: 'none', borderRadius: 12, fontSize: 15, fontWeight: 700, cursor: 'pointer' }}>
            Sign In
          </button>
        </form>
        <p style={{ marginTop: 16, textAlign: 'center', fontSize: 12, color: '#9ca3af' }}>
          Set <code style={{ background: '#f3f4f6', padding: '1px 6px', borderRadius: 4 }}>ADMIN_PASSWORD</code> in Vercel env vars
        </p>
      </div>
    </div>
  );
}

/* ─── Shops tab ─── */
function ShopsTab({ shops, stats, loading, error, onRefresh, onApprove, onUnpublish, actionLoading }: {
  shops: ShopRow[];
  stats: Stats | null;
  loading: boolean;
  error: string;
  onRefresh: () => void;
  onApprove: (shopId: string, collection: string, approve: boolean) => void;
  onUnpublish: (shopId: string, reason: string) => void;
  actionLoading: string | null;
}) {
  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState<'all' | 'approved' | 'pending'>('all');
  const [unpublishTarget, setUnpublishTarget] = useState<string | null>(null);
  const [unpublishReason, setUnpublishReason] = useState('');

  const filtered = shops.filter(s => {
    if (search) {
      const q = search.toLowerCase();
      if (!s.shopName.toLowerCase().includes(q) && !s.ownerPhone.includes(q) && !s.shopArea.toLowerCase().includes(q) && !s.shopType.toLowerCase().includes(q)) return false;
    }
    if (filter === 'approved' && !s.isApproved) return false;
    if (filter === 'pending' && s.isApproved) return false;
    return true;
  });

  function exportCSV() {
    const rows = [
      ['Name', 'Type', 'Area', 'Phone', 'Status', 'Subscription', 'Website'],
      ...filtered.map(s => [s.shopName, s.shopType, s.shopArea, s.ownerPhone, s.isApproved ? 'Approved' : 'Pending', s.subscriptionStatus, s.websiteIsPublished ? 'Published' : 'No']),
    ];
    const csv = rows.map(r => r.map(c => `"${String(c ?? '').replace(/"/g, '""')}"`).join(',')).join('\n');
    const blob = new Blob([csv], { type: 'text/csv' });
    const a = document.createElement('a'); a.href = URL.createObjectURL(blob); a.download = 'wekerala-shops.csv'; a.click();
  }

  return (
    <div>
      {/* Stats */}
      {stats && (
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginBottom: 20 }}>
          <StatCard icon="🏪" label="Total Shops" value={stats.total} bg="#f0fdf4" />
          <StatCard icon="✅" label="Approved" value={stats.approved} bg="#eff6ff" />
          <StatCard icon="⏳" label="Pending" value={stats.pending} bg="#fffbeb" />
          <StatCard icon="🟢" label="Open Now" value={stats.openNow} bg="#faf5ff" />
        </div>
      )}

      {error && (
        <div style={{ background: '#fef2f2', border: '1px solid #fecaca', borderRadius: 12, padding: '12px 16px', marginBottom: 16, fontSize: 14, color: '#dc2626' }}>{error}</div>
      )}

      {/* Search + filter row */}
      <div style={{ display: 'flex', gap: 8, marginBottom: 12, flexWrap: 'wrap' }}>
        <div style={{ flex: 1, minWidth: 200, background: '#fff', borderRadius: 10, border: '1.5px solid #e5e7eb', display: 'flex', alignItems: 'center', padding: '0 12px' }}>
          <span style={{ marginRight: 8, color: '#9ca3af' }}>🔍</span>
          <input
            value={search} onChange={e => setSearch(e.target.value)}
            placeholder="Search by name, phone, area, type…"
            style={{ flex: 1, border: 'none', outline: 'none', fontSize: 13, padding: '10px 0', color: '#111827', background: 'transparent' }}
          />
        </div>
        <div style={{ display: 'flex', gap: 6 }}>
          {(['all', 'approved', 'pending'] as const).map(f => (
            <button key={f} onClick={() => setFilter(f)} style={{ padding: '8px 14px', borderRadius: 20, border: 'none', background: filter === f ? '#283618' : '#f3f4f6', color: filter === f ? '#fefae0' : '#374151', fontSize: 12, fontWeight: 600, cursor: 'pointer' }}>
              {f === 'all' ? 'All' : f === 'approved' ? '✓ Approved' : '⏳ Pending'}
            </button>
          ))}
        </div>
      </div>

      {/* Table header + export */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
        <p style={{ margin: 0, fontSize: 14, fontWeight: 700, color: '#111827' }}>
          All Shops <span style={{ fontWeight: 400, color: '#9ca3af', fontSize: 13 }}>{filtered.length}</span>
        </p>
        {filtered.length > 0 && (
          <button onClick={exportCSV} style={{ padding: '6px 14px', background: '#f3f4f6', border: 'none', borderRadius: 10, fontSize: 12, color: '#374151', cursor: 'pointer', fontWeight: 600 }}>
            ↓ Export CSV
          </button>
        )}
      </div>

      {/* Shop list */}
      {loading ? (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {[1,2,3,4].map(i => <div key={i} style={{ height: 72, background: '#f9fafb', borderRadius: 14, border: '1px solid #f3f4f6' }} />)}
        </div>
      ) : filtered.length === 0 ? (
        <div style={{ textAlign: 'center', padding: '48px 20px' }}>
          <div style={{ fontSize: 40, marginBottom: 8 }}>🏪</div>
          <p style={{ color: '#9ca3af', fontSize: 14 }}>{shops.length === 0 ? 'No shops yet' : 'No shops match your search'}</p>
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {filtered.map(shop => (
            <div key={shop.shopId} style={{ background: '#fff', borderRadius: 14, border: '1px solid #f3f4f6', padding: '14px 16px', boxShadow: '0 1px 2px rgba(0,0,0,0.05)' }}>
              <div style={{ display: 'flex', alignItems: 'flex-start', gap: 12 }}>
                {/* Logo */}
                <div style={{ width: 44, height: 44, borderRadius: 12, background: '#f3f4f6', overflow: 'hidden', flexShrink: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 20 }}>
                  {shop.logoUrl ? (
                    <Image src={shop.logoUrl} alt={shop.shopName} width={44} height={44} style={{ objectFit: 'cover' }} />
                  ) : '🏪'}
                </div>
                {/* Info */}
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
                    <p style={{ margin: 0, fontWeight: 700, fontSize: 14, color: '#111827' }}>{shop.shopName}</p>
                    {shop.collection !== 'shops' && (
                      <span style={{ fontSize: 10, background: '#eff6ff', color: '#1d4ed8', padding: '1px 8px', borderRadius: 10, fontWeight: 600, textTransform: 'uppercase' }}>{shop.collection}</span>
                    )}
                  </div>
                  {shop.shopNameMl && <p style={{ margin: '1px 0 0', fontSize: 11, color: '#9ca3af' }}>{shop.shopNameMl}</p>}
                  <p style={{ margin: '3px 0 0', fontSize: 12, color: '#6b7280' }}>
                    {[shop.shopType, shop.shopArea].filter(Boolean).join(' · ')}
                  </p>
                  <div style={{ display: 'flex', gap: 6, marginTop: 6, flexWrap: 'wrap' }}>
                    <Badge label={shop.isOpen ? 'Open' : 'Closed'} color={shop.isOpen ? 'green' : 'gray'} />
                    <Badge label={shop.isApproved ? 'Approved' : 'Pending'} color={shop.isApproved ? 'green' : 'amber'} />
                    {shop.websiteIsPublished && <Badge label="Website Live" color="green" />}
                  </div>
                </div>
              </div>

              {/* Actions */}
              <div style={{ display: 'flex', gap: 8, marginTop: 12, flexWrap: 'wrap' }}>
                {!shop.isApproved ? (
                  <button
                    onClick={() => onApprove(shop.shopId, shop.collection, true)}
                    disabled={actionLoading === shop.shopId}
                    style={{ flex: 1, padding: '8px', background: '#f0fdf4', border: 'none', borderRadius: 10, color: '#166534', fontSize: 12, fontWeight: 700, cursor: 'pointer', opacity: actionLoading === shop.shopId ? 0.5 : 1 }}
                  >
                    {actionLoading === shop.shopId ? '…' : '✓ Approve'}
                  </button>
                ) : (
                  <button
                    onClick={() => onApprove(shop.shopId, shop.collection, false)}
                    disabled={actionLoading === shop.shopId}
                    style={{ flex: 1, padding: '8px', background: '#fef2f2', border: 'none', borderRadius: 10, color: '#dc2626', fontSize: 12, fontWeight: 700, cursor: 'pointer', opacity: actionLoading === shop.shopId ? 0.5 : 1 }}
                  >
                    {actionLoading === shop.shopId ? '…' : '✕ Block'}
                  </button>
                )}
                {shop.ownerPhone && (
                  <a
                    href={`https://wa.me/${shop.ownerPhone.replace(/\D/g, '')}?text=${encodeURIComponent('Hi, this is the wekerala admin team.')}`}
                    target="_blank" rel="noopener noreferrer"
                    style={{ flex: 1, padding: '8px', background: '#f0fdf4', border: 'none', borderRadius: 10, color: '#166534', fontSize: 12, fontWeight: 700, cursor: 'pointer', textDecoration: 'none', textAlign: 'center' }}
                  >
                    💬 WhatsApp
                  </a>
                )}
                <a
                  href={shop.collection === 'shops' ? `/shop?shopId=${shop.shopId}` : `/${shop.shopId}`}
                  target="_blank" rel="noopener noreferrer"
                  style={{ flex: 1, padding: '8px', background: '#f9fafb', border: 'none', borderRadius: 10, color: '#374151', fontSize: 12, fontWeight: 700, cursor: 'pointer', textDecoration: 'none', textAlign: 'center' }}
                >
                  View →
                </a>
                {shop.websiteIsPublished && (
                  unpublishTarget === shop.shopId ? (
                    <div style={{ width: '100%', display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                      <input
                        placeholder="Reason (optional)"
                        value={unpublishReason} onChange={e => setUnpublishReason(e.target.value)}
                        style={{ flex: 1, padding: '7px 10px', border: '1.5px solid #fca5a5', borderRadius: 8, fontSize: 12, outline: 'none', minWidth: 140 }}
                      />
                      <button
                        onClick={() => { onUnpublish(shop.shopId, unpublishReason); setUnpublishTarget(null); setUnpublishReason(''); }}
                        disabled={actionLoading === shop.shopId}
                        style={{ padding: '7px 14px', background: '#dc2626', border: 'none', borderRadius: 8, color: '#fff', fontSize: 12, fontWeight: 700, cursor: 'pointer' }}
                      >
                        Confirm
                      </button>
                      <button onClick={() => setUnpublishTarget(null)} style={{ padding: '7px 10px', background: '#f3f4f6', border: 'none', borderRadius: 8, fontSize: 12, cursor: 'pointer' }}>
                        Cancel
                      </button>
                    </div>
                  ) : (
                    <button
                      onClick={() => setUnpublishTarget(shop.shopId)}
                      style={{ flex: 1, padding: '8px', background: '#fef2f2', border: 'none', borderRadius: 10, color: '#dc2626', fontSize: 12, fontWeight: 700, cursor: 'pointer' }}
                    >
                      🌐 Unpublish
                    </button>
                  )
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

/* ─── Main admin page ─── */
type Tab = 'shops' | 'deals' | 'analytics';

export default function AdminPage() {
  const [password, setPassword] = useState('');
  const [authed, setAuthed] = useState(false);
  const [authError, setAuthError] = useState('');
  const [savedPw, setSavedPw] = useState('');
  const [activeTab, setActiveTab] = useState<Tab>('shops');

  const [shops, setShops] = useState<ShopRow[]>([]);
  const [stats, setStats] = useState<Stats | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [actionLoading, setActionLoading] = useState<string | null>(null);
  const [toast, setToast] = useState<{ msg: string; ok: boolean } | null>(null);

  useEffect(() => {
    const pw = sessionStorage.getItem('admin_pw');
    if (pw) { setSavedPw(pw); setAuthed(true); }
  }, []);

  const showToast = (msg: string, ok: boolean) => {
    setToast({ msg, ok });
    setTimeout(() => setToast(null), 3500);
  };

  const fetchShops = useCallback(async (pw: string) => {
    setLoading(true); setError('');
    try {
      const res = await fetch('/api/admin/shops', { headers: { 'x-admin-password': pw } });
      if (res.status === 401) { setAuthed(false); sessionStorage.removeItem('admin_pw'); setAuthError('Session expired.'); return; }
      if (!res.ok) throw new Error();
      const data = await res.json();
      setShops(data.shops ?? []);
      setStats(data.stats ?? null);
    } catch {
      setError('Could not load shops. Check connection.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { if (authed && savedPw) fetchShops(savedPw); }, [authed, savedPw, fetchShops]);

  function handleLogin(pw: string) {
    sessionStorage.setItem('admin_pw', pw); setSavedPw(pw); setAuthed(true); setAuthError('');
  }

  async function handleApprove(shopId: string, collection: string, approve: boolean) {
    setActionLoading(shopId);
    try {
      const res = await fetch('/api/admin/shops', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json', 'x-admin-password': savedPw },
        body: JSON.stringify({ shopId, collection, isApproved: approve }),
      });
      const data = await res.json();
      if (!res.ok) { showToast(data.error ?? 'Update failed', false); return; }
      setShops(prev => prev.map(s => s.shopId === shopId ? { ...s, isApproved: approve } : s));
      setStats(prev => prev ? { ...prev, approved: prev.approved + (approve ? 1 : -1), pending: prev.pending + (approve ? -1 : 1) } : prev);
      showToast(approve ? 'Shop approved ✓' : 'Shop blocked ✗', approve);
    } catch { showToast('Network error', false); }
    finally { setActionLoading(null); }
  }

  async function handleUnpublish(shopId: string, reason: string) {
    setActionLoading(shopId);
    try {
      const res = await fetch('/api/admin/shops', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json', 'x-admin-password': savedPw },
        body: JSON.stringify({ shopId, action: 'unpublish_website', reason }),
      });
      if (!res.ok) throw new Error();
      setShops(prev => prev.map(s => s.shopId === shopId ? { ...s, websiteIsPublished: false } : s));
      showToast('Website unpublished', true);
    } catch { showToast('Failed to unpublish', false); }
    finally { setActionLoading(null); }
  }

  if (!authed) {
    return <LoginGate onLogin={handleLogin} error={authError} />;
  }

  const TABS: { id: Tab; label: string; icon: string }[] = [
    { id: 'shops',     label: 'Shops',     icon: '🏪' },
    { id: 'deals',     label: 'Deals',     icon: '🎁' },
    { id: 'analytics', label: 'Analytics', icon: '📊' },
  ];

  return (
    <div style={{ minHeight: '100vh', background: '#f8f9fa' }}>
      {/* Toast */}
      {toast && (
        <div style={{ position: 'fixed', top: 16, right: 16, zIndex: 1000, background: toast.ok ? '#166534' : '#dc2626', color: '#fff', borderRadius: 12, padding: '12px 18px', fontSize: 13, fontWeight: 600, boxShadow: '0 4px 16px rgba(0,0,0,0.15)', display: 'flex', alignItems: 'center', gap: 8 }}>
          {toast.ok ? '✓' : '✕'} {toast.msg}
        </div>
      )}

      {/* Header */}
      <header style={{ background: '#283618', padding: '16px 20px', position: 'sticky', top: 0, zIndex: 50 }}>
        <div style={{ maxWidth: 900, margin: '0 auto', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <span style={{ fontSize: 20 }}>🏪</span>
            <div>
              <span style={{ fontFamily: 'Caveat, cursive', fontSize: 20, color: '#fefae0', fontWeight: 700 }}>wekerala</span>
              <span style={{ marginLeft: 8, background: 'rgba(254,250,224,0.15)', color: '#fefae0', fontSize: 10, padding: '2px 8px', borderRadius: 6, fontWeight: 700, textTransform: 'uppercase', letterSpacing: 0.5 }}>Admin</span>
            </div>
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            <button onClick={() => fetchShops(savedPw)} disabled={loading} style={{ background: 'rgba(254,250,224,0.1)', border: '1px solid rgba(254,250,224,0.2)', borderRadius: 10, padding: '6px 14px', color: '#fefae0', fontSize: 12, cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 6 }}>
              🔄 {loading ? 'Loading…' : 'Refresh'}
            </button>
            <button onClick={() => { sessionStorage.removeItem('admin_pw'); setAuthed(false); setSavedPw(''); setShops([]); }} style={{ background: 'transparent', border: '1px solid rgba(254,250,224,0.2)', borderRadius: 10, padding: '6px 14px', color: '#fefae0', fontSize: 12, cursor: 'pointer' }}>
              Logout
            </button>
          </div>
        </div>
      </header>

      {/* Tabs */}
      <div style={{ background: '#fff', borderBottom: '1px solid #f3f4f6' }}>
        <div style={{ maxWidth: 900, margin: '0 auto', display: 'flex' }}>
          {TABS.map(tab => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              style={{ display: 'flex', alignItems: 'center', gap: 6, padding: '14px 20px', border: 'none', background: 'none', borderBottom: activeTab === tab.id ? '2px solid #283618' : '2px solid transparent', color: activeTab === tab.id ? '#283618' : '#6b7280', fontSize: 14, fontWeight: activeTab === tab.id ? 700 : 500, cursor: 'pointer', transition: 'all 0.15s' }}
            >
              {tab.icon} {tab.label}
            </button>
          ))}
        </div>
      </div>

      {/* Content */}
      <main style={{ maxWidth: 900, margin: '0 auto', padding: '24px 20px' }}>
        {activeTab === 'shops' && (
          <ShopsTab
            shops={shops}
            stats={stats}
            loading={loading}
            error={error}
            onRefresh={() => fetchShops(savedPw)}
            onApprove={handleApprove}
            onUnpublish={handleUnpublish}
            actionLoading={actionLoading}
          />
        )}
        {activeTab === 'deals' && <DealsTab adminPw={savedPw} />}
        {activeTab === 'analytics' && <AnalyticsTab adminPw={savedPw} />}
      </main>
    </div>
  );
}
