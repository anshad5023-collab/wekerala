import { db } from './firebase-init.js';
import { doc, getDoc, onSnapshot } from 'https://www.gstatic.com/firebasejs/10.7.1/firebase-firestore.js';
import { t, toggleLang, getLang } from './translations.js';
import { getItemCount } from './cart.js';

import { renderHome } from './pages/home.js';
import { renderProductDetail } from './pages/product-detail.js';
import { renderCart } from './pages/cart-page.js';
import { renderCheckout } from './pages/checkout.js';
import { renderConfirmation } from './pages/confirmation.js';
import { renderOrderStatus } from './pages/order-status.js';

const appEl = document.getElementById('app');

// Active Firestore unsubscribe function (cleaned up on each navigation)
let unsubscribePage = null;
let unsubscribeShop = null;

// Shared state
export const state = {
  shop: null,
  shopId: null,
  slug: null,
};

function parseRoute() {
  // Hash format: #/slug/rest...
  const hash = window.location.hash.replace('#', '') || '/';
  const parts = hash.split('/').filter(Boolean);
  return {
    slug: parts[0] || null,
    rest: parts.slice(1),
  };
}

function cartIcon(slug) {
  const count = getItemCount(slug);
  const badge = count > 0 ? `<span class="cart-badge">${count}</span>` : '';
  return `
    <button class="cart-btn" id="cart-btn" aria-label="cart">
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <path d="M6 2L3 6v14a2 2 0 002 2h14a2 2 0 002-2V6l-3-4z"/>
        <line x1="3" y1="6" x2="21" y2="6"/>
        <path d="M16 10a4 4 0 01-8 0"/>
      </svg>
      ${badge}
    </button>`;
}

export function renderHeader(slug, shop, showBack = false) {
  const isOpen = shop?.isOpen ?? true;
  const lang = getLang();
  const name = lang === 'ml' && shop?.shopNameMl ? shop.shopNameMl : (shop?.shopName ?? 'ShopLink');
  const openLabel = isOpen ? t('open') : t('closed');
  const openClass = isOpen ? '' : 'closed';
  const backBtn = showBack
    ? `<button class="back-btn" id="back-btn">
        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
          <polyline points="15 18 9 12 15 6"/>
        </svg>
      </button>`
    : '';
  return `
    <header class="header">
      ${backBtn}
      <span class="header-title">${name}</span>
      <span class="header-open-badge ${openClass}">${openLabel}</span>
      <button class="lang-btn" id="lang-btn">${t('lang_toggle')}</button>
      ${cartIcon(slug)}
    </header>`;
}

function attachHeaderEvents(slug) {
  document.getElementById('lang-btn')?.addEventListener('click', () => {
    toggleLang();
    navigate();
  });
  document.getElementById('cart-btn')?.addEventListener('click', () => {
    window.location.hash = `#/${slug}/cart`;
  });
  document.getElementById('back-btn')?.addEventListener('click', () => {
    history.back();
  });
}

export function attachHeaderEventsFor(slug) {
  attachHeaderEvents(slug);
}

async function loadShop(slug) {
  // Query by shopSlug field
  const { collection, query, where, getDocs } = await import(
    'https://www.gstatic.com/firebasejs/10.7.1/firebase-firestore.js'
  );
  const q = query(collection(db, 'shops'), where('shopSlug', '==', slug), where('isActive', '==', true));
  const snap = await getDocs(q);
  if (snap.empty) return null;
  const docSnap = snap.docs[0];
  return { shopId: docSnap.id, ...docSnap.data() };
}

function showError(msg) {
  appEl.innerHTML = `
    <div class="error-page">
      <div class="error-icon">😕</div>
      <div class="error-title">${msg}</div>
      <div class="error-sub">${t('error_load')}</div>
    </div>`;
}

async function navigate() {
  // Clean up previous page subscription
  if (unsubscribePage) { unsubscribePage(); unsubscribePage = null; }

  const { slug, rest } = parseRoute();

  if (!slug) {
    appEl.innerHTML = `<div class="empty-state"><div class="empty-state-icon">🏪</div><div class="empty-state-title">ShopLink</div></div>`;
    return;
  }

  // Load shop if slug changed
  if (state.slug !== slug) {
    if (unsubscribeShop) { unsubscribeShop(); unsubscribeShop = null; }
    appEl.innerHTML = `<div class="page-loading"><div class="spinner"></div></div>`;
    const shopData = await loadShop(slug);
    if (!shopData) { showError(`Shop "${slug}" not found`); return; }
    state.shop = shopData;
    state.shopId = shopData.shopId;
    state.slug = slug;

    // Listen for isOpen / shopName changes
    unsubscribeShop = onSnapshot(doc(db, 'shops', state.shopId), (d) => {
      if (d.exists()) {
        state.shop = { shopId: d.id, ...d.data() };
        // Update open badge in header without full re-render
        const badge = document.querySelector('.header-open-badge');
        if (badge) {
          badge.textContent = state.shop.isOpen ? t('open') : t('closed');
          badge.className = `header-open-badge${state.shop.isOpen ? '' : ' closed'}`;
        }
      }
    });
  }

  const page = rest[0];

  if (!page) {
    unsubscribePage = await renderHome(appEl, state, attachHeaderEventsFor);
  } else if (page === 'p' && rest[1]) {
    unsubscribePage = await renderProductDetail(appEl, state, rest[1], attachHeaderEventsFor);
  } else if (page === 'cart') {
    await renderCart(appEl, state, attachHeaderEventsFor);
  } else if (page === 'checkout') {
    await renderCheckout(appEl, state, attachHeaderEventsFor);
  } else if (page === 'confirm' && rest[1]) {
    await renderConfirmation(appEl, state, rest[1], attachHeaderEventsFor);
  } else if (page === 'status' && rest[1]) {
    unsubscribePage = await renderOrderStatus(appEl, state, rest[1], attachHeaderEventsFor);
  } else {
    showError('Page not found');
  }
}

window.addEventListener('hashchange', navigate);
navigate();
