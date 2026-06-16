'use client';

import { useEffect, useState, Suspense } from 'react';
import { useSearchParams } from 'next/navigation';
import { useAuthStore } from '@/lib/auth-store';
import { Switch } from '@/components/ui/switch';
import { THEMES, GOOGLE_FONTS, getTheme, defaultConfig, type ThemeConfig, type WebsiteConfig, type CouponCode } from '@/lib/theme-engine';

type Tab = 'theme' | 'design' | 'pages' | 'offers' | 'plugins';
const ALL_SECTIONS = ['hero', 'products', 'about', 'contact'];

// ── Improvement 1: Color Palette Presets ──────────────────────────────────────
const COLOR_SCHEMES = [
  { name: 'Kerala Green',  primary: '#2D6A4F', secondary: '#74C69D' },
  { name: 'Saffron',       primary: '#E76F51', secondary: '#F4A261' },
  { name: 'Ocean Blue',    primary: '#023E8A', secondary: '#0077B6' },
  { name: 'Festival',      primary: '#FF9500', secondary: '#FFD700' },
  { name: 'Rose',          primary: '#C77DFF', secondary: '#E0AAFF' },
  { name: 'Midnight',      primary: '#1B263B', secondary: '#415A77' },
  { name: 'Fresh Mint',    primary: '#2EC4B6', secondary: '#CBF3F0' },
  { name: 'Crimson',       primary: '#9D0208', secondary: '#E85D04' },
  { name: 'Pure White',    primary: '#1E293B', secondary: '#3B82F6' },
  { name: 'Forest',        primary: '#1B4332', secondary: '#40916C' },
];

