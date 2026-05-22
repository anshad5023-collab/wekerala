'use client';

import { useEffect, useState } from 'react';
import { ToggleLeft, ToggleRight, Loader } from 'lucide-react';

const PROJECT_ID = (process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID ?? 'shoplink-prod').replace(/^﻿/, '');
const API_KEY = process.env.NEXT_PUBLIC_FIREBASE_API_KEY ?? 'AIzaSyCFB9YZL3_bXjvRMoWaYFv8nTs_ote52GQ';
const BASE_REST = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

const ALL_SECTORS = [
  { id: 'shops',         label: 'Shops',            icon: '🛍' },
  { id: 'services',      label: 'Services',          icon: '🔧' },
  { id: 'restaurants',   label: 'Restaurants',       icon: '🍽' },
  { id: 'hotels',        label: 'Hotels',            icon: '🏨' },
  { id: 'doctors',       label: 'Doctors',           icon: '🩺' },
  { id: 'hospitals',     label: 'Hospitals',         icon: '🏥' },
  { id: 'education',     label: 'Education',         icon: '📚' },
  { id: 'home-services', label: 'Home Services',     icon: '🔨' },
  { id: 'beauty',        label: 'Beauty & Wellness', icon: '💆' },
  { id: 'theaters',      label: 'Theaters',          icon: '🎭' },
];

type Visibility = Record<string, boolean>;

export function SectorsTab({ adminPw }: { adminPw: string }) {
  const [visibility, setVisibility] = useState<Visibility>({});
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState<string | null>(null);
  const [error, setError] = useState('');

  useEffect(() => {
    load();
  }, []);

  async function load() {
    setLoading(true);
    setError('');
    try {
      const res = await fetch(`${BASE_REST}/config/sectorVisibility?key=${API_KEY}`);
      if (res.status === 404) {
        // Doc doesn't exist yet — default all sectors ON
        const defaults: Visibility = {};
        ALL_SECTORS.forEach(s => { defaults[s.id] = true; });
        setVisibility(defaults);
      } else if (res.ok) {
        const json = await res.json();
        const fields = json.fields ?? {};
        const parsed: Visibility = {};
        ALL_SECTORS.forEach(s => {
          parsed[s.id] = fields[s.id]?.booleanValue ?? true;
        });
        setVisibility(parsed);
      } else {
        setError('Failed to load sector config.');
      }
    } catch {
      setError('Network error loading sectors.');
    } finally {
      setLoading(false);
    }
  }

  async function toggle(sectorId: string) {
    const newVal = !visibility[sectorId];
    setSaving(sectorId);
    try {
      const allFields: Record<string, unknown> = {};
      ALL_SECTORS.forEach(s => {
        allFields[s.id] = { booleanValue: s.id === sectorId ? newVal : (visibility[s.id] ?? true) };
      });
      const res = await fetch(`${BASE_REST}/config/sectorVisibility?key=${API_KEY}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ fields: allFields }),
      });
      if (!res.ok) throw new Error();
      setVisibility(prev => ({ ...prev, [sectorId]: newVal }));
    } catch {
      setError('Failed to save. Try again.');
    } finally {
      setSaving(null);
    }
  }

  if (loading) return <div className="flex justify-center py-20"><Loader className="h-6 w-6 animate-spin text-gray-400" /></div>;

  return (
    <div className="space-y-4">
      <div className="rounded-2xl border border-amber-100 bg-amber-50 p-4 text-sm text-amber-800">
        <strong>Sector Visibility</strong> — toggle which category buttons appear on the wekerala home page. Hidden sectors still exist in the database; they are just not shown to customers.
      </div>
      {error && <div className="rounded-2xl border border-red-100 bg-red-50 p-3 text-sm text-red-700">{error}</div>}
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
        {ALL_SECTORS.map(sector => {
          const isOn = visibility[sector.id] ?? true;
          const isSaving = saving === sector.id;
          return (
            <div key={sector.id} className="flex items-center justify-between rounded-2xl border border-gray-100 bg-white p-4 shadow-sm">
              <div className="flex items-center gap-3">
                <span className="text-2xl">{sector.icon}</span>
                <div>
                  <p className="font-semibold text-gray-900">{sector.label}</p>
                  <p className="text-xs text-gray-400">{isOn ? 'Visible to users' : 'Hidden from users'}</p>
                </div>
              </div>
              <button
                onClick={() => toggle(sector.id)}
                disabled={isSaving}
                className={`flex items-center gap-1.5 rounded-xl px-3 py-1.5 text-sm font-semibold transition-colors ${
                  isOn
                    ? 'bg-green-100 text-green-700 hover:bg-green-200'
                    : 'bg-gray-100 text-gray-500 hover:bg-gray-200'
                }`}
              >
                {isSaving
                  ? <Loader className="h-4 w-4 animate-spin" />
                  : isOn
                    ? <ToggleRight className="h-4 w-4" />
                    : <ToggleLeft className="h-4 w-4" />
                }
                {isOn ? 'ON' : 'OFF'}
              </button>
            </div>
          );
        })}
      </div>
    </div>
  );
}
