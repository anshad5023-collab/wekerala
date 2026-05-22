'use client';

import { useEffect, useState } from 'react';
import { Megaphone, Loader2, CheckCircle } from 'lucide-react';

interface Announcement {
  title: string;
  body: string;
  type: 'info' | 'warning' | 'success';
  active: boolean;
  updatedAt: string;
}

const TYPE_OPTIONS = [
  { value: 'info' as const, label: 'ℹ Info', activeClass: 'bg-blue-100 text-blue-700 ring-2 ring-blue-400', inactiveClass: 'bg-gray-100 text-gray-600' },
  { value: 'warning' as const, label: '⚠ Warning', activeClass: 'bg-amber-100 text-amber-700 ring-2 ring-amber-400', inactiveClass: 'bg-gray-100 text-gray-600' },
  { value: 'success' as const, label: '✓ Success', activeClass: 'bg-green-100 text-green-700 ring-2 ring-green-400', inactiveClass: 'bg-gray-100 text-gray-600' },
];

const TYPE_PREVIEW: Record<string, string> = {
  info: 'bg-blue-50 border-blue-200 text-blue-800',
  warning: 'bg-amber-50 border-amber-200 text-amber-800',
  success: 'bg-green-50 border-green-200 text-green-800',
};

export function AnnouncementsTab({ adminPw }: { adminPw: string }) {
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [current, setCurrent] = useState<Announcement | null>(null);
  const [toast, setToast] = useState<{ msg: string; ok: boolean } | null>(null);

  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [type, setType] = useState<'info' | 'warning' | 'success'>('info');
  const [active, setActive] = useState(true);

  const showToast = (msg: string, ok: boolean) => {
    setToast({ msg, ok });
    setTimeout(() => setToast(null), 3000);
  };

  useEffect(() => {
    fetch('/api/admin/announcements', { headers: { 'x-admin-password': adminPw } })
      .then((r) => r.json())
      .then((data) => {
        const a = data.announcement as Announcement | null;
        if (a) {
          setCurrent(a);
          setTitle(a.title ?? '');
          setBody(a.body ?? '');
          setType(a.type ?? 'info');
          setActive(a.active !== false);
        }
      })
      .catch(() => {})
      .finally(() => setLoading(false));
  }, [adminPw]);

  async function save(overrideActive?: boolean) {
    setSaving(true);
    const activeValue = overrideActive !== undefined ? overrideActive : active;
    try {
      const res = await fetch('/api/admin/announcements', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'x-admin-password': adminPw },
        body: JSON.stringify({ title, body, type, active: activeValue }),
      });
      if (!res.ok) throw new Error();
      const updated: Announcement = { title, body, type, active: activeValue, updatedAt: new Date().toISOString() };
      setCurrent(updated);
      setActive(activeValue);
      showToast(overrideActive !== undefined ? (activeValue ? 'Announcement activated' : 'Announcement deactivated') : 'Announcement saved', true);
    } catch {
      showToast('Failed to save', false);
    } finally {
      setSaving(false);
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
        <h2 className="text-lg font-bold text-gray-900">Platform Announcements</h2>
        <p className="text-xs text-gray-500">Show a banner to all merchants on their control panel dashboard</p>
      </div>

      {/* Current status card */}
      {current && (
        <div className={`mb-5 rounded-2xl border p-4 ${current.active ? 'bg-green-50 border-green-200' : 'bg-gray-50 border-gray-200'}`}>
          <div className="mb-2 flex items-center justify-between">
            <span className="text-xs font-bold uppercase tracking-wide text-gray-500">Current Announcement</span>
            <span className={`rounded-full px-2.5 py-0.5 text-xs font-bold ${current.active ? 'bg-green-600 text-white' : 'bg-gray-300 text-gray-600'}`}>
              {current.active ? '● LIVE' : '○ OFF'}
            </span>
          </div>
          {current.title && <p className="font-semibold text-gray-900 text-sm">{current.title}</p>}
          {current.body && <p className="mt-1 text-xs text-gray-600">{current.body}</p>}
          {current.updatedAt && (
            <p className="mt-2 text-xs text-gray-400">Last updated: {new Date(current.updatedAt).toLocaleString()}</p>
          )}
        </div>
      )}

      {loading ? (
        <div className="flex justify-center py-12">
          <Loader2 className="h-6 w-6 animate-spin text-gray-400" />
        </div>
      ) : (
        <div className="space-y-4">
          {/* Editor card */}
          <div className="rounded-2xl border border-gray-100 bg-white p-4 shadow-sm space-y-4">
            <div className="flex items-center gap-2">
              <Megaphone className="h-5 w-5 text-[#283618]" />
              <span className="font-semibold text-sm text-gray-800">Edit Announcement</span>
            </div>

            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">Title</label>
              <input
                type="text"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                placeholder="e.g. New feature available!"
                className="w-full rounded-xl border border-gray-200 px-3 py-2 text-sm outline-none focus:border-[#283618] focus:ring-1 focus:ring-[#283618]/20"
              />
            </div>

            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1">Message</label>
              <textarea
                value={body}
                onChange={(e) => setBody(e.target.value)}
                placeholder="Message shown to all shop owners on their dashboard…"
                rows={3}
                className="w-full rounded-xl border border-gray-200 px-3 py-2 text-sm outline-none focus:border-[#283618] focus:ring-1 focus:ring-[#283618]/20 resize-none"
              />
            </div>

            <div>
              <label className="block text-xs font-medium text-gray-600 mb-2">Banner style</label>
              <div className="flex gap-2">
                {TYPE_OPTIONS.map((opt) => (
                  <button
                    key={opt.value}
                    type="button"
                    onClick={() => setType(opt.value)}
                    className={`rounded-full px-3 py-1.5 text-xs font-semibold transition-colors ${type === opt.value ? opt.activeClass : opt.inactiveClass}`}
                  >
                    {opt.label}
                  </button>
                ))}
              </div>
            </div>

            {/* Preview */}
            {(title || body) && (
              <div className={`rounded-xl border px-4 py-3 text-sm ${TYPE_PREVIEW[type]}`}>
                <p className="font-semibold">{title || 'Announcement'}</p>
                {body && <p className="mt-0.5 text-xs opacity-80">{body}</p>}
              </div>
            )}

            {/* Active toggle */}
            <div className="flex items-center gap-3">
              <button
                type="button"
                onClick={() => save(!active)}
                disabled={saving}
                className={`rounded-full px-4 py-1.5 text-xs font-bold transition-colors disabled:opacity-50 ${active ? 'bg-green-100 text-green-700 hover:bg-green-200' : 'bg-gray-100 text-gray-500 hover:bg-gray-200'}`}
              >
                {active ? '● Active — shown to merchants' : '○ Inactive — hidden from merchants'}
              </button>
            </div>

            <button
              onClick={() => save()}
              disabled={saving || (!title && !body)}
              className="flex w-full items-center justify-center gap-2 rounded-xl bg-[#283618] py-2.5 text-sm font-semibold text-[#fefae0] hover:bg-[#1e2912] disabled:opacity-50 transition-colors"
            >
              {saving ? <Loader2 className="h-4 w-4 animate-spin" /> : <CheckCircle className="h-4 w-4" />}
              {saving ? 'Saving…' : 'Save Announcement'}
            </button>
          </div>

          <div className="rounded-2xl border border-blue-100 bg-blue-50 p-4 text-sm text-blue-700">
            <strong>How it works:</strong> When active, this banner appears at the top of every merchant&apos;s control panel. Use it for maintenance alerts, new features, or important platform updates. Set it to Inactive to hide it.
          </div>
        </div>
      )}
    </div>
  );
}
