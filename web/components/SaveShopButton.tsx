'use client';

import { useState, useEffect } from 'react';
import { useAuthStore } from '@/lib/auth-store';

interface SaveShopButtonProps {
  shopId: string;
  shopName: string;
  bannerImageUrl?: string;
}

export function SaveShopButton({ shopId, shopName, bannerImageUrl }: SaveShopButtonProps) {
  const { uid } = useAuthStore();
  const [saved, setSaved] = useState(false);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (!uid) return;
    fetch(`/api/bookmarks?uid=${encodeURIComponent(uid)}`)
      .then((r) => r.json())
      .then((d) => {
        const bookmarks = d.bookmarks ?? [];
        setSaved(bookmarks.some((b: { businessId: string }) => b.businessId === shopId));
      })
      .catch(() => {});
  }, [uid, shopId]);

  async function toggle() {
    if (!uid) {
      window.location.href = '/auth';
      return;
    }
    if (busy) return;
    setBusy(true);
    try {
      if (saved) {
        await fetch(`/api/bookmarks?uid=${encodeURIComponent(uid)}&businessId=${shopId}`, { method: 'DELETE' });
        setSaved(false);
      } else {
        await fetch('/api/bookmarks', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ uid, businessId: shopId, collection: 'shops', businessName: shopName, photoUrl: bannerImageUrl ?? '' }),
        });
        setSaved(true);
      }
    } catch { /* fail silently */ }
    finally { setBusy(false); }
  }

  return (
    <button
      onClick={toggle}
      disabled={busy}
      title={saved ? 'Remove from saved' : 'Save this shop'}
      style={{
        position: 'fixed',
        bottom: 80,
        right: 16,
        zIndex: 50,
        width: 44,
        height: 44,
        borderRadius: '50%',
        border: 'none',
        background: saved ? '#ef4444' : 'rgba(0,0,0,0.55)',
        backdropFilter: 'blur(8px)',
        cursor: busy ? 'default' : 'pointer',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        fontSize: 20,
        boxShadow: '0 2px 12px rgba(0,0,0,0.25)',
        transition: 'background 0.2s',
        opacity: busy ? 0.6 : 1,
      }}
    >
      {saved ? '❤' : '🤍'}
    </button>
  );
}
