import { WK } from '@/lib/wk-constants';

export interface WkCardData {
  id: string;
  name: string;
  category: string;
  rating?: number;
  reviews?: number;
  photoUrl?: string;
  tags?: string[];
  screens?: number;
  href?: string;
  extraInfo?: string;
}

export function WkCard({ name, category, rating, reviews, photoUrl, tags = [], screens, href, extraInfo }: WkCardData) {
  const inner = (
    <div style={{ background: WK.tile, borderRadius: 14, overflow: 'hidden', display: 'flex', flexDirection: 'column', cursor: 'pointer', height: '100%' }}>
      <div style={{ aspectRatio: '1 / 1', background: WK.muted, borderBottom: `1px solid ${WK.paper}`, display: 'flex', alignItems: 'center', justifyContent: 'center', overflow: 'hidden' }}>
        {photoUrl ? (
          <img src={photoUrl} alt={name} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
        ) : (
          <span style={{ fontFamily: WK.mono, fontSize: 9, color: WK.paper, opacity: 0.5 }}>photo</span>
        )}
      </div>
      <div style={{ padding: '8px 10px 10px' }}>
        <span style={{ fontFamily: WK.hand, fontSize: 17, color: WK.paper, lineHeight: 1, display: 'block' }}>{name}</span>
        <span style={{ fontFamily: WK.mono, fontSize: 9, color: WK.paper, opacity: 0.7, display: 'block', marginTop: 2 }}>{category}</span>
        {extraInfo && (
          <span style={{ fontFamily: WK.mono, fontSize: 9, color: WK.sticky, display: 'block', marginTop: 3 }}>{extraInfo}</span>
        )}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: 6 }}>
          {screens !== undefined ? (
            <span style={{ fontFamily: WK.mono, fontSize: 10, color: WK.paper }}>{screens} screen{screens !== 1 ? 's' : ''}</span>
          ) : rating !== undefined ? (
            <>
              <span style={{ fontFamily: WK.mono, fontSize: 10, color: WK.paper }}>★ {rating}</span>
              {reviews !== undefined && <span style={{ fontFamily: WK.mono, fontSize: 9, color: WK.paper, opacity: 0.6 }}>({reviews})</span>}
            </>
          ) : null}
        </div>
        {tags.length > 0 && (
          <div style={{ display: 'flex', gap: 4, marginTop: 6, flexWrap: 'wrap' }}>
            {tags.map((t, i) => (
              <span key={i} style={{ border: `1px solid ${WK.paper}`, borderRadius: 8, padding: '1px 6px', fontFamily: WK.mono, fontSize: 8, color: WK.paper }}>{t}</span>
            ))}
          </div>
        )}
      </div>
    </div>
  );

  if (href) {
    return <a href={href} style={{ textDecoration: 'none', display: 'block' }}>{inner}</a>;
  }
  return inner;
}
