'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';

// GitHub Releases CDN — auto-redirects to newest release on every new build
const APK_URL = 'https://github.com/anshad5023-collab/wekerala/releases/latest/download/app-release.apk';
const WINDOWS_URL = 'https://github.com/anshad5023-collab/wekerala/releases/latest/download/oratas-setup.exe';

type Platform = 'android' | 'windows' | 'other';

function detectPlatform(): Platform {
  if (typeof navigator === 'undefined') return 'other';
  const ua = navigator.userAgent.toLowerCase();
  if (/android/.test(ua)) return 'android';
  if (/win/.test(ua)) return 'windows';
  return 'other';
}

const FEATURES = [
  { icon: '📦', title: 'Manage Orders', desc: 'Receive and track customer orders in real time' },
  { icon: '🛍', title: 'Product Catalog', desc: 'Add, edit and organise your products with photos' },
  { icon: '💬', title: 'WhatsApp Orders', desc: 'Customers order directly via WhatsApp' },
  { icon: '📊', title: 'Sales Analytics', desc: 'Daily sales charts and top-selling products' },
  { icon: '🖨', title: 'Billing & KOT', desc: 'Print bills and kitchen order tickets' },
  { icon: '🌐', title: 'Your Own Website', desc: 'Publish a free storefront on wekerala.in' },
];

