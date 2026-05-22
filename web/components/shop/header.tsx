'use client';

import { useState } from 'react';
import Image from 'next/image';
import { ShoppingCart, Store } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { useCartStore } from '@/lib/cart-store';
import { useAuthStore } from '@/lib/auth-store';
import { LoginModal } from '@/components/wk/login-modal';
import { type Language } from '@/lib/translations';

interface HeaderProps {
  language: Language;
  onLanguageToggle: () => void;
  onCartClick: () => void;
  shopName: string;
  shopNameMl: string;
  logoUrl: string;
}

export function Header({ language, onLanguageToggle, onCartClick, shopName, shopNameMl, logoUrl }: HeaderProps) {
  const itemCount = useCartStore((state) => state.getItemCount());
  const { uid, phone, logout } = useAuthStore();
  const [showLogin, setShowLogin] = useState(false);
  const displayName = language === 'ml' && shopNameMl ? shopNameMl : shopName;

  return (
    <>
      <header className="sticky top-0 z-50 bg-[#22c55e] text-white shadow-md">
        <div className="max-w-screen-xl mx-auto flex items-center justify-between px-4 py-3">
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-full bg-white/20 overflow-hidden">
              {logoUrl ? (
                <Image src={logoUrl} alt={shopName} width={40} height={40} className="rounded-full object-cover" />
              ) : (
                <Store className="h-5 w-5" />
              )}
            </div>
            <h1 className="text-lg font-bold italic tracking-tight">{displayName || 'wekerala'}</h1>
          </div>

          <div className="flex items-center gap-2">
            <Button
              variant="ghost"
              size="sm"
              onClick={onLanguageToggle}
              className="rounded-full bg-white/10 px-3 text-xs font-medium text-white hover:bg-white/20 hover:text-white"
            >
              {language === 'en' ? 'മല' : 'EN'}
            </Button>

            {uid ? (
              <Button
                variant="ghost"
                size="sm"
                onClick={logout}
                className="rounded-full bg-white/10 px-3 text-xs font-medium text-white hover:bg-white/20 hover:text-white"
              >
                {phone?.replace('+91', '') ?? 'me'}
              </Button>
            ) : (
              <Button
                size="sm"
                onClick={() => setShowLogin(true)}
                className="rounded-full bg-white text-green-700 px-4 text-xs font-bold hover:bg-white/90"
              >
                Login
              </Button>
            )}

            <Button
              variant="ghost"
              size="icon"
              onClick={onCartClick}
              className="relative text-white hover:bg-white/20 hover:text-white"
              aria-label="Shopping cart"
            >
              <ShoppingCart className="h-5 w-5" />
              {itemCount > 0 && (
                <span className="absolute -right-1 -top-1 flex h-5 w-5 items-center justify-center rounded-full bg-white text-xs font-bold text-primary">
                  {itemCount}
                </span>
              )}
            </Button>
          </div>
        </div>
      </header>
      <LoginModal open={showLogin} onClose={() => setShowLogin(false)} />
    </>
  );
}
