'use client';

import { useState, useEffect, useCallback, Suspense } from 'react';
import Link from 'next/link';
import { useSearchParams } from 'next/navigation';
import { LoginModal } from '@/components/wk/login-modal';
import { AddProductSheet } from '@/components/wk/add-product-sheet';
import { useAuthStore } from '@/lib/auth-store';

/* ─── Types ─── */
interface Business {
  id: string;
  name: string;
  type: string;
  logoUrl?: string;
  photoUrl?: string;
  shopArea?: string;
  district?: string;
  description?: string;
  website?: Record<string, unknown>;
  [key: string]: unknown;
}

interface Order {
  id: string;
  status?: string;
  totalAmount?: number;
  total?: number;
  createdAt?: string;
  customerPhone?: string;
  customerName?: string;
  items?: Array<{ productName?: string; name?: string; qty: number; price: number; subtotal?: number }>;
}

interface Coupon { code: string; discountPercent: number; minOrder: number; active: boolean; }

/* ─── Constants ─── */
const TYPE_ICONS: Record<string, string> = {
  shops: '🛍', services: '🔧', theaters: '🎭',
  hotels: '🏨', restaurants: '🍽', beauty: '💆',
};
const COLLECTIONS = ['shops', 'services', 'theaters', 'hotels', 'restaurants', 'beauty'];

const STATUS_COLORS: Record<string, string> = {
  new: '#f59e0b', pending: '#f59e0b', confirmed: '#22c55e',
  preparing: '#22c55e', ready: '#f97316', out_for_delivery: '#3b82f6',
  delivered: '#6366f1', cancelled: '#ef4444',
};
const STATUS_NEXT: Record<string, { label: string; next: string } | undefined> = {
  new:              { label: 'Confirm Order',   next: 'confirmed' },
  confirmed:        { label: 'Start Preparing', next: 'preparing' },
  preparing:        { label: 'Mark Ready',      next: 'ready' },
  ready:            { label: 'Mark Delivered',  next: 'delivered' },
  out_for_delivery: { label: 'Mark Delivered',  next: 'delivered' },
};
const WA_STATUS: Record<string, string> = {
  confirmed: 'confirmed ✅', preparing: 'being prepared 🍳',
  ready: 'ready 📦', out_for_delivery: 'out for delivery 🚚', delivered: 'delivered ✅',
};

/* ─── Data loaders ─── */
async function loadAllBusinesses(uid: string): Promise<Business[]> {
  const results = await Promise.all(
    COLLECTIONS.map(async (col) => {
      try {
        const res = await fetch(`/api/my-listings?uid=${uid}&collection=${col}`);
        const data = await res.json();
        return (data.listings ?? []).map((l: Record<string, unknown>) => ({
          id: l.id as string,
          name: ((l.shopName as string) || (l.name as string) || 'Unnamed'),
          type: col,
          logoUrl: l.logoUrl as string | undefined,
          photoUrl: l.photoUrl as string | undefined,
          shopArea: l.shopArea as string | undefined,
          district: l.district as string | undefined,
          description: l.description as string | undefined,
          ...l,
        } as Business));
      } catch { return []; }
    })
  );
  return results.flat();
}

