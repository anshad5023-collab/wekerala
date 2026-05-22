import Link from 'next/link';
import { WK } from '@/lib/wk-constants';

const box = {
  border: `1px solid ${WK.ink}`,
  background: 'transparent',
  borderRadius: 10,
  boxSizing: 'border-box' as const,
};

interface WkTopBarProps {
  title: string;
  backHref?: string;
}

export function WkTopBar({ title, backHref }: WkTopBarProps) {
  return (
    <header style={{
      borderBottom: `1px solid ${WK.ink}`,
      padding: '12px 14px',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      flexShrink: 0,
      background: WK.paper,
    }}>
      <div style={{ ...box, width: 28, height: 28, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        {backHref ? (
          <Link href={backHref} style={{ fontFamily: WK.mono, fontSize: 12, color: WK.ink, textDecoration: 'none', lineHeight: 1 }}>←</Link>
        ) : (
          <span style={{ fontFamily: WK.mono, fontSize: 12, color: WK.ink }}>≡</span>
        )}
      </div>

      <span style={{ fontFamily: WK.hand, fontSize: 22, color: WK.ink, lineHeight: 1.1 }}>{title}</span>

      <div style={{ ...box, padding: '4px 10px', borderRadius: 12, cursor: 'pointer' }}>
        <span style={{ fontFamily: WK.mono, fontSize: 10, color: WK.ink }}>login</span>
      </div>
    </header>
  );
}
