'use client';

import { useState } from 'react';
import { Star, Loader2 } from 'lucide-react';

const COLLECTIONS = ['services', 'theaters', 'hotels', 'restaurants', 'beauty', 'doctors', 'hospitals', 'education', 'homeServices', 'realestate'] as const;

export function FeaturedTab({ adminPw }: { adminPw: string }) {
  const [businessId, setBusinessId] = useState('');
  const [collection, setCollection] = useState<string>('services');
  const [isFeatured, setIsFeatured] = useState(true);
  const [loading, setLoading] = useState(false);
  const [toast, setToast] = useState<{ msg: string; ok: boolean } | null>(null);

  const showToast = (msg: string, ok: boolean) => {
    setToast({ msg, ok });
    setTimeout(() => setToast(null), 3000);
  };

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!businessId.trim()) return;
    setLoading(true);
    try {
      const res = await fetch('/api/admin/featured', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json', 'x-admin-password': adminPw },
        body: JSON.stringify({ businessId: businessId.trim(), collection, isFeatured }),
      });
      if (!res.ok) throw new Error();
      showToast(isFeatured ? `⭐ ${businessId} is now Featured` : `Featured removed from ${businessId}`, true);
      setBusinessId('');
    } catch {
      showToast('Failed to update featured status', false);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div>
      {toast && (
        <div className={`fixed right-4 top-4 z-50 rounded-2xl px-4 py-3 text-sm font-medium text-white shadow-lg ${toast.ok ? 'bg-green-600' : 'bg-red-500'}`}>
          {toast.msg}
        </div>
      )}

      <div className="mb-4">
        <h2 className="text-lg font-bold text-gray-900">Featured Listings</h2>
        <p className="text-xs text-gray-500">Pin businesses to appear at the top of search results and category pages</p>
      </div>

      <form onSubmit={handleSubmit} className="rounded-2xl border border-gray-100 bg-white p-4 shadow-sm space-y-3">
        <div className="flex items-center gap-2 mb-2">
          <Star className="h-5 w-5 text-amber-500" />
          <span className="font-semibold text-sm text-gray-800">Pin / Unpin Featured Business</span>
        </div>

        <div>
          <label className="block text-xs font-medium text-gray-600 mb-1">Business Document ID</label>
          <input
            type="text"
            placeholder="Firestore doc ID (e.g. abc123xyz)"
            value={businessId}
            onChange={(e) => setBusinessId(e.target.value)}
            required
            className="w-full rounded-xl border border-gray-200 px-3 py-2 text-sm outline-none focus:border-[#283618] focus:ring-1 focus:ring-[#283618]/20"
          />
          <p className="mt-1 text-xs text-gray-400">Find the doc ID in the listing URL: /listing/collection/<strong>THIS_ID</strong></p>
        </div>

        <div>
          <label className="block text-xs font-medium text-gray-600 mb-1">Collection</label>
          <select
            value={collection}
            onChange={(e) => setCollection(e.target.value)}
            className="w-full rounded-xl border border-gray-200 bg-white px-3 py-2 text-sm outline-none focus:border-[#283618]"
          >
            {COLLECTIONS.map((c) => <option key={c} value={c}>{c}</option>)}
          </select>
        </div>

        <div className="flex items-center gap-3">
          <label className="text-sm font-medium text-gray-700">Action:</label>
          <button
            type="button"
            onClick={() => setIsFeatured(true)}
            className={`rounded-full px-3 py-1 text-xs font-semibold transition-colors ${isFeatured ? 'bg-amber-500 text-white' : 'bg-gray-100 text-gray-600'}`}
          >
            ⭐ Pin as Featured
          </button>
          <button
            type="button"
            onClick={() => setIsFeatured(false)}
            className={`rounded-full px-3 py-1 text-xs font-semibold transition-colors ${!isFeatured ? 'bg-red-500 text-white' : 'bg-gray-100 text-gray-600'}`}
          >
            ✕ Unpin
          </button>
        </div>

        <button
          type="submit"
          disabled={loading || !businessId.trim()}
          className="flex w-full items-center justify-center gap-2 rounded-xl bg-[#283618] py-2.5 text-sm font-semibold text-[#fefae0] hover:bg-[#1e2912] disabled:opacity-50"
        >
          {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : <Star className="h-4 w-4" />}
          {loading ? 'Updating…' : (isFeatured ? 'Pin as Featured' : 'Remove Featured')}
        </button>
      </form>
    </div>
  );
}
