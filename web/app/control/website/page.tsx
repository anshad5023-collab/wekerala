'use client';

import { useEffect, useState, Suspense } from 'react';
import { useSearchParams } from 'next/navigation';
import { useAuthStore } from '@/lib/auth-store';
import { Switch } from '@/components/ui/switch';
import { THEMES, GOOGLE_FONTS, getTheme, defaultConfig, type ThemeConfig, type WebsiteConfig, type CouponCode } from '@/lib/theme-engine';

type Tab = 'theme' | 'design' | 'pages' | 'offers' | 'plugins';
const ALL_SECTIONS = ['hero', 'products', 'about', 'contact'];

function ThemeMiniPreview({ theme }: { theme: ThemeConfig }) {
  const { defaults, layout } = theme;
  const isDark = ['dark', 'neopop', 'luxury'].includes(layout);
  const cardBg = isDark ? `${defaults.primaryColor}28` : '#ebebeb';
  const heroBg = layout === 'neopop'
    ? `linear-gradient(135deg,${defaults.primaryColor},${defaults.secondaryColor})`
    : layout === 'editorial' ? '#cccccc'
    : defaults.primaryColor;

  return (
    <div className="w-full h-28 rounded-t-xl overflow-hidden relative" style={{ backgroundColor: defaults.bgColor }}>
      {layout === 'festival' && (
        <div className="absolute top-0 left-0 right-0 h-1 z-10"
          style={{ background: `linear-gradient(to right,${defaults.primaryColor},${defaults.secondaryColor})` }} />
      )}
      <div className="h-10 w-full" style={{ background: heroBg }} />
      <div className={`p-1.5 ${layout === 'luxury' ? 'space-y-1' : 'grid grid-cols-2 gap-1'}`}>
        {[1, 2, 3, 4].map(i =>
          layout === 'luxury' ? (
            <div key={i} className="h-4 rounded flex gap-1 overflow-hidden" style={{ backgroundColor: '#111' }}>
              <div className="w-4 h-full" style={{ backgroundColor: `${defaults.primaryColor}40` }} />
            </div>
          ) : (
            <div key={i} className="h-7 rounded"
              style={{ backgroundColor: cardBg, border: layout === 'neopop' ? `1px solid ${defaults.primaryColor}50` : undefined }} />
          )
        )}
      </div>
      <div className="absolute bottom-1.5 right-1.5 w-4 h-4 rounded-full bg-green-500" />
    </div>
  );
}

function AddCouponForm({ onAdd }: { onAdd: (c: CouponCode) => void }) {
  const [code, setCode] = useState('');
  const [pct, setPct] = useState('10');
  return (
    <div className="bg-white rounded-xl p-4 border-2 border-dashed border-gray-200">
      <p className="text-xs font-semibold text-gray-500 mb-3">Add New Coupon</p>
      <div className="flex gap-2">
        <input value={code} onChange={e => setCode(e.target.value.toUpperCase())}
          className="flex-1 px-3 py-2 border rounded-lg text-sm font-mono focus:outline-none focus:ring-2 focus:ring-[#283618]"
          placeholder="CODE" maxLength={20} />
        <div className="relative w-24">
          <input type="number" value={pct} onChange={e => setPct(e.target.value)}
            min="1" max="100"
            className="w-full px-3 py-2 border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[#283618]"
            placeholder="%" />
          <span className="absolute right-2.5 top-2 text-gray-400 text-sm">%</span>
        </div>
        <button
          onClick={() => {
            if (!code.trim() || !pct) return;
            onAdd({ code: code.trim(), discountPercent: parseInt(pct, 10), active: true });
            setCode(''); setPct('10');
          }}
          className="px-3 py-2 rounded-lg text-sm font-semibold text-white shrink-0"
          style={{ backgroundColor: '#283618' }}>
          Add
        </button>
      </div>
    </div>
  );
}

export default function WebsiteBuilderPage() {
  return (
    <Suspense fallback={<div className="min-h-screen bg-[#f8f9fa] flex items-center justify-center text-gray-400">Loading…</div>}>
      <BuilderContent />
    </Suspense>
  );
}