export default function DownloadPage() {
  const [platform, setPlatform] = useState<Platform>('other');

  useEffect(() => {
    setPlatform(detectPlatform());
  }, []);

  const androidPrimary = platform !== 'windows';

  return (
    <div style={{ minHeight: '100dvh', background: 'var(--background)', display: 'flex', flexDirection: 'column' }}>

      {/* Header */}
      <header style={{ background: 'var(--primary)', padding: '14px 20px', display: 'flex', alignItems: 'center', gap: 12 }}>
        <Link href="/" style={{ color: 'var(--primary-foreground)', textDecoration: 'none', fontSize: 20 }}>←</Link>
        <span className="wk-hand" style={{ fontSize: 22, color: 'var(--primary-foreground)' }}>Download Oratas</span>
      </header>

      <div style={{ maxWidth: 960, width: '100%', margin: '0 auto', padding: '32px 20px', flex: 1 }}>

        {/* Hero */}
        <div className="wk-fade-up" style={{ textAlign: 'center', marginBottom: 40 }}>
          <div style={{ width: 88, height: 88, background: 'var(--primary)', borderRadius: 24, display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 16px', fontSize: 48 }}>
            🏪
          </div>
          <h1 style={{ margin: '0 0 8px', fontSize: 28, fontWeight: 800, color: 'var(--foreground)' }}>Oratas Shop Manager</h1>
          <p style={{ margin: 0, fontSize: 16, color: 'var(--muted-foreground)', maxWidth: 480, marginLeft: 'auto', marginRight: 'auto', lineHeight: 1.6 }}>
            Manage your shop from your phone or Windows PC. One app, all platforms.
          </p>
          {platform !== 'other' && (
            <p style={{ marginTop: 10, fontSize: 13, color: 'var(--accent)', fontWeight: 600 }}>
              {platform === 'android' ? '📱 Android detected — download below' : '🖥 Windows detected — download below'}
            </p>
          )}
        </div>

        {/* Download buttons — primary platform first */}
        <div className="wk-fade-up" style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(260px, 1fr))', gap: 16, marginBottom: 48, animationDelay: '60ms' }}>

          {/* Android */}
          <a href={APK_URL} style={{ textDecoration: 'none', order: androidPrimary ? 0 : 1 }}>
            <div
              className="wk-btn-press"
              style={{
                background: androidPrimary ? 'var(--primary)' : 'var(--card)',
                border: `2px solid var(--primary)`,
                borderRadius: 20,
                padding: '28px 24px',
                display: 'flex',
                alignItems: 'center',
                gap: 18,
                cursor: 'pointer',
                boxShadow: androidPrimary ? '0 4px 20px oklch(0.21 0.07 138 / 0.25)' : '0 2px 8px oklch(0.21 0.07 138 / 0.08)',
              }}
            >
              <div style={{ fontSize: 48, lineHeight: 1 }}>📱</div>
              <div>
                <p style={{ margin: '0 0 4px', fontSize: 12, color: androidPrimary ? 'var(--primary-foreground)' : 'var(--muted-foreground)', textTransform: 'uppercase', letterSpacing: 0.5, fontWeight: 600, opacity: 0.75 }}>Download for</p>
                <p style={{ margin: '0 0 4px', fontSize: 22, fontWeight: 800, color: androidPrimary ? 'var(--primary-foreground)' : 'var(--foreground)' }}>Android</p>
                <p style={{ margin: 0, fontSize: 12, color: androidPrimary ? 'var(--primary-foreground)' : 'var(--muted-foreground)', opacity: 0.8 }}>APK · Android 7.0+</p>
              </div>
              <div style={{ marginLeft: 'auto', background: androidPrimary ? 'var(--primary-foreground)' : 'var(--primary)', color: androidPrimary ? 'var(--primary)' : 'var(--primary-foreground)', borderRadius: 12, padding: '8px 16px', fontSize: 13, fontWeight: 700, whiteSpace: 'nowrap' }}>
                Download
              </div>
            </div>
          </a>

          {/* Windows */}
          <a href={WINDOWS_URL} style={{ textDecoration: 'none', order: androidPrimary ? 1 : 0 }}>
            <div
              className="wk-btn-press"
              style={{
                background: !androidPrimary ? 'oklch(0.40 0.18 270)' : 'var(--card)',
                border: `2px solid oklch(0.40 0.18 270)`,
                borderRadius: 20,
                padding: '28px 24px',
                display: 'flex',
                alignItems: 'center',
                gap: 18,
                cursor: 'pointer',
                boxShadow: !androidPrimary ? '0 4px 20px oklch(0.40 0.18 270 / 0.25)' : '0 2px 8px oklch(0.40 0.18 270 / 0.08)',
              }}
            >
              <div style={{ fontSize: 48, lineHeight: 1 }}>🖥</div>
              <div>
                <p style={{ margin: '0 0 4px', fontSize: 12, color: !androidPrimary ? '#fff' : 'var(--muted-foreground)', textTransform: 'uppercase', letterSpacing: 0.5, fontWeight: 600, opacity: 0.75 }}>Download for</p>
                <p style={{ margin: '0 0 4px', fontSize: 22, fontWeight: 800, color: !androidPrimary ? '#fff' : 'var(--foreground)' }}>Windows</p>
                <p style={{ margin: 0, fontSize: 12, color: !androidPrimary ? '#fff' : 'var(--muted-foreground)', opacity: 0.8 }}>Installer · Windows 10+</p>
              </div>
              <div style={{ marginLeft: 'auto', background: !androidPrimary ? '#fff' : 'oklch(0.40 0.18 270)', color: !androidPrimary ? 'oklch(0.40 0.18 270)' : '#fff', borderRadius: 12, padding: '8px 16px', fontSize: 13, fontWeight: 700, whiteSpace: 'nowrap' }}>
                Download
              </div>
            </div>
          </a>
        </div>

        {/* Features */}
        <h2 className="wk-fade-up" style={{ margin: '0 0 20px', fontSize: 18, fontWeight: 700, color: 'var(--foreground)', animationDelay: '100ms' }}>What you get</h2>
        <div className="wk-fade-up" style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(240px, 1fr))', gap: 14, marginBottom: 40, animationDelay: '130ms' }}>
          {FEATURES.map(f => (
            <div key={f.title} style={{ background: 'var(--card)', borderRadius: 16, padding: '16px 18px', display: 'flex', gap: 14, alignItems: 'flex-start', border: '1px solid var(--border)' }}>
              <span style={{ fontSize: 28, lineHeight: 1, marginTop: 2 }}>{f.icon}</span>
              <div>
                <p style={{ margin: '0 0 4px', fontSize: 14, fontWeight: 700, color: 'var(--foreground)' }}>{f.title}</p>
                <p style={{ margin: 0, fontSize: 12, color: 'var(--muted-foreground)', lineHeight: 1.5 }}>{f.desc}</p>
              </div>
            </div>
          ))}
        </div>

        {/* Install instructions */}
        <div className="wk-fade-up" style={{ display: 'flex', flexDirection: 'column', gap: 14, animationDelay: '160ms' }}>

          {/* Android install note */}
          <div style={{ background: 'oklch(0.98 0.06 75)', border: '1px solid oklch(0.85 0.10 75)', borderRadius: 16, padding: 20 }}>
            <p style={{ margin: '0 0 10px', fontSize: 14, fontWeight: 700, color: 'oklch(0.40 0.12 60)' }}>⚠️ Android install note</p>
            <ol style={{ margin: 0, paddingLeft: 18, fontSize: 13, color: 'oklch(0.35 0.10 60)', lineHeight: 1.8 }}>
              <li>Download the APK file</li>
              <li>Open your Downloads folder and tap the file</li>
              <li>If prompted, allow <strong>Install from unknown sources</strong> for your browser</li>
              <li>Tap Install and open the app</li>
            </ol>
          </div>

          {/* Windows install note */}
          <div style={{ background: 'oklch(0.97 0.03 270)', border: '1px solid oklch(0.85 0.08 270)', borderRadius: 16, padding: 20 }}>
            <p style={{ margin: '0 0 10px', fontSize: 14, fontWeight: 700, color: 'oklch(0.35 0.15 270)' }}>🖥 Windows install note</p>
            <ol style={{ margin: 0, paddingLeft: 18, fontSize: 13, color: 'oklch(0.30 0.12 270)', lineHeight: 1.8 }}>
              <li>Download and extract the ZIP file</li>
              <li>Open the extracted folder and double-click <strong>oratas.exe</strong></li>
              <li>If Windows Defender shows a SmartScreen warning, click <strong>More info → Run anyway</strong></li>
              <li>The app will launch — sign in with your phone number</li>
            </ol>
          </div>
        </div>

      </div>
    </div>
  );
}
