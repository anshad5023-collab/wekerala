import { db } from '../firebase-init.js';
import { doc, getDoc } from 'https://www.gstatic.com/firebasejs/10.7.1/firebase-firestore.js';
import { t } from '../translations.js';
import { renderHeader } from '../app.js';

export async function renderConfirmation(appEl, state, orderId, attachHeader) {
  const { shop, shopId, slug } = state;

  appEl.innerHTML = `${renderHeader(slug, shop, false)}<div class="page-loading"><div class="spinner"></div></div>`;
  attachHeader(slug);

  let order;
  try {
    const snap = await getDoc(doc(db, 'shops', shopId, 'orders', orderId));
    if (!snap.exists()) throw new Error('not found');
    order = snap.data();
  } catch {
    appEl.innerHTML = `${renderHeader(slug, shop, false)}
      <div class="error-page"><div class="error-icon">😕</div><div class="error-title">${t('error_load')}</div></div>`;
    attachHeader(slug);
    return;
  }

  const itemsHtml = order.items.map((item) => {
    const variant = item.variantName ? ` (${item.variantName})` : '';
    return `<div class="confirm-item-row">
      <span>${item.productName}${variant} × ${item.qty}</span>
      <span>₹${item.subtotal}</span>
    </div>`;
  }).join('');

  appEl.innerHTML = `
    ${renderHeader(slug, shop, false)}
    <div class="confirm-page">
      <div class="confirm-icon">✅</div>
      <div class="confirm-title">${t('order_placed')}</div>
      <div class="confirm-subtitle">${t('order_placed_sub')}</div>
      <div class="order-number-box">
        <div class="order-number-label">${t('order_number')}</div>
        <div class="order-number-value">#${order.orderNumber}</div>
      </div>
      <div class="confirm-items">
        ${itemsHtml}
        <div class="confirm-total">
          <span>${t('total')}</span>
          <span>₹${order.totalAmount}</span>
        </div>
      </div>
      <div style="display:flex;flex-direction:column;gap:10px;width:100%">
        <button class="btn-primary" id="track-btn">${t('track_order')}</button>
        <button class="btn-secondary" id="back-shop-btn">${t('back_to_shop')}</button>
      </div>
    </div>`;

  attachHeader(slug);

  document.getElementById('track-btn')?.addEventListener('click', () => {
    window.location.hash = `#/${slug}/status/${orderId}`;
  });
  document.getElementById('back-shop-btn')?.addEventListener('click', () => {
    window.location.hash = `#/${slug}`;
  });
}
