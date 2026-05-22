'use client';

import { useState } from 'react';
import { ShieldCheck, Loader2 } from 'lucide-react';

const COLLECTIONS = ['services', 'theaters', 'hotels', 'restaurants', 'beauty', 'doctors', 'hospitals', 'education', 'homeServices', 'realestate'] as const;

export function BadgesTab({ adminPw }: { adminPw: string }) {
  const [businessId, setBusinessId] = useState('');
  const [collection, setCollection] = useState<string>('services');
  const [isVerified, setIsVerified] = useState(true);
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
      const res = await fetch('/api/admin/badges', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json', 'x-admin-password': adminPw },
        body: JSON.stringify({ businessId: businessId.trim(), collection, isVerified }),
      });
      if (!res.ok) throw new Error();
      showToast(isVerified ? `✓ Verified badge granted to ${businessId}` : `Badge removed from ${businessId}`, true);
      setBusinessId('');
    } catch {
      showToast('Failed to update badge', false);
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
        <h2 className="text-lg font-bold text-gray-900">Verified Badges</h2>
        <p className="text-xs text-gray-500">Grant or remove the ✓ Verified badge on any business listing</p>
      </div>

      <form onSubmit={handleSubmit} className="rounded-2xl border border-gray-100 bg-white p-4 shadow-sm space-y-3">
        <div className="flex items-center gap-2 mb-2">
          <ShieldCheck className="h-5 w-5 text-green-600" />
          <span className="font-semibold text-sm text-gray-800">Grant / Revoke Verified Badge</span>
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
            onClick={() => setIsVerified(true)}
            className={`rounded-full px-3 py-1 text-xs font-semibold transition-colors ${isVerified ? 'bg-green-600 text-white' : 'bg-gray-100 text-gray-600'}`}
          >
            ✓ Grant Verified
          </button>
          <button
            type="button"
            onClick={() => setIsVerified(false)}
            className={`rounded-full px-3 py-1 text-xs font-semibold transition-colors ${!isVerified ? 'bg-red-500 text-white' : 'bg-gray-100 text-gray-600'}`}
          >
            ✕ Revoke
          </button>
        </div>

        <button
          type="submit"
          disabled={loading || !businessId.trim()}
          className="flex w-full items-center justify-center gap-2 rounded-xl bg-[#283618] py-2.5 text-sm font-semibold text-[#fefae0] hover:bg-[#1e2912] disabled:opacity-50"
        >
          {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : <ShieldCheck className="h-4 w-4" />}
          {loading ? 'Updating…' : (isVerified ? 'Grant Verified Badge' : 'Revoke Badge')}
        </button>
      </form>
    </div>
  );
}
