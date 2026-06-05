'use client';

import Link from 'next/link';
import { WK } from '@/lib/wk-constants';

const PLANS = [
  {
    name: 'Free Trial',
    price: '₹0',
    period: '14 days',
    highlight: false,
    tag: 'Current',
    tagColor: '#6b7280',
    features: [
      'Online shop with all features',
      'Unlimited products',
      'WhatsApp order alerts',
      'Basic website builder',
      'Up to 50 orders / month',
    ],
    cta: null,
  },
  {
    name: 'Basic',
    price: '₹299',
    period: 'per month',
    highlight: false,
    tag: '',
    tagColor: '',
    features: [
      'Everything in Free Trial',
      'Unlimited orders',
      'Custom coupons & discounts',
      'Advanced website builder (10 themes)',
      'Analytics dashboard',
      'Priority WhatsApp support',
    ],
    cta: 'Get Basic',
    ctaMsg: 'Hi wekerala team, I want to subscribe to the Basic plan (₹299/month). My shop ID: ',
  },
  {
    name: 'Pro',
    price: '₹599',
    period: 'per month',
    highlight: true,
    tag: 'Best Value',
    tagColor: WK.sticky,
    features: [
      'Everything in Basic',
      'Custom domain (yourshop.com)',
      'Google Analytics & Facebook Pixel',
      'Live chat widget (Tawk.To)',
      'Multiple shop management',
      'Dedicated account manager',
    ],
    cta: 'Get Pro',
    ctaMsg: 'Hi wekerala team, I want to subscribe to the Pro plan (₹599/month). My shop ID: ',
  },
];

export default function SubscriptionPage() {
  return (
    <div style={{ width: '100%', maxWidth: 480, margin: '0 auto', minHeight: '100dvh', background: WK.paper, display: 'flex', flexDirection: 'column' }}>
      {/* Header */}
      <header style={{ padding: '14px 16px', display: 'flex', alignItems: 'center', gap: 12, borderBottom: `1px solid rgba(254,250,224,0.12)`, flexShrink: 0 }}>
        <Link href="/control" style={{ border: `1px solid ${WK.ink}`, borderRadius: 10, width: 32, height: 32, display: 'flex', alignItems: 'center', justifyContent: 'center', textDecoration: 'none', flexShrink: 0 }}>
          <span style={{ fontFamily: WK.mono, fontSize: 13, color: WK.ink }}>←</span>
        </Link>
        <span style={{ fontFamily: WK.hand, fontSize: 22, color: WK.ink }}>Plans</span>
      </header>

      <div style={{ flex: 1, overflowY: 'auto', padding: '20px 16px 40px' }}>
        {/* Hero */}
        <div style={{ textAlign: 'center', marginBottom: 28 }}>
          <p style={{ fontFamily: WK.hand, fontSize: 28, color: WK.ink, margin: '0 0 8px', lineHeight: 1.2 }}>
            Grow your business on wekerala
          </p>
          <p style={{ fontFamily: WK.mono, fontSize: 11, color: WK.muted, margin: 0, lineHeight: 1.7, maxWidth: 300, marginLeft: 'auto', marginRight: 'auto' }}>
            Start free, upgrade when you&apos;re ready. No contracts, cancel anytime.
          </p>
        </div>

        {/* Plan cards */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
          {PLANS.map((plan) => (
            <div
              key={plan.name}
              style={{
                borderRadius: 20,
                padding: '20px 20px',
                border: plan.highlight ? `2px solid ${WK.sticky}` : `1px solid rgba(254,250,224,0.2)`,
                background: plan.highlight ? 'rgba(221,161,94,0.08)' : 'rgba(254,250,224,0.04)',
                position: 'relative',
              }}
            >
              {plan.tag && (
                <div style={{ position: 'absolute', top: -11, left: 20, background: plan.tagColor, borderRadius: 20, padding: '3px 12px' }}>
                  <span style={{ fontFamily: WK.mono, fontSize: 10, color: plan.highlight ? '#fff' : WK.paper, fontWeight: 700 }}>{plan.tag}</span>
                </div>
              )}

              <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', marginBottom: 14 }}>
                <div>
                  <p style={{ fontFamily: WK.hand, fontSize: 20, color: WK.ink, margin: 0, lineHeight: 1.1 }}>{plan.name}</p>
                  <p style={{ fontFamily: WK.mono, fontSize: 10, color: WK.muted, margin: '3px 0 0' }}>{plan.period}</p>
                </div>
                <div style={{ textAlign: 'right' }}>
                  <p style={{ fontFamily: WK.hand, fontSize: 26, color: plan.highlight ? WK.sticky : WK.ink, margin: 0, lineHeight: 1 }}>{plan.price}</p>
                </div>
              </div>

              <div style={{ display: 'flex', flexDirection: 'column', gap: 7, marginBottom: plan.cta ? 16 : 0 }}>
                {plan.features.map((f) => (
                  <div key={f} style={{ display: 'flex', alignItems: 'flex-start', gap: 8 }}>
                    <span style={{ fontFamily: WK.mono, fontSize: 12, color: plan.highlight ? WK.sticky : '#4ade80', flexShrink: 0, marginTop: 1 }}>✓</span>
                    <span style={{ fontFamily: WK.mono, fontSize: 11, color: WK.ink, lineHeight: 1.5 }}>{f}</span>
                  </div>
                ))}
              </div>

              {plan.cta && (
                <a
                  href={`https://wa.me/918848013569?text=${encodeURIComponent((plan.ctaMsg ?? '') + '(my shop)')}`}
                  target="_blank"
                  rel="noopener noreferrer"
                  style={{
                    display: 'block', width: '100%', textAlign: 'center',
                    padding: '12px 0', borderRadius: 14,
                    background: plan.highlight ? WK.sticky : WK.ink,
                    color: plan.highlight ? '#fff' : WK.paper,
                    fontFamily: WK.mono, fontSize: 13, textDecoration: 'none',
                    boxSizing: 'border-box',
                  }}
                >
                  {plan.cta} via WhatsApp →
                </a>
              )}
            </div>
          ))}
        </div>

        {/* Note */}
        <p style={{ fontFamily: WK.mono, fontSize: 10, color: WK.muted, textAlign: 'center', marginTop: 24, lineHeight: 1.7 }}>
          Payments are currently processed manually via WhatsApp.
          Online billing coming soon. Questions? WhatsApp us at +91 88480 13569.
        </p>
      </div>
    </div>
  );
}
