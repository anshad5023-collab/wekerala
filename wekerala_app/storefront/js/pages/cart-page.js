import { t, getLang } from '../translations.js';
import { getCart, updateQty, removeItem, getTotal } from '../cart.js';
import { renderHeader } from '../app.js';

export async function renderCart(appEl, state, attachHeader) {
  const { shop, slug } = state;
  let orderNote = '';

  function itemsHtml(cart) {
    return cart.map((item) => {
      const variantLine = item.variantName ? `<div class="cart-item-variant">${item.variantName}</div>` : '';
      const noteLine = item.itemNote ? `<div class="cart-item-note">${item.itemNote}</div>` : '';
      const imgHtml = `<div class="cart-item-img-placeholder">🛒</div>`;
      return `
        <div class="cart-item">
          ${imgHtml}
          <div class="cart-item-info">
            <div class="cart-item-name">${item.productName}</div>
            ${variantLine}
            ${noteLine}
            <div class="cart-item-bottom">
              <div class="qty-control">
                <button class="qty-btn" data-action="minus" data-pid="${item.productId}" data-vid="${item.variantId}">−</button>
                <span class="qty-num">${item.qty}</span>
                <button class="qty-btn" data-action="plus" data-pid="${item.productId}" data-vid="${item.variantId}">+</button>
              </div>
              <div class="cart-item-price">₹${(item.price * item.qty).toFixed(0)}</div>
            </div>
            <button class="cart-item-remove" data-pid="${item.productId}" data-vid="${item.variantId}">${t('out_of_stock') === t('out_of_stock') ? '✕ Remove' : '✕'}</button>
          </div>
        </div>`;
    }).join('');
  }

  function render() {
    const cart = getCart(slug);
    const total = getTotal(slug);
    const minOrder = shop.minOrderValue || 0;
    const belowMin = minOrder > 0 && total < minOrder;

    if (cart.length === 0) {
      appEl.innerHTML = `
        ${renderHeader(slug, shop, true)}
        <div class="empty-state">
          <div class="empty-state-icon">🛒</div>
          <div class="empty-state-title">${t('cart_empty')}</div>
          <div class="empty-state-sub">${t('cart_empty_sub')}</div>
        </div>
        <div class="cart-actions">
          <button class="btn-primary" id="back-shop">${t('continue_shopping')}</button>
        </div>`;
      attachHeader(slug);
      document.getElementById('back-shop')?.addEventListener('click', () => { window.location.hash = `#/${slug}`; });
      return;
    }

    appEl.innerHTML = `
      ${renderHeader(slug, shop, true)}
      <div class="cart-list">${itemsHtml(cart)}</div>
      <div class="order-note-section">
        <div class="section-label">${t('order_note')}</div>
        <textarea class="note-input" id="order-note" placeholder="${t('order_note_placeholder')}">${orderNote}</textarea>
      </div>
      <div class="cart-summary">
        <div class="cart-summary-row">
          <span>${t('subtotal')}</span><span>₹${total.toFixed(0)}</span>
        </div>
        <div class="cart-summary-row total">
          <span>${t('total')}</span><span>₹${total.toFixed(0)}</span>
        </div>
      </div>
      ${belowMin ? `<div class="min-order-notice">${t('min_order_notice')}${minOrder}</div>` : ''}
      <div class="cart-actions">
        <button class="btn-primary" id="checkout-btn" ${belowMin ? 'disabled' : ''}>${t('proceed_checkout')}</button>
        <button class="btn-secondary" id="back-shop">${t('continue_shopping')}</button>
      </div>`;

    attachHeader(slug);
    bindEvents();
  }

  function bindEvents() {
    document.getElementById('order-note')?.addEventListener('input', (e) => { orderNote = e.target.value; });

    document.querySelector('.cart-list')?.addEventListener('click', (e) => {
      const btn = e.target.closest('[data-action]');
      const removeBtn = e.target.closest('.cart-item-remove');

      if (btn) {
        const pid = btn.dataset.pid;
        const vid = btn.dataset.vid;
        const cart = getCart(slug);
        const item = cart.find((i) => i.productId === pid && i.variantId === vid);
        if (!item) return;
        const newQty = btn.dataset.action === 'plus' ? item.qty + 1 : item.qty - 1;
        updateQty(slug, pid, vid, newQty);
        render();
      } else if (removeBtn) {
        removeItem(slug, removeBtn.dataset.pid, removeBtn.dataset.vid);
        render();
      }
    });

    document.getElementById('checkout-btn')?.addEventListener('click', () => {
      // Save order note for checkout to read
      sessionStorage.setItem(`order_note_${slug}`, orderNote);
      window.location.hash = `#/${slug}/checkout`;
    });

    document.getElementById('back-shop')?.addEventListener('click', () => { window.location.hash = `#/${slug}`; });
  }

  render();
}
