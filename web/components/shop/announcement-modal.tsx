'use client';

import { useEffect, useState } from 'react';
import { X } from 'lucide-react';

interface AnnouncementModalProps {
  text: string;
  shopId: string;
}

export function AnnouncementModal({ text, shopId }: AnnouncementModalProps) {
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    const key = `announced_${shopId}`;
    if (!localStorage.getItem(key)) {
      setVisible(true);
    }
  }, [shopId]);

  const dismiss = () => {
    localStorage.setItem(`announced_${shopId}`, '1');
    setVisible(false);
  };

  if (!visible) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 px-4">
      <div className="relative w-full max-w-sm rounded-2xl bg-white p-6 shadow-2xl">
        <button
          onClick={dismiss}
          className="absolute right-3 top-3 rounded-full p-1 text-gray-400 hover:bg-gray-100 hover:text-gray-600"
          aria-label="Close"
        >
          <X size={18} />
        </button>
        <p className="mt-1 text-center text-base font-medium text-gray-800">{text}</p>
        <button
          onClick={dismiss}
          className="mt-5 w-full rounded-xl bg-primary py-2.5 text-sm font-semibold text-white"
        >
          Got it
        </button>
      </div>
    </div>
  );
}
