'use client';

import { useState, useEffect } from 'react';
import { ArrowLeft } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { useCartStore } from '@/lib/cart-store';
import { useAuthStore } from '@/lib/auth-store';
import { translations, type Language } from '@/lib/translations';

interface CheckoutPageProps {
  language: Language;
  onBack: () => void;
  onConfirm: (details: CustomerDetails) => void;
  onLanguageToggle: () => void;
  shopId?: string;
  deliveryCharge?: number;
  freeDeliveryAbove?: number;
  upiId?: string;
  isSubmitting?: boolean;
  errorMessage?: string;
}

export interface CustomerDetails {
  name: string;
  phone: string;
  address: string;
  note: string;
  couponCode?: string;
  discountPercent?: number;
  deliveryCharge?: number;
  paymentMethod?: 'cash' | 'upi';
  preferredDelivery?: string; // ISO datetime string for pre-orders
}

interface SavedAddress { id: string; label: string; address: string; isDefault: boolean; }

export function CheckoutPage({ language, onBack, onConfirm, onLanguageToggle, shopId, deliveryCharge = 0, freeDeliveryAbove = 0, upiId, isSubmitting = false, errorMessage = '' }: CheckoutPageProps) {
  const t = translations[language];
  const subtotal = useCartStore((state) => state.getTotal());
  const cartItems = useCartStore((state) => state.items);
  const itemCount = useCartStore((state) => state.getItemCount());
  const { uid, phone: savedPhone } = useAuthStore();

  const [formData, setFormData] = useState<CustomerDetails>({
    name: '',
    phone: savedPhone ?? '',
    address: '',
    note: '',
  });
  const [savedAddresses, setSavedAddresses] = useState<SavedAddress[]>([]);
  const [errors, setErrors] = useState<Partial<CustomerDetails>>({});
  const [couponInput, setCouponInput] = useState('');
  const [couponApplying, setCouponApplying] = useState(false);
  const [couponError, setCouponError] = useState('');
  const [appliedCoupon, setAppliedCoupon] = useState<{ code: string; discountPercent: number } | null>(null);
  const [paymentMethod, setPaymentMethod] = useState<'cash' | 'upi'>('cash');
  const [upiCopied, setUpiCopied] = useState(false);

  useEffect(() => {
    if (!uid) return;
    fetch(`/api/customer/addresses?uid=${encodeURIComponent(uid)}`)
      .then((r) => r.json())
      .then((data) => {
        const addrs: SavedAddress[] = data.addresses ?? [];
        setSavedAddresses(addrs);
        const def = addrs.find((a) => a.isDefault) ?? addrs[0];
        if (def) setFormData((prev) => ({ ...prev, address: prev.address || def.address }));
      })
      .catch(() => {});
  }, [uid]);

  const isFreeDelivery = freeDeliveryAbove > 0 && subtotal >= freeDeliveryAbove;
  const actualDelivery = (deliveryCharge > 0 && !isFreeDelivery) ? deliveryCharge : 0;
  const discountAmount = appliedCoupon ? Math.round(subtotal * appliedCoupon.discountPercent / 100) : 0;
  const total = subtotal;
  const finalTotal = subtotal - discountAmount + actualDelivery;

  const applyCoupon = async () => {
    if (!shopId || !couponInput.trim()) return;
    setCouponApplying(true);
    setCouponError('');
    try {
      const res = await fetch(`/api/coupon?shopId=${shopId}&code=${encodeURIComponent(couponInput.trim())}`);
      const data = await res.json() as { valid: boolean; code?: string; discountPercent?: number; error?: string };
      if (data.valid && data.code && data.discountPercent) {
        setAppliedCoupon({ code: data.code, discountPercent: data.discountPercent });
        setCouponError('');
      } else {
        setCouponError(data.error || 'Invalid coupon');
        setAppliedCoupon(null);
      }
    } catch {
      setCouponError('Could not validate coupon');
    } finally {
      setCouponApplying(false);
    }
  };

  const validate = () => {
    const newErrors: Partial<CustomerDetails> = {};
    if (!formData.name.trim()) newErrors.name = 'Required';
    const cleanPhone = formData.phone.replace(/\D/g, '');
    if (!cleanPhone) newErrors.phone = 'Required';
    else if (cleanPhone.length !== 10 && !(cleanPhone.length === 12 && cleanPhone.startsWith('91')))
      newErrors.phone = 'Enter a valid 10-digit mobile number';
    if (!formData.address.trim()) newErrors.address = 'Required';
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (validate()) {
      const normalizedPhone = formData.phone.replace(/\D/g, '').slice(-10);
      onConfirm({
        ...formData,
        phone: normalizedPhone,
        couponCode: appliedCoupon?.code,
        discountPercent: appliedCoupon?.discountPercent,
        deliveryCharge: actualDelivery,
        paymentMethod,
      });
    }
  };

  return (
    <div className="flex min-h-screen flex-col bg-background">
      {/* Header */}
      <header className="sticky top-0 z-50 flex items-center justify-between bg-primary px-4 py-4 text-primary-foreground shadow-md">
        <div className="flex items-center gap-3">
          <Button
            variant="ghost"
            size="icon"
            onClick={onBack}
            className="text-white hover:bg-white/20 hover:text-white"
            aria-label="Go back"
          >
            <ArrowLeft className="h-5 w-5" />
          </Button>
          <h1 className="text-lg font-bold italic">{t.checkout}</h1>
        </div>
        <Button
          variant="ghost"
          size="sm"
          onClick={onLanguageToggle}
          className="rounded-full bg-white/10 px-3 text-xs font-medium text-white hover:bg-white/20 hover:text-white"
        >
          {language === 'en' ? 'മല' : 'EN'}
        </Button>
      </header>

      {/* Order Summary Strip */}
      <div className="bg-white border-b border-border px-4 py-3">
        <div className="flex items-center justify-between">
          <span className="text-sm font-medium text-foreground">{itemCount} item{itemCount !== 1 ? 's' : ''}</span>
          <span className="text-sm font-bold text-primary">₹{(subtotal + (discountAmount > 0 ? -discountAmount : 0)).toFixed(0)}</span>
        </div>
        <div className="mt-1 flex gap-1.5 overflow-x-auto pb-1">
          {cartItems.slice(0, 5).map((item) => (
            <span key={item.product.id} className="whitespace-nowrap rounded-full bg-primary/10 px-2 py-0.5 text-xs text-primary">
              {item.product.name.en} ×{item.quantity}
            </span>
          ))}
          {cartItems.length > 5 && (
            <span className="whitespace-nowrap rounded-full bg-muted px-2 py-0.5 text-xs text-muted-foreground">
              +{cartItems.length - 5} more
            </span>
          )}
        </div>
      </div>

      {/* Form */}
      <form onSubmit={handleSubmit} className="flex flex-1 flex-col">
        <div className="flex-1 space-y-4 p-4">
          <h2 className="text-lg font-semibold italic text-foreground">{t.deliveryDetails}</h2>
          
          {/* Customer Name */}
          <div className="space-y-1.5">
            <label htmlFor="name" className="text-sm font-medium italic text-foreground">
              {t.customerName} *
            </label>
            <input
              id="name"
              type="text"
              value={formData.name}
              onChange={(e) => setFormData({ ...formData, name: e.target.value })}
              placeholder={t.namePlaceholder}
              className={`w-full rounded-lg border bg-card px-4 py-3 italic text-card-foreground outline-none transition-colors placeholder:text-muted-foreground focus:border-primary focus:ring-2 focus:ring-primary/20 ${
                errors.name ? 'border-destructive' : 'border-border'
              }`}
            />
            {errors.name && <p className="text-xs text-destructive">{errors.name}</p>}
          </div>

          {/* Phone Number */}
          <div className="space-y-1.5">
            <label htmlFor="phone" className="text-sm font-medium italic text-foreground">
              {t.phoneNumber} *
            </label>
            <input
              id="phone"
              type="tel"
              value={formData.phone}
              onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
              placeholder={t.phonePlaceholder}
              className={`w-full rounded-lg border bg-card px-4 py-3 italic text-card-foreground outline-none transition-colors placeholder:text-muted-foreground focus:border-primary focus:ring-2 focus:ring-primary/20 ${
                errors.phone ? 'border-destructive' : 'border-border'
              }`}
            />
            {errors.phone && <p className="text-xs text-destructive">{errors.phone}</p>}
          </div>

          {/* Saved address picker */}
          {savedAddresses.length > 0 && (
            <div className="space-y-1.5">
              <p className="text-sm font-medium italic text-foreground">Saved Addresses</p>
              <div className="flex gap-2 overflow-x-auto pb-1 scrollbar-hide">
                {savedAddresses.map((a) => (
                  <button
                    key={a.id}
                    type="button"
                    onClick={() => setFormData((prev) => ({ ...prev, address: a.address }))}
                    className={`shrink-0 rounded-lg border px-3 py-2 text-left text-xs italic transition-colors ${
                      formData.address === a.address
                        ? 'border-primary bg-primary/10 text-primary'
                        : 'border-border bg-card text-muted-foreground hover:border-primary/50'
                    }`}
                  >
                    <span className="font-semibold block">{a.label}</span>
                    <span className="line-clamp-1">{a.address}</span>
                  </button>
                ))}
              </div>
            </div>
          )}

          {/* Delivery Address */}
          <div className="space-y-1.5">
            <label htmlFor="address" className="text-sm font-medium italic text-foreground">
              {t.deliveryAddress} *
            </label>
            <textarea
              id="address"
              value={formData.address}
              onChange={(e) => setFormData({ ...formData, address: e.target.value })}
              placeholder={t.addressPlaceholder}
              rows={3}
              className={`w-full resize-none rounded-lg border bg-card px-4 py-3 italic text-card-foreground outline-none transition-colors placeholder:text-muted-foreground focus:border-primary focus:ring-2 focus:ring-primary/20 ${
                errors.address ? 'border-destructive' : 'border-border'
              }`}
            />
            {errors.address && <p className="text-xs text-destructive">{errors.address}</p>}
          </div>

          {/* Order Note */}
          <div className="space-y-1.5">
            <label htmlFor="note" className="text-sm font-medium italic text-foreground">
              {t.orderNote}
            </label>
            <textarea
              id="note"
              value={formData.note}
              onChange={(e) => setFormData({ ...formData, note: e.target.value })}
              placeholder={t.orderNotePlaceholder}
              rows={2}
              className="w-full resize-none rounded-lg border border-border bg-card px-4 py-3 italic text-card-foreground outline-none transition-colors placeholder:text-muted-foreground focus:border-primary focus:ring-2 focus:ring-primary/20"
            />
          </div>

          {/* Preferred Delivery Date/Time — for pre-orders and bakeries */}
          <div className="space-y-1.5">
            <label htmlFor="preferred-delivery" className="text-sm font-medium italic text-foreground">
              Preferred Delivery Date &amp; Time <span className="text-muted-foreground font-normal">(optional)</span>
            </label>
            <input
              id="preferred-delivery"
              type="datetime-local"
              min={new Date().toISOString().slice(0, 16)}
              value={formData.preferredDelivery ?? ''}
              onChange={(e) => setFormData({ ...formData, preferredDelivery: e.target.value || undefined })}
              className="w-full rounded-lg border border-border bg-card px-4 py-3 text-card-foreground outline-none transition-colors focus:border-primary focus:ring-2 focus:ring-primary/20"
            />
            <p className="text-xs text-muted-foreground italic">For bakery orders, cake deliveries, scheduled home delivery etc.</p>
          </div>

          {/* Payment Method */}
          <div className="space-y-2">
            <p className="text-sm font-medium italic text-foreground">Payment Method</p>
            <div className="grid grid-cols-2 gap-3">
              <button
                type="button"
                onClick={() => setPaymentMethod('cash')}
                className={`flex flex-col items-center gap-1 rounded-xl border-2 p-3 transition-colors ${
                  paymentMethod === 'cash'
                    ? 'border-primary bg-primary/10 text-primary'
                    : 'border-border bg-card text-muted-foreground hover:border-primary/40'
                }`}
              >
                <span className="text-2xl">💵</span>
                <span className="text-sm font-semibold italic">Cash on Delivery</span>
              </button>
              {upiId && (
                <button
                  type="button"
                  onClick={() => setPaymentMethod('upi')}
                  className={`flex flex-col items-center gap-1 rounded-xl border-2 p-3 transition-colors ${
                    paymentMethod === 'upi'
                      ? 'border-primary bg-primary/10 text-primary'
                      : 'border-border bg-card text-muted-foreground hover:border-primary/40'
                  }`}
                >
                  <span className="text-2xl">📱</span>
                  <span className="text-sm font-semibold italic">Pay via UPI</span>
                </button>
              )}
            </div>
            {paymentMethod === 'upi' && upiId && (
              <div className="rounded-xl border border-primary/30 bg-primary/5 p-3 space-y-2">
                <p className="text-xs italic text-muted-foreground">
                  Pay <span className="font-bold text-primary">₹{finalTotal}</span> to:
                </p>
                <div className="flex items-center justify-between gap-2">
                  <span className="font-mono text-sm font-semibold text-foreground break-all">{upiId}</span>
                  <button
                    type="button"
                    onClick={() => { navigator.clipboard.writeText(upiId); setUpiCopied(true); setTimeout(() => setUpiCopied(false), 2000); }}
                    className="shrink-0 rounded-lg border border-primary/40 px-3 py-1.5 text-xs font-medium italic text-primary hover:bg-primary/10"
                  >
                    {upiCopied ? '✓ Copied' : 'Copy'}
                  </button>
                </div>
                <a
                  href={`upi://pay?pa=${encodeURIComponent(upiId)}&am=${finalTotal}&cu=INR&tn=Order+from+shop`}
                  className="block w-full rounded-lg bg-[#5A2D82] py-2.5 text-center text-sm font-semibold italic text-white hover:opacity-90"
                >
                  Open UPI App (PhonePe / GPay / Paytm)
                </a>
                <p className="text-xs italic text-center text-muted-foreground">
                  Pay first, then place the order below ↓
                </p>
              </div>
            )}
            {paymentMethod === 'upi' && !upiId && (
              <p className="text-xs italic text-muted-foreground">This shop does not have UPI set up. Please pay cash on delivery.</p>
            )}
          </div>

          {/* Coupon Code */}
          {shopId && (
            <div className="space-y-1.5">
              <label className="text-sm font-medium italic text-foreground">Coupon Code</label>
              {appliedCoupon ? (
                <div className="flex items-center justify-between rounded-lg border border-green-300 bg-green-50 px-4 py-3">
                  <div>
                    <span className="text-sm font-bold text-green-700">{appliedCoupon.code}</span>
                    <span className="ml-2 text-xs text-green-600">{appliedCoupon.discountPercent}% off — saving ₹{discountAmount}</span>
                  </div>
                  <button
                    type="button"
                    onClick={() => { setAppliedCoupon(null); setCouponInput(''); }}
                    className="text-xs text-red-500 underline"
                  >
                    Remove
                  </button>
                </div>
              ) : (
                <div className="flex gap-2">
                  <input
                    type="text"
                    value={couponInput}
                    onChange={(e) => { setCouponInput(e.target.value.toUpperCase()); setCouponError(''); }}
                    placeholder="Enter coupon code"
                    className="flex-1 rounded-lg border border-border bg-card px-4 py-3 text-sm italic text-card-foreground outline-none focus:border-primary focus:ring-2 focus:ring-primary/20"
                  />
                  <Button
                    type="button"
                    variant="outline"
                    onClick={applyCoupon}
                    disabled={couponApplying || !couponInput.trim()}
                    className="shrink-0 px-4 italic"
                  >
                    {couponApplying ? '...' : 'Apply'}
                  </Button>
                </div>
              )}
              {couponError && <p className="text-xs text-destructive">{couponError}</p>}
            </div>
          )}
        </div>

        {/* Submit Bar */}
        <div className="sticky bottom-0 border-t border-border bg-card p-4 shadow-[0_-4px_20px_rgba(0,0,0,0.1)]">
          <div className="mb-4 space-y-1">
            <div className="flex items-center justify-between text-sm">
              <span className="italic text-muted-foreground">Subtotal</span>
              <span className="italic text-card-foreground">₹{subtotal}</span>
            </div>
            {actualDelivery > 0 && (
              <div className="flex items-center justify-between text-sm">
                <span className="italic text-muted-foreground">Delivery</span>
                <span className="italic text-card-foreground">₹{actualDelivery}</span>
              </div>
            )}
            {isFreeDelivery && deliveryCharge > 0 && (
              <div className="flex items-center justify-between text-sm">
                <span className="italic text-green-600">Delivery</span>
                <span className="italic text-green-600 font-medium">Free 🎉</span>
              </div>
            )}
            {appliedCoupon && (
              <div className="flex items-center justify-between text-sm">
                <span className="italic text-green-600">Coupon ({appliedCoupon.code})</span>
                <span className="italic text-green-600">-₹{discountAmount}</span>
              </div>
            )}
            <div className="flex items-center justify-between border-t border-border pt-1 mt-1">
              <span className="italic text-muted-foreground">{t.total}</span>
              <span className="text-2xl font-bold italic text-primary">₹{finalTotal}</span>
            </div>
          </div>
          {errorMessage && (
            <p className="mb-3 rounded-lg border border-orange-300 bg-orange-50 px-3 py-2 text-sm text-orange-700 text-center">
              🔴 {errorMessage}
            </p>
          )}
          <Button type="submit" disabled={isSubmitting} className="w-full py-6 text-lg font-semibold italic" size="lg">
            {isSubmitting ? 'Placing Order...' : t.confirmOrder}
          </Button>
        </div>
      </form>
    </div>
  );
}
