'use client';
import { WK } from '@/lib/wk-constants';

export type OwnerTab = 'home' | 'web' | 'settings';

const TABS: { id: OwnerTab; label: string; icon: string }[] = [
  { id: 'home',     label: 'home',     icon: '⌂' },
  { id: 'web',      label: 'web',      icon: '◉' },
  { id: 'settings', label: 'settings', icon: '⚙' },
];

export function OwnerNav({ active, onChange }: { active: OwnerTab; onChange: (t: OwnerTab) => void }) {
  return (
    <nav style={{
      borderTop: `1px solid rgba(254,250,224,0.15)`,
      padding: '12px 16px',
      display: 'flex',
      gap: 10,
      background: WK.paper,
      flexShrink: 0,
    }}>
      {TABS.map((tab) => (
        <button
          key={tab.id}
          onClick={() => onChange(tab.id)}
          style={{
            flex: 1,
            padding: '11px 0',
            borderRadius: 20,
            border: `1px solid ${active === tab.id ? WK.ink : 'rgba(254,250,224,0.2)'}`,
            background: active === tab.id ? 'rgba(254,250,224,0.1)' : 'transparent',
            cursor: 'pointer',
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            gap: 3,
          }}
        >
          <span style={{ fontSize: 14 }}>{tab.icon}</span>
          <span style={{ fontFamily: WK.mono, fontSize: 9, color: active === tab.id ? WK.ink : WK.muted, letterSpacing: 0.3 }}>
            {tab.label}
          </span>
        </button>
      ))}
    </nav>
  );
}
