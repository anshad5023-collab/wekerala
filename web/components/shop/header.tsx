'use client';

import { useState, useRef, useEffect } from 'react';
import Image from 'next/image';
import { ShoppingCart, Store, ChevronDown, Package, LogOut } from 'lucide-react';
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
  const [showUserMenu, setShowUserMenu] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);
  const displayName = language === 'ml' && shopNameMl ? shopNameMl : shopName;

  useEffect(() => {
    const handler = (e: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) setShowUserMenu(false);
    };
    document.addEventListener('mousedown', handler);
    return () => document.removeEventListener('mousedown', handler);
  }, []);

  return (
    <>
      <header className="sticky top-0 z-50 bg-primary text-primary-foreground shadow-md">
        <div className="max-w-screen-xl mx-auto flex items-center justify-between px-4 py-3">
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-full bg-white/15 overflow-hidden">
              {logoUrl ? (
                <Image src={logoUrl} alt={shopName} width={40} height={40} className="rounded-full object-cover" />
              ) : (
                <Store className="h-5 w-5" />
              )}
            </div>
            <h1 className="text-lg font-bold tracking-tight">{displayName || 'wekerala'}</h1>
          </div>

          <div className="flex items-center gap-2">
            <Button
              variant="ghost"
              size="sm"
              onClick={onLanguageToggle}
              className="rounded-full bg-white/10 px-3 text-xs font-medium text-primary-foreground hover:bg-white/20 hover:text-primary-foreground"
            >
              {language === 'en' ? 'മല' : 'EN'}
            </Button>

            {uid ? (
              <div ref={menuRef} className="relative">
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => setShowUserMenu((v) => !v)}
                  className="rounded-full bg-white/10 px-3 text-xs font-medium text-primary-foreground hover:bg-white/20 hover:text-primary-foreground gap-1"
                >
                  {phone?.replace('+91', '') ?? 'me'}
                  <ChevronDown className="h-3 w-3" />
                </Button>
                {showUserMenu && (
                  <div className="absolute right-0 top-full mt-2 w-44 rounded-xl border border-border bg-white shadow-lg z-50 overflow-hidden">
                    <a
                      href="/customer/orders"
                      className="flex items-center gap-2 px-4 py-3 text-sm text-foreground hover:bg-muted transition-colors"
                      onClick={() => setShowUserMenu(false)}
                    >
                      <Package className="h-4 w-4 text-primary" />
                      My Orders
                    </a>
                    <button
                      onClick={() => { logout(); setShowUserMenu(false); }}
                      className="flex w-full items-center gap-2 px-4 py-3 text-sm text-red-600 hover:bg-red-50 transition-colors"
                    >
                      <LogOut className="h-4 w-4" />
                      Sign out
                    </button>
                  </div>
                )}
              </div>
            ) : (
              <Button
                size="sm"
                onClick={() => setShowLogin(true)}
                className="rounded-full bg-white/15 px-4 text-xs font-bold text-primary-foreground hover:bg-white/25"
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
