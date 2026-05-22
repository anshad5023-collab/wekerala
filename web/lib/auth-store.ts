import { create } from 'zustand';
import { persist } from 'zustand/middleware';

interface AuthState {
  uid: string | null;
  phone: string | null;
  setUser: (uid: string, phone: string) => void;
  logout: () => void;
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      uid: null,
      phone: null,
      setUser: (uid, phone) => set({ uid, phone }),
      logout: () => set({ uid: null, phone: null }),
    }),
    { name: 'wk-auth' }
  )
);
