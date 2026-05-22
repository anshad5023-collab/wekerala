import { db } from '../firebase-init.js';
import {
  collection, query, where, orderBy, limit, startAfter, getDocs,
} from 'https://www.gstatic.com/firebasejs/10.7.1/firebase-firestore.js';
import { t, getLang } from '../translations.js';
import { addItem, getItemCount } from '../cart.js';
import { renderHeader } from '../app.js';

const PAGE_SIZE = 20;

function productCardHtml(p, slug, lang) {
  const name = lang === 'ml' && p.nameMl ? p.nameMl : p.nameEn;
  const imgHtml = p.imageUrl
    ? `<img class="product-card-img" src="${p.imageUrl}" alt="${name}" loading="lazy">`
    : `<div class="product-card-img-placeholder">🛒</div>`;
  const priceHtml = p.offerPrice && p.offerPrice < p.price
    ? `<span class="price-main">₹${p.offerPrice}</span><span class="price-original">₹${p.price}</span>`
    : `<span class="price-main">₹${p.price}</span>`;
  const addBtn = p.isOutOfStock
    ? `<div class="product-card-oos">${t('out_of_stock')}</div>`
    : p.hasVariants
      ? `<button class="product-card-add" data-id="${p.productId}">${t('add_to_cart')}</button>`
      : `<button class="product-card-add" data-id="${p.productId}" data-price="${p.offerPrice || p.price}" data-name="${name}" data-unit="${p.unit || ''}">${t('add_to_cart')}</button>`;

  return `
    <div class="product-card" data-id="${p.productId}">
      <div class="product-card-img-wrap">${imgHtml}</div>
      <div class="product-card-body">
        <div class="product-card-name">${name}</div>
        <div class="product-card-unit">${p.unit || ''}</div>
        <div class="product-card-price">${priceHtml}</div>
        ${addBtn}
      </div>
    </div>`;
}

function closedPageHtml(shop, slug) {
  const phone = shop.ownerWhatsApp || shop.ownerPhone || '';
  const waLink = phone ? `https://wa.me/91${phone.replace(/\D/g, '').slice(-10)}` : '#';
  return `
    <div class="closed-page">
      <div class="closed-icon">🔒</div>
      <div class="closed-title">${t('shop_closed')}</div>
      <div class="closed-subtitle">${t('shop_closed_msg')}</div>
      ${phone ? `<a class="whatsapp-btn" href="${waLink}" target="_blank">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="white"><path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347z"/><path d="M12 0C5.373 0 0 5.373 0 12c0 2.123.555 4.116 1.524 5.845L.057 23.885l6.224-1.635A11.945 11.945 0 0012 24c6.627 0 12-5.373 12-12S18.627 0 12 0zm0 22c-1.885 0-3.646-.514-5.153-1.41l-.369-.22-3.694.97.985-3.598-.241-.372A9.945 9.945 0 012 12C2 6.477 6.477 2 12 2s10 4.477 10 10-4.477 10-10 10z"/></svg>
        ${t('contact_shop')}
      </a>` : ''}
    </div>`;
}

