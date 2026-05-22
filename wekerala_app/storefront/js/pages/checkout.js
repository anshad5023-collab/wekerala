import { db } from '../firebase-init.js';
import {
  collection, doc, runTransaction, serverTimestamp,
} from 'https://www.gstatic.com/firebasejs/10.7.1/firebase-firestore.js';
import { t, getLang } from '../translations.js';
import { getCart, getTotal, clearCart } from '../cart.js';
import { renderHeader } from '../app.js';

export async function renderCheckout(appEl, state, attachHeader) {
  const { shop, shopId, slug } = state;
  const lang = getLang();
  const cart = getCart(slug);
  const orderNote = sessionStorage.getItem(`order_note_${slug}`) || '';

  if (cart.length === 0) {
    window.location.hash = `#/${slug}/cart`;
    return;
  }

  const canDeliver = shop.deliveryType === 'delivery' || shop.deliveryType === 'both';
  const canPickup = shop.deliveryType === 'pickup' || shop.deliveryType === 'both';
  const cashEnabled = Array.isArray(shop.paymentMethods) ? shop.paymentMethods.includes('cash') : true;
  const upiEnabled = Array.isArray(shop.paymentMethods) ? shop.paymentMethods.includes('upi') : false;

  let form = {
    name: '',
    phone: '',
    location: '',
    deliveryType: canDeliver ? 'delivery' : 'pickup',
    paymentMethod: cashEnabled ? 'cash' : 'upi',
  };
  let errors = {};
  let submitting = false;

  function validate() {
    errors = {};
    if (!form.name.trim()) errors.name = t('name_required');
    if (!/^\d{10}$/.test(form.phone.replace(/\s/g, ''))) errors.phone = t('phone_required');
    return Object.keys(errors).length === 0;
  }

  function deliveryOptionsHtml() {
    if (!canDeliver || !canPickup) return '';
    return `
      <div class="form-group">
        <div class="form-label">${t('delivery_type')}</div>
        <div class="delivery-options">
          <div class="delivery-option${form.deliveryType === 'delivery' ? ' active' : ''}" data-dtype="delivery">${t('delivery')}</div>
          <div class="delivery-option${form.deliveryType === 'pickup' ? ' active' : ''}" data-dtype="pickup">${t('pickup')}</div>
        </div>
      </div>`;
  }

  function paymentOptionsHtml() {
    return `
      <div class="form-group">
        <div class="form-label">${t('payment_method')}</div>
        <div class="payment-options">
          ${cashEnabled ? `<div class="payment-option${form.paymentMethod === 'cash' ? ' active' : ''}" data-pm="cash">${t('cash')}</div>` : ''}
          ${upiEnabled ? `<div class="payment-option${form.paymentMethod === 'upi' ? ' active' : ''}" data-pm="upi">${t('upi')}</div>` : ''}
        </div>
        ${form.paymentMethod === 'upi' && shop.upiId ? `<div class="upi-id-box">${t('upi_pay_to')}: ${shop.upiId}</div>` : ''}
      </div>`;
  }

  function render() {
    const total = getTotal(slug);
    appEl.innerHTML = `
      ${renderHeader(slug, shop, true)}
      <form class="checkout-form" id="checkout-form" autocomplete="on">
        <div class="form-group">
          <label class="form-label" for="name">${t('your_name')}</label>
          <input class="form-input" id="name" type="text" value="${form.name}" autocomplete="name" placeholder="${t('your_name')}">
          ${errors.name ? `<div class="form-error">${errors.name}</div>` : ''}
        </div>
        <div class="form-group">
          <label class="form-label" for="phone">${t('your_phone')}</label>
          <input class="form-input" id="phone" type="tel" value="${form.phone}" inputmode="numeric" autocomplete="tel" placeholder="10-digit number">
          ${errors.phone ? `<div class="form-error">${errors.phone}</div>` : ''}
        </div>
        <div class="form-group">
          <label class="form-label" for="location">${t('your_location')}</label>
          <input class="form-input" id="location" type="text" value="${form.location}" placeholder="${t('location_placeholder')}">
        </div>
        ${deliveryOptionsHtml()}
        ${paymentOptionsHtml()}
        <div class="cart-summary">
          <div class="cart-summary-row total">
            <span>${t('total')}</span><span>₹${total.toFixed(0)}</span>
          </div>
        </div>
        <button type="submit" class="btn-primary" ${submitting ? 'disabled' : ''}>
          ${submitting ? t('loading') : t('place_order')}
        </button>
      </form>`;

    attachHeader(slug);
    bindEvents();
  }

  function bindEvents() {
    document.querySelector('.delivery-options')?.addEventListener('click', (e) => {
      const opt = e.target.closest('[data-dtype]');
      if (opt) { form.deliveryType = opt.dataset.dtype; render(); }
    });

    document.querySelector('.payment-options')?.addEventListener('click', (e) => {
      const opt = e.target.closest('[data-pm]');
      if (opt) { form.paymentMethod = opt.dataset.pm; render(); }
    });

    ['name', 'phone', 'location'].forEach((field) => {
      document.getElementById(field)?.addEventListener('input', (e) => {
        form[field] = e.target.value;
      });
    });

    document.getElementById('checkout-form')?.addEventListener('submit', async (e) => {
      e.preventDefault();
      form.name = document.getElementById('name').value.trim();
      form.phone = document.getElementById('phone').value.trim();
      form.location = document.getElementById('location').value.trim();
      if (!validate()) { render(); return; }

      submitting = true;
      render();

      try {
        const orderId = `${shopId}_${Date.now()}`;
        const orderRef = doc(collection(db, 'shops', shopId, 'orders'));
        const shopRef = doc(db, 'shops', shopId);

        const items = cart.map((item) => ({
          productId: item.productId,
          productName: item.productName,
          variantName: item.variantName || '',
          qty: item.qty,
          unit: item.unit,
          price: item.price,
          itemNote: item.itemNote || '',
          subtotal: item.price * item.qty,
        }));

        const totalAmount = items.reduce((s, i) => s + i.subtotal, 0);
        const now = serverTimestamp();

        await runTransaction(db, async (txn) => {
          const shopSnap = await txn.get(shopRef);
          const orderNumber = (shopSnap.data()?.totalOrders || 0) + 1;

          txn.set(orderRef, {
            orderId: orderRef.id,
            shopId,
            orderNumber,
            status: 'new',
            customerName: form.name,
            customerPhone: form.phone,
            customerLocation: form.location || null,
            deliveryType: form.deliveryType,
            orderNote,
            items,
            totalAmount,
            paymentMethod: form.paymentMethod,
            paymentStatus: 'pending',
            createdAt: now,
            updatedAt: now,
            statusHistory: [{ status: 'new', timestamp: new Date().toISOString() }],
          });

          txn.update(shopRef, { totalOrders: orderNumber });
        });

        clearCart(slug);
        sessionStorage.removeItem(`order_note_${slug}`);
        window.location.hash = `#/${slug}/confirm/${orderRef.id}`;
      } catch (err) {
        console.error('Order error:', err);
        submitting = false;
        appEl.querySelector('button[type=submit]').textContent = t('error_order');
        appEl.querySelector('button[type=submit]').disabled = false;
      }
    });
  }

  render();
}
