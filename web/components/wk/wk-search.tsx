import { WK } from '@/lib/wk-constants';

interface WkSearchProps {
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
}

export function WkSearch({ value, onChange, placeholder = 'search…' }: WkSearchProps) {
  return (
    <div style={{
      background: WK.tile,
      border: `1px solid ${WK.tile}`,
      borderRadius: 22,
      height: 38,
      display: 'flex',
      alignItems: 'center',
      padding: '0 18px',
      gap: 12,
    }}>
      <div style={{ border: `1px solid ${WK.paper}`, width: 14, height: 14, borderRadius: '50%', flexShrink: 0 }} />
      <input
        type="text"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        style={{
          fontFamily: WK.mono,
          fontSize: 11,
          color: WK.paper,
          flex: 1,
          background: 'transparent',
          border: 'none',
          outline: 'none',
        }}
      />
      <div style={{ border: `1px solid ${WK.paper}`, padding: '3px 8px', borderRadius: 10 }}>
        <span style={{ fontFamily: WK.mono, fontSize: 10, color: WK.paper }}>⌘K</span>
      </div>
    </div>
  );
}
