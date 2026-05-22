'use client';

import { useEffect, useState, useCallback } from 'react';
import { RefreshCw, TrendingUp } from 'lucide-react';

interface AnalyticsData {
  listings: Record<string, number>;
  totalListings: number;
  approvedDeals: number;
  pendingDeals: number;
  totalRatings: number;
}

const COLLECTION_LABELS: Record<string, string> = {
  shops: 'Shops',
  services: 'Services',
  theaters: 'Theaters',
  hotels: 'Hotels',
  restaurants: 'Restaurants',
  beauty: 'Beauty & Wellness',
  doctors: 'Doctors',
  hospitals: 'Hospitals',
  education: 'Education',
  homeServices: 'Home Services',
};

export function AnalyticsTab({ adminPw }: { adminPw: string }) {
  const [data, setData] = useState<AnalyticsData | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const fetchAnalytics = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const res = await fetch('/api/admin/analytics', {
        headers: { 'x-admin-password': adminPw },
      });
      if (!res.ok) throw new Error();
      setData(await res.json());
    } catch {
      setError('Failed to load analytics');
    } finally {
      setLoading(false);
    }
  }, [adminPw]);

  useEffect(() => { fetchAnalytics(); }, [fetchAnalytics]);

  return (
    <div>
      <div className="mb-4 flex items-center justify-between">
        <div>
          <h2 className="text-lg font-bold text-gray-900">Platform Analytics</h2>
          <p className="text-xs text-gray-500">Live counts across all collections</p>
        </div>
        <button
          onClick={fetchAnalytics}
          disabled={loading}
          className="flex items-center gap-1.5 rounded-xl border border-gray-200 px-3 py-1.5 text-xs font-medium text-gray-600 hover:bg-gray-50"
        >
          <RefreshCw className={`h-3.5 w-3.5 ${loading ? 'animate-spin' : ''}`} />
          Refresh
        </button>
      </div>

      {error && <p className="mb-4 text-sm text-red-500">{error}</p>}

      {loading && !data ? (
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
          {[1, 2, 3, 4].map((i) => <div key={i} className="h-20 rounded-2xl bg-white shadow-sm animate-pulse" />)}
        </div>
      ) : data ? (
        <>
          {/* Top-level stats */}
          <div className="mb-6 grid grid-cols-2 gap-3 sm:grid-cols-4">
            <div className="flex items-center gap-3 rounded-2xl bg-white p-4 shadow-sm border border-gray-100">
              <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-blue-50">
                <TrendingUp className="h-5 w-5 text-blue-600" />
              </div>
              <div>
                <p className="text-2xl font-black text-gray-900">{data.totalListings}</p>
                <p className="text-xs font-medium text-gray-500">Total Listings</p>
              </div>
            </div>
            <div className="flex items-center gap-3 rounded-2xl bg-white p-4 shadow-sm border border-gray-100">
              <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-amber-50">
                <span className="text-lg">⭐</span>
              </div>
              <div>
                <p className="text-2xl font-black text-gray-900">{data.totalRatings}</p>
                <p className="text-xs font-medium text-gray-500">Total Ratings</p>
              </div>
            </div>
            <div className="flex items-center gap-3 rounded-2xl bg-white p-4 shadow-sm border border-gray-100">
              <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-green-50">
                <span className="text-lg">✅</span>
              </div>
              <div>
                <p className="text-2xl font-black text-gray-900">{data.approvedDeals}</p>
                <p className="text-xs font-medium text-gray-500">Active Deals</p>
              </div>
            </div>
            <div className="flex items-center gap-3 rounded-2xl bg-white p-4 shadow-sm border border-gray-100">
              <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-orange-50">
                <span className="text-lg">⏳</span>
              </div>
              <div>
                <p className="text-2xl font-black text-gray-900">{data.pendingDeals}</p>
                <p className="text-xs font-medium text-gray-500">Pending Deals</p>
              </div>
            </div>
          </div>

          {/* Per-collection breakdown */}
          <div className="overflow-hidden rounded-2xl border border-gray-100 bg-white shadow-sm">
            <div className="border-b border-gray-100 bg-gray-50 px-4 py-2">
              <span className="text-xs font-bold uppercase tracking-wide text-gray-600">Listings by Category</span>
            </div>
            <div className="divide-y divide-gray-50">
              {Object.entries(data.listings)
                .sort(([, a], [, b]) => b - a)
                .map(([col, count]) => (
                  <div key={col} className="flex items-center justify-between px-4 py-3">
                    <span className="text-sm font-medium text-gray-700">{COLLECTION_LABELS[col] ?? col}</span>
                    <div className="flex items-center gap-3">
                      <div className="h-2 rounded-full bg-[#283618]" style={{ width: Math.max(4, (count / (data.totalListings || 1)) * 120) }} />
                      <span className="w-8 text-right text-sm font-bold text-gray-900">{count}</span>
                    </div>
                  </div>
                ))}
            </div>
          </div>
        </>
      ) : null}
    </div>
  );
}
