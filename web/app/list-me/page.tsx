'use client';
import Link from 'next/link';
import { WkTopBar } from '@/components/wk/wk-topbar';
import { WkNav } from '@/components/wk/wk-nav';
import { WK } from '@/lib/wk-constants';

const OPTIONS = [
  {
    title: 'Add a listing',
    desc: 'Register your shop, service, hotel, restaurant, theater, or beauty business on wekerala.',
    icon: '🏪',
    href: '/register',
  },
  {
    title: 'Create your website',
    desc: 'Get a free hosted storefront where customers can browse your products and place orders.',
    icon: '🌐',
    href: '/create-shop',
  },
];

export default function ListMePage() {
  return (
    <div style={{
      width: '100%',
      maxWidth: 480,
      margin: '0 auto',
      minHeight: '100dvh',
      background: WK.paper,
      display: 'flex',
      flexDirection: 'column',
    }}>
      <WkTopBar title="list me" backHref="/" />

      <div style={{ flex: 1, padding: 20, display: 'flex', flexDirection: 'column', gap: 14 }}>
        <p style={{ fontFamily: WK.mono, fontSize: 11, color: WK.muted, marginBottom: 4 }}>
          join wekerala as a business
        </p>

        {OPTIONS.map((opt) => (
          <Link key={opt.href} href={opt.href} style={{ textDecoration: 'none' }}>
            <div style={{
              border: `1px solid rgba(254,250,224,0.25)`,
              borderRadius: 16,
              padding: 20,
              display: 'flex',
              gap: 16,
              alignItems: 'flex-start',
              background: 'rgba(254,250,224,0.05)',
              cursor: 'pointer',
            }}>
              <div style={{
                fontSize: 30,
                width: 52,
                height: 52,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                background: 'rgba(254,250,224,0.1)',
                borderRadius: 14,
                flexShrink: 0,
              }}>
                {opt.icon}
              </div>
              <div style={{ flex: 1 }}>
                <p style={{ fontFamily: WK.hand, fontSize: 19, color: WK.ink, marginBottom: 4, lineHeight: 1.2 }}>
                  {opt.title}
                </p>
                <p style={{ fontFamily: WK.mono, fontSize: 11, color: WK.muted, lineHeight: 1.6 }}>
                  {opt.desc}
                </p>
              </div>
              <span style={{ fontFamily: WK.mono, fontSize: 14, color: WK.muted, alignSelf: 'center' }}>→</span>
            </div>
          </Link>
        ))}
      </div>

      <WkNav active="list-me" />
    </div>
  );
}
