'use client';

import { useEffect, useState, useCallback } from 'react';
import { ArrowLeft, ShoppingBag, CheckCircle2, Package, Truck, Star, XCircle } from 'lucide-react';

const STEPS = [
  { key: 'new',              label: 'Order Received',   icon: ShoppingBag,  desc: 'Your order has been placed' },
  { key: 'confirmed',        label: 'Confirmed',        icon: CheckCircle2, desc: 'The shop confirmed your order' },
  { key: 'preparing',        label: 'Being Prepared',   icon: Package,      desc: 'Your items are being packed' },
  { key: 'ready',            label: 'Ready',            icon: Star,         desc: 'Ready for pickup / delivery' },
  { key: 'out_for_delivery', label: 'Out for Delivery', icon: Truck,        desc: 'On the way to you' },
  { key: 'delivered',        label: 'Delivered',        icon: CheckCircle2, desc: 'Order delivered!' },
];

interface OrderData {
  status: string;
  shopName: string;
  totalAmount: number;
  customerName: string;
  items: Array<{ productName: string; qty: number; subtotal: number }>;
  createdAt: string;
  scheduledFor?: string; // preferred delivery date from checkout
}

function formatTime(iso: string) {
  try { return new Date(iso).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' }); }
  catch { return ''; }
}

function formatDate(iso: string) {
  try { return new Date(iso).toLocaleDateString('en-IN', { day: 'numeric', month: 'short' }); }
  catch { return ''; }
}

export function OrderTracking({ orderId, shopId }: { orderId: string; shopId: string }) {
  const [order, setOrder] = useState<OrderData | null>(null);
  const [loading, setLoading] = useState(true);

  const fetch_ = useCallback(() => {
    fetch(`/api/order-status?orderId=${orderId}&shopId=${shopId}`)
      .then((r) => r.json())
      .then((data) => { setOrder(data as OrderData); setLoading(false); })
      .catch(() => setLoading(false));
  }, [orderId, shopId]);

  useEffect(() => {
    fetch_();
    const iv = setInterval(fetch_, 20000);
    return () => clearInterval(iv);
  }, [fetch_]);

  const status = order?.status ?? 'loading';
  const isCancelled = status === 'cancelled';
  const currentIdx = isCancelled ? -1 : STEPS.findIndex((s) => s.key === status);

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="sticky top-0 z-50 bg-primary text-primary-foreground shadow-md">
        <div className="mx-auto flex max-w-2xl items-center gap-3 px-4 py-3">
        <button
          onClick={() => window.history.back()}
          className="flex items-center justify-center rounded-full p-1.5 hover:bg-white/20 transition-colors"
          aria-label="Go back"
        >
          <ArrowLeft className="h-5 w-5" />
        </button>
        <div className="flex-1">
          <h1 className="text-base font-bold italic leading-tight">
            {order?.shopName || 'Order Tracking'}
          </h1>
          {order?.createdAt && (
            <p className="text-xs opacity-80">{formatDate(order.createdAt)} · {formatTime(order.createdAt)}</p>
          )}
        </div>
        {!isCancelled && currentIdx < STEPS.length - 1 && (
          <div className="flex items-center gap-1.5 rounded-full bg-white/15 px-2.5 py-1">
            <span className="relative flex h-2 w-2">
              <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-white opacity-75" />
              <span className="relative inline-flex h-2 w-2 rounded-full bg-white" />
            </span>
            <span className="text-[11px] font-medium">Live</span>
          </div>
        )}
        </div>
      </header>

      <div className="mx-auto max-w-2xl p-4 space-y-4 pb-24">
        {loading ? (
          <div className="space-y-3">
            {[1, 2, 3].map((i) => <div key={i} className="h-16 rounded-xl bg-gray-200 animate-pulse" />)}
          </div>
        ) : status === 'not_found' ? (
          <div className="mt-12 text-center">
            <p className="text-muted-foreground italic">Order not found.</p>
          </div>
        ) : (
          <>
            {/* Status banner */}
            <div className={`rounded-xl p-4 text-center ${isCancelled ? 'bg-red-50 border border-red-200' : 'bg-primary/10 border border-primary/20'}`}>
              {isCancelled ? (
                <>
                  <XCircle className="mx-auto mb-2 h-10 w-10 text-red-500" />
                  <p className="text-lg font-bold italic text-red-600">Order Cancelled</p>
                  <p className="text-sm italic text-red-400 mt-1">This order was cancelled.</p>
                </>
              ) : (
                <>
                  <div className="mx-auto mb-2 flex h-12 w-12 items-center justify-center rounded-full bg-primary/20">
                    {currentIdx >= 0 && (() => {
                      const Icon = STEPS[currentIdx]?.icon ?? CheckCircle2;
                      return <Icon className="h-6 w-6 text-primary" />;
                    })()}
                  </div>
                  <p className="text-lg font-bold italic text-primary">
                    {STEPS[currentIdx]?.label ?? status}
                  </p>
                  <p className="text-sm italic text-muted-foreground mt-1">
                    {STEPS[currentIdx]?.desc}
                  </p>
                </>
              )}
            </div>

            {/* Scheduled delivery date — for bakery/restaurant pre-orders */}
            {order?.scheduledFor && (
              <div className="rounded-xl bg-purple-50 border border-purple-200 p-3 flex items-center gap-2">
                <span className="text-purple-600">📅</span>
                <div>
                  <p className="text-xs font-semibold text-purple-700">Scheduled Delivery</p>
                  <p className="text-sm font-bold text-purple-800">
                    {new Date(order.scheduledFor).toLocaleDateString('en-IN', {weekday:'short',day:'numeric',month:'short',hour:'2-digit',minute:'2-digit'})}
                  </p>
                </div>
              </div>
            )}

            {/* Timeline */}
            {!isCancelled && (
              <div className="rounded-xl border border-border bg-card p-4">
                <h3 className="text-sm font-semibold italic text-muted-foreground mb-4">Progress</h3>
                <div className="relative">
                  {STEPS.map((step, idx) => {
                    const done = idx < currentIdx;
                    const active = idx === currentIdx;
                    const Icon = step.icon;
                    return (
                      <div key={step.key} className="flex gap-3 pb-5 last:pb-0 relative">
                        {/* Vertical line */}
                        {idx < STEPS.length - 1 && (
                          <div
                            className={`absolute left-4 top-8 w-0.5 h-full -translate-x-1/2 ${done ? 'bg-primary' : 'bg-border'}`}
                          />
                        )}
                        {/* Icon dot */}
                        <div className={`relative z-10 flex h-8 w-8 shrink-0 items-center justify-center rounded-full border-2 ${
                          done ? 'border-primary bg-primary text-primary-foreground' :
                          active ? 'border-primary bg-primary/10 text-primary animate-pulse' :
                          'border-border bg-background text-muted-foreground'
                        }`}>
                          <Icon className="h-4 w-4" />
                        </div>
                        {/* Label */}
                        <div className="pt-1">
                          <p className={`text-sm font-semibold italic ${active ? 'text-primary' : done ? 'text-foreground' : 'text-muted-foreground'}`}>
                            {step.label}
                          </p>
                          {active && (
                            <p className="text-xs italic text-muted-foreground mt-0.5">{step.desc}</p>
                          )}
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>
            )}

            {/* Order summary */}
            {order && (order.items?.length > 0 || order.totalAmount > 0) && (
              <div className="rounded-xl border border-border bg-card p-4">
                <h3 className="text-sm font-semibold italic text-muted-foreground mb-3">Order Summary</h3>
                <div className="space-y-2">
                  {(order.items ?? []).map((item, i) => (
                    <div key={i} className="flex justify-between text-sm italic">
                      <span className="text-muted-foreground">{item.productName} ×{item.qty}</span>
                      <span className="font-medium text-foreground">₹{item.subtotal}</span>
                    </div>
                  ))}
                  {order.totalAmount > 0 && (
                    <div className="flex justify-between pt-2 border-t border-border">
                      <span className="font-semibold italic text-foreground">Total</span>
                      <span className="text-lg font-bold italic text-primary">₹{order.totalAmount}</span>
                    </div>
                  )}
                </div>
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
}
