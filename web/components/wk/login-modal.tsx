'use client';

import { useState, useRef, useEffect } from 'react';
import { RecaptchaVerifier, signInWithPhoneNumber, ConfirmationResult } from 'firebase/auth';
import { auth } from '@/lib/firebase';
import { useAuthStore } from '@/lib/auth-store';
import { WK } from '@/lib/wk-constants';

interface LoginModalProps {
  open: boolean;
  onClose: () => void;
}

export function LoginModal({ open, onClose }: LoginModalProps) {
  const [phone, setPhone] = useState('');
  const [otp, setOtp] = useState('');
  const [step, setStep] = useState<'phone' | 'otp'>('phone');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const confirmRef = useRef<ConfirmationResult | null>(null);
  const recaptchaRef = useRef<RecaptchaVerifier | null>(null);
  const setUser = useAuthStore((s) => s.setUser);

  useEffect(() => {
    if (!open) {
      setStep('phone');
      setPhone('');
      setOtp('');
      setError('');
    }
  }, [open]);

  const sendOtp = async () => {
    setError('');
    setLoading(true);
    try {
      if (!recaptchaRef.current) {
        recaptchaRef.current = new RecaptchaVerifier(auth, 'recaptcha-container', { size: 'invisible' });
      }
      const fullPhone = phone.startsWith('+') ? phone : `+91${phone}`;
      confirmRef.current = await signInWithPhoneNumber(auth, fullPhone, recaptchaRef.current);
      setStep('otp');
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : 'Failed to send OTP');
      recaptchaRef.current = null;
    } finally {
      setLoading(false);
    }
  };

  const verifyOtp = async () => {
    if (!confirmRef.current) return;
    setError('');
    setLoading(true);
    try {
      const result = await confirmRef.current.confirm(otp);
      setUser(result.user.uid, result.user.phoneNumber ?? `+91${phone}`);
      onClose();
    } catch {
      setError('Invalid OTP. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const inputStyle: React.CSSProperties = {
    flex: 1,
    padding: '13px 14px',
    background: 'transparent',
    border: 'none',
    outline: 'none',
    fontFamily: WK.mono,
    fontSize: 14,
    color: WK.ink,
  };

  const btnStyle = (disabled: boolean): React.CSSProperties => ({
    width: '100%',
    padding: '14px 0',
    background: WK.ink,
    color: WK.paper,
    border: 'none',
    borderRadius: 12,
    cursor: disabled ? 'not-allowed' : 'pointer',
    fontFamily: WK.mono,
    fontSize: 13,
    opacity: disabled ? 0.45 : 1,
  });

  // Always keep recaptcha-container in DOM so Firebase never loses it
  return (
    <>
    <div id="recaptcha-container" style={{ position: 'fixed', bottom: 0, zIndex: 0 }} />
    {open && <div
      style={{
        position: 'fixed', inset: 0, zIndex: 1000,
        background: 'rgba(0,0,0,0.6)',
        display: 'flex', alignItems: 'flex-end', justifyContent: 'center',
      }}
      onClick={onClose}
    >
      <div
        onClick={(e) => e.stopPropagation()}
        style={{
          background: WK.paper,
          width: '100%',
          maxWidth: 480,
          borderRadius: '20px 20px 0 0',
          padding: 24,
          paddingBottom: 40,
        }}
      >
        <div style={{ textAlign: 'center', marginBottom: 20 }}>
          <span style={{ fontFamily: WK.hand, fontSize: 24, color: WK.ink }}>
            {step === 'phone' ? 'login' : 'enter OTP'}
          </span>
        </div>

        {step === 'phone' ? (
          <>
            <div style={{
              display: 'flex',
              border: `1px solid ${WK.ink}`,
              borderRadius: 12,
              overflow: 'hidden',
              marginBottom: 12,
            }}>
              <span style={{
                padding: '13px 12px',
                fontFamily: WK.mono,
                fontSize: 13,
                color: WK.ink,
                borderRight: `1px solid ${WK.ink}`,
                background: 'rgba(254,250,224,0.06)',
              }}>+91</span>
              <input
                type="tel"
                value={phone}
                onChange={(e) => setPhone(e.target.value.replace(/\D/g, '').slice(0, 10))}
                placeholder="phone number"
                style={inputStyle}
              />
            </div>
            <button onClick={sendOtp} disabled={phone.length < 10 || loading} style={btnStyle(phone.length < 10 || loading)}>
              {loading ? 'sending…' : 'send OTP'}
            </button>
          </>
        ) : (
          <>
            <p style={{ fontFamily: WK.mono, fontSize: 11, color: WK.muted, marginBottom: 12 }}>
              OTP sent to +91{phone}
            </p>
            <input
              type="text"
              inputMode="numeric"
              value={otp}
              onChange={(e) => setOtp(e.target.value.replace(/\D/g, '').slice(0, 6))}
              placeholder="• • • • • •"
              style={{
                width: '100%',
                padding: '14px',
                border: `1px solid ${WK.ink}`,
                borderRadius: 12,
                background: 'transparent',
                outline: 'none',
                fontFamily: WK.mono,
                fontSize: 20,
                color: WK.ink,
                textAlign: 'center',
                letterSpacing: 8,
                marginBottom: 12,
                boxSizing: 'border-box',
              }}
            />
            <button onClick={verifyOtp} disabled={otp.length < 6 || loading} style={btnStyle(otp.length < 6 || loading)}>
              {loading ? 'verifying…' : 'verify'}
            </button>
            <button
              onClick={() => { setStep('phone'); setOtp(''); setError(''); }}
              style={{
                width: '100%',
                padding: '10px 0',
                background: 'transparent',
                color: WK.muted,
                border: 'none',
                cursor: 'pointer',
                fontFamily: WK.mono,
                fontSize: 11,
                marginTop: 8,
              }}
            >
              ← change number
            </button>
          </>
        )}

        {error && (
          <p style={{ fontFamily: WK.mono, fontSize: 11, color: '#ef4444', marginTop: 10, textAlign: 'center' }}>
            {error}
          </p>
        )}
      </div>
    </div>}
    </>
  );
}
