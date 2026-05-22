'use client';

import { useState, useEffect, Suspense } from 'react';
import { useSearchParams } from 'next/navigation';
import { useAuthStore } from '@/lib/auth-store';

interface Order {
  id: string;
  totalAmount: number;
  status: string;
  createdAt: string;
  customerName: string;
  items: Array<{ productName: string; qty: number; subtotal: number }>;
}

function AnalyticsContent() {
  const params = useSearchParams();
  const { setUser } = useAuthStore();
  const shopId = params.get('shopId') || '';
  const uid = params.get('uid') || '';

  const [orders, setOrders] = useState<Order[]>([]);
  const [loading, setLoading] = useState(true);
  const [period, setPeriod] = useState<'today' | 'week' | 'month' | 'all'>('week');

  useEffect(() => {
    if (uid) setUser(uid, '');
  }, [uid, setUser]);

  useEffect(() => {
    if (!shopId) return;
    setLoading(true);
    fetch(`/api/orders?shopId=${shopId}&pageSize=200`)
      .then(r => r.json())
      .then(data => {
        setOrders((data.orders ?? []) as Order[]);
      })
      .catch(() => {})
      .finally(() => setLoading(false));
  }, [shopId]);

  const now = new Date();
  const filtered = orders.filter(o => {
    if (period === 'all') return true;
    const d = new Date(o.createdAt);
    if (period === 'today') {
      return d.toDateString() === now.toDateString();
    }
    if (period === 'week') {
      const weekAgo = new Date(now); weekAgo.setDate(weekAgo.getDate() - 7);
      return d >= weekAgo;
    }
    if (period === 'month') {
      const monthAgo = new Date(now); monthAgo.setMonth(monthAgo.getMonth() - 1);
      return d >= monthAgo;
    }
    return true;
  });

  const revenue = filtered.filter(o => o.status !== 'cancelled').reduce((sum, o) => sum + (o.totalAmount || 0), 0);
  const orderCount = filtered.length;
  const deliveredCount = filtered.filter(o => o.status === 'delivered').length;
  const cancelledCount = filtered.filter(o => o.status === 'cancelled').length;

  // Top products
  const productMap: Record<string, { name: string; qty: number; revenue: number }> = {};
  filtered.filter(o => o.status !== 'cancelled').forEach(o => {
    (o.items || []).forEach(item => {
      const name = item.productName || 'Unknown';
      if (!productMap[name]) productMap[name] = { name, qty: 0, revenue: 0 };
      productMap[name].qty += item.qty || 1;
      productMap[name].revenue += item.subtotal || 0;
    });
  });
  const topProducts = Object.values(productMap).sort((a, b) => b.revenue - a.revenue).slice(0, 5);

  // Daily revenue for last 7 days
  const dailyRevenue: Record<string, number> = {};
  for (let i = 6; i >= 0; i--) {
    const d = new Date(now);
    d.setDate(d.getDate() - i);
    dailyRevenue[d.toLocaleDateString('en-IN', { weekday: 'short' })] = 0;
  }
  filtered.filter(o => o.status !== 'cancelled').forEach(o => {
    const d = new Date(o.createdAt);
    const daysAgo = Math.floor((now.getTime() - d.getTime()) / 86400000);
    if (daysAgo < 7) {
      const key = d.toLocaleDateString('en-IN', { weekday: 'short' });
      dailyRevenue[key] = (dailyRevenue[key] || 0) + (o.totalAmount || 0);
    }
  });
  const maxRevenue = Math.max(...Object.values(dailyRevenue), 1);

  return (
    <div style={{ minHeight: '100dvh', background: '#f8f9fa', fontFamily: 'system-ui, sans-serif' }}>
      {/* Header */}
      <header style={{ background: '#283618', color: '#fefae0', padding: '12px 16px', display: 'flex', alignItems: 'center', gap: 12 }}>
        <button onClick={() => window.history.back()} style={{ background: 'none', border: 'none', color: '#fefae0', fontSize: 20, cursor: 'pointer' }}>←</button>
        <span style={{ flex: 1, fontWeight: 600 }}>Analytics</span>
        <select value={period} onChange={e => setPeriod(e.target.value as typeof period)}
          style={{ background: '#fefae0', color: '#283618', border: 'none', borderRadius: 8, padding: '4px 8px', fontSize: 12, fontWeight: 600 }}>
          <option value="today">Today</option>
          <option value="week">Last 7 days</option>
          <option value="month">Last 30 days</option>
          <option value="all">All time</option>
        </select>
      </header>

      {loading ? (
        <div style={{ padding: 32, textAlign: 'center', color: '#aaa' }}>Loading…</div>
      ) : (
        <div style={{ padding: '16px', maxWidth: 480, margin: '0 auto' }}>
          {/* KPI Cards */}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 16 }}>
            {[
              { label: 'Revenue', value: `₹${revenue.toLocaleString()}`, color: '#283618' },
              { label: 'Orders', value: orderCount.toString(), color: '#1d4ed8' },
              { label: 'Delivered', value: deliveredCount.toString(), color: '#16a34a' },
              { label: 'Cancelled', value: cancelledCount.toString(), color: '#dc2626' },
            ].map(kpi => (
              <div key={kpi.label} style={{ background: '#fff', borderRadius: 14, padding: '16px', boxShadow: '0 1px 4px rgba(0,0,0,0.06)' }}>
                <p style={{ fontSize: 11, color: '#888', margin: '0 0 4px', textTransform: 'uppercase', letterSpacing: 0.5 }}>{kpi.label}</p>
                <p style={{ fontSize: 22, fontWeight: 700, color: kpi.color, margin: 0 }}>{kpi.value}</p>
              </div>
            ))}
          </div>

          {/* Revenue bar chart */}
          {period !== 'today' && (
            <div style={{ background: '#fff', borderRadius: 14, padding: '16px', marginBottom: 16, boxShadow: '0 1px 4px rgba(0,0,0,0.06)' }}>
              <p style={{ fontSize: 12, fontWeight: 600, color: '#283618', margin: '0 0 12px' }}>Revenue — Last 7 Days</p>
              <div style={{ display: 'flex', alignItems: 'flex-end', gap: 8, height: 80 }}>
                {Object.entries(dailyRevenue).map(([day, rev]) => (
                  <div key={day} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4 }}>
                    <div style={{ width: '100%', background: '#283618', borderRadius: 4, height: Math.max(4, (rev / maxRevenue) * 60), transition: 'height 0.3s' }} />
                    <span style={{ fontSize: 9, color: '#888' }}>{day}</span>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Top products */}
          {topProducts.length > 0 && (
            <div style={{ background: '#fff', borderRadius: 14, padding: '16px', marginBottom: 16, boxShadow: '0 1px 4px rgba(0,0,0,0.06)' }}>
              <p style={{ fontSize: 12, fontWeight: 600, color: '#283618', margin: '0 0 12px' }}>Top Products</p>
              {topProducts.map((prod, i) => (
                <div key={prod.name} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '8px 0', borderTop: i > 0 ? '1px solid #f3f4f6' : 'none' }}>
                  <span style={{ width: 20, height: 20, borderRadius: '50%', background: '#283618', color: '#fefae0', fontSize: 10, fontWeight: 700, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>{i + 1}</span>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <p style={{ fontSize: 13, fontWeight: 600, margin: 0, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{prod.name}</p>
                    <p style={{ fontSize: 11, color: '#888', margin: '2px 0 0' }}>{prod.qty} sold</p>
                  </div>
                  <span style={{ fontSize: 13, fontWeight: 700, color: '#283618', flexShrink: 0 }}>₹{prod.revenue.toLocaleString()}</span>
                </div>
              ))}
            </div>
          )}

          {/* Recent orders */}
          <div style={{ background: '#fff', borderRadius: 14, padding: '16px', boxShadow: '0 1px 4px rgba(0,0,0,0.06)' }}>
            <p style={{ fontSize: 12, fontWeight: 600, color: '#283618', margin: '0 0 12px' }}>Recent Orders</p>
            {filtered.length === 0 && (
              <p style={{ fontSize: 13, color: '#aaa', textAlign: 'center', padding: '20px 0' }}>No orders in this period</p>
            )}
            {filtered.slice(0, 20).map((order, i) => (
              <div key={order.id} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '10px 0', borderTop: i > 0 ? '1px solid #f3f4f6' : 'none' }}>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <p style={{ fontSize: 13, fontWeight: 600, margin: 0 }}>{order.customerName || 'Customer'}</p>
                  <p style={{ fontSize: 11, color: '#888', margin: '2px 0 0' }}>{new Date(order.createdAt).toLocaleDateString('en-IN')}</p>
                </div>
                <span style={{
                  fontSize: 10, fontWeight: 600, padding: '2px 8px', borderRadius: 20,
                  background: order.status === 'delivered' ? '#dcfce7' : order.status === 'cancelled' ? '#fee2e2' : '#fef9c3',
                  color: order.status === 'delivered' ? '#16a34a' : order.status === 'cancelled' ? '#dc2626' : '#92400e',
                }}>{order.status}</span>
                <span style={{ fontSize: 13, fontWeight: 700, color: '#283618', flexShrink: 0 }}>₹{order.totalAmount || 0}</span>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

export default function AnalyticsPage() {
  return (
    <Suspense fallback={<div style={{ padding: 32, textAlign: 'center' }}>Loading…</div>}>
      <AnalyticsContent />
    </Suspense>
  );
}
