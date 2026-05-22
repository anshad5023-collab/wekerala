'use client';
import { useState } from 'react';
import { WK } from '@/lib/wk-constants';

export interface FilterConfig {
  id: string;
  label: string;
  options?: string[];
  isToggle?: boolean;
}

export type FilterState = Record<string, string[] | boolean>;

interface WkFilterProps {
  filters: FilterConfig[];
  selected: FilterState;
  onChange: (updated: FilterState) => void;
}

export function WkFilter({ filters, selected, onChange }: WkFilterProps) {
  const [openFilter, setOpenFilter] = useState<string | null>(null);

  const toggle = (group: string, item: string) => {
    const cur = (selected[group] as string[]) ?? [];
    onChange({ ...selected, [group]: cur.includes(item) ? cur.filter((x) => x !== item) : [...cur, item] });
  };

  const toggleBool = (group: string) => {
    onChange({ ...selected, [group]: !selected[group] });
  };

  const activeChips: { group: string; label: string }[] = [];
  for (const f of filters) {
    if (f.isToggle) continue;
    ((selected[f.id] as string[]) ?? []).forEach((v) => activeChips.push({ group: f.id, label: v }));
  }

  const clearAll = () => {
    const cleared: FilterState = {};
    for (const f of filters) cleared[f.id] = f.isToggle ? false : [];
    onChange(cleared);
  };

  const openDef = filters.find((f) => f.id === openFilter);

  return (
    <>
      {/* Filter pills */}
      <div style={{ padding: '0 14px 10px', display: 'flex', gap: 8, overflowX: 'auto', flexShrink: 0 }}>
        {filters.map((f) => {
          const active = f.isToggle ? !!selected[f.id] : ((selected[f.id] as string[]) ?? []).length > 0;
          return (
            <div
              key={f.id}
              onClick={() => f.isToggle ? toggleBool(f.id) : setOpenFilter(openFilter === f.id ? null : f.id)}
              style={{
                border: `1px solid ${active ? WK.sticky : WK.ink}`,
                background: active ? WK.sticky : 'transparent',
                borderRadius: 16,
                padding: '6px 12px',
                display: 'flex',
                alignItems: 'center',
                gap: 6,
                cursor: 'pointer',
                flexShrink: 0,
              }}
            >
              <span style={{ fontFamily: WK.mono, fontSize: 10, color: active ? WK.paper : WK.ink }}>{f.label}</span>
              {!f.isToggle && (
                <span style={{ fontFamily: WK.mono, fontSize: 9, color: active ? WK.paper : WK.ink }}>
                  {openFilter === f.id ? '▴' : '▾'}
                </span>
              )}
            </div>
          );
        })}
      </div>

      {/* Active chips */}
      {activeChips.length > 0 && (
        <div style={{ padding: '0 14px 10px', display: 'flex', gap: 6, flexWrap: 'wrap', flexShrink: 0 }}>
          {activeChips.map((c, i) => (
            <div
              key={i}
              onClick={() => toggle(c.group, c.label)}
              style={{ background: WK.tile, border: `1px solid ${WK.tile}`, borderRadius: 12, padding: '4px 10px', display: 'flex', alignItems: 'center', gap: 6, cursor: 'pointer' }}
            >
              <span style={{ fontFamily: WK.mono, fontSize: 10, color: WK.paper }}>{c.label}</span>
              <span style={{ fontFamily: WK.mono, fontSize: 10, color: WK.paper }}>×</span>
            </div>
          ))}
          <div onClick={clearAll} style={{ padding: '4px 10px', cursor: 'pointer' }}>
            <span style={{ fontFamily: WK.mono, fontSize: 10, color: WK.muted }}>clear all</span>
          </div>
        </div>
      )}

      {/* Bottom sheet dropdown */}
      {openFilter && openDef?.options && (
        <div
          onClick={() => setOpenFilter(null)}
          style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.45)', display: 'flex', alignItems: 'flex-end', zIndex: 200 }}
        >
          <div
            onClick={(e) => e.stopPropagation()}
            style={{
              width: '100%',
              maxHeight: '70%',
              background: WK.paper,
              borderTop: `1px solid ${WK.ink}`,
              borderTopLeftRadius: 18,
              borderTopRightRadius: 18,
              padding: 18,
              display: 'flex',
              flexDirection: 'column',
              gap: 10,
            }}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{ fontFamily: WK.hand, fontSize: 20, color: WK.ink, lineHeight: 1.1 }}>Choose {openDef.label}</span>
              <div onClick={() => setOpenFilter(null)} style={{ cursor: 'pointer' }}>
                <span style={{ fontFamily: WK.mono, fontSize: 14, color: WK.ink }}>×</span>
              </div>
            </div>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, overflowY: 'auto' }}>
              {openDef.options.map((it) => {
                const isOn = ((selected[openFilter] as string[]) ?? []).includes(it);
                return (
                  <div
                    key={it}
                    onClick={() => toggle(openFilter, it)}
                    style={{
                      border: `1px solid ${isOn ? WK.sticky : WK.ink}`,
                      background: isOn ? WK.sticky : 'transparent',
                      borderRadius: 14,
                      padding: '6px 12px',
                      cursor: 'pointer',
                    }}
                  >
                    <span style={{ fontFamily: WK.mono, fontSize: 11, color: isOn ? WK.paper : WK.ink }}>{it}</span>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      )}
    </>
  );
}