export async function renderHome(appEl, state, attachHeader) {
  const { shop, shopId, slug } = state;
  const lang = getLang();
  let activeCategory = 'all';
  let searchQuery = '';
  let lastDoc = null;
  let hasMore = true;
  let allProducts = [];
  let loading = false;

  const categories = Array.isArray(shop.categories) ? shop.categories : [];

  function categoryTabsHtml() {
    const tabs = [{ id: 'all', label: t('all_categories') }, ...categories.map((c) => ({ id: c, label: c }))];
    return tabs.map((c) => `<button class="cat-tab${c.id === activeCategory ? ' active' : ''}" data-cat="${c.id}">${c.label}</button>`).join('');
  }

  function gridHtml() {
    if (allProducts.length === 0 && !loading) {
      return `<div class="empty-state" style="grid-column:1/-1">
        <div class="empty-state-icon">📦</div>
        <div class="empty-state-title">${t('no_products')}</div>
      </div>`;
    }
    return allProducts.map((p) => productCardHtml(p, slug, lang)).join('');
  }

  function render() {
    const isOpen = shop.isOpen;
    appEl.innerHTML = `
      ${renderHeader(slug, shop)}
      ${!isOpen ? closedPageHtml(shop, slug) : `
        <div class="search-bar">
          <input class="search-input" type="search" placeholder="${t('search_placeholder')}" value="${searchQuery}" id="search-input">
        </div>
        <div class="category-tabs" id="cat-tabs">${categoryTabsHtml()}</div>
        <div class="section-header">
          <span class="section-title">${activeCategory === 'all' ? t('all_categories') : activeCategory}</span>
          <span class="section-count">${allProducts.length} items</span>
        </div>
        <div class="product-grid" id="product-grid">${gridHtml()}</div>
        ${loading ? `<div class="page-loading"><div class="spinner"></div></div>` : ''}
        ${hasMore && !loading && allProducts.length > 0 ? `<button class="load-more" id="load-more">${t('load_more')}</button>` : ''}
      `}`;

    attachHeader(slug);
    bindEvents();
  }

  function bindEvents() {
    document.getElementById('search-input')?.addEventListener('input', (e) => {
      searchQuery = e.target.value.trim();
      reset();
    });

    document.getElementById('cat-tabs')?.addEventListener('click', (e) => {
      const btn = e.target.closest('.cat-tab');
      if (!btn) return;
      activeCategory = btn.dataset.cat;
      reset();
    });

    document.getElementById('product-grid')?.addEventListener('click', (e) => {
      const card = e.target.closest('.product-card');
      if (!card) return;
      const addBtn = e.target.closest('.product-card-add');
      if (addBtn && !addBtn.disabled) {
        const p = allProducts.find((x) => x.productId === card.dataset.id);
        if (!p) return;
        if (p.hasVariants) {
          // Navigate to detail page for variant selection
          window.location.hash = `#/${slug}/p/${p.productId}`;
          return;
        }
        addItem(slug, {
          productId: p.productId,
          productName: getLang() === 'ml' && p.nameMl ? p.nameMl : p.nameEn,
          variantId: '',
          variantName: '',
          price: p.offerPrice || p.price,
          qty: p.minQty || 1,
          unit: p.unit || '',
          itemNote: '',
        });
        updateCartBadge();
        addBtn.textContent = '✓ Added';
        setTimeout(() => { addBtn.textContent = t('add_to_cart'); }, 1200);
      } else {
        window.location.hash = `#/${slug}/p/${card.dataset.id}`;
      }
    });

    document.getElementById('load-more')?.addEventListener('click', () => {
      loadProducts(false);
    });
  }

  function updateCartBadge() {
    const count = getItemCount(slug);
    const badge = document.querySelector('.cart-badge');
    const btn = document.getElementById('cart-btn');
    if (btn) {
      const existing = btn.querySelector('.cart-badge');
      if (count > 0) {
        if (existing) { existing.textContent = count; }
        else { btn.insertAdjacentHTML('beforeend', `<span class="cart-badge">${count}</span>`); }
      } else {
        existing?.remove();
      }
    }
  }

  function reset() {
    lastDoc = null;
    hasMore = true;
    allProducts = [];
    loadProducts(true);
  }

  async function loadProducts(initial) {
    if (loading) return;
    loading = true;
    if (initial) render();

    try {
      let q;
      const col = collection(db, 'shops', shopId, 'products');
      const constraints = [where('isHidden', '==', false)];
      if (activeCategory !== 'all') constraints.push(where('category', '==', activeCategory));
      constraints.push(orderBy('nameEn'));
      constraints.push(limit(PAGE_SIZE));
      if (lastDoc) constraints.push(startAfter(lastDoc));

      q = query(col, ...constraints);
      const snap = await getDocs(q);

      let newProducts = snap.docs.map((d) => ({ productId: d.id, ...d.data() }));

      if (searchQuery) {
        const sq = searchQuery.toLowerCase();
        newProducts = newProducts.filter(
          (p) => p.nameEn.toLowerCase().includes(sq) || (p.nameMl && p.nameMl.includes(sq))
        );
      }

      allProducts = [...allProducts, ...newProducts];
      lastDoc = snap.docs[snap.docs.length - 1] || null;
      hasMore = snap.docs.length === PAGE_SIZE;
    } catch (err) {
      console.error('Load products error:', err);
    }

    loading = false;
    render();
  }

  loadProducts(true);
  return null;
}
