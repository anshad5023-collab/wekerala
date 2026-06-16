'use client';

import { useEffect, useState, useCallback } from 'react';
import Link from 'next/link';
import { ArrowLeft, Package, ShoppingBag, X, RefreshCw } from 'lucide-react';
import { useAuthStore } from '@/lib/auth-store';

const STATUS_CONFIG: Record<string, { label: string; color: string; bg: string }> = {
  new:              { label: 'New',          color: '#2563eb', bg: '#eff6ff' },
  confirmed:        { label: 'Confirmed',    color: '#7c3aed', bg: '#f5f3ff' },
  preparing:        { label: 'Preparing',    color: '#d97706', bg: '#fffbeb' },
  ready:            { label: 'Ready',        color: '#ea580c', bg: '#fff7ed' },
  out_for_delivery: { label: 'On the way',   color: '#0891b2', bg: '#ecfeff' },
  delivered:        { label: 'Delivered',    color: '#16a34a', bg: '#f0fdf4' },
  cancelled:        { label: 'Cancelled',    color: '#dc2626', bg: '#fef2f2' },
};

const CANCELLABLE_STATUSES = new Set(['new', 'confirmed']);

interface OrderItem { productName: string; qty: number; subtotal: number; variantName?: string; }
interface Order {
  id: string;
  shopId: string;
  shopName?: string;
  status: string;
  totalAmount: number;
  createdAt: string;
  items: OrderItem[];
}

function formatDate(iso: string) {
  try {
    return new Date(iso).toLocaleDateString('en-IN', {
      day: 'numeric', month: 'short', year: 'numeric',
      hour: '2-digit', minute: '2-digit',
    });
  } catch { return iso; }
}