function BuilderContent() {
  const params = useSearchParams();
  const { setUser } = useAuthStore();
  const shopId = params.get('shopId') || '';
  const uid = params.get('uid') || '';

  if (!shopId) {
    return (
      <div style={{ minHeight: '100dvh', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 16, padding: 32, textAlign: 'center', background: '#f8f9fa' }}>
        <div style={{ fontSize: 56 }}>🌐</div>
        <h2 style={{ margin: 0, fontSize: 22, fontWeight: 800, color: '#111827' }}>Open from Control Panel</h2>
        <p style={{ margin: 0, color: '#6b7280', fontSize: 14, maxWidth: 320, lineHeight: 1.6 }}>
          The Website Builder needs to know which shop to edit.<br />Please open it from your business dashboard.
        </p>
        <a href="/control" style={{ padding: '12px 28px', background: '#283618', color: '#fefae0', borderRadius: 24, textDecoration: 'none', fontWeight: 700, fontSize: 14 }}>
          Go to Control Panel →
        </a>
      </div>
    );
  }

  const [activeTab, setActiveTab] = useState<Tab>('theme');
  const [themeFilter, setThemeFilter] = useState('All');
  const [config, setConfig] = useState<WebsiteConfig>(defaultConfig());
  const [publishStatus, setPublishStatus] = useState<'idle' | 'publishing' | 'success' | 'error'>('idle');
  const [publishError, setPublishError] = useState('');
  const [siteUrl, setSiteUrl] = useState('');
  const [slugUrl, setSlugUrl] = useState('');
  const [newBanner, setNewBanner] = useState('');
  const [draftSaved, setDraftSaved] = useState(false);
  const [loaded, setLoaded] = useState(false);

  const setC = (partial: Partial<WebsiteConfig>) => { setConfig(prev => ({ ...prev, ...partial })); setDraftSaved(false); };

  // AI bridge — register window functions so Flutter can apply/undo AI patches
  useEffect(() => {
    // Called by Flutter via evaluateJavascript when AI applies a change
    (window as any).__applyAiPatch = (patchJson: string) => {
      try {
        const patch = JSON.parse(patchJson) as Partial<WebsiteConfig>;
        // Save checkpoint for undo (only set once per session)
        if (!(window as any).__aiCheckpointSet) {
          (window as any).__aiCheckpoint = JSON.stringify(config);
          (window as any).__aiCheckpointSet = true;
        }
        setConfig(prev => ({ ...prev, ...patch }));
        setDraftSaved(false);
        // Notify Flutter that patch was applied
        (window as any).__aiPatchApplied = true;
      } catch (e) {
        console.error('[AI Bridge] Failed to apply patch:', e);
      }
    };

    // Called by Flutter to undo last AI changes
    (window as any).__undoAiChanges = () => {
      const checkpoint = (window as any).__aiCheckpoint;
      if (checkpoint) {
        try {
          setConfig(JSON.parse(checkpoint));
          setDraftSaved(false);
          (window as any).__aiCheckpointSet = false;
          (window as any).__aiCheckpoint = null;
        } catch (e) {
          console.error('[AI Bridge] Failed to undo:', e);
        }
      }
    };

    // Called by Flutter to get current config as JSON string
    (window as any).__getCurrentConfig = () => JSON.stringify(config);

    return () => {
      delete (window as any).__applyAiPatch;
      delete (window as any).__undoAiChanges;
      delete (window as any).__getCurrentConfig;
    };
  }, [config]); // keep bridge up to date with latest config

  useEffect(() => {
    if (uid) setUser(uid, '');
    if (!shopId) return;
    fetch(`/api/website?shopId=${shopId}`)
      .then(r => r.json())
      .then(data => {
        const base = defaultConfig(data.website?.themeId || 'modern', { shopName: data.shopName, ownerPhone: data.ownerPhone });
        if (data.website) {
          const w = data.website as Record<string, unknown>;
          setConfig({ ...base, ...Object.fromEntries(Object.entries(w).filter(([, v]) => v !== null && v !== undefined)) } as WebsiteConfig);
        } else {
          setConfig(base);
        }
        setLoaded(true);
      })
      .catch(() => { setLoaded(true); });
  }, [shopId, uid, setUser]);

  // Auto-save draft every 8 seconds after changes
  useEffect(() => {
    if (!loaded || !shopId || draftSaved) return;
    const t = setTimeout(async () => {
      try {
        await fetch('/api/website', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ shopId, uid, config, draft: true }),
        });
        setDraftSaved(true);
      } catch { /* silent */ }
    }, 8000);
    return () => clearTimeout(t);
  }, [config, shopId, uid, loaded, draftSaved]);

  const moveSection = (i: number, dir: -1 | 1) => {
    const secs = [...config.sections];
    const t = i + dir;
    if (t < 0 || t >= secs.length) return;
    [secs[i], secs[t]] = [secs[t], secs[i]];
    setC({ sections: secs });
  };

  const addBanner = () => {
    if (!newBanner.trim()) return;
    setC({ banners: [...(config.banners || []), newBanner.trim()] });
    setNewBanner('');
  };

  const handlePreview = async () => {
    try {
      const res = await fetch('/api/website/preview-token', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ shopId, uid }),
      });
      const data = await res.json();
      window.open(data.previewUrl, '_blank');
    } catch {
      // Fallback to old behavior if token generation fails
      window.open(`/sites/${shopId}?preview=true`, '_blank');
    }
  };

  const handlePublish = async () => {
    setPublishStatus('publishing');
    setPublishError('');
    try {
      const res = await fetch('/api/website', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ shopId, uid, config }),
      });
      if (!res.ok) {
        const d = await res.json().catch(() => ({}));
        throw new Error((d as { error?: string }).error || `Error ${res.status}`);
      }
      const d = await res.json().catch(() => ({})) as { siteUrl?: string; slugUrl?: string };
      const primary = d.siteUrl || `https://wekerala.vercel.app/sites/${shopId}`;
      setSiteUrl(primary);
      setSlugUrl(d.slugUrl || primary);
      setPublishStatus('success');
    } catch (e) {
      setPublishError(e instanceof Error ? e.message : 'Failed to publish');
      setPublishStatus('error');
    }
  };

  const tags = ['All', 'Minimal', 'Dark', 'Kerala', 'D2C', 'Fashion', 'Premium', 'Catalog', 'B2B'];
  const filtered = themeFilter === 'All' ? THEMES : THEMES.filter(t => t.tag === themeFilter);
  const currentTheme = getTheme(config.themeId);
  const socialLinks = config.socialLinks || { instagram: '', facebook: '', youtube: '', twitter: '' };

  return (
    <div className="flex flex-col h-screen bg-[#f8f9fa]" style={{ maxHeight: '100dvh' }}>

      {/* ── Header ── */}
      <header className="shrink-0 bg-[#283618] text-[#fefae0] px-3 py-3 flex items-center gap-2 z-30">
        <button onClick={() => window.history.back()} className="text-lg mr-1">←</button>
        <span className="flex-1 font-semibold text-sm truncate">Website Builder</span>
        {draftSaved && <span className="text-xs text-[#fefae0]/50">Saved</span>}
        <button
          onClick={handlePreview}
          className="px-3 py-1.5 rounded-lg text-xs font-medium border border-[#fefae0]/40 hover:bg-[#fefae0]/10">
          Preview
        </button>
        {publishStatus === 'success' && (
          <button
            onClick={() => {
              const url = siteUrl || `https://wekerala.vercel.app/sites/${shopId}`;
              if (navigator.share) navigator.share({ title: config.siteName, url });
              else navigator.clipboard.writeText(url);
            }}
            className="px-3 py-1.5 rounded-lg text-xs font-medium border border-[#fefae0]/40 hover:bg-[#fefae0]/10">
            Share
          </button>
        )}
        <button
          onClick={handlePublish}
          disabled={publishStatus === 'publishing'}
          className="px-3 py-1.5 rounded-lg text-xs font-bold text-[#283618] disabled:opacity-60"
          style={{ backgroundColor: '#dda15e' }}>
          {publishStatus === 'publishing' ? '…' : config.isPublished ? '✓ Update' : 'Publish'}
        </button>
      </header>

      {/* ── Scrollable content ── */}
      <main className="flex-1 overflow-y-auto">

        {publishStatus === 'success' && (
          <div className="bg-green-50 border-b border-green-200 px-4 py-3 space-y-1">
            <p className="text-green-800 font-medium text-sm">✓ Your site is live!</p>
            <p className="text-green-700 text-xs break-all font-mono">{siteUrl}</p>
            <div className="flex gap-3 mt-1.5">
              <button onClick={() => navigator.clipboard.writeText(siteUrl)}
                className="text-xs text-green-700 underline">Copy link</button>
              <a href={siteUrl} target="_blank" rel="noopener noreferrer"
                className="text-xs text-green-700 underline">Open site →</a>
            </div>
            {slugUrl && slugUrl !== siteUrl && (
              <p className="text-green-600 text-xs break-all">Also accessible at: {slugUrl}</p>
            )}
          </div>
        )}
        {publishStatus === 'error' && (
          <div className="bg-red-50 border-b border-red-200 px-4 py-3">
            <p className="text-red-700 text-sm font-medium">
              {publishError?.includes('already taken') ? '⚠ Site name taken' : '✕ Failed to publish'}
            </p>
            <p className="text-red-600 text-xs mt-0.5">{publishError}</p>
          </div>
        )}

        {/* Draft status banner — shown when there are unsaved AI changes on a live site */}
        {!draftSaved && config.isPublished && (
          <div className="bg-amber-50 border-b border-amber-200 px-4 py-2 flex items-center gap-2 text-sm text-amber-800">
            <span>⚡</span>
            <span>You have unpublished changes from AI. Preview them or publish when ready.</span>
          </div>
        )}

        {/* ──── THEME TAB ──── */}
        {activeTab === 'theme' && (
          <div className="p-4">
            <div className="flex gap-2 overflow-x-auto pb-2 scrollbar-hide">
              {tags.map(tag => (
                <button key={tag} onClick={() => setThemeFilter(tag)}
                  className="shrink-0 px-3 py-1 rounded-full text-xs font-medium"
                  style={themeFilter === tag
                    ? { backgroundColor: '#283618', color: '#fefae0' }
                    : { backgroundColor: '#e5e7eb', color: '#374151' }}>
                  {tag}
                </button>
              ))}
            </div>
            <div className="grid grid-cols-2 gap-3 mt-3">
              {filtered.map(theme => {
                const active = config.themeId === theme.id;
                return (
                  <div key={theme.id} className="rounded-xl overflow-hidden border-2 bg-white"
                    style={{ borderColor: active ? '#283618' : '#e5e7eb' }}>
                    <ThemeMiniPreview theme={theme} />
                    <div className="p-2.5">
                      <div className="flex items-center justify-between gap-1">
                        <span className="font-semibold text-sm truncate">{theme.name}</span>
                        <span className="shrink-0 text-xs px-1.5 py-0.5 rounded-full bg-gray-100 text-gray-500">{theme.tag}</span>
                      </div>
                      <p className="text-xs text-gray-400 mt-0.5 line-clamp-1">{theme.description}</p>
                      <button
                        onClick={() => {
                          setC({ themeId: theme.id, primaryColor: theme.defaults.primaryColor, secondaryColor: theme.defaults.secondaryColor, fontFamily: theme.defaults.fontFamily });
                          setActiveTab('design');
                        }}
                        className="w-full mt-2 py-1.5 rounded-lg text-xs font-semibold"
                        style={active ? { backgroundColor: '#283618', color: '#fefae0' } : { backgroundColor: '#f3f4f6', color: '#374151' }}>
                        {active ? '✓ Selected' : 'Use This →'}
                      </button>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        )}

        {/* ──── DESIGN TAB ──── */}
        {activeTab === 'design' && (
          <div className="p-4 space-y-5">
            {/* Current theme indicator */}
            <div className="flex items-center gap-2 p-2.5 bg-white rounded-xl border">
              <div className="w-24 shrink-0 rounded-xl overflow-hidden"><ThemeMiniPreview theme={currentTheme} /></div>
              <div className="pl-1 flex-1 min-w-0">
                <p className="font-semibold text-sm">{currentTheme.name}</p>
                <p className="text-xs text-gray-400">{currentTheme.tag}</p>
                <button onClick={() => setActiveTab('theme')} className="text-xs text-[#283618] underline mt-1">Change theme</button>
              </div>
            </div>

            {/* Announcement bar */}
            <section className="bg-white rounded-xl p-4 space-y-3">
              <div className="flex items-center justify-between">
                <h3 className="font-semibold text-sm text-gray-700">📢 Announcement Bar</h3>
                <Switch checked={config.announcementBarEnabled || false} onCheckedChange={v => setC({ announcementBarEnabled: v })} />
              </div>
              {config.announcementBarEnabled && (
                <>
                  <input value={config.announcementBar || ''} onChange={e => setC({ announcementBar: e.target.value })}
                    className="w-full px-3 py-2 border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[#283618]"
                    placeholder="🎉 Free delivery on orders above ₹500!" />
                  <div className="flex items-center gap-3">
                    <label className="text-xs text-gray-500 shrink-0">Bar colour</label>
                    <input type="color" value={config.announcementBarColor || config.primaryColor}
                      onChange={e => setC({ announcementBarColor: e.target.value })}
                      className="w-9 h-9 rounded-lg border cursor-pointer p-0.5" />
                    <span className="text-xs text-gray-400 font-mono">{config.announcementBarColor || config.primaryColor}</span>
                  </div>
                </>
              )}
            </section>

            {/* Site info */}
            <section className="bg-white rounded-xl p-4 space-y-3">
              <h3 className="font-semibold text-sm text-gray-700">Site Info</h3>
              <div>
                <label className="text-xs text-gray-500">Site Name</label>
                <input value={config.siteName} onChange={e => setC({ siteName: e.target.value })}
                  className="w-full mt-1 px-3 py-2 border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[#283618]"
                  placeholder="My Shop" />
              </div>
              <div>
                <label className="text-xs text-gray-500">Tagline</label>
                <input value={config.tagline} onChange={e => setC({ tagline: e.target.value })}
                  className="w-full mt-1 px-3 py-2 border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[#283618]"
                  placeholder="Fresh & quality, delivered fast" />
              </div>
              <div>
                <label className="text-xs text-gray-500">About Text</label>
                <textarea value={config.aboutText} onChange={e => setC({ aboutText: e.target.value })}
                  rows={3} className="w-full mt-1 px-3 py-2 border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[#283618]"
                  placeholder="Tell customers about your shop…" />
              </div>
              <div>
                <label className="text-xs text-gray-500">Order Button Text</label>
                <input value={config.primaryButtonText || 'Order Now'} onChange={e => setC({ primaryButtonText: e.target.value })}
                  className="w-full mt-1 px-3 py-2 border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[#283618]"
                  placeholder="Order Now" />
              </div>
            </section>

            {/* Colours & font */}
            <section className="bg-white rounded-xl p-4 space-y-3">
              <h3 className="font-semibold text-sm text-gray-700">Colours & Font</h3>
              <div className="flex gap-4">
                <div className="flex-1">
                  <label className="text-xs text-gray-500">Primary</label>
                  <div className="flex items-center gap-2 mt-1">
                    <input type="color" value={config.primaryColor} onChange={e => setC({ primaryColor: e.target.value })}
                      className="w-10 h-10 rounded-lg border cursor-pointer p-0.5" />
                    <span className="text-xs text-gray-400 font-mono">{config.primaryColor}</span>
                  </div>
                </div>
                <div className="flex-1">
                  <label className="text-xs text-gray-500">Secondary</label>
                  <div className="flex items-center gap-2 mt-1">
                    <input type="color" value={config.secondaryColor} onChange={e => setC({ secondaryColor: e.target.value })}
                      className="w-10 h-10 rounded-lg border cursor-pointer p-0.5" />
                    <span className="text-xs text-gray-400 font-mono">{config.secondaryColor}</span>
                  </div>
                </div>
              </div>
              <div>
                <label className="text-xs text-gray-500">Font Family</label>
                <select value={config.fontFamily} onChange={e => setC({ fontFamily: e.target.value })}
                  className="w-full mt-1 px-3 py-2 border rounded-lg text-sm focus:outline-none bg-white"
                  style={{ fontFamily: config.fontFamily }}>
                  {GOOGLE_FONTS.map(f => <option key={f} value={f} style={{ fontFamily: f }}>{f}</option>)}
                </select>
              </div>
            </section>

            {/* Social Links */}
            <section className="bg-white rounded-xl p-4 space-y-3">
              <h3 className="font-semibold text-sm text-gray-700">Social Links</h3>
              {([
                { key: 'instagram', label: '📸 Instagram', placeholder: 'https://instagram.com/yourshop' },
                { key: 'facebook',  label: '📘 Facebook',  placeholder: 'https://facebook.com/yourpage' },
                { key: 'youtube',   label: '📺 YouTube',   placeholder: 'https://youtube.com/@yourshop' },
                { key: 'twitter',   label: '🐦 Twitter/X', placeholder: 'https://x.com/yourshop' },
              ] as { key: keyof typeof socialLinks; label: string; placeholder: string }[]).map(({ key, label, placeholder }) => (
                <div key={key}>
                  <label className="text-xs text-gray-500">{label}</label>
                  <input
                    value={socialLinks[key] || ''}
                    onChange={e => setC({ socialLinks: { ...socialLinks, [key]: e.target.value } })}
                    className="w-full mt-1 px-3 py-2 border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[#283618]"
                    placeholder={placeholder} />
                </div>
              ))}
            </section>

            {/* SEO */}
            <section className="bg-white rounded-xl p-4 space-y-3">
              <h3 className="font-semibold text-sm text-gray-700">🔍 SEO Settings</h3>
              <p className="text-xs text-gray-400">Controls how your site appears on Google search.</p>
              <div>
                <label className="text-xs text-gray-500">Page Title (for Google)</label>
                <input value={config.seoTitle || ''} onChange={e => setC({ seoTitle: e.target.value })}
                  className="w-full mt-1 px-3 py-2 border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[#283618]"
                  placeholder={config.siteName || 'My Shop — Kerala'} />
              </div>
              <div>
                <label className="text-xs text-gray-500">Meta Description</label>
                <textarea value={config.seoDescription || ''} onChange={e => setC({ seoDescription: e.target.value })}
                  rows={2} className="w-full mt-1 px-3 py-2 border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[#283618]"
                  placeholder="Best shop in Kerala. Fresh products, fast delivery to your door." />
              </div>
            </section>

            {/* Branding */}
            <section className="bg-white rounded-xl p-4 space-y-3">
              <h3 className="font-semibold text-sm text-gray-700">Branding</h3>
              <div>
                <label className="text-xs text-gray-500">Logo URL (override shop logo)</label>
                <input value={config.logoUrl || ''} onChange={e => setC({ logoUrl: e.target.value })}
                  className="w-full mt-1 px-3 py-2 border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[#283618]"
                  placeholder="https://... (leave blank to use shop logo)" />
              </div>
              <div>
                <label className="text-xs text-gray-500">Favicon URL</label>
                <input value={config.faviconUrl || ''} onChange={e => setC({ faviconUrl: e.target.value })}
                  className="w-full mt-1 px-3 py-2 border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[#283618]"
                  placeholder="https://... 32×32px icon" />
              </div>
            </section>

            {/* Sections */}
            <section className="bg-white rounded-xl p-4 space-y-2">
              <h3 className="font-semibold text-sm text-gray-700">Sections</h3>
              <p className="text-xs text-gray-400">Reorder with arrows. Remove or re-add sections.</p>
              {config.sections.map((sec, i) => (
                <div key={sec} className="flex items-center gap-2 px-3 py-2 bg-gray-50 rounded-lg">
                  <span className="flex-1 text-sm capitalize font-medium">{sec}</span>
                  <button onClick={() => moveSection(i, -1)} disabled={i === 0}
                    className="w-7 h-7 flex items-center justify-center rounded text-gray-400 hover:bg-gray-200 disabled:opacity-20 text-base">↑</button>
                  <button onClick={() => moveSection(i, 1)} disabled={i === config.sections.length - 1}
                    className="w-7 h-7 flex items-center justify-center rounded text-gray-400 hover:bg-gray-200 disabled:opacity-20 text-base">↓</button>
                  <button onClick={() => setC({ sections: config.sections.filter(s => s !== sec) })}
                    className="w-7 h-7 flex items-center justify-center rounded text-red-400 hover:bg-red-50 text-sm">✕</button>
                </div>
              ))}
              {ALL_SECTIONS.filter(s => !config.sections.includes(s)).map(sec => (
                <button key={sec} onClick={() => setC({ sections: [...config.sections, sec] })}
                  className="w-full p-2 border-2 border-dashed border-gray-200 rounded-lg text-sm text-gray-400 hover:border-[#dda15e] hover:text-[#dda15e]">
                  + Add {sec} section
                </button>
              ))}
            </section>

            {/* WhatsApp */}
            <section className="bg-white rounded-xl p-4 space-y-3">
              <div className="flex items-center justify-between">
                <h3 className="font-semibold text-sm text-gray-700">💬 WhatsApp Button</h3>
                <Switch checked={config.whatsappEnabled} onCheckedChange={v => setC({ whatsappEnabled: v })} />
              </div>
              {config.whatsappEnabled && (
                <input value={config.whatsappNumber} onChange={e => setC({ whatsappNumber: e.target.value })}
                  className="w-full px-3 py-2 border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[#283618]"
                  placeholder="919876543210 (with country code)" />
              )}
            </section>

            {/* Store Hours */}
            <section className="bg-white rounded-xl p-4 space-y-3">
              <div className="flex items-center justify-between">
                <h3 className="font-semibold text-sm text-gray-700">🕐 Store Hours</h3>
                <Switch checked={config.storeHoursEnabled} onCheckedChange={v => setC({ storeHoursEnabled: v })} />
              </div>
              {config.storeHoursEnabled && (
                <input value={config.storeHoursText} onChange={e => setC({ storeHoursText: e.target.value })}
                  className="w-full px-3 py-2 border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[#283618]"
                  placeholder="Mon–Sat: 9am–9pm, Sun: Closed" />
              )}
            </section>

            {/* Delivery Settings */}
            <section className="bg-white rounded-xl p-4 space-y-3">
              <h3 className="font-semibold text-sm text-gray-700">🚚 Delivery Settings</h3>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-xs text-gray-500">Delivery Charge (₹)</label>
                  <input type="number" min="0"
                    value={config.deliveryCharge ?? 0}
                    onChange={e => setC({ deliveryCharge: Number(e.target.value) })}
                    className="w-full mt-1 px-3 py-2 border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[#283618]"
                    placeholder="0 = Free" />
                </div>
                <div>
                  <label className="text-xs text-gray-500">Free Above (₹)</label>
                  <input type="number" min="0"
                    value={config.freeDeliveryAbove ?? 0}
                    onChange={e => setC({ freeDeliveryAbove: Number(e.target.value) })}
                    className="w-full mt-1 px-3 py-2 border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[#283618]"
                    placeholder="0 = always" />
                </div>
              </div>
              <div>
                <label className="text-xs text-gray-500">Minimum Order Amount (₹)</label>
                <input type="number" min="0"
                  value={config.minOrderAmount ?? 0}
                  onChange={e => setC({ minOrderAmount: Number(e.target.value) })}
                  className="w-full mt-1 px-3 py-2 border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[#283618]"
                  placeholder="0 = no minimum" />
              </div>
              <p className="text-xs text-gray-400">
                {(config.deliveryCharge ?? 0) === 0
                  ? 'Free delivery on all orders'
                  : (config.freeDeliveryAbove ?? 0) > 0
                    ? `₹${config.deliveryCharge} delivery · Free above ₹${config.freeDeliveryAbove}`
                    : `₹${config.deliveryCharge} delivery charge`}
              </p>
            </section>

            {/* Extra banners */}
            <section className="bg-white rounded-xl p-4 space-y-3">
              <h3 className="font-semibold text-sm text-gray-700">Extra Banners <span className="text-gray-400 font-normal text-xs">(for hero carousel)</span></h3>
              {(config.banners || []).map((url, i) => (
                <div key={i} className="flex items-center gap-2">
                  <p className="flex-1 text-xs text-gray-500 truncate">{url}</p>
                  <button onClick={() => setC({ banners: config.banners.filter((_, idx) => idx !== i) })}
                    className="text-red-400 text-sm shrink-0">✕</button>
                </div>
              ))}
              <div className="flex gap-2">
                <input value={newBanner} onChange={e => setNewBanner(e.target.value)}
                  className="flex-1 px-3 py-2 border rounded-lg text-sm focus:outline-none"
                  placeholder="https://... image URL" />
                <button onClick={addBanner} className="px-3 py-2 rounded-lg text-sm font-medium text-white"
                  style={{ backgroundColor: '#283618' }}>+ Add</button>
              </div>
            </section>
          </div>
        )}

        {/* ──── PAGES TAB ──── */}
        {activeTab === 'pages' && (
          <div className="p-4 space-y-4">
            <p className="text-xs text-gray-500">Custom pages appear in your site navigation when enabled.</p>
            {([
              { label: 'About Us',        contentKey: 'customAbout' as const,    visibleKey: 'showAboutPage' as const },
              { label: 'Contact Us',       contentKey: 'customContact' as const,  visibleKey: 'showContactPage' as const },
              { label: 'Shipping Policy',  contentKey: 'customShipping' as const, visibleKey: 'showShippingPage' as const },
              { label: 'Return Policy',    contentKey: 'customReturn' as const,   visibleKey: 'showReturnPage' as const },
              { label: 'Privacy Policy',   contentKey: 'customPrivacy' as const,  visibleKey: 'showPrivacyPage' as const },
            ]).map(page => (
              <section key={page.label} className="bg-white rounded-xl p-4 space-y-3">
                <div className="flex items-center justify-between">
                  <h3 className="font-semibold text-sm text-gray-700">{page.label}</h3>
                  <Switch checked={config[page.visibleKey] as boolean} onCheckedChange={v => setC({ [page.visibleKey]: v })} />
                </div>
                {config[page.visibleKey] && (
                  <textarea
                    value={config[page.contentKey] as string}
                    onChange={e => setC({ [page.contentKey]: e.target.value })}
                    rows={5}
                    className="w-full px-3 py-2 border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[#283618]"
                    placeholder={`Write your ${page.label} here…`} />
                )}
              </section>
            ))}
          </div>
        )}

        {/* ──── OFFERS TAB ──── */}
        {activeTab === 'offers' && (
          <div className="p-4 space-y-4">
            <div className="bg-amber-50 border border-amber-200 rounded-xl p-3">
              <p className="text-xs text-amber-800 font-semibold mb-1">🎟 Coupon Codes</p>
              <p className="text-xs text-amber-700">Customers enter these codes at checkout to get a discount. Codes are case-insensitive.</p>
            </div>

            {(config.couponCodes || []).length === 0 && (
              <div className="text-center py-8">
                <p className="text-3xl mb-2">🎁</p>
                <p className="text-sm text-gray-500">No coupon codes yet.</p>
              </div>
            )}

            {(config.couponCodes || []).map((coupon, i) => (
              <div key={i} className="bg-white rounded-xl p-4 flex items-center gap-3 border border-gray-100">
                <div className="flex-1 min-w-0">
                  <p className="font-mono font-bold text-sm text-gray-800 tracking-wider">{coupon.code}</p>
                  <p className="text-xs text-gray-500 mt-0.5">{coupon.discountPercent}% off entire order</p>
                </div>
                <Switch checked={coupon.active} onCheckedChange={v => {
                  const codes = [...(config.couponCodes || [])];
                  codes[i] = { ...codes[i], active: v };
                  setC({ couponCodes: codes });
                }} />
                <button onClick={() => {
                  const codes = [...(config.couponCodes || [])];
                  codes.splice(i, 1);
                  setC({ couponCodes: codes });
                }} className="text-red-400 hover:text-red-600 text-base shrink-0">✕</button>
              </div>
            ))}

            <AddCouponForm onAdd={c => setC({ couponCodes: [...(config.couponCodes || []), c] })} />
          </div>
        )}

        {/* ──── PLUGINS TAB ──── */}
        {activeTab === 'plugins' && (
          <div className="p-4 space-y-4">
            <p className="text-xs text-gray-500">Paste the ID from each service. Leave blank to disable.</p>

            <section className="bg-white rounded-xl p-4 space-y-2">
              <div className="flex items-start gap-3">
                <span className="text-2xl">📊</span>
                <div className="flex-1">
                  <h3 className="font-semibold text-sm">Google Analytics</h3>
                  <p className="text-xs text-gray-400 mt-0.5">Track visitors — get your ID from analytics.google.com</p>
                  <input value={config.googleAnalyticsId} onChange={e => setC({ googleAnalyticsId: e.target.value })}
                    className="w-full mt-2 px-3 py-2 border rounded-lg text-sm focus:outline-none font-mono"
                    placeholder="G-XXXXXXXXXX" />
                </div>
              </div>
            </section>

            <section className="bg-white rounded-xl p-4 space-y-2">
              <div className="flex items-start gap-3">
                <span className="text-2xl">📱</span>
                <div className="flex-1">
                  <h3 className="font-semibold text-sm">Facebook Pixel</h3>
                  <p className="text-xs text-gray-400 mt-0.5">Track for Facebook/Instagram Ads — get ID from Meta Business Suite</p>
                  <input value={config.facebookPixelId} onChange={e => setC({ facebookPixelId: e.target.value })}
                    className="w-full mt-2 px-3 py-2 border rounded-lg text-sm focus:outline-none font-mono"
                    placeholder="1234567890" />
                </div>
              </div>
            </section>

            <section className="bg-white rounded-xl p-4 space-y-2">
              <div className="flex items-start gap-3">
                <span className="text-2xl">💬</span>
                <div className="flex-1">
                  <h3 className="font-semibold text-sm">Live Chat — Tawk.To (Free)</h3>
                  <p className="text-xs text-gray-400 mt-0.5">Adds a live chat bubble — get property ID from tawk.to</p>
                  <input value={config.tawkPropertyId} onChange={e => setC({ tawkPropertyId: e.target.value })}
                    className="w-full mt-2 px-3 py-2 border rounded-lg text-sm focus:outline-none font-mono"
                    placeholder="abc123def456/1hxyz..." />
                </div>
              </div>
            </section>

            <section className="bg-white rounded-xl p-4">
              <div className="flex items-center gap-3">
                <span className="text-2xl">⭐</span>
                <div className="flex-1">
                  <h3 className="font-semibold text-sm">Customer Reviews</h3>
                  <p className="text-xs text-gray-400 mt-0.5">Show star ratings on product cards</p>
                </div>
                <Switch checked={config.reviewsEnabled} onCheckedChange={v => setC({ reviewsEnabled: v })} />
              </div>
            </section>
          </div>
        )}

      </main>

      {/* ── Bottom Tabs ── */}
      <nav className="shrink-0 bg-white border-t border-gray-200 flex z-30">
        {([
          { id: 'theme',   label: 'Theme',   icon: '🎨' },
          { id: 'design',  label: 'Design',  icon: '✏️' },
          { id: 'pages',   label: 'Pages',   icon: '📄' },
          { id: 'offers',  label: 'Offers',  icon: '🎟' },
          { id: 'plugins', label: 'Plugins', icon: '🔌' },
        ] as { id: Tab; label: string; icon: string }[]).map(tab => (
          <button key={tab.id} onClick={() => setActiveTab(tab.id)}
            className="relative flex-1 flex flex-col items-center gap-0.5 py-2.5 text-xs font-medium transition-colors"
            style={{ color: activeTab === tab.id ? '#283618' : '#9ca3af' }}>
            <span className="text-base leading-none">{tab.icon}</span>
            <span className="text-[10px]">{tab.label}</span>
            {activeTab === tab.id && <div className="absolute bottom-0 left-1/2 -translate-x-1/2 h-0.5 w-8 rounded-full" style={{ backgroundColor: '#283618' }} />}
          </button>
        ))}
      </nav>

    </div>
  );
}
