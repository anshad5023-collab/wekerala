import { db } from '../firebase-init.js';
import { doc, onSnapshot } from 'https://www.gstatic.com/firebasejs/10.7.1/firebase-firestore.js';
import { t } from '../translations.js';
import { renderHeader } from '../app.js';

const STATUS_ORDER = ['new', 'confirmed', 'processing', 'ready', 'delivered'];

function statusLabel(status) {
  const map = {
    new: t('status_new'),
    confirmed: t('status_confirmed'),
    processing: t('status_processing'),
    ready: t('status_ready'),
    delivered: t('status_delivered'),
    cancelled: t('status_cancelled'),
  };
  return map[status] ?? status;
}

function formatTime(ts) {
  if (!ts) return '';
  const d = ts.toDate ? ts.toDate() : new Date(ts);
  return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}

function timelineHtml(order) {
  if (order.status === 'cancelled') {
    return `<div class="timeline-item current">
      <div class="timeline-dot"></div>
      <div class="timeline-content">
        <div class="timeline-status">${statusLabel('cancelled')}</div>
      </div>
    </div>`;
  }

  const currentIdx = STATUS_ORDER.indexOf(order.status);
  const historyMap = {};
  (order.statusHistory || []).forEach((h) => { historyMap[h.status] = h.timestamp; });

  return STATUS_ORDER.map((s, i) => {
    const done = i < currentIdx;
    const current = i === currentIdx;
    const cls = done ? 'done' : current ? 'current' : '';
    const time = historyMap[s] ? `<div class="timeline-time">${formatTime(historyMap[s] instanceof Object ? null : historyMap[s])}</div>` : '';
    const dot = done
      ? `<div class="timeline-dot"><svg width="12" height="12" viewBox="0 0 12 12" fill="white"><polyline points="2,6 5,9 10,3" stroke="white" stroke-width="1.5" fill="none"/></svg></div>`
      : `<div class="timeline-dot"></div>`;
    return `<div class="timeline-item ${cls}">
      ${dot}
      <div class="timeline-content">
        <div class="timeline-status">${statusLabel(s)}</div>
        ${time}
      </div>
    </div>`;
  }).join('');
}

export async function renderOrderStatus(appEl, state, orderId, attachHeader) {
  const { shop, shopId, slug } = state;

  appEl.innerHTML = `${renderHeader(slug, shop, true)}<div class="page-loading"><div class="spinner"></div></div>`;
  attachHeader(slug);

  function render(order) {
    appEl.innerHTML = `
      ${renderHeader(slug, shop, true)}
      <div class="status-page">
        <div class="status-header">
          <div class="status-order-num">${t('order_number')} #${order.orderNumber}</div>
          <div class="status-current">${statusLabel(order.status)}</div>
          <div style="display:flex;justify-content:center;margin-top:8px">
            <span class="status-live-badge">
              <span class="status-live-dot"></span>
              ${t('live_updates')}
            </span>
          </div>
        </div>
        <div class="status-timeline">${timelineHtml(order)}</div>
        <div style="display:flex;flex-direction:column;gap:10px">
          <button class="btn-secondary" id="back-shop-btn">${t('back_to_shop')}</button>
        </div>
      </div>`;

    attachHeader(slug);
    document.getElementById('back-shop-btn')?.addEventListener('click', () => {
      window.location.hash = `#/${slug}`;
    });
  }

  const unsubscribe = onSnapshot(
    doc(db, 'shops', shopId, 'orders', orderId),
    (snap) => {
      if (!snap.exists()) {
        appEl.innerHTML = `${renderHeader(slug, shop, true)}
          <div class="error-page"><div class="error-icon">😕</div><div class="error-title">${t('error_load')}</div></div>`;
        attachHeader(slug);
        return;
      }
      render(snap.data());
    },
    (err) => {
      console.error('Order status error:', err);
    }
  );

  return unsubscribe;
}
