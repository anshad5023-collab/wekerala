import { db } from '../firebase-init.js';
import { doc, getDoc } from 'https://www.gstatic.com/firebasejs/10.7.1/firebase-firestore.js';
import { t, getLang } from '../translations.js';
import { addItem } from '../cart.js';
import { renderHeader } from '../app.js';

export async function renderProductDetail(appEl, state, productId, attachHeader) {
  const { shop, shopId, slug } = state;
  const lang = getLang();

  appEl.innerHTML = `${renderHeader(slug, shop, true)}<div class="page-loading"><div class="spinner"></div></div>`;
  attachHeader(slug);

  let product;
  try {
    const snap = await getDoc(doc(db, 'shops', shopId, 'products', productId));
    if (!snap.exists()) throw new Error('not found');
    product = { productId: snap.id, ...snap.data() };
  } catch {
    appEl.innerHTML = `${renderHeader(slug, shop, true)}
      <div class="error-page"><div class="error-icon">😕</div><div class="error-title">${t('error_load')}</div></div>`;
    attachHeader(slug);
    return null;
  }

  const name = lang === 'ml' && product.nameMl ? product.nameMl : product.nameEn;
  const variants = Array.isArray(product.variants) ? product.variants : [];
  let selectedVariant = variants.length > 0 ? variants[0] : null;
  let qty = product.minQty || 1;
  let itemNote = '';

  function effectivePrice() {
    if (selectedVariant) return selectedVariant.offerPrice || selectedVariant.price;
    return product.offerPrice || product.price;
  }

  function variantsHtml() {
    if (!product.hasVariants || variants.length === 0) return '';
    return `
      <div class="variant-label">${t('select_variant')}</div>
      <div class="variant-chips">
        ${variants.map((v) => `
          <div class="variant-chip${selectedVariant?.variantId === v.variantId ? ' active' : ''}" data-vid="${v.variantId}">
            ${v.name} — ₹${v.offerPrice || v.price}
          </div>`).join('')}
      </div>`;
  }

  function priceHtml() {
    const base = selectedVariant ? selectedVariant.price : product.price;
    const offer = selectedVariant ? selectedVariant.offerPrice : product.offerPrice;
    const main = offer && offer < base ? offer : base;
    const cross = offer && offer < base ? `<span class="price-original">₹${base}</span>` : '';
    return `<span class="price-main">₹${main}</span>${cross}`;
  }

  function render() {
    const imgHtml = product.imageUrl
      ? `<img class="detail-img" src="${product.imageUrl}" alt="${name}">`
      : `<div class="detail-img-placeholder">🛒</div>`;

    appEl.innerHTML = `
      ${renderHeader(slug, shop, true)}
      ${imgHtml}
      <div class="detail-body">
        <div class="detail-name">${name}</div>
        <div class="detail-unit">${product.unit || ''}</div>
        <div class="detail-price">${priceHtml()}</div>
        ${variantsHtml()}
        <div class="qty-row">
          <span class="qty-label">${t('quantity')}</span>
          <div class="qty-control">
            <button class="qty-btn" id="qty-minus">−</button>
            <span class="qty-num" id="qty-num">${qty}</span>
            <button class="qty-btn" id="qty-plus">+</button>
          </div>
        </div>
        <div class="section-label">${t('item_note')}</div>
        <textarea class="note-input" id="item-note" placeholder="${t('item_note_placeholder')}">${itemNote}</textarea>
        <button class="btn-primary" id="add-to-cart-btn" ${product.isOutOfStock ? 'disabled' : ''}>
          ${product.isOutOfStock ? t('out_of_stock') : t('add_to_cart')}
        </button>
      </div>`;

    attachHeader(slug);
    bindEvents();
  }

  function bindEvents() {
    document.getElementById('qty-minus')?.addEventListener('click', () => {
      if (qty > (product.minQty || 1)) { qty--; document.getElementById('qty-num').textContent = qty; }
    });
    document.getElementById('qty-plus')?.addEventListener('click', () => {
      qty++;
      document.getElementById('qty-num').textContent = qty;
    });

    document.querySelector('.variant-chips')?.addEventListener('click', (e) => {
      const chip = e.target.closest('.variant-chip');
      if (!chip) return;
      selectedVariant = variants.find((v) => v.variantId === chip.dataset.vid) || null;
      render();
    });

    document.getElementById('item-note')?.addEventListener('input', (e) => {
      itemNote = e.target.value;
    });

    document.getElementById('add-to-cart-btn')?.addEventListener('click', () => {
      addItem(slug, {
        productId: product.productId,
        productName: name,
        variantId: selectedVariant?.variantId || '',
        variantName: selectedVariant?.name || '',
        price: effectivePrice(),
        qty,
        unit: product.unit || '',
        itemNote,
      });
      window.location.hash = `#/${slug}`;
    });
  }

  render();
  return null;
}