/* ─── Sub-components ─── */
function OrderCard({ order, shopId, shopName }: { order: Order; shopId: string; shopName: string }) {
  const [status, setStatus] = useState(order.status ?? 'new');
  const [updating, setUpdating] = useState(false);

  const updateStatus = useCallback(async (next: string) => {
    setUpdating(true);
    try {
      await fetch(`/api/orders?shopId=${shopId}&orderId=${order.id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status: next }),
      });
      setStatus(next);
      const phone = (order.customerPhone as string)?.replace(/\D/g, '');
      if (phone && WA_STATUS[next]) {
        const origin = typeof window !== 'undefined' ? window.location.origin : '';
        const trackUrl = `${origin}/shop?shopId=${shopId}&view=tracking&orderId=${order.id}`;
        const msg = encodeURIComponent(`Hi ${order.customerName || 'there'}! Your order from *${shopName}* is now *${WA_STATUS[next]}*.\n\nTrack: ${trackUrl}`);
        window.open(`https://wa.me/${phone}?text=${msg}`, '_blank');
      }
    } catch { /* fail silently */ }
    finally { setUpdating(false); }
  }, [order, shopId, shopName]);

  const advance = STATUS_NEXT[status];
  const items = order.items ?? [];
  const total = order.totalAmount ?? order.total;
  const isDone = status === 'delivered' || status === 'cancelled';

  return (
    <div style={{ background: '#fff', border: '1px solid #f3f4f6', borderRadius: 14, padding: 14, boxShadow: '0 1px 2px rgba(0,0,0,0.05)' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
        <span style={{ fontSize: 12, color: '#6b7280', fontFamily: 'monospace' }}>#{order.id.slice(-6).toUpperCase()}</span>
        <span style={{ fontSize: 11, color: STATUS_COLORS[status] ?? '#6b7280', fontWeight: 700, textTransform: 'uppercase', letterSpacing: 0.5 }}>{status.replace('_', ' ')}</span>
      </div>
      {order.customerName && (
        <p style={{ margin: '0 0 6px', fontSize: 13, color: '#dda15e', fontWeight: 600 }}>👤 {order.customerName}</p>
      )}
      {items.slice(0, 3).map((item, i) => (
        <p key={i} style={{ margin: '0 0 2px', fontSize: 13, color: '#374151' }}>
          {item.qty}× {item.productName ?? item.name} — ₹{item.subtotal ?? (item.qty * item.price)}
        </p>
      ))}
      {items.length > 3 && <p style={{ margin: '0 0 2px', fontSize: 12, color: '#9ca3af' }}>+{items.length - 3} more</p>}
      {total != null && <p style={{ margin: '8px 0 0', fontSize: 15, fontWeight: 700, color: '#111827' }}>Total: ₹{total}</p>}
      {!isDone && (
        <div style={{ display: 'flex', gap: 8, marginTop: 10 }}>
          {advance && (
            <button
              onClick={() => updateStatus(advance.next)} disabled={updating}
              style={{ flex: 1, padding: '9px 0', borderRadius: 10, border: 'none', background: '#283618', color: '#fefae0', fontSize: 12, fontWeight: 700, cursor: 'pointer', opacity: updating ? 0.6 : 1 }}
            >
              {updating ? '…' : advance.label}
            </button>
          )}
          <button
            onClick={() => updateStatus('cancelled')} disabled={updating}
            style={{ padding: '9px 14px', borderRadius: 10, border: '1.5px solid #fca5a5', background: 'transparent', color: '#dc2626', fontSize: 12, cursor: 'pointer' }}
          >
            Cancel
          </button>
        </div>
      )}
    </div>
  );
}

function CouponsSection({ shopId, uid }: { shopId: string; uid: string }) {
  const [open, setOpen] = useState(false);
  const [coupons, setCoupons] = useState<Coupon[]>([]);
  const [loading, setLoading] = useState(false);
  const [code, setCode] = useState('');
  const [discount, setDiscount] = useState('');
  const [minOrder, setMinOrder] = useState('');
  const [adding, setAdding] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    if (!open) return;
    setLoading(true);
    fetch(`/api/coupons?shopId=${shopId}&uid=${uid}`)
      .then(r => r.json()).then(d => setCoupons(d.coupons ?? []))
      .catch(() => {}).finally(() => setLoading(false));
  }, [open, shopId, uid]);

  async function addCoupon(e: React.FormEvent) {
    e.preventDefault();
    if (!code.trim() || !discount) return;
    setAdding(true); setError('');
    try {
      const res = await fetch(`/api/coupons?shopId=${shopId}&uid=${uid}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ code: code.trim(), discountPercent: Number(discount), minOrder: Number(minOrder) || 0 }),
      });
      const d = await res.json() as { ok?: boolean; coupons?: Coupon[]; error?: string };
      if (!res.ok) { setError(d.error ?? 'Failed'); return; }
      setCoupons(d.coupons ?? []); setCode(''); setDiscount(''); setMinOrder('');
    } catch { setError('Network error'); }
    finally { setAdding(false); }
  }

  async function deleteCoupon(c: string) {
    setCoupons(prev => prev.filter(x => x.code !== c));
    await fetch(`/api/coupons?shopId=${shopId}&uid=${uid}&code=${c}`, { method: 'DELETE' });
  }

  const inp: React.CSSProperties = { background: '#f9fafb', border: '1.5px solid #e5e7eb', borderRadius: 10, padding: '10px 12px', fontSize: 13, color: '#111827', outline: 'none', width: '100%', boxSizing: 'border-box' };

  return (
    <div style={{ border: '1px solid #f3f4f6', borderRadius: 14, overflow: 'hidden', marginTop: 8 }}>
      <button onClick={() => setOpen(v => !v)} style={{ width: '100%', padding: '14px 16px', background: '#f9fafb', border: 'none', cursor: 'pointer', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <span style={{ fontSize: 14, fontWeight: 600, color: '#374151' }}>🎟 Coupon Codes</span>
        <span style={{ fontSize: 14, color: '#9ca3af' }}>{open ? '▲' : '▼'}</span>
      </button>
      {open && (
        <div style={{ padding: 16, background: '#fff', display: 'flex', flexDirection: 'column', gap: 10 }}>
          {loading ? <p style={{ fontSize: 13, color: '#9ca3af', textAlign: 'center' }}>Loading…</p>
            : coupons.length === 0 ? <p style={{ fontSize: 13, color: '#9ca3af' }}>No coupons yet.</p>
            : coupons.map(c => (
              <div key={c.code} style={{ display: 'flex', alignItems: 'center', gap: 8, background: '#f9fafb', borderRadius: 10, padding: '8px 12px' }}>
                <span style={{ flex: 1, fontSize: 13, fontWeight: 700, color: '#dda15e', fontFamily: 'monospace' }}>{c.code}</span>
                <span style={{ fontSize: 12, color: '#374151' }}>{c.discountPercent}% off</span>
                {c.minOrder > 0 && <span style={{ fontSize: 11, color: '#9ca3af' }}>min ₹{c.minOrder}</span>}
                <button onClick={() => deleteCoupon(c.code)} style={{ border: 'none', background: 'transparent', color: '#ef4444', cursor: 'pointer', fontSize: 14 }}>✕</button>
              </div>
            ))
          }
          <form onSubmit={addCoupon} style={{ display: 'flex', flexDirection: 'column', gap: 8, borderTop: '1px solid #f3f4f6', paddingTop: 12 }}>
            <div style={{ display: 'flex', gap: 8 }}>
              <input value={code} onChange={e => setCode(e.target.value.toUpperCase().replace(/\s/g, ''))} placeholder="CODE" required style={{ ...inp, flex: 2, textTransform: 'uppercase' }} />
              <input value={discount} onChange={e => setDiscount(e.target.value)} placeholder="%" type="number" min="1" max="90" required style={{ ...inp, flex: 1 }} />
            </div>
            <input value={minOrder} onChange={e => setMinOrder(e.target.value)} placeholder="Min order ₹ (optional)" type="number" style={inp} />
            {error && <p style={{ fontSize: 12, color: '#dc2626', margin: 0 }}>{error}</p>}
            <button type="submit" disabled={adding || !code.trim() || !discount} style={{ padding: '10px', background: '#dda15e', border: 'none', borderRadius: 10, fontSize: 13, fontWeight: 700, color: '#fff', cursor: 'pointer', opacity: adding ? 0.6 : 1 }}>
              {adding ? 'Adding…' : 'Add Coupon'}
            </button>
          </form>
        </div>
      )}
    </div>
  );
}

function PostDealSection({ biz }: { biz: Business }) {
  const [open, setOpen] = useState(false);
  const [title, setTitle] = useState('');
  const [discount, setDiscount] = useState('');
  const [description, setDescription] = useState('');
  const [validUntil, setValidUntil] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [done, setDone] = useState(false);

  async function handlePost(e: React.FormEvent) {
    e.preventDefault();
    if (!title.trim()) return;
    setSubmitting(true);
    try {
      await fetch('/api/deals', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ businessId: biz.id, businessName: biz.name, collection: biz.type, title: title.trim(), discount: discount.trim(), description: description.trim(), validUntil: validUntil || undefined, ownerId: '' }),
      });
      setDone(true); setTitle(''); setDiscount(''); setDescription(''); setValidUntil('');
      setTimeout(() => { setDone(false); setOpen(false); }, 2500);
    } catch { /* fail silently */ }
    finally { setSubmitting(false); }
  }

  const inp: React.CSSProperties = { background: '#f9fafb', border: '1.5px solid #e5e7eb', borderRadius: 10, padding: '10px 12px', fontSize: 13, color: '#111827', outline: 'none', width: '100%', boxSizing: 'border-box' };

  return (
    <div style={{ border: '1px solid #f3f4f6', borderRadius: 14, overflow: 'hidden', marginTop: 8 }}>
      <button onClick={() => setOpen(v => !v)} style={{ width: '100%', padding: '14px 16px', background: '#fffbeb', border: 'none', cursor: 'pointer', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <span style={{ fontSize: 14, fontWeight: 600, color: '#92400e' }}>🎁 Post a Deal or Offer</span>
        <span style={{ fontSize: 14, color: '#9ca3af' }}>{open ? '▲' : '▼'}</span>
      </button>
      {open && (
        <form onSubmit={handlePost} style={{ padding: 16, background: '#fff', display: 'flex', flexDirection: 'column', gap: 10 }}>
          {done && <p style={{ fontSize: 13, color: '#22c55e', textAlign: 'center', fontWeight: 600 }}>✓ Deal submitted for review!</p>}
          <input placeholder="Deal title *" value={title} onChange={e => setTitle(e.target.value)} required style={inp} />
          <input placeholder="Discount (e.g. 20% off, Buy 1 Get 1)" value={discount} onChange={e => setDiscount(e.target.value)} style={inp} />
          <textarea placeholder="Description (optional)" value={description} onChange={e => setDescription(e.target.value)} rows={2} style={{ ...inp, resize: 'none' }} />
          <input type="date" value={validUntil} onChange={e => setValidUntil(e.target.value)} style={inp} />
          <button type="submit" disabled={submitting || !title.trim()} style={{ padding: '11px', background: '#dda15e', border: 'none', borderRadius: 10, fontSize: 13, fontWeight: 700, color: '#fff', cursor: 'pointer', opacity: submitting || !title.trim() ? 0.6 : 1 }}>
            {submitting ? 'Submitting…' : 'Submit for Review'}
          </button>
          <p style={{ fontSize: 11, color: '#9ca3af', textAlign: 'center', margin: 0 }}>Reviewed by the wekerala team before going live.</p>
        </form>
      )}
    </div>
  );
}

/* ─── Tabs ─── */
type OwnerTab = 'orders' | 'website' | 'settings';

function HomeTab({ biz, orders, ordersLoading }: { biz: Business | null; orders: Order[]; ordersLoading: boolean }) {
  if (!biz) return (
    <div style={{ textAlign: 'center', padding: '60px 24px' }}>
      <div style={{ fontSize: 48, marginBottom: 12 }}>📋</div>
      <p style={{ fontSize: 14, color: '#6b7280' }}>Select a business above to see activity.</p>
    </div>
  );

  if (biz.type === 'shops') {
    return (
      <div style={{ padding: 16 }}>
        <p style={{ fontSize: 11, fontWeight: 700, color: '#9ca3af', textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 12 }}>Recent Orders</p>
        {ordersLoading ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {[1,2,3].map(i => <div key={i} style={{ height: 72, background: '#f3f4f6', borderRadius: 14 }} />)}
          </div>
        ) : orders.length === 0 ? (
          <div style={{ textAlign: 'center', padding: '40px 20px' }}>
            <div style={{ fontSize: 36, marginBottom: 8 }}>📦</div>
            <p style={{ fontSize: 14, color: '#6b7280' }}>No orders yet. Share your storefront to start receiving orders.</p>
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {orders.map(order => <OrderCard key={order.id} order={order} shopId={biz.id} shopName={biz.name} />)}
          </div>
        )}
      </div>
    );
  }

  return (
    <div style={{ padding: 16 }}>
      <div style={{ background: '#fff', border: '1px solid #f3f4f6', borderRadius: 16, padding: 20, boxShadow: '0 1px 3px rgba(0,0,0,0.05)' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 12 }}>
          <span style={{ fontSize: 28 }}>{TYPE_ICONS[biz.type] ?? '🏢'}</span>
          <div>
            <p style={{ margin: 0, fontSize: 17, fontWeight: 700, color: '#111827' }}>{biz.name}</p>
            {(biz.shopArea || biz.district) && <p style={{ margin: '2px 0 0', fontSize: 12, color: '#6b7280' }}>📍 {biz.shopArea ?? biz.district}</p>}
          </div>
        </div>
        {biz.description && <p style={{ margin: '0 0 10px', fontSize: 13, color: '#6b7280', lineHeight: 1.6 }}>{biz.description}</p>}
        <p style={{ margin: 0, fontSize: 12, color: '#9ca3af' }}>Go to the <span style={{ color: '#dda15e', fontWeight: 600 }}>Web</span> tab to preview and share your listing.</p>
      </div>
      <PostDealSection biz={biz} />
    </div>
  );
}

function WebTab({ biz, uid, storefrontPath }: { biz: Business | null; uid: string | null; storefrontPath: string }) {
  const [copied, setCopied] = useState(false);

  if (!biz) return (
    <div style={{ textAlign: 'center', padding: '60px 24px' }}>
      <p style={{ fontSize: 14, color: '#6b7280' }}>Select a business to preview its web page.</p>
    </div>
  );

  const fullUrl = typeof window !== 'undefined' ? `${window.location.origin}${storefrontPath}` : storefrontPath;

  const copyLink = () => {
    navigator.clipboard.writeText(fullUrl).then(() => { setCopied(true); setTimeout(() => setCopied(false), 2000); });
  };
  const shareWhatsApp = () => window.open(`https://wa.me/?text=${encodeURIComponent(`Check out ${biz.name} on wekerala: ${fullUrl}`)}`, '_blank');

  return (
    <div style={{ padding: 16, display: 'flex', flexDirection: 'column', gap: 12 }}>
      {/* Action row */}
      <div style={{ display: 'flex', gap: 8 }}>
        {biz.type === 'shops' && (
          <Link
            href={`/control/website?shopId=${biz.id}&uid=${uid ?? ''}`}
            style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '11px 0', borderRadius: 12, background: '#283618', color: '#fefae0', fontSize: 13, fontWeight: 700, textDecoration: 'none' }}
          >
            🌐 Website Builder
          </Link>
        )}
        <button onClick={copyLink} style={{ flex: 1, padding: '11px 0', borderRadius: 12, border: '1.5px solid #e5e7eb', background: '#f9fafb', color: '#374151', fontSize: 13, fontWeight: 600, cursor: 'pointer' }}>
          {copied ? '✓ Copied' : '⎘ Copy Link'}
        </button>
        <button onClick={shareWhatsApp} style={{ flex: 1, padding: '11px 0', borderRadius: 12, border: 'none', background: '#22c55e', color: '#fff', fontSize: 13, fontWeight: 600, cursor: 'pointer' }}>
          📱 Share
        </button>
      </div>

      {/* URL card */}
      <div style={{ background: '#f9fafb', border: '1px solid #f3f4f6', borderRadius: 12, padding: '10px 14px' }}>
        {biz.type === 'shops' && (biz.website as Record<string,unknown> | null)?.isPublished && (
          <span style={{ fontSize: 10, color: '#22c55e', fontWeight: 700, textTransform: 'uppercase', letterSpacing: 0.5, display: 'block', marginBottom: 4 }}>● Website Live</span>
        )}
        <p style={{ margin: 0, fontSize: 12, color: '#6b7280', wordBreak: 'break-all', lineHeight: 1.5, fontFamily: 'monospace' }}>{fullUrl}</p>
        {biz.type === 'shops' && !(biz.website as Record<string,unknown> | null)?.isPublished && (
          <p style={{ margin: '4px 0 0', fontSize: 11, color: '#9ca3af' }}>Use Website Builder to publish your live site</p>
        )}
      </div>

      {biz.type === 'shops' && uid && <CouponsSection shopId={biz.id} uid={uid} />}

      {/* Live preview */}
      <div>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
          <p style={{ margin: 0, fontSize: 11, fontWeight: 700, color: '#9ca3af', textTransform: 'uppercase', letterSpacing: 0.5 }}>Live Preview</p>
          <Link href={storefrontPath} target="_blank" style={{ fontSize: 12, color: '#283618', fontWeight: 600, textDecoration: 'none' }}>Open full →</Link>
        </div>
        <div style={{ position: 'relative', width: '100%', height: 360, borderRadius: 16, overflow: 'hidden', border: '1px solid #e5e7eb' }}>
          <div style={{ position: 'absolute', top: 0, left: 0, width: '167%', height: '167%', transform: 'scale(0.6)', transformOrigin: 'top left', pointerEvents: 'none' }}>
            <iframe src={storefrontPath} style={{ width: '100%', height: '100%', border: 'none' }} title="Live preview" />
          </div>
        </div>
      </div>
    </div>
  );
}

function SettingsTab({ businesses, phone, onLogout, selectedBiz, uid }: { businesses: Business[]; phone: string | null; onLogout: () => void; selectedBiz: Business | null; uid: string | null }) {
  return (
    <div style={{ padding: 16, display: 'flex', flexDirection: 'column', gap: 20 }}>
      {/* My listings */}
      <div>
        <p style={{ margin: '0 0 10px', fontSize: 11, fontWeight: 700, color: '#9ca3af', textTransform: 'uppercase', letterSpacing: 0.5 }}>My Listings</p>
        {businesses.length === 0 ? (
          <p style={{ fontSize: 13, color: '#9ca3af' }}>No listings yet.</p>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {businesses.map(biz => (
              <div key={biz.id} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '12px 14px', borderRadius: 14, border: '1px solid #f3f4f6', background: '#fff', boxShadow: '0 1px 2px rgba(0,0,0,0.04)' }}>
                <span style={{ fontSize: 18 }}>{TYPE_ICONS[biz.type] ?? '🏢'}</span>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <p style={{ margin: 0, fontSize: 14, fontWeight: 600, color: '#111827' }}>{biz.name}</p>
                  <p style={{ margin: 0, fontSize: 10, color: '#9ca3af', textTransform: 'uppercase', letterSpacing: 0.3 }}>{biz.type}</p>
                </div>
                <Link href={biz.type === 'shops' ? `/shop?shopId=${biz.id}` : `/${biz.id}`} target="_blank" style={{ fontSize: 12, color: '#283618', fontWeight: 600, textDecoration: 'none', border: '1px solid #283618', padding: '4px 10px', borderRadius: 8 }}>
                  View
                </Link>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Quick actions */}
      <div>
        <p style={{ margin: '0 0 10px', fontSize: 11, fontWeight: 700, color: '#9ca3af', textTransform: 'uppercase', letterSpacing: 0.5 }}>Quick Actions</p>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {[
            { label: '+ Add a listing', icon: '🏪', href: '/register', accent: false },
            { label: 'Website Builder', icon: '🌐', href: selectedBiz?.type === 'shops' ? `/control/website?shopId=${selectedBiz.id}&uid=${uid ?? ''}` : '/control/website', accent: false },
            { label: 'Analytics', icon: '📊', href: selectedBiz ? `/control/analytics?shopId=${selectedBiz.id}&uid=${uid ?? ''}` : '#', accent: false },
            { label: 'Subscription Plans', icon: '⭐', href: '/subscription', accent: true },
          ].map(item => (
            <Link key={item.href} href={item.href} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '14px 16px', borderRadius: 14, border: item.accent ? '1.5px solid #dda15e' : '1px solid #f3f4f6', background: item.accent ? '#fffbeb' : '#fff', textDecoration: 'none', boxShadow: '0 1px 2px rgba(0,0,0,0.04)' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                <span style={{ fontSize: 18 }}>{item.icon}</span>
                <span style={{ fontSize: 13, fontWeight: 600, color: item.accent ? '#92400e' : '#374151' }}>{item.label}</span>
              </div>
              <span style={{ fontSize: 14, color: item.accent ? '#dda15e' : '#9ca3af' }}>→</span>
            </Link>
          ))}
        </div>
      </div>

      {/* Account */}
      <div>
        <p style={{ margin: '0 0 10px', fontSize: 11, fontWeight: 700, color: '#9ca3af', textTransform: 'uppercase', letterSpacing: 0.5 }}>Account</p>
        <div style={{ background: '#fff', border: '1px solid #f3f4f6', borderRadius: 14, padding: '14px 16px', marginBottom: 8 }}>
          <p style={{ margin: 0, fontSize: 11, color: '#9ca3af' }}>Phone</p>
          <p style={{ margin: '2px 0 0', fontSize: 15, fontWeight: 600, color: '#111827' }}>{phone ?? '—'}</p>
        </div>
        <button onClick={onLogout} style={{ width: '100%', padding: '13px', borderRadius: 14, border: '1.5px solid #fca5a5', background: '#fff', cursor: 'pointer', fontSize: 13, fontWeight: 600, color: '#dc2626' }}>
          Logout
        </button>
      </div>
    </div>
  );
}

/* ─── Main control page ─── */
function ControlPageInner() {
  const params = useSearchParams();
  const { uid, phone, logout, setUser } = useAuthStore();
  const [showLogin, setShowLogin] = useState(false);
  const [activeTab, setActiveTab] = useState<OwnerTab>('orders');
  const [businesses, setBusinesses] = useState<Business[]>([]);
  const [selectedBiz, setSelectedBiz] = useState<Business | null>(null);
  const [bizLoading, setBizLoading] = useState(false);
  const [showBizPicker, setShowBizPicker] = useState(false);
  const [showAddProduct, setShowAddProduct] = useState(false);
  const [orders, setOrders] = useState<Order[]>([]);
  const [ordersLoading, setOrdersLoading] = useState(false);

  useEffect(() => {
    const paramUid = params.get('uid');
    const paramPhone = params.get('phone');
    if (paramUid && !uid) setUser(paramUid, paramPhone ?? '');
  }, [params, uid, setUser]);

  useEffect(() => {
    if (!uid) { setBusinesses([]); setSelectedBiz(null); return; }
    setBizLoading(true);
    loadAllBusinesses(uid)
      .then(list => { setBusinesses(list); setSelectedBiz(prev => prev ?? list[0] ?? null); })
      .finally(() => setBizLoading(false));
  }, [uid]);

  useEffect(() => {
    if (activeTab !== 'home' || !selectedBiz || selectedBiz.type !== 'shops') { setOrders([]); return; }
    setOrdersLoading(true);
    fetch(`/api/orders?shopId=${selectedBiz.id}`)
      .then(r => r.json()).then(d => setOrders(d.orders ?? []))
      .catch(console.error).finally(() => setOrdersLoading(false));
  }, [activeTab, selectedBiz]);

  const storefrontPath = selectedBiz
    ? selectedBiz.type === 'shops' ? `/sites/${selectedBiz.id}` : `/${selectedBiz.id}`
    : '/';

  const TABS: { id: OwnerTab; icon: string; label: string }[] = [
    { id: 'orders',   icon: '📦', label: 'Orders' },
    { id: 'website',  icon: '🌐', label: 'Website' },
    { id: 'settings', icon: '⚙️', label: 'Settings' },
  ];

  return (
    <div style={{ width: '100%', minHeight: '100dvh', background: '#f8f9fa', display: 'flex', flexDirection: 'column' }}>

      {/* Header */}
      <header style={{ background: '#283618', padding: '14px 16px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexShrink: 0 }}>
        <div style={{ maxWidth: 1280, width: '100%', margin: '0 auto', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <Link href="/" style={{ width: 32, height: 32, borderRadius: 10, border: '1px solid rgba(254,250,224,0.3)', display: 'flex', alignItems: 'center', justifyContent: 'center', textDecoration: 'none', color: '#fefae0', fontSize: 16 }}>←</Link>
        <span style={{ fontFamily: 'Caveat, cursive', fontSize: 22, color: '#fefae0' }}>control panel</span>
        {uid ? (
          <button onClick={logout} style={{ background: 'rgba(254,250,224,0.1)', border: '1px solid rgba(254,250,224,0.2)', borderRadius: 20, padding: '5px 12px', color: '#fefae0', fontSize: 11, cursor: 'pointer' }}>
            {phone?.replace('+91', '') ?? 'logout'}
          </button>
        ) : (
          <button onClick={() => setShowLogin(true)} style={{ background: '#dda15e', border: 'none', borderRadius: 20, padding: '6px 14px', color: '#fff', fontSize: 12, fontWeight: 700, cursor: 'pointer' }}>
            Login
          </button>
        )}
        </div>
      </header>

      {!uid ? (
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: 32, gap: 16, textAlign: 'center' }}>
          <div style={{ fontSize: 56, marginBottom: 8 }}>🔐</div>
          <h2 style={{ margin: 0, fontSize: 22, fontWeight: 700, color: '#111827' }}>Your Business Dashboard</h2>
          <p style={{ margin: 0, fontSize: 14, color: '#6b7280', lineHeight: 1.6, maxWidth: 280 }}>
            Log in with your phone number to manage your listings, receive orders, and more.
          </p>
          <button onClick={() => setShowLogin(true)} style={{ marginTop: 8, padding: '14px 36px', background: '#283618', color: '#fefae0', border: 'none', borderRadius: 24, cursor: 'pointer', fontSize: 14, fontWeight: 700 }}>
            Login to Continue
          </button>
        </div>
      ) : (
        <div style={{ flex: 1, display: 'flex', maxWidth: 1280, width: '100%', margin: '0 auto', alignSelf: 'center', boxSizing: 'border-box', width: '100%' }}>

          {/* Desktop sidebar nav */}
          <aside style={{ display: 'none', width: 220, background: '#fff', borderRight: '1px solid #f3f4f6', flexDirection: 'column', gap: 4, padding: '16px 12px', flexShrink: 0 }} className="md-sidebar">
            <style>{`@media(min-width:768px){.md-sidebar{display:flex!important}.mobile-bottom-nav{display:none!important}.mobile-biz-bar{max-width:100%!important}}`}</style>

            {/* Business selector in sidebar */}
            <button onClick={() => setShowBizPicker(v => !v)} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '10px 12px', background: '#f9fafb', border: '1px solid #e5e7eb', borderRadius: 12, cursor: 'pointer', marginBottom: 16, width: '100%' }}>
              <span style={{ fontSize: 20 }}>{selectedBiz ? (TYPE_ICONS[selectedBiz.type] ?? '🏢') : '📋'}</span>
              <div style={{ textAlign: 'left', flex: 1, minWidth: 0 }}>
                <p style={{ margin: 0, fontSize: 13, fontWeight: 700, color: '#111827', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{bizLoading ? 'Loading…' : (selectedBiz?.name ?? 'No business')}</p>
                {selectedBiz && <p style={{ margin: 0, fontSize: 10, color: '#9ca3af', textTransform: 'uppercase' }}>{selectedBiz.type}</p>}
              </div>
              <span style={{ color: '#9ca3af', fontSize: 12 }}>▾</span>
            </button>

            {TABS.map(tab => (
              <button key={tab.id} onClick={() => setActiveTab(tab.id)} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '12px 14px', borderRadius: 12, border: 'none', background: activeTab === tab.id ? '#283618' : 'transparent', color: activeTab === tab.id ? '#fefae0' : '#6b7280', cursor: 'pointer', fontSize: 14, fontWeight: activeTab === tab.id ? 700 : 500, width: '100%', textAlign: 'left' }}>
                <span style={{ fontSize: 18 }}>{tab.icon}</span>
                {tab.label}
              </button>
            ))}
          </aside>

          {/* Main content area */}
          <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden', minHeight: 0 }}>
            {/* Mobile business selector bar */}
            <div className="mobile-biz-bar">
              <button onClick={() => setShowBizPicker(v => !v)} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '10px 16px', background: '#fff', borderBottom: '1px solid #f3f4f6', cursor: 'pointer', border: 'none', borderBottomWidth: 1, borderBottomStyle: 'solid', borderBottomColor: '#f3f4f6', width: '100%' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                  <span style={{ fontSize: 20 }}>{selectedBiz ? (TYPE_ICONS[selectedBiz.type] ?? '🏢') : '📋'}</span>
                  <div style={{ textAlign: 'left' }}>
                    <p style={{ margin: 0, fontSize: 15, fontWeight: 700, color: '#111827' }}>{bizLoading ? 'Loading…' : (selectedBiz?.name ?? 'No business yet')}</p>
                    {selectedBiz && <p style={{ margin: 0, fontSize: 10, color: '#9ca3af', textTransform: 'uppercase', letterSpacing: 0.3 }}>{selectedBiz.type}</p>}
                  </div>
                </div>
                <span style={{ fontSize: 14, color: '#9ca3af' }}>▾</span>
              </button>
            </div>

            {/* Business picker dropdown */}
            {showBizPicker && businesses.length > 0 && (
              <div style={{ background: '#fff', borderBottom: '1px solid #f3f4f6', flexShrink: 0 }}>
                {businesses.map(biz => (
                  <button key={biz.id} onClick={() => { setSelectedBiz(biz); setShowBizPicker(false); }} style={{ display: 'flex', alignItems: 'center', gap: 10, width: '100%', padding: '12px 16px', background: selectedBiz?.id === biz.id ? '#f0fdf4' : '#fff', border: 'none', borderBottom: '1px solid #f9fafb', cursor: 'pointer' }}>
                    <span style={{ fontSize: 18 }}>{TYPE_ICONS[biz.type] ?? '🏢'}</span>
                    <div style={{ textAlign: 'left' }}>
                      <p style={{ margin: 0, fontSize: 14, fontWeight: 600, color: '#111827' }}>{biz.name}</p>
                      <p style={{ margin: 0, fontSize: 10, color: '#9ca3af', textTransform: 'uppercase' }}>{biz.type}</p>
                    </div>
                    {selectedBiz?.id === biz.id && <span style={{ marginLeft: 'auto', color: '#22c55e', fontSize: 16 }}>✓</span>}
                  </button>
                ))}
              </div>
            )}

            {/* Tab content */}
            <div style={{ flex: 1, overflowY: 'auto' }}>
              {activeTab === 'orders' && <HomeTab biz={selectedBiz} orders={orders} ordersLoading={ordersLoading} />}
              {activeTab === 'website' && <WebTab biz={selectedBiz} uid={uid} storefrontPath={storefrontPath} />}
              {activeTab === 'settings' && <SettingsTab businesses={businesses} phone={phone} onLogout={logout} selectedBiz={selectedBiz} uid={uid} />}
            </div>

            {/* Mobile bottom nav */}
            <div className="mobile-bottom-nav" style={{ borderTop: '1px solid #f3f4f6', background: '#fff', display: 'flex', flexShrink: 0 }}>
              {TABS.map(tab => (
                <button key={tab.id} onClick={() => setActiveTab(tab.id)} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3, padding: '12px 0', border: 'none', background: 'none', cursor: 'pointer', borderTop: activeTab === tab.id ? '2px solid #283618' : '2px solid transparent', color: activeTab === tab.id ? '#283618' : '#9ca3af' }}>
                  <span style={{ fontSize: 20 }}>{tab.icon}</span>
                  <span style={{ fontSize: 10, fontWeight: activeTab === tab.id ? 700 : 500 }}>{tab.label}</span>
                </button>
              ))}
            </div>
          </div>
        </div>
      )}

      {selectedBiz && (
        <AddProductSheet
          open={showAddProduct}
          shopId={selectedBiz.id}
          onClose={() => setShowAddProduct(false)}
        />
      )}

      <LoginModal open={showLogin} onClose={() => setShowLogin(false)} />
    </div>
  );
}

export default function ControlPage() {
  return (
    <Suspense fallback={<div style={{ minHeight: '100dvh', background: '#f8f9fa' }} />}>
      <ControlPageInner />
    </Suspense>
  );
}
