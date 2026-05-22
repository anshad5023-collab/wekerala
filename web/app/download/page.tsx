'use client';

import Link from 'next/link';

const APK_URL = '/api/download-app';
const WINDOWS_URL = 'https://firebasestorage.googleapis.com/v0/b/shoplink-prod.firebasestorage.app/o/releases%2Foratas-setup.exe?alt=media';

const FEATURES = [
  { icon: '📦', title: 'Manage Orders', desc: 'Receive and track customer orders in real time' },
  { icon: '🛍', title: 'Product Catalog', desc: 'Add, edit and organise your products with photos' },
  { icon: '💬', title: 'WhatsApp Orders', desc: 'Customers order directly via WhatsApp' },
  { icon: '📊', title: 'Sales Analytics', desc: 'Daily sales charts and top-selling products' },
  { icon: '🖨', title: 'Billing & KOT', desc: 'Print bills and kitchen order tickets' },
  { icon: '🌐', title: 'Your Own Website', desc: 'Publish a free storefront on wekerala.in' },
];

export default function DownloadPage() {
  return (
    <div style={{ minHeight: '100dvh', background: '#f8f9fa', display: 'flex', flexDirection: 'column' }}>

      {/* Header */}
      <header style={{ background: '#283618', padding: '14px 20px', display: 'flex', alignItems: 'center', gap: 12 }}>
        <Link href="/" style={{ color: '#fefae0', textDecoration: 'none', fontSize: 20 }}>←</Link>
        <span style={{ fontFamily: 'Caveat, cursive', fontSize: 22, color: '#fefae0' }}>Download Oratas</span>
      </header>

      <div style={{ maxWidth: 960, width: '100%', margin: '0 auto', padding: '32px 20px', flex: 1 }}>

        {/* Hero */}
        <div style={{ textAlign: 'center', marginBottom: 40 }}>
          <div style={{ width: 88, height: 88, background: '#283618', borderRadius: 24, display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 16px', fontSize: 48 }}>
            🏪
          </div>
          <h1 style={{ margin: '0 0 8px', fontSize: 28, fontWeight: 800, color: '#111827' }}>Oratas Shop Manager</h1>
          <p style={{ margin: 0, fontSize: 16, color: '#6b7280', maxWidth: 480, marginLeft: 'auto', marginRight: 'auto', lineHeight: 1.6 }}>
            Manage your shop from your phone or Windows PC. One app, all platforms.
          </p>
        </div>

        {/* Download buttons */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(260px, 1fr))', gap: 16, marginBottom: 48 }}>

          {/* Android */}
          <a href={APK_URL} style={{ textDecoration: 'none' }}>
            <div style={{ background: '#fff', border: '2px solid #283618', borderRadius: 20, padding: '28px 24px', display: 'flex', alignItems: 'center', gap: 18, cursor: 'pointer', transition: 'box-shadow 0.2s', boxShadow: '0 2px 8px rgba(40,54,24,0.08)' }}>
              <div style={{ fontSize: 48, lineHeight: 1 }}>📱</div>
              <div>
                <p style={{ margin: '0 0 4px', fontSize: 12, color: '#9ca3af', textTransform: 'uppercase', letterSpacing: 0.5, fontWeight: 600 }}>Download for</p>
                <p style={{ margin: '0 0 4px', fontSize: 22, fontWeight: 800, color: '#111827' }}>Android</p>
                <p style={{ margin: 0, fontSize: 12, color: '#6b7280' }}>APK · Android 7.0+</p>
              </div>
              <div style={{ marginLeft: 'auto', background: '#283618', color: '#fefae0', borderRadius: 12, padding: '8px 16px', fontSize: 13, fontWeight: 700 }}>
                Download
              </div>
            </div>
          </a>

          {/* Windows */}
          <a href={WINDOWS_URL} style={{ textDecoration: 'none' }}>
            <div style={{ background: '#fff', border: '2px solid #4f46e5', borderRadius: 20, padding: '28px 24px', display: 'flex', alignItems: 'center', gap: 18, cursor: 'pointer', boxShadow: '0 2px 8px rgba(79,70,229,0.08)' }}>
              <div style={{ fontSize: 48, lineHeight: 1 }}>🖥</div>
              <div>
                <p style={{ margin: '0 0 4px', fontSize: 12, color: '#9ca3af', textTransform: 'uppercase', letterSpacing: 0.5, fontWeight: 600 }}>Download for</p>
                <p style={{ margin: '0 0 4px', fontSize: 22, fontWeight: 800, color: '#111827' }}>Windows</p>
                <p style={{ margin: 0, fontSize: 12, color: '#6b7280' }}>Desktop · Windows 10+</p>
              </div>
              <div style={{ marginLeft: 'auto', background: '#4f46e5', color: '#fff', borderRadius: 12, padding: '8px 16px', fontSize: 13, fontWeight: 700 }}>
                Download
              </div>
            </div>
          </a>
        </div>

        {/* Features */}
        <h2 style={{ margin: '0 0 20px', fontSize: 18, fontWeight: 700, color: '#111827' }}>What you get</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(240px, 1fr))', gap: 14, marginBottom: 40 }}>
          {FEATURES.map(f => (
            <div key={f.title} style={{ background: '#fff', borderRadius: 16, padding: '16px 18px', display: 'flex', gap: 14, alignItems: 'flex-start', border: '1px solid #f3f4f6' }}>
              <span style={{ fontSize: 28, lineHeight: 1, marginTop: 2 }}>{f.icon}</span>
              <div>
                <p style={{ margin: '0 0 4px', fontSize: 14, fontWeight: 700, color: '#111827' }}>{f.title}</p>
                <p style={{ margin: 0, fontSize: 12, color: '#6b7280', lineHeight: 1.5 }}>{f.desc}</p>
              </div>
            </div>
          ))}
        </div>

        {/* Install instructions */}
        <div style={{ background: '#fffbeb', border: '1px solid #fde68a', borderRadius: 16, padding: 20 }}>
          <p style={{ margin: '0 0 10px', fontSize: 14, fontWeight: 700, color: '#92400e' }}>⚠️ Android install note</p>
          <ol style={{ margin: 0, paddingLeft: 18, fontSize: 13, color: '#78350f', lineHeight: 1.8 }}>
            <li>Download the APK file</li>
            <li>Open your Downloads folder and tap the file</li>
            <li>If prompted, allow <strong>Install from unknown sources</strong> for your browser</li>
            <li>Tap Install and open the app</li>
          </ol>
        </div>
      </div>
    </div>
  );
}
