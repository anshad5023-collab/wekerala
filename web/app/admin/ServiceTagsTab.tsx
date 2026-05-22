'use client';

import { useEffect, useState, useCallback } from 'react';
import { Plus, ToggleLeft, ToggleRight, Trash2, Tag, Loader2, RefreshCw, Upload } from 'lucide-react';
import { SERVICE_SECTORS, SERVICE_TAGS_SEED, type ServiceSector } from '@/lib/wk-constants';

interface ServiceTag {
  id: string;
  name: string;
  nameMl: string;
  sector: string;
  isActive: boolean;
  createdAt: string;
}

export function ServiceTagsTab({ adminPw }: { adminPw: string }) {
  const [tags, setTags] = useState<ServiceTag[]>([]);
  const [loading, setLoading] = useState(false);
  const [actionId, setActionId] = useState<string | null>(null);
  const [toast, setToast] = useState<{ msg: string; ok: boolean } | null>(null);
  const [seeding, setSeeding] = useState(false);
  const [filterSector, setFilterSector] = useState<string>('All');

  // New tag form
  const [newName, setNewName] = useState('');
  const [newNameMl, setNewNameMl] = useState('');
  const [newSector, setNewSector] = useState<ServiceSector>('Home Services');
  const [adding, setAdding] = useState(false);

  const showToast = (msg: string, ok: boolean) => {
    setToast({ msg, ok });
    setTimeout(() => setToast(null), 3000);
  };

  const fetchTags = useCallback(async () => {
    setLoading(true);
    try {
      const res = await fetch('/api/service-tags?adminAll=true', {
        headers: { 'x-admin-password': adminPw },
      });
      if (!res.ok) throw new Error();
      const data = await res.json();
      setTags(data.tags ?? []);
    } catch {
      showToast('Failed to load tags', false);
    } finally {
      setLoading(false);
    }
  }, [adminPw]);

  useEffect(() => { fetchTags(); }, [fetchTags]);

  async function handleToggle(tag: ServiceTag) {
    setActionId(tag.id);
    try {
      const res = await fetch('/api/service-tags', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json', 'x-admin-password': adminPw },
        body: JSON.stringify({ id: tag.id, isActive: !tag.isActive }),
      });
      if (!res.ok) throw new Error();
      setTags((prev) => prev.map((t) => t.id === tag.id ? { ...t, isActive: !t.isActive } : t));
      showToast(tag.isActive ? 'Tag hidden from owners' : 'Tag shown to owners', true);
    } catch {
      showToast('Update failed', false);
    } finally {
      setActionId(null);
    }
  }

  async function handleDelete(tag: ServiceTag) {
    if (!confirm(`Delete "${tag.name}"? This cannot be undone.`)) return;
    setActionId(tag.id);
    try {
      const res = await fetch(`/api/service-tags?id=${tag.id}`, {
        method: 'DELETE',
        headers: { 'x-admin-password': adminPw },
      });
      if (!res.ok) throw new Error();
      setTags((prev) => prev.filter((t) => t.id !== tag.id));
      showToast('Tag deleted', true);
    } catch {
      showToast('Delete failed', false);
    } finally {
      setActionId(null);
    }
  }

  async function handleAdd(e: React.FormEvent) {
    e.preventDefault();
    if (!newName.trim()) return;
    setAdding(true);
    try {
      const res = await fetch('/api/service-tags', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'x-admin-password': adminPw },
        body: JSON.stringify({ name: newName, nameMl: newNameMl, sector: newSector }),
      });
      if (!res.ok) throw new Error();
      const data = await res.json();
      const newTag: ServiceTag = {
        id: data.id,
        name: newName.trim(),
        nameMl: newNameMl.trim(),
        sector: newSector,
        isActive: true,
        createdAt: new Date().toISOString(),
      };
      setTags((prev) => [...prev, newTag].sort((a, b) => {
        const s = a.sector.localeCompare(b.sector);
        return s !== 0 ? s : a.name.localeCompare(b.name);
      }));
      setNewName('');
      setNewNameMl('');
      showToast(`"${newTag.name}" added`, true);
    } catch {
      showToast('Failed to add tag', false);
    } finally {
      setAdding(false);
    }
  }

  async function handleSeedAll() {
    if (!confirm(`This will add all ${SERVICE_TAGS_SEED.length} default service tags to Firestore. Existing tags will NOT be duplicated — but this doesn't check for duplicates automatically. Proceed?`)) return;
    setSeeding(true);
    let added = 0;
    let failed = 0;
    for (const tag of SERVICE_TAGS_SEED) {
      try {
        const res = await fetch('/api/service-tags', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'x-admin-password': adminPw },
          body: JSON.stringify(tag),
        });
        if (res.ok) added++;
        else failed++;
      } catch {
        failed++;
      }
    }
    showToast(`Seeded ${added} tags${failed > 0 ? `, ${failed} failed` : ''}`, failed === 0);
    fetchTags();
    setSeeding(false);
  }

  const sectors = ['All', ...SERVICE_SECTORS] as const;
  const filteredTags = filterSector === 'All' ? tags : tags.filter((t) => t.sector === filterSector);
  const grouped = filteredTags.reduce<Record<string, ServiceTag[]>>((acc, tag) => {
    const s = tag.sector || 'Uncategorised';
    if (!acc[s]) acc[s] = [];
    acc[s].push(tag);
    return acc;
  }, {});

  return (
    <div>
      {/* Toast */}
      {toast && (
        <div className={`fixed right-4 top-4 z-50 rounded-2xl px-4 py-3 text-sm font-medium text-white shadow-lg ${toast.ok ? 'bg-green-600' : 'bg-red-500'}`}>
          {toast.msg}
        </div>
      )}

      {/* Header row */}
      <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <div>
          <h2 className="text-lg font-bold text-gray-900">Service Tags</h2>
          <p className="text-xs text-gray-500">{tags.length} tags · {tags.filter(t => t.isActive).length} active</p>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={fetchTags}
            disabled={loading}
            className="flex items-center gap-1.5 rounded-xl border border-gray-200 px-3 py-1.5 text-xs font-medium text-gray-600 hover:bg-gray-50"
          >
            <RefreshCw className={`h-3.5 w-3.5 ${loading ? 'animate-spin' : ''}`} />
            Refresh
          </button>
          <button
            onClick={handleSeedAll}
            disabled={seeding}
            className="flex items-center gap-1.5 rounded-xl bg-amber-50 px-3 py-1.5 text-xs font-semibold text-amber-700 hover:bg-amber-100 disabled:opacity-50"
          >
            {seeding ? <Loader2 className="h-3.5 w-3.5 animate-spin" /> : <Upload className="h-3.5 w-3.5" />}
            {seeding ? 'Seeding…' : `Seed ${SERVICE_TAGS_SEED.length} Tags`}
          </button>
        </div>
      </div>

      {/* Add tag form */}
      <form onSubmit={handleAdd} className="mb-6 rounded-2xl border border-gray-100 bg-white p-4 shadow-sm">
        <p className="mb-3 text-sm font-semibold text-gray-700">Add New Tag</p>
        <div className="flex flex-wrap gap-2">
          <input
            type="text"
            placeholder="Tag name (English) *"
            value={newName}
            onChange={(e) => setNewName(e.target.value)}
            required
            className="flex-1 min-w-[160px] rounded-xl border border-gray-200 px-3 py-2 text-sm outline-none focus:border-[#283618] focus:ring-1 focus:ring-[#283618]/20"
          />
          <input
            type="text"
            placeholder="Malayalam name (optional)"
            value={newNameMl}
            onChange={(e) => setNewNameMl(e.target.value)}
            className="flex-1 min-w-[160px] rounded-xl border border-gray-200 px-3 py-2 text-sm outline-none focus:border-[#283618] focus:ring-1 focus:ring-[#283618]/20"
          />
          <select
            value={newSector}
            onChange={(e) => setNewSector(e.target.value as ServiceSector)}
            className="rounded-xl border border-gray-200 px-3 py-2 text-sm outline-none focus:border-[#283618] focus:ring-1 focus:ring-[#283618]/20 bg-white"
          >
            {SERVICE_SECTORS.map((s) => <option key={s} value={s}>{s}</option>)}
          </select>
          <button
            type="submit"
            disabled={adding || !newName.trim()}
            className="flex items-center gap-1.5 rounded-xl bg-[#283618] px-4 py-2 text-sm font-semibold text-[#fefae0] hover:bg-[#1e2912] disabled:opacity-50"
          >
            {adding ? <Loader2 className="h-4 w-4 animate-spin" /> : <Plus className="h-4 w-4" />}
            Add
          </button>
        </div>
      </form>

      {/* Sector filter */}
      <div className="mb-4 flex flex-wrap gap-2">
        {sectors.map((s) => (
          <button
            key={s}
            onClick={() => setFilterSector(s)}
            className={`rounded-full px-3 py-1 text-xs font-semibold transition-colors ${
              filterSector === s
                ? 'bg-[#283618] text-[#fefae0]'
                : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
            }`}
          >
            {s}
          </button>
        ))}
      </div>

      {/* Tags grouped by sector */}
      {loading ? (
        <div className="space-y-2">
          {Array.from({ length: 4 }).map((_, i) => (
            <div key={i} className="h-12 rounded-2xl bg-white shadow-sm animate-pulse" />
          ))}
        </div>
      ) : Object.keys(grouped).length === 0 ? (
        <div className="flex flex-col items-center gap-3 py-16 text-center">
          <Tag className="h-10 w-10 text-gray-300" />
          <p className="text-gray-500 text-sm">No tags yet.</p>
          <p className="text-xs text-gray-400">Click &ldquo;Seed {SERVICE_TAGS_SEED.length} Tags&rdquo; to load all default service types.</p>
        </div>
      ) : (
        <div className="space-y-4">
          {Object.entries(grouped).sort(([a], [b]) => a.localeCompare(b)).map(([sector, sectorTags]) => (
            <div key={sector} className="overflow-hidden rounded-2xl border border-gray-100 bg-white shadow-sm">
              <div className="border-b border-gray-100 bg-gray-50 px-4 py-2 flex items-center justify-between">
                <span className="text-xs font-bold uppercase tracking-wide text-gray-600">{sector}</span>
                <span className="text-xs text-gray-400">{sectorTags.length} tags</span>
              </div>
              <div className="divide-y divide-gray-50">
                {sectorTags.map((tag) => (
                  <div key={tag.id} className={`flex items-center justify-between px-4 py-2.5 transition-colors ${tag.isActive ? '' : 'bg-gray-50/60 opacity-60'}`}>
                    <div className="flex items-center gap-2.5 min-w-0">
                      <span className="font-medium text-sm text-gray-900 truncate">{tag.name}</span>
                      {tag.nameMl && (
                        <span className="text-xs text-gray-400 truncate">{tag.nameMl}</span>
                      )}
                    </div>
                    <div className="flex items-center gap-1.5 shrink-0">
                      <span className={`rounded-full px-2 py-0.5 text-xs font-semibold ${tag.isActive ? 'bg-green-50 text-green-700' : 'bg-gray-100 text-gray-500'}`}>
                        {tag.isActive ? 'Active' : 'Hidden'}
                      </span>
                      <button
                        onClick={() => handleToggle(tag)}
                        disabled={actionId === tag.id}
                        title={tag.isActive ? 'Hide from owners' : 'Show to owners'}
                        className="rounded-lg p-1.5 text-gray-400 hover:bg-gray-100 hover:text-gray-700 disabled:opacity-40"
                      >
                        {actionId === tag.id
                          ? <Loader2 className="h-4 w-4 animate-spin" />
                          : tag.isActive
                            ? <ToggleRight className="h-4 w-4 text-green-600" />
                            : <ToggleLeft className="h-4 w-4" />}
                      </button>
                      <button
                        onClick={() => handleDelete(tag)}
                        disabled={actionId === tag.id}
                        title="Delete tag"
                        className="rounded-lg p-1.5 text-gray-400 hover:bg-red-50 hover:text-red-600 disabled:opacity-40"
                      >
                        <Trash2 className="h-3.5 w-3.5" />
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
