'use client';

import { useEffect, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import { Suspense } from 'react';

const PROJECT_ID = (process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID ?? 'shoplink-prod').replace(/^﻿/, '');
const API_KEY = process.env.NEXT_PUBLIC_FIREBASE_API_KEY ?? '';
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

type FVal = { stringValue?: string; integerValue?: string; doubleValue?: number; booleanValue?: boolean; timestampValue?: string; mapValue?: { fields: Record<string, FVal> }; arrayValue?: { values?: FVal[] }; nullValue?: null };

function parseValue(v: FVal): unknown {
  if ('stringValue' in v) return v.stringValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return v.doubleValue;
  if ('booleanValue' in v) return v.booleanValue;
  if ('timestampValue' in v) return v.timestampValue;
  if ('nullValue' in v) return null;
  if ('mapValue' in v && v.mapValue) return Object.fromEntries(Object.entries(v.mapValue.fields ?? {}).map(([k, val]) => [k, parseValue(val)]));
  if ('arrayValue' in v && v.arrayValue) return (v.arrayValue.values ?? []).map(parseValue);
  return null;
}

interface Order {
  orderId: string;
  orderNumber: string;
  customerName: string;
  status: string;
  totalAmount: number;
  createdAt: string;
  scheduledFor?: string;
  shopId: string;
  items: Array<{ productName: string; qty: number; unit: string; subtotal: number }>;
}

const STATUS_STEPS = ['new', 'confirmed', 'processing', 'ready', 'out_for_delivery', 'delivered'];
const STATUS_LABELS: Record<string, string> = {
  new: 'Order Received',
  confirmed: 'Confirmed',
  processing: 'Being Prepared',
  ready: 'Ready for Pickup',
  out_for_delivery: 'Out for Delivery',
  delivered: 'Delivered',
  cancelled: 'Cancelled',
};
const STATUS_COLORS: Record<string, string> = {
  new: 'bg-blue-500',
  confirmed: 'bg-indigo-500',
  processing: 'bg-yellow-500',
  ready: 'bg-orange-500',
  out_for_delivery: 'bg-purple-500',
  delivered: 'bg-green-500',
  cancelled: 'bg-red-500',
};

async function fetchOrderByPhone(shopId: string, phone: string): Promise<Order[]> {
  const url = `${BASE}/shops/${shopId}/orders?key=${API_KEY}`;
  const res = await fetch(url);
  if (!res.ok) return [];
  const data = await res.json() as { documents?: Array<{ name: string; fields: Record<string, FVal> }> };
  return (data.documents ?? [])
    .map((doc) => {
      const id = doc.name.split('/').pop()!;
      const fields = Object.fromEntries(Object.entries(doc.fields ?? {}).map(([k, v]) => [k, parseValue(v)])) as Record<string, unknown>;
      return { orderId: id, ...fields } as Order;
    })
    .filter((o) => (o.customerPhone as string | undefined)?.replace(/\D/g,'').endsWith(phone.replace(/\D/g,'').slice(-10)));
}

function TrackContent() {
  const params = useSearchParams();
  const [shopId, setShopId] = useState(params.get('shop') ?? '');
  const [phone, setPhone] = useState(params.get('phone') ?? '');
  const [orders, setOrders] = useState<Order[]>([]);
  const [loading, setLoading] = useState(false);
  const [searched, setSearched] = useState(false);

  const handleSearch = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!shopId || !phone) return;
    setLoading(true);
    const found = await fetchOrderByPhone(shopId, phone);
    found.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
    setOrders(found);
    setSearched(true);
    setLoading(false);
  };

  const stepIdx = (status: string) => STATUS_STEPS.indexOf(status);

  return (
    <main className="min-h-screen bg-gray-50 px-4 py-8">
      <div className="mx-auto max-w-lg">
        <h1 className="mb-2 text-center text-2xl font-bold text-gray-800">Track Your Order</h1>
        <p className="mb-6 text-center text-sm text-gray-500">Enter your phone number to see all your orders</p>

        <form onSubmit={handleSearch} className="mb-6 rounded-xl bg-white p-4 shadow-sm">
          <div className="mb-3">
            <label className="mb-1 block text-sm font-medium text-gray-700">Shop ID</label>
            <input
              value={shopId}
              onChange={(e) => setShopId(e.target.value)}
              placeholder="Enter shop ID"
              required
              className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm outline-none focus:border-green-500 focus:ring-2 focus:ring-green-200"
            />
          </div>
          <div className="mb-4">
            <label className="mb-1 block text-sm font-medium text-gray-700">Your Phone Number</label>
            <input
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
              placeholder="10-digit mobile number"
              required
              className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm outline-none focus:border-green-500 focus:ring-2 focus:ring-green-200"
            />
          </div>
          <button
            type="submit"
            disabled={loading}
            className="w-full rounded-lg bg-green-600 py-2.5 text-sm font-semibold text-white hover:bg-green-700 disabled:opacity-50"
          >
            {loading ? 'Searching...' : 'Track Orders'}
          </button>
        </form>

        {searched && orders.length === 0 && (
          <p className="text-center text-sm text-gray-500">No orders found for this phone number.</p>
        )}

        {orders.map((order) => {
          const isCancelled = order.status === 'cancelled';
          const currentStep = stepIdx(order.status);
          const date = order.createdAt ? new Date(order.createdAt).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : '';
          const dueDate = order.scheduledFor ? new Date(order.scheduledFor).toLocaleDateString('en-IN', { weekday: 'short', day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' }) : null;

          return (
            <div key={order.orderId} className="mb-4 rounded-xl bg-white p-4 shadow-sm">
              <div className="mb-3 flex items-center justify-between">
                <div>
                  <p className="text-xs text-gray-400">Order #{order.orderNumber || order.orderId.substring(0, 8).toUpperCase()}</p>
                  <p className="text-sm font-semibold text-gray-800">{order.customerName}</p>
                  <p className="text-xs text-gray-400">{date}</p>
                </div>
                <div className="text-right">
                  <span className={`inline-block rounded-full px-2.5 py-1 text-xs font-bold text-white ${STATUS_COLORS[order.status] ?? 'bg-gray-400'}`}>
                    {STATUS_LABELS[order.status] ?? order.status}
                  </span>
                  <p className="mt-1 text-sm font-bold text-gray-800">₹{order.totalAmount?.toFixed(0)}</p>
                </div>
              </div>

              {dueDate && (
                <div className="mb-3 rounded-lg bg-purple-50 px-3 py-2">
                  <p className="text-xs font-semibold text-purple-700">📅 Scheduled for: {dueDate}</p>
                </div>
              )}

              {!isCancelled && (
                <div className="mb-3 flex items-center gap-0">
                  {STATUS_STEPS.map((step, i) => (
                    <div key={step} className="flex flex-1 flex-col items-center">
                      <div className={`h-2 w-full ${i <= currentStep ? 'bg-green-500' : 'bg-gray-200'} ${i === 0 ? 'rounded-l-full' : ''} ${i === STATUS_STEPS.length - 1 ? 'rounded-r-full' : ''}`} />
                      {i === currentStep && (
                        <p className="mt-1 text-center text-[9px] font-semibold text-green-700">{STATUS_LABELS[step]}</p>
                      )}
                    </div>
                  ))}
                </div>
              )}

              {(order.items ?? []).length > 0 && (
                <div className="border-t border-gray-100 pt-2">
                  {(order.items as Array<{ productName: string; qty: number; unit: string; subtotal: number }>).map((item, i) => (
                    <div key={i} className="flex justify-between py-0.5 text-xs text-gray-600">
                      <span>{item.productName} × {item.qty} {item.unit}</span>
                      <span>₹{item.subtotal?.toFixed(0)}</span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          );
        })}
      </div>
    </main>
  );
}

export default function TrackPage() {
  return (
    <Suspense fallback={<div className="flex min-h-screen items-center justify-center text-sm text-gray-500">Loading...</div>}>
      <TrackContent />
    </Suspense>
  );
}
