'use client';
import { useState } from 'react';
import Link from 'next/link';
import { signInWithPopup, GoogleAuthProvider } from 'firebase/auth';
import { auth } from '@/lib/firebase';
import { useAuthStore } from '@/lib/auth-store';
import { WK } from '@/lib/wk-constants';

export default function AuthPage() {
  const { setUser } = useAuthStore();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState(false);

  async function handleGoogleSignIn() {
    setLoading(true);
    setError(null);
    try {
      const provider = new GoogleAuthProvider();
      const result = await signInWithPopup(auth, provider);
      const user = result.user;
      const uid = user.uid;
      const phone = user.phoneNumber ?? user.email ?? '';
      setUser(uid, phone);
      setDone(true);
      setTimeout(() => {
        if (typeof window !== 'undefined') {
          window.history.back();
        }
      }, 1200);
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Sign in failed. Please try again.';
      setError(message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div style={{
      width: '100%',
      maxWidth: 480,
      margin: '0 auto',
      minHeight: '100dvh',
      background: WK.paper,
      display: 'flex',
      flexDirection: 'column',
    }}>
      {/* Header */}
      <header style={{
        padding: '12px 14px',
        display: 'flex',
        alignItems: 'center',
        gap: 10,
        flexShrink: 0,
      }}>
        <button
          onClick={() => window.history.back()}
          style={{
            border: `1px solid ${WK.ink}`,
            background: 'transparent',
            borderRadius: 8,
            width: 32,
            height: 32,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            cursor: 'pointer',
            flexShrink: 0,
          }}
        >
          <span style={{ fontFamily: WK.mono, fontSize: 14, color: WK.ink }}>←</span>
        </button>
      </header>

      {/* Centered card */}
      <div style={{
        flex: 1,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '20px 24px 40px',
      }}>
        <div style={{
          background: WK.tile,
          borderRadius: 24,
          padding: '32px 28px',
          width: '100%',
          maxWidth: 360,
          textAlign: 'center',
        }}>
          {/* Logo / Icon */}
          <div style={{
            width: 64,
            height: 64,
            background: WK.paper,
            borderRadius: 20,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            margin: '0 auto 20px',
          }}>
            <span style={{ fontFamily: WK.hand, fontSize: 32, color: WK.ink }}>wk</span>
          </div>

          {/* Title */}
          <h1 style={{
            fontFamily: WK.hand,
            fontSize: 26,
            color: WK.paper,
            margin: '0 0 8px',
          }}>
            Sign in to save & rate
          </h1>

          {/* Subtitle */}
          <p style={{
            fontFamily: WK.mono,
            fontSize: 11,
            color: WK.paper,
            opacity: 0.65,
            margin: '0 0 28px',
            lineHeight: 1.6,
          }}>
            Your bookmarks and ratings are saved to your account
          </p>

          {/* Success state */}
          {done ? (
            <div style={{
              background: '#d1fae5',
              borderRadius: 12,
              padding: '14px 16px',
              marginBottom: 16,
            }}>
              <p style={{ fontFamily: WK.mono, fontSize: 12, color: '#065f46', margin: 0 }}>
                ✓ Signed in successfully! Redirecting…
              </p>
            </div>
          ) : (
            <>
              {/* Error message */}
              {error && (
                <div style={{
                  background: '#fee2e2',
                  borderRadius: 12,
                  padding: '12px 14px',
                  marginBottom: 16,
                }}>
                  <p style={{ fontFamily: WK.mono, fontSize: 11, color: '#991b1b', margin: 0 }}>{error}</p>
                </div>
              )}

              {/* Google Sign-In button */}
              <button
                onClick={handleGoogleSignIn}
                disabled={loading}
                style={{
                  width: '100%',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: 10,
                  background: loading ? 'rgba(40,54,24,0.5)' : WK.paper,
                  color: WK.ink,
                  border: 'none',
                  borderRadius: 14,
                  padding: '14px 20px',
                  fontFamily: WK.mono,
                  fontSize: 13,
                  cursor: loading ? 'default' : 'pointer',
                  marginBottom: 20,
                }}
              >
                {loading ? (
                  <span>Signing in…</span>
                ) : (
                  <>
                    <svg width="18" height="18" viewBox="0 0 18 18" fill="none" xmlns="http://www.w3.org/2000/svg">
                      <path d="M17.64 9.2c0-.637-.057-1.251-.164-1.84H9v3.481h4.844a4.14 4.14 0 01-1.796 2.716v2.259h2.908c1.702-1.567 2.684-3.875 2.684-6.615z" fill="#4285F4"/>
                      <path d="M9 18c2.43 0 4.467-.806 5.956-2.18l-2.908-2.259c-.806.54-1.837.86-3.048.86-2.344 0-4.328-1.584-5.036-3.711H.957v2.332A8.997 8.997 0 009 18z" fill="#34A853"/>
                      <path d="M3.964 10.71A5.41 5.41 0 013.682 9c0-.593.102-1.17.282-1.71V4.958H.957A8.996 8.996 0 000 9c0 1.452.348 2.827.957 4.042l3.007-2.332z" fill="#FBBC05"/>
                      <path d="M9 3.58c1.321 0 2.508.454 3.44 1.345l2.582-2.58C13.463.891 11.426 0 9 0A8.997 8.997 0 00.957 4.958L3.964 7.29C4.672 5.163 6.656 3.58 9 3.58z" fill="#EA4335"/>
                    </svg>
                    <span>Continue with Google</span>
                  </>
                )}
              </button>

              {/* Divider */}
              <div style={{
                display: 'flex',
                alignItems: 'center',
                gap: 12,
                marginBottom: 20,
              }}>
                <div style={{ flex: 1, height: 1, background: 'rgba(40,54,24,0.15)' }} />
                <span style={{ fontFamily: WK.mono, fontSize: 10, color: WK.paper, opacity: 0.4 }}>or</span>
                <div style={{ flex: 1, height: 1, background: 'rgba(40,54,24,0.15)' }} />
              </div>

              {/* Phone login note */}
              <div style={{
                background: 'rgba(40,54,24,0.06)',
                borderRadius: 12,
                padding: '14px 16px',
                textAlign: 'left',
              }}>
                <p style={{
                  fontFamily: WK.mono,
                  fontSize: 11,
                  color: WK.paper,
                  opacity: 0.7,
                  margin: 0,
                  lineHeight: 1.6,
                }}>
                  For phone login, use the main login on the home page.{' '}
                  <Link
                    href="/"
                    style={{ color: WK.paper, fontWeight: 600, opacity: 1 }}
                  >
                    Go home →
                  </Link>
                </p>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
