'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { ArrowLeft, MapPin, Plus, Trash2, Home, Briefcase, MoreHorizontal } from 'lucide-react';
import { useAuthStore } from '@/lib/auth-store';

interface SavedAddress {
  id: string;
  label: string;
  address: string;
  isDefault: boolean;
}

const LABEL_OPTIONS = ['Home', 'Work', 'Other'] as const;
type LabelOption = typeof LABEL_OPTIONS[number];

function labelIcon(label: string) {
  if (label === 'Home') return <Home className="h-4 w-4" />;
  if (label === 'Work') return <Briefcase className="h-4 w-4" />;
  return <MoreHorizontal className="h-4 w-4" />;
}

export default function CustomerAddressesPage() {
  const { uid } = useAuthStore();
  const [addresses, setAddresses] = useState<SavedAddress[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [deletingId, setDeletingId] = useState<string | null>(null);

  const [newLabel, setNewLabel] = useState<LabelOption>('Home');
  const [newAddress, setNewAddress] = useState('');
  const [newIsDefault, setNewIsDefault] = useState(false);
  const [formError, setFormError] = useState('');

  useEffect(() => {
    if (!uid) { setLoading(false); return; }
    fetch(`/api/customer/addresses?uid=${encodeURIComponent(uid)}`)
      .then((r) => r.json())
      .then((data) => setAddresses((data.addresses ?? []) as SavedAddress[]))
      .catch(() => setAddresses([]))
      .finally(() => setLoading(false));
  }, [uid]);

  async function handleAdd(e: React.FormEvent) {
    e.preventDefault();
    if (!uid) return;
    if (!newAddress.trim()) { setFormError('Address is required'); return; }
    setFormError('');
    setSubmitting(true);
    try {
      const res = await fetch(`/api/customer/addresses?uid=${encodeURIComponent(uid)}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ label: newLabel, address: newAddress.trim(), isDefault: newIsDefault }),
      });
      const data = await res.json() as { ok?: boolean; id?: string; error?: string };
      if (!res.ok || !data.ok) { setFormError(data.error ?? 'Failed to save address'); return; }
      const added: SavedAddress = { id: data.id!, label: newLabel, address: newAddress.trim(), isDefault: newIsDefault };
      setAddresses((prev) => newIsDefault
        ? [added, ...prev.map((a) => ({ ...a, isDefault: false }))]
        : [...prev, added]
      );
      setNewLabel('Home');
      setNewAddress('');
      setNewIsDefault(false);
      setShowForm(false);
    } catch {
      setFormError('Something went wrong. Please try again.');
    } finally {
      setSubmitting(false);
    }
  }

  async function handleDelete(id: string) {
    if (!uid) return;
    setDeletingId(id);
    try {
      await fetch(`/api/customer/addresses?uid=${encodeURIComponent(uid)}&id=${id}`, { method: 'DELETE' });
      setAddresses((prev) => prev.filter((a) => a.id !== id));
    } catch {
      // silently ignore
    } finally {
      setDeletingId(null);
    }
  }

  return (
    <div className="min-h-screen bg-[#f0fdf4]">
      {/* Header */}
      <header className="sticky top-0 z-50 flex items-center gap-3 bg-[#22c55e] px-4 py-3 text-white shadow-md">
        <button
          onClick={() => window.history.back()}
          className="flex items-center justify-center rounded-full p-1.5 hover:bg-white/20 transition-colors"
          aria-label="Go back"
        >
          <ArrowLeft className="h-5 w-5" />
        </button>
        <h1 className="text-lg font-bold italic flex-1">Saved Addresses</h1>
        {uid && (
          <button
            onClick={() => { setShowForm((p) => !p); setFormError(''); }}
            className="flex items-center gap-1.5 rounded-lg bg-white/20 px-3 py-1.5 text-sm font-medium hover:bg-white/30 transition-colors"
          >
            <Plus className="h-4 w-4" />
            Add
          </button>
        )}
      </header>

      <div className="p-4 space-y-4 pb-24 max-w-lg mx-auto">
        {/* Not signed in */}
        {!uid ? (
          <div className="mt-16 text-center px-4">
            <div className="mx-auto mb-4 flex h-20 w-20 items-center justify-center rounded-full bg-primary/10">
              <MapPin className="h-10 w-10 text-primary" />
            </div>
            <h2 className="text-xl font-bold italic text-foreground mb-2">Sign in to manage addresses</h2>
            <p className="italic text-muted-foreground mb-6 text-sm">
              Your saved delivery addresses will appear here after signing in.
            </p>
            <Link
              href="/auth"
              className="inline-block rounded-xl bg-primary px-8 py-3 font-semibold italic text-primary-foreground hover:bg-primary/90 transition-colors"
            >
              Sign In
            </Link>
          </div>
        ) : (
          <>
            {/* Add address form */}
            {showForm && (
              <form
                onSubmit={handleAdd}
                className="rounded-xl border border-green-200 bg-white shadow-sm p-4 space-y-3"
              >
                <h2 className="font-semibold italic text-gray-800">New Address</h2>

                {/* Label picker */}
                <div className="flex gap-2">
                  {LABEL_OPTIONS.map((opt) => (
                    <button
                      key={opt}
                      type="button"
                      onClick={() => setNewLabel(opt)}
                      className={`flex-1 rounded-lg border py-2 text-sm font-medium italic transition-colors ${
                        newLabel === opt
                          ? 'border-primary bg-primary/10 text-primary'
                          : 'border-gray-200 text-gray-500 hover:border-gray-300'
                      }`}
                    >
                      {opt}
                    </button>
                  ))}
                </div>

                {/* Address textarea */}
                <div>
                  <label className="block text-xs font-medium italic text-gray-500 mb-1">
                    Full Address
                  </label>
                  <textarea
                    value={newAddress}
                    onChange={(e) => setNewAddress(e.target.value)}
                    placeholder="House / flat no., street, area, city, district, pincode"
                    rows={3}
                    className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm italic text-gray-800 placeholder:text-gray-400 focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary resize-none"
                  />
                </div>

                {/* Default toggle */}
                <label className="flex items-center gap-2 cursor-pointer select-none">
                  <input
                    type="checkbox"
                    checked={newIsDefault}
                    onChange={(e) => setNewIsDefault(e.target.checked)}
                    className="h-4 w-4 accent-primary"
                  />
                  <span className="text-sm italic text-gray-600">Set as default address</span>
                </label>

                {formError && (
                  <p className="text-sm italic text-red-600">{formError}</p>
                )}

                <div className="flex gap-2 pt-1">
                  <button
                    type="button"
                    onClick={() => { setShowForm(false); setFormError(''); }}
                    className="flex-1 rounded-lg border border-gray-200 py-2 text-sm italic text-gray-500 hover:border-gray-300 transition-colors"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    disabled={submitting}
                    className="flex-1 rounded-lg bg-primary py-2 text-sm font-semibold italic text-white hover:bg-primary/90 transition-colors disabled:opacity-60"
                  >
                    {submitting ? 'Saving…' : 'Save Address'}
                  </button>
                </div>
              </form>
            )}

            {/* Loading skeleton */}
            {loading ? (
              <div className="space-y-3">
                {[1, 2].map((i) => (
                  <div key={i} className="h-24 rounded-xl bg-gray-200 animate-pulse" />
                ))}
              </div>
            ) : addresses.length === 0 && !showForm ? (
              /* Empty state */
              <div className="mt-12 text-center px-4">
                <div className="mx-auto mb-4 flex h-20 w-20 items-center justify-center rounded-full bg-primary/10">
                  <MapPin className="h-10 w-10 text-primary" />
                </div>
                <h2 className="text-xl font-bold italic text-foreground mb-2">No saved addresses</h2>
                <p className="italic text-muted-foreground text-sm mb-6">
                  Tap the Add button above to save a delivery address.
                </p>
              </div>
            ) : (
              /* Address list */
              <div className="space-y-3">
                {addresses.map((addr) => (
                  <div
                    key={addr.id}
                    className={`rounded-xl border bg-white shadow-sm overflow-hidden ${
                      addr.isDefault ? 'border-primary' : 'border-gray-100'
                    }`}
                  >
                    <div className="flex items-start gap-3 p-4">
                      <div className="mt-0.5 flex h-8 w-8 items-center justify-center rounded-full bg-primary/10 text-primary shrink-0">
                        {labelIcon(addr.label)}
                      </div>
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2 mb-0.5">
                          <span className="text-sm font-semibold italic text-gray-800">{addr.label}</span>
                          {addr.isDefault && (
                            <span className="rounded-full bg-primary/10 px-2 py-0.5 text-[10px] font-medium italic text-primary">
                              Default
                            </span>
                          )}
                        </div>
                        <p className="text-sm italic text-gray-600 leading-relaxed">{addr.address}</p>
                      </div>
                      <button
                        onClick={() => handleDelete(addr.id)}
                        disabled={deletingId === addr.id}
                        className="ml-1 flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-red-400 hover:bg-red-50 transition-colors disabled:opacity-40"
                        aria-label="Delete address"
                      >
                        <Trash2 className="h-4 w-4" />
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
}