// ── Improvement 7: Viewport config ───────────────────────────────────────────
const VIEWPORTS = {
  desktop: { width: '100%',  label: '💻 Desktop' },
  tablet:  { width: '768px', label: '⬛ Tablet' },
  mobile:  { width: '390px', label: '📱 Mobile' },
} as const;

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

  // ── Improvement 3: Upload state ───────────────────────────────────────────
  const [uploading, setUploading] = useState<Record<string, boolean>>({});

  // ── Improvement 4: Drag-to-reorder state ──────────────────────────────────
  const [dragIdx, setDragIdx] = useState<number | null>(null);

  // ── Improvement 5: Expanded section settings state ────────────────────────
  const [expandedSection, setExpandedSection] = useState<string | null>(null);

  // ── Improvement 7: Viewport & preview key state ───────────────────────────
  const [viewport, setViewport] = useState<'desktop' | 'tablet' | 'mobile'>('desktop');
  const [previewKey, setPreviewKey] = useState(0);
  // Mobile-only: shop owners are on phones, but the live preview panel is desktop-
  // only. This lets them flip the whole builder between editing and a live preview.
  const [mobileView, setMobileView] = useState<'edit' | 'preview'>('edit');
  const [iframePreviewToken, setIframePreviewToken] = useState<string>('');

  // ── Session token (server-signed, replaces raw uid in API calls) ──────────
  const [sessionToken, setSessionToken] = useState<string>('');
  useEffect(() => {
    if (!shopId || !uid) return;
    fetch('/api/auth/session', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ shopId, uid }),
    })
      .then(r => r.json())
      .then((d: { token?: string }) => { if (d.token) setSessionToken(d.token); })
      .catch(() => { /* session will fail gracefully — server returns 401 */ });
  }, [shopId, uid]);

  const setC = (partial: Partial<WebsiteConfig>) => { setConfig(prev => ({ ...prev, ...partial })); setDraftSaved(false); };

  // Strip raw control chars (0x00-0x1F) from all strings in a config before sending to API
  const sanitizeConfig = (obj: unknown): unknown => {
    if (typeof obj === 'string') return obj.replace(/[\x00-\x1F]/g, '');
    if (Array.isArray(obj)) return obj.map(sanitizeConfig);
    if (obj && typeof obj === 'object') return Object.fromEntries(Object.entries(obj as Record<string, unknown>).map(([k, v]) => [k, sanitizeConfig(v)]));
    return obj;
  };

  // AI bridge — register window functions so Flutter can apply/undo AI patches
  useEffect(() => {
    // Called by Flutter via evaluateJavascript when AI applies a change.
    // Accepts either a JSON string OR a plain JS object (Flutter passes an object).
    (window as any).__applyAiPatch = (patchOrJson: string | Partial<WebsiteConfig>) => {
      try {
        const patch: Partial<WebsiteConfig> = typeof patchOrJson === 'string'
          ? JSON.parse(patchOrJson) as Partial<WebsiteConfig>
          : patchOrJson;
        // Save checkpoint for undo (only set once per session)
        if (!(window as any).__aiCheckpointSet) {
          (window as any).__aiCheckpoint = JSON.stringify(config);
          (window as any).__aiCheckpointSet = true;
        }
        setConfig(prev => ({ ...prev, ...patch }));
        setDraftSaved(false);
        // Notify Flutter that patch was applied
        try {
          (window as any).WekeralaAI?.postMessage(JSON.stringify({ type: 'patch_applied' }));
        } catch {/* ignore */}
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

  // ── Improvement 2: Inject Google Fonts for visual font picker ─────────────
  useEffect(() => {
    const styleId = 'wb-google-fonts';
    if (document.getElementById(styleId)) return;
    const style = document.createElement('style');
    style.id = styleId;
    style.textContent = `@import url('https://fonts.googleapis.com/css2?family=Poppins:wght@400;600&family=Inter:wght@400;600&family=Playfair+Display:wght@400;600&family=Montserrat:wght@400;600&family=Roboto:wght@400;600&family=Raleway:wght@400;600&family=Nunito:wght@400;600&family=DM+Sans:wght@400;600&family=Space+Grotesk:wght@400;600&family=Outfit:wght@400;600&family=Lato:wght@400;600&family=Open+Sans:wght@400;600&family=Josefin+Sans:wght@400;600&family=Bebas+Neue&family=Sora:wght@400;600&display=swap');`;
    document.head.appendChild(style);
  }, []);

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

  // Fetch preview token for iframe (so draft shows instead of "coming soon")
  useEffect(() => {
    if (!shopId || !sessionToken) return;
    fetch('/api/website/preview-token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${sessionToken}` },
      body: JSON.stringify({ shopId }),
    })
      .then(r => r.json())
      .then(d => { if (d.previewUrl) { const url = new URL(d.previewUrl); setIframePreviewToken(url.searchParams.get('preview') || ''); } })
      .catch(() => {});
  }, [shopId, uid]);

  // Auto-save draft 3 seconds after changes, then refresh preview
  useEffect(() => {
    if (!loaded || !shopId || draftSaved) return;
    const t = setTimeout(async () => {
      try {
        await fetch('/api/website', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', ...(sessionToken ? { 'Authorization': `Bearer ${sessionToken}` } : {}) },
          body: JSON.stringify({ shopId, config: sanitizeConfig(config), draft: true }),
        });
        setDraftSaved(true);
        setPreviewKey(k => k + 1); // refresh iframe to show new font/colors
      } catch { /* silent */ }
    }, 3000);
    return () => clearTimeout(t);
  }, [config, shopId, uid, loaded, draftSaved]);

  // ── Improvement 3: Upload handler ─────────────────────────────────────────
  const handleUpload = async (field: 'logoUrl' | 'faviconUrl', file: File) => {
    setUploading(prev => ({ ...prev, [field]: true }));
    try {
      const formData = new FormData();
      formData.append('file', file);
      formData.append('shopId', shopId);
      const res = await fetch('/api/upload', { method: 'POST', headers: sessionToken ? { 'Authorization': `Bearer ${sessionToken}` } : {}, body: formData });
      const data = await res.json();
      if (data.url) setC({ [field]: data.url });
    } catch (e) {
      console.error('Upload failed', e);
    } finally {
      setUploading(prev => ({ ...prev, [field]: false }));
    }
  };

  const handleBannerUpload = async (file: File) => {
    setUploading(prev => ({ ...prev, banner: true }));
    try {
      const formData = new FormData();
      formData.append('file', file);
      formData.append('shopId', shopId);
      const res = await fetch('/api/upload', { method: 'POST', headers: sessionToken ? { 'Authorization': `Bearer ${sessionToken}` } : {}, body: formData });
      const data = await res.json();
      if (data.url) setC({ banners: [...(config.banners || []), data.url] });
    } catch (e) {
      console.error('Banner upload failed', e);
    } finally {
      setUploading(prev => ({ ...prev, banner: false }));
    }
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
        headers: { 'Content-Type': 'application/json', ...(sessionToken ? { 'Authorization': `Bearer ${sessionToken}` } : {}) },
        body: JSON.stringify({ shopId }),
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
        headers: { 'Content-Type': 'application/json', ...(sessionToken ? { 'Authorization': `Bearer ${sessionToken}` } : {}) },
        body: JSON.stringify({ shopId, config: sanitizeConfig(config) }),
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

  // Only offer non-hidden themes, and derive the filter chips from what's actually
  // available so newly-tagged themes (Food, Shop, …) can never go unlisted again.
  const visibleThemes = THEMES.filter(t => !t.hidden);
  const tags = ['All', ...Array.from(new Set(visibleThemes.map(t => t.tag)))];
  const filtered = themeFilter === 'All' ? visibleThemes : visibleThemes.filter(t => t.tag === themeFilter);
  const currentTheme = getTheme(config.themeId);
  const socialLinks = config.socialLinks || { instagram: '', facebook: '', youtube: '', twitter: '' };

  // ── Improvement 5: Section-level settings panels ───────────────────────────
  const SECTION_SETTINGS: Record<string, React.ReactElement> = {
    products: (
      <div className="mt-2 pl-4 space-y-2 border-l-2 border-blue-100">
        <div>
          <label className="text-xs text-gray-500">Grid Columns</label>
          <div className="flex gap-2 mt-1">
            {[2, 3, 4, 5].map(n => (
              <button
                key={n}
                onClick={() => setC({ productColumns: n } as any)}
                className={`px-3 py-1 text-xs rounded border ${(config as any).productColumns === n ? 'bg-blue-500 text-white border-blue-500' : 'border-gray-300'}`}
              >
                {n}
              </button>
            ))}
          </div>
        </div>
        <label className="flex items-center gap-2 text-xs">
          <input type="checkbox" checked={(config as any).showProductPrice !== false} onChange={e => setC({ showProductPrice: e.target.checked } as any)} />
          Show price
        </label>
        <label className="flex items-center gap-2 text-xs">
          <input type="checkbox" checked={(config as any).showProductRating !== false} onChange={e => setC({ showProductRating: e.target.checked } as any)} />
          Show rating
        </label>
      </div>
    ),
    hero: (
      <div className="mt-2 pl-4 space-y-2 border-l-2 border-blue-100">
        <div>
          <label className="text-xs text-gray-500">Hero Height</label>
          <select
            value={(config as any).heroHeight || 'medium'}
            onChange={e => setC({ heroHeight: e.target.value } as any)}
            className="mt-1 w-full text-xs border border-gray-300 rounded p-1"
          >
            <option value="small">Small (300px)</option>
            <option value="medium">Medium (450px)</option>
            <option value="large">Large (600px)</option>
            <option value="fullscreen">Full Screen</option>
          </select>
        </div>
      </div>
    ),
    about: (
      <div className="mt-2 pl-4 space-y-2 border-l-2 border-blue-100">
        <div>
          <label className="text-xs text-gray-500">Layout</label>
          <select
            value={(config as any).aboutLayout || 'text-only'}
            onChange={e => setC({ aboutLayout: e.target.value } as any)}
            className="mt-1 w-full text-xs border border-gray-300 rounded p-1"
          >
            <option value="text-only">Text only</option>
            <option value="text-image">Text + Image</option>
            <option value="centered">Centered</option>
          </select>
        </div>
      </div>
    ),
  };

  return (
    <div className="flex flex-col h-screen bg-[#f8f9fa]" style={{ maxHeight: '100dvh' }}>

      {/* ── Header ── */}
      <header className="shrink-0 bg-[#283618] text-[#fefae0] px-3 py-3 flex items-center gap-2 z-30">
        <button onClick={() => window.history.back()} className="text-lg mr-1">←</button>
        <span className="hidden sm:inline flex-1 font-semibold text-sm truncate">Website Builder</span>

        {/* Mobile-only Edit/Preview toggle — gives phone users the live preview
            the desktop split-view has. */}
        <div className="flex lg:hidden flex-1 justify-center">
          <div className="inline-flex rounded-lg bg-[#fefae0]/15 p-0.5">
            <button
              onClick={() => setMobileView('edit')}
              className={`px-3 py-1 rounded-md text-xs font-semibold transition-colors ${mobileView === 'edit' ? 'bg-[#fefae0] text-[#283618]' : 'text-[#fefae0]/80'}`}>
              Edit
            </button>
            <button
              onClick={() => { setMobileView('preview'); setPreviewKey(k => k + 1); }}
              className={`px-3 py-1 rounded-md text-xs font-semibold transition-colors ${mobileView === 'preview' ? 'bg-[#fefae0] text-[#283618]' : 'text-[#fefae0]/80'}`}>
              Preview
            </button>
          </div>
        </div>

        {draftSaved && <span className="hidden sm:inline text-xs text-[#fefae0]/50">Saved</span>}
        <button
          onClick={handlePreview}
          className="hidden lg:inline-block px-3 py-1.5 rounded-lg text-xs font-medium border border-[#fefae0]/40 hover:bg-[#fefae0]/10">
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

      {/* ── Improvement 7: Split-view layout ── */}
      <div className="flex flex-1 overflow-hidden">

        {/* ── LEFT: Settings Panel ── */}
        <div className={`w-full lg:w-[420px] lg:min-w-[420px] flex-col border-r border-gray-200 overflow-hidden ${mobileView === 'preview' ? 'hidden lg:flex' : 'flex'}`}>

          {/* Scrollable content area */}
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
                    <input value={config.siteName} onChange={e => { setC({ siteName: e.target.value }); setPublishError(''); }}
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

                  {/* ── Improvement 1: Color Palette Presets ── */}
                  <div>
                    <label className="text-xs text-gray-500 block mb-2">Quick Presets</label>
                    <div className="grid grid-cols-5 gap-2 mb-4">
                      {COLOR_SCHEMES.map(scheme => (
                        <button
                          key={scheme.name}
                          onClick={() => setC({ primaryColor: scheme.primary, secondaryColor: scheme.secondary })}
                          className="flex flex-col items-center gap-1 p-2 rounded-lg border border-gray-200 hover:border-blue-400 transition-colors"
                          title={scheme.name}
                        >
                          <div className="flex gap-1">
                            <div className="w-4 h-4 rounded-full border border-gray-300" style={{ background: scheme.primary }} />
                            <div className="w-4 h-4 rounded-full border border-gray-300" style={{ background: scheme.secondary }} />
                          </div>
                          <span className="text-[10px] text-gray-500 text-center leading-tight">{scheme.name}</span>
                        </button>
                      ))}
                    </div>
                  </div>

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

                  {/* ── Improvement 2: Font Visual Picker ── */}
                  <div>
                    <label className="text-xs text-gray-500 block mb-2">Font Family</label>
                    <div className="grid grid-cols-2 gap-2">
                      {GOOGLE_FONTS.map(font => (
                        <button
                          key={font}
                          onClick={() => setC({ fontFamily: font })}
                          className={`p-3 rounded-lg border text-left transition-colors ${
                            config.fontFamily === font
                              ? 'border-blue-500 bg-blue-50'
                              : 'border-gray-200 hover:border-gray-400'
                          }`}
                        >
                          <span style={{ fontFamily: font }} className="text-sm block">
                            {font}
                          </span>
                          <span style={{ fontFamily: font }} className="text-xs text-gray-500 block">
                            Fresh Vegetables Daily
                          </span>
                        </button>
                      ))}
                    </div>
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

                {/* Branding — Improvement 3: Image Uploader */}
                <section className="bg-white rounded-xl p-4 space-y-3">
                  <h3 className="font-semibold text-sm text-gray-700">Branding</h3>
                  <div>
                    <label className="text-xs text-gray-500">Logo URL (override shop logo)</label>
                    <div className="flex gap-2 mt-1">
                      <input value={config.logoUrl || ''} onChange={e => setC({ logoUrl: e.target.value })}
                        className="flex-1 px-3 py-2 border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[#283618]"
                        placeholder="https://... (leave blank to use shop logo)" />
                      <label className="cursor-pointer px-3 py-2 text-xs bg-gray-100 hover:bg-gray-200 rounded-lg border border-gray-300 flex items-center gap-1 whitespace-nowrap">
                        {uploading['logoUrl'] ? '...' : '📎 Upload'}
                        <input
                          type="file"
                          accept="image/*"
                          className="hidden"
                          onChange={e => { const f = e.target.files?.[0]; if (f) handleUpload('logoUrl', f); }}
                        />
                      </label>
                    </div>
                  </div>
                  <div>
                    <label className="text-xs text-gray-500">Favicon URL</label>
                    <div className="flex gap-2 mt-1">
                      <input value={config.faviconUrl || ''} onChange={e => setC({ faviconUrl: e.target.value })}
                        className="flex-1 px-3 py-2 border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-[#283618]"
                        placeholder="https://... 32×32px icon" />
                      <label className="cursor-pointer px-3 py-2 text-xs bg-gray-100 hover:bg-gray-200 rounded-lg border border-gray-300 flex items-center gap-1 whitespace-nowrap">
                        {uploading['faviconUrl'] ? '...' : '📎 Upload'}
                        <input
                          type="file"
                          accept="image/*"
                          className="hidden"
                          onChange={e => { const f = e.target.files?.[0]; if (f) handleUpload('faviconUrl', f); }}
                        />
                      </label>
                    </div>
                  </div>
                </section>

                {/* Sections — Improvements 4 & 5: Drag-to-reorder + Section settings */}
                <section className="bg-white rounded-xl p-4 space-y-2">
                  <h3 className="font-semibold text-sm text-gray-700">Sections</h3>
                  <p className="text-xs text-gray-400">Drag to reorder. Click ▶ for section settings.</p>
                  {config.sections.map((sec, i) => (
                    <div key={sec}>
                      <div
                        draggable
                        onDragStart={() => setDragIdx(i)}
                        onDragOver={e => { e.preventDefault(); }}
                        onDrop={() => {
                          if (dragIdx === null || dragIdx === i) return;
                          const newSections = [...config.sections];
                          const [moved] = newSections.splice(dragIdx, 1);
                          newSections.splice(i, 0, moved);
                          setC({ sections: newSections });
                          setDragIdx(null);
                        }}
                        className={`flex items-center gap-2 p-2 rounded-lg border bg-white cursor-grab active:cursor-grabbing transition-opacity ${
                          dragIdx === i ? 'opacity-50' : 'opacity-100'
                        }`}
                      >
                        <span className="text-gray-400 cursor-grab select-none">⠿</span>
                        <span className="flex-1 text-sm capitalize font-medium">{sec}</span>
                        {SECTION_SETTINGS[sec] && (
                          <button
                            onClick={() => setExpandedSection(expandedSection === sec ? null : sec)}
                            className={`text-xs px-1.5 py-0.5 rounded transition-colors ${expandedSection === sec ? 'text-blue-600 bg-blue-50' : 'text-gray-400 hover:text-gray-600'}`}
                          >
                            {expandedSection === sec ? '▼' : '▶'}
                          </button>
                        )}
                        <button
                          onClick={() => setC({ sections: config.sections.filter(s => s !== sec) })}
                          className="text-gray-400 hover:text-red-500 text-xs px-1"
                        >
                          ✕
                        </button>
                      </div>
                      {expandedSection === sec && SECTION_SETTINGS[sec] && (
                        <div className="px-2 pb-1">
                          {SECTION_SETTINGS[sec]}
                        </div>
                      )}
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

                {/* Extra banners — Improvement 3: Banner upload */}
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
                  <label className="cursor-pointer flex items-center gap-2 px-3 py-2 text-xs bg-gray-100 hover:bg-gray-200 rounded-lg border border-gray-300 w-full justify-center">
                    {uploading['banner'] ? 'Uploading...' : '📎 Upload Banner Image'}
                    <input
                      type="file"
                      accept="image/*"
                      className="hidden"
                      onChange={e => { const f = e.target.files?.[0]; if (f) handleBannerUpload(f); }}
                    />
                  </label>
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

                {/* ── Improvement 6: Custom HTML Editor ── */}
                <section className="bg-white rounded-xl p-4 space-y-2">
                  <div className="flex items-center justify-between">
                    <div>
                      <p className="text-sm font-medium">Custom Code</p>
                      <p className="text-xs text-gray-500">Add custom HTML/CSS/JS to your site footer</p>
                    </div>
                  </div>
                  <textarea
                    value={(config as any).customHtml || ''}
                    onChange={e => setC({ customHtml: e.target.value } as any)}
                    placeholder="<!-- Add custom HTML, CSS, or tracking scripts here -->"
                    rows={6}
                    className="w-full text-xs font-mono border border-gray-300 rounded-lg p-3 resize-y focus:outline-none focus:ring-2 focus:ring-blue-500"
                    spellCheck={false}
                  />
                  <p className="text-xs text-gray-400">⚠️ Only add code you trust. Injected into every page.</p>
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

        {/* ── RIGHT: Live Preview Panel — always on desktop; on mobile shown when
              the Edit/Preview toggle is set to Preview ── */}
        <div className={`flex-1 flex-col bg-gray-100 ${mobileView === 'preview' ? 'flex' : 'hidden'} lg:flex`}>

          {/* Viewport toggle bar — desktop only (mobile preview is already phone-width) */}
          <div className="hidden lg:flex items-center gap-2 p-3 border-b border-gray-200 bg-white shrink-0">
            {(Object.entries(VIEWPORTS) as [keyof typeof VIEWPORTS, typeof VIEWPORTS[keyof typeof VIEWPORTS]][]).map(([key, val]) => (
              <button
                key={key}
                onClick={() => setViewport(key)}
                className={`px-3 py-1.5 text-xs rounded-lg transition-colors ${viewport === key ? 'bg-blue-500 text-white' : 'bg-gray-100 hover:bg-gray-200'}`}
              >
                {val.label}
              </button>
            ))}
            <div className="flex-1" />
            <button
              onClick={() => setPreviewKey(k => k + 1)}
              className="px-3 py-1.5 text-xs bg-gray-100 hover:bg-gray-200 rounded-lg transition-colors"
            >
              ↻ Refresh
            </button>
          </div>

          {/* Preview iframe container */}
          <div className="flex-1 overflow-auto flex items-start justify-center p-4">
            <div
              style={{
                width: VIEWPORTS[viewport].width,
                maxWidth: '100%',
                height: '100%',
                minHeight: '600px',
                transition: 'width 0.3s ease',
              }}
              className="shadow-lg rounded-lg overflow-hidden bg-white"
            >
              <iframe
                key={previewKey}
                src={shopId && iframePreviewToken ? `/sites/${shopId}?preview=${iframePreviewToken}` : shopId ? `/sites/${shopId}` : 'about:blank'}
                className="w-full h-full border-0"
                style={{ minHeight: '600px' }}
                title="Site Preview"
              />
            </div>
          </div>

        </div>

      </div>
      {/* end split-view layout */}

    </div>
  );
}