function OrderCard({ order, onCancelled, customerUid }: { order: Order; onCancelled: (id: string) => void; customerUid: string }) {
  const status = STATUS_CONFIG[order.status] ?? { label: order.status, color: '#6b7280', bg: '#f9fafb' };
  const items = order.items ?? [];
  const [showItems, setShowItems] = useState(false);
  const [cancelling, setCancelling] = useState(false);

  const handleCancel = async () => {
    if (!confirm('Cancel this order?')) return;
    setCancelling(true);
    try {
      const res = await fetch(`/api/orders?shopId=${order.shopId}&orderId=${order.id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status: 'cancelled', customerUid }),
      });
      if (!res.ok) {
        const err = await res.json().catch(() => ({}));
        alert(err.error || 'Could not cancel this order.');
        return;
      }
      onCancelled(order.id);
    } catch {
      alert('Could not cancel this order — check your connection and try again.');
    } finally {
      setCancelling(false);
    }
  };

  return (
    <div className="rounded-xl border border-border bg-card shadow-sm overflow-hidden">
      <div
        style={{ background: status.bg, borderBottom: `1px solid ${status.color}33` }}
        className="flex items-center justify-between px-4 py-2"
      >
        <span style={{ color: status.color }} className="text-xs font-semibold uppercase tracking-wide">
          {status.label}
        </span>
        <span className="text-xs text-muted-foreground">{formatDate(order.createdAt)}</span>
      </div>

      <div className="p-4">
        <div className="flex items-start justify-between gap-2 mb-3">
          <div className="min-w-0">
            <p className="font-semibold italic text-foreground truncate">{order.shopName || 'Shop'}</p>
            <button
              onClick={() => setShowItems((v) => !v)}
              className="text-sm italic text-primary hover:underline mt-0.5 text-left"
            >
              {items.length} item{items.length !== 1 ? 's' : ''} — {showItems ? 'hide' : 'show details'}
            </button>
          </div>
          <span className="text-lg font-bold italic text-primary whitespace-nowrap shrink-0">
            ₹{order.totalAmount}
          </span>
        </div>

        {showItems && items.length > 0 && (
          <div className="mb-3 rounded-lg bg-muted/40 p-2 space-y-1">
            {items.map((item, i) => (
              <div key={i} className="flex items-center justify-between text-sm">
                <span className="italic text-foreground truncate mr-2">
                  {item.productName}{item.variantName ? ` (${item.variantName})` : ''} ×{item.qty}
                </span>
                <span className="italic text-muted-foreground whitespace-nowrap">₹{item.subtotal}</span>
              </div>
            ))}
          </div>
        )}

        <div className="flex gap-2">
          {order.shopId && order.id && (
            <Link
              href={`/shop?shopId=${order.shopId}&view=tracking&orderId=${order.id}`}
              className="flex-1 text-center rounded-lg border border-primary text-primary text-sm font-medium italic py-2 hover:bg-primary/5 transition-colors"
            >
              Track
            </Link>
          )}
          {CANCELLABLE_STATUSES.has(order.status) && (
            <button
              onClick={handleCancel}
              disabled={cancelling}
              className="flex items-center gap-1 rounded-lg border border-red-300 text-red-600 text-sm font-medium italic px-3 py-2 hover:bg-red-50 transition-colors disabled:opacity-50"
            >
              <X className="h-4 w-4" />
              {cancelling ? '…' : 'Cancel'}
            </button>
          )}
          <Link
            href={`/shop?shopId=${order.shopId}`}
            className="flex-1 text-center rounded-lg bg-primary text-primary-foreground text-sm font-medium italic py-2 hover:bg-primary/90 transition-colors"
          >
            Shop Again
          </Link>
        </div>
      </div>
    </div>
  );
}

export default function CustomerOrdersPage() {
  const { uid, phone } = useAuthStore();
  const [orders, setOrders] = useState<Order[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  const fetchOrders = useCallback(async (showSpinner = false) => {
    if (!uid) { setLoading(false); return; }
    if (showSpinner) setRefreshing(true);
    try {
      const data = await fetch(`/api/customer/orders?uid=${encodeURIComponent(uid)}`).then((r) => r.json());
      setOrders((data.orders ?? []) as Order[]);
    } catch { /* keep existing orders */ } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, [uid]);

  // Initial load
  useEffect(() => { fetchOrders(); }, [fetchOrders]);

  // Poll every 30s for status updates on active orders
  useEffect(() => {
    const hasActiveOrders = orders.some((o) => !['delivered', 'cancelled'].includes(o.status));
    if (!hasActiveOrders) return;
    const id = setInterval(() => fetchOrders(), 30_000);
    return () => clearInterval(id);
  }, [orders, fetchOrders]);

  const handleCancelled = (orderId: string) => {
    setOrders((prev) => prev.map((o) => o.id === orderId ? { ...o, status: 'cancelled' } : o));
  };

  return (
    <div className="min-h-screen bg-[#f0fdf4]">
      <header className="sticky top-0 z-50 flex items-center gap-3 bg-[#22c55e] px-4 py-3 text-white shadow-md">
        <button
          onClick={() => window.history.back()}
          className="flex items-center justify-center rounded-full p-1.5 hover:bg-white/20 transition-colors"
          aria-label="Go back"
        >
          <ArrowLeft className="h-5 w-5" />
        </button>
        <h1 className="text-lg font-bold italic flex-1">My Orders</h1>
        {uid && (
          <button
            onClick={() => fetchOrders(true)}
            disabled={refreshing}
            className="rounded-full p-1.5 hover:bg-white/20 transition-colors disabled:opacity-50"
            aria-label="Refresh orders"
          >
            <RefreshCw className={`h-4 w-4 ${refreshing ? 'animate-spin' : ''}`} />
          </button>
        )}
        {phone && <span className="text-xs opacity-75 truncate max-w-[120px]">{phone}</span>}
      </header>

      <div className="p-4 space-y-4 pb-24">
        {!uid ? (
          <div className="mt-16 text-center px-4">
            <div className="mx-auto mb-4 flex h-20 w-20 items-center justify-center rounded-full bg-primary/10">
              <Package className="h-10 w-10 text-primary" />
            </div>
            <h2 className="text-xl font-bold italic text-foreground mb-2">Sign in to view orders</h2>
            <p className="italic text-muted-foreground mb-6 text-sm">
              Your order history will appear here after signing in.
            </p>
            <Link
              href="/auth"
              className="inline-block rounded-xl bg-primary px-8 py-3 font-semibold italic text-primary-foreground hover:bg-primary/90 transition-colors"
            >
              Sign In
            </Link>
          </div>
        ) : loading ? (
          <div className="space-y-4">
            {[1, 2, 3].map((i) => (
              <div key={i} className="h-36 rounded-xl bg-gray-200 animate-pulse" />
            ))}
          </div>
        ) : orders.length === 0 ? (
          <div className="mt-16 text-center px-4">
            <div className="mx-auto mb-4 flex h-20 w-20 items-center justify-center rounded-full bg-primary/10">
              <ShoppingBag className="h-10 w-10 text-primary" />
            </div>
            <h2 className="text-xl font-bold italic text-foreground mb-2">No orders yet</h2>
            <p className="italic text-muted-foreground text-sm">
              Your orders will appear here once you place one.
            </p>
          </div>
        ) : (
          orders.map((order) => (
            <OrderCard key={order.id} order={order} onCancelled={handleCancelled} customerUid={uid ?? ''} />
          ))
        )}
      </div>
    </div>
  );
}
