'use client';
import { WK } from '@/lib/wk-constants';

export interface Business {
  id: string;
  name: string;
  type: string;
  logoUrl?: string;
  photoUrl?: string;
  shopArea?: string;
  district?: string;
  description?: string;
  [key: string]: unknown;
}

interface Props {
  open: boolean;
  businesses: Business[];
  selected: Business | null;
  onSelect: (b: Business) => void;
  onClose: () => void;
}

export function BusinessSelector({ open, businesses, selected, onSelect, onClose }: Props) {
  if (!open) return null;
  return (
    <div
      style={{ position: 'fixed', inset: 0, zIndex: 1000, background: 'rgba(0,0,0,0.6)', display: 'flex', alignItems: 'flex-end', justifyContent: 'center' }}
      onClick={onClose}
    >
      <div
        onClick={(e) => e.stopPropagation()}
        style={{ background: WK.paper, width: '100%', maxWidth: 480, borderRadius: '20px 20px 0 0', padding: 24, paddingBottom: 40, maxHeight: '70vh', overflowY: 'auto' }}
      >
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 20 }}>
          <span style={{ fontFamily: WK.hand, fontSize: 22, color: WK.ink }}>your businesses</span>
          <button onClick={onClose} style={{ background: 'transparent', border: 'none', cursor: 'pointer', fontFamily: WK.mono, fontSize: 18, color: WK.muted }}>✕</button>
        </div>

        {businesses.length === 0 ? (
          <p style={{ fontFamily: WK.mono, fontSize: 11, color: WK.muted, textAlign: 'center', padding: '20px 0' }}>
            No businesses yet. Add one via "list me".
          </p>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {businesses.map((biz) => {
              const photo = biz.logoUrl ?? biz.photoUrl ?? '';
              const isSelected = selected?.id === biz.id;
              return (
                <button
                  key={biz.id}
                  onClick={() => onSelect(biz)}
                  style={{
                    display: 'flex', alignItems: 'center', gap: 12,
                    padding: '12px 14px', borderRadius: 14, width: '100%', textAlign: 'left',
                    border: `1px solid ${isSelected ? WK.ink : 'rgba(254,250,224,0.2)'}`,
                    background: isSelected ? 'rgba(254,250,224,0.08)' : 'transparent',
                    cursor: 'pointer',
                  }}
                >
                  <div style={{ width: 40, height: 40, borderRadius: 10, background: 'rgba(254,250,224,0.15)', flexShrink: 0, overflow: 'hidden', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    {photo ? (
                      <img src={photo} alt={biz.name} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                    ) : (
                      <span style={{ fontFamily: WK.hand, fontSize: 18, color: WK.ink }}>{biz.name[0]?.toUpperCase() ?? '?'}</span>
                    )}
                  </div>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <p style={{ fontFamily: WK.hand, fontSize: 16, color: WK.ink, marginBottom: 2 }}>{biz.name}</p>
                    <p style={{ fontFamily: WK.mono, fontSize: 9, color: WK.muted, textTransform: 'uppercase', letterSpacing: 0.5 }}>{biz.type}</p>
                  </div>
                  {isSelected && <span style={{ color: WK.sticky, fontFamily: WK.mono, fontSize: 14 }}>✓</span>}
                </button>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
