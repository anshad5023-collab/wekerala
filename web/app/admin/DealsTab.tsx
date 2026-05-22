'use client';

import { useEffect, useState, useCallback } from 'react';
import { CheckCircle, XCircle, Loader2, RefreshCw, Clock } from 'lucide-react';

interface Deal {
  id: string;
  businessId: string;
  businessName: string;
  collection: string;
  title: string;
  description?: string;
  discount?: string;
  validUntil?: string;
  status: 'pending' | 'approved' | 'rejected';
  createdAt: string;
}

export function DealsTab({ adminPw }: { adminPw: string }) {
  const [deals, setDeals] = useState<Deal[]>([]);
  const [loading, setLoading] = useState(false);
  const [actionId, setActionId] = useState<string | null>(null);
  const [toast, setToast] = useState<{ msg: string; ok: boolean } | null>(null);
  const [filter, setFilter] = useState<'pending' | 'approved' | 'all'>('pending');

  const showToast = (msg: string, ok: boolean) => {
    setToast({ msg, ok });
    setTimeout(() => setToast(null), 3000);
  };

  const fetchDeals = useCallback(async () => {
    setLoading(true);
    try {
      const res = await fetch(`/api/admin/deals?status=${filter}`, {
        headers: { 'x-admin-password': adminPw },
      });
      if (!res.ok) throw new Error();
      const data = await res.json();
      setDeals(data.deals ?? []);
    } catch {
      showToast('Failed to load deals', false);
    } finally {
      setLoading(false);
    }
  }, [adminPw, filter]);

  useEffect(() => { fetchDeals(); }, [fetchDeals]);

  async function handleAction(id: string, status: 'approved' | 'rejected') {
    setActionId(id);
    try {
      const res = await fetch('/api/admin/deals', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json', 'x-admin-password': adminPw },
        body: JSON.stringify({ id, status }),
      });
      if (!res.ok) throw new Error();
      setDeals((prev) => prev.filter((d) => d.id !== id));
      showToast(status === 'approved' ? 'Deal approved' : 'Deal rejected', status === 'approved');
    } catch {
      showToast('Action failed', false);
    } finally {
      setActionId(null);
    }
  }

  return (
    <div>
      {toast && (
        <div className={`fixed right-4 top-4 z-50 rounded-2xl px-4 py-3 text-sm font-medium text-white shadow-lg ${toast.ok ? 'bg-green-600' : 'bg-red-500'}`}>
          {toast.msg}
        </div>
      )}

      <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <div>
          <h2 className="text-lg font-bold text-gray-900">Deals & Offers</h2>
          <p className="text-xs text-gray-500">{deals.length} deals</p>
        </div>
        <div className="flex items-center gap-2">
          {(['pending', 'approved', 'all'] as const).map((f) => (
            <button
              key={f}
              onClick={() => setFilter(f)}
              className={`rounded-full px-3 py-1 text-xs font-semibold transition-colors ${filter === f ? 'bg-[#283618] text-[#fefae0]' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'}`}
            >
              {f}
            </button>
          ))}
          <button onClick={fetchDeals} disabled={loading} className="flex items-center gap-1.5 rounded-xl border border-gray-200 px-3 py-1.5 text-xs font-medium text-gray-600 hover:bg-gray-50">
            <RefreshCw className={`h-3.5 w-3.5 ${loading ? 'animate-spin' : ''}`} />
          </button>
        </div>
      </div>

      {loading ? (
        <div className="space-y-2">
          {[1, 2, 3].map((i) => <div key={i} className="h-20 rounded-2xl bg-white shadow-sm animate-pulse" />)}
        </div>
      ) : deals.length === 0 ? (
        <div className="flex flex-col items-center gap-3 py-16 text-center">
          <Clock className="h-10 w-10 text-gray-300" />
          <p className="text-gray-500 text-sm">No {filter === 'all' ? '' : filter} deals.</p>
        </div>
      ) : (
        <div className="space-y-3">
          {deals.map((deal) => (
            <div key={deal.id} className="rounded-2xl border border-gray-100 bg-white p-4 shadow-sm">
              <div className="flex items-start justify-between gap-3">
                <div className="min-w-0">
                  <p className="font-semibold text-gray-900 truncate">{deal.title}</p>
                  <p className="text-xs text-gray-500">{deal.businessName} · {deal.collection}</p>
                  {deal.discount && <p className="mt-1 text-xs font-semibold text-amber-600">{deal.discount}</p>}
                  {deal.description && <p className="mt-1 text-xs text-gray-400 line-clamp-2">{deal.description}</p>}
                  {deal.validUntil && <p className="mt-1 text-xs text-gray-400">Valid until: {new Date(deal.validUntil).toLocaleDateString()}</p>}
                </div>
                <span className={`shrink-0 rounded-full px-2 py-0.5 text-xs font-semibold ${deal.status === 'pending' ? 'bg-amber-50 text-amber-700' : deal.status === 'approved' ? 'bg-green-50 text-green-700' : 'bg-red-50 text-red-600'}`}>
                  {deal.status}
                </span>
              </div>
              {deal.status === 'pending' && (
                <div className="mt-3 flex gap-2">
                  <button
                    onClick={() => handleAction(deal.id, 'approved')}
                    disabled={actionId === deal.id}
                    className="flex flex-1 items-center justify-center gap-1.5 rounded-xl bg-green-50 py-2 text-xs font-bold text-green-700 hover:bg-green-100 disabled:opacity-50"
                  >
                    {actionId === deal.id ? <Loader2 className="h-3.5 w-3.5 animate-spin" /> : <CheckCircle className="h-3.5 w-3.5" />}
                    Approve
                  </button>
                  <button
                    onClick={() => handleAction(deal.id, 'rejected')}
                    disabled={actionId === deal.id}
                    className="flex flex-1 items-center justify-center gap-1.5 rounded-xl bg-red-50 py-2 text-xs font-bold text-red-600 hover:bg-red-100 disabled:opacity-50"
                  >
                    {actionId === deal.id ? <Loader2 className="h-3.5 w-3.5 animate-spin" /> : <XCircle className="h-3.5 w-3.5" />}
                    Reject
                  </button>
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
