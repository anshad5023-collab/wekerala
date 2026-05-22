import { db, auth } from './firebase-init.js';
import {
  signInWithEmailAndPassword,
  signOut,
  onAuthStateChanged,
} from 'https://www.gstatic.com/firebasejs/10.7.1/firebase-auth.js';
import {
  collection,
  getDocs,
  doc,
  updateDoc,
  query,
  orderBy,
  where,
  Timestamp,
} from 'https://www.gstatic.com/firebasejs/10.7.1/firebase-firestore.js';

// ── State ─────────────────────────────────────────────────────────────────────
let allShops = [];
let selectedShopId = null;

// ── Auth ──────────────────────────────────────────────────────────────────────
onAuthStateChanged(auth, (user) => {
  if (user) {
    showScreen('dashboard-screen');
    loadDashboard();
  } else {
    showScreen('login-screen');
  }
});

document.getElementById('login-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  const email = document.getElementById('admin-email').value.trim();
  const password = document.getElementById('admin-password').value;
  const btn = document.getElementById('login-btn');
  const errorEl = document.getElementById('login-error');

  btn.disabled = true;
  btn.textContent = 'Signing in…';
  errorEl.classList.add('hidden');

  try {
    await signInWithEmailAndPassword(auth, email, password);
  } catch (err) {
    errorEl.textContent = friendlyAuthError(err.code);
    errorEl.classList.remove('hidden');
    btn.disabled = false;
    btn.textContent = 'Sign In';
  }
});

document.getElementById('logout-btn').addEventListener('click', () => signOut(auth));

// ── Navigation ─────────────────────────────────────────────────────────────────
document.querySelectorAll('.nav-item').forEach((item) => {
  item.addEventListener('click', () => {
    document.querySelectorAll('.nav-item').forEach((n) => n.classList.remove('active'));
    item.classList.add('active');
    const page = item.dataset.page;
    document.querySelectorAll('.page').forEach((p) => p.classList.remove('active'));
    document.getElementById(`page-${page}`).classList.add('active');
    if (page === 'shops') renderShopsList(allShops);
  });
});

// ── Dashboard ─────────────────────────────────────────────────────────────────
async function loadDashboard() {
  try {
    const snap = await getDocs(collection(db, 'shops'));
    allShops = snap.docs.map((d) => ({ id: d.id, ...d.data() }));

    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const todayTs = Timestamp.fromDate(today);

    const newToday = allShops.filter(
      (s) => s.createdAt && s.createdAt.seconds >= todayTs.seconds
    ).length;

    const activeShops = allShops.filter((s) => s.isActive !== false).length;

    // Count today's orders across all shops
    let ordersToday = 0;
    await Promise.all(
      allShops.slice(0, 20).map(async (shop) => {
        const oSnap = await getDocs(
          query(
            collection(db, 'shops', shop.id, 'orders'),
            where('createdAt', '>=', todayTs)
          )
        );
        ordersToday += oSnap.size;
      })
    );

    document.getElementById('stat-total-shops').textContent = allShops.length;
    document.getElementById('stat-new-today').textContent = newToday;
    document.getElementById('stat-orders-today').textContent = ordersToday;
    document.getElementById('stat-active-shops').textContent = activeShops;
    document.getElementById('last-updated').textContent =
      'Updated ' + new Date().toLocaleTimeString();

    // Recent 5 shops
    const recent = [...allShops]
      .sort((a, b) => (b.createdAt?.seconds ?? 0) - (a.createdAt?.seconds ?? 0))
      .slice(0, 5);
    document.getElementById('recent-shops-list').innerHTML = recent
      .map(shopCardHTML)
      .join('');
    attachShopCardListeners();
  } catch (err) {
    console.error('Dashboard load error:', err);
  }
}

// ── Shops List ────────────────────────────────────────────────────────────────
document.getElementById('shop-search').addEventListener('input', (e) => {
  const q = e.target.value.toLowerCase();
  const filtered = allShops.filter(
    (s) =>
      (s.name ?? '').toLowerCase().includes(q) ||
      (s.phone ?? '').includes(q) ||
      (s.district ?? '').toLowerCase().includes(q)
  );
  renderShopsList(filtered);
});

function renderShopsList(shops) {
  const listEl = document.getElementById('shops-list');
  const emptyEl = document.getElementById('shops-empty');
  if (shops.length === 0) {
    listEl.innerHTML = '';
    emptyEl.classList.remove('hidden');
    return;
  }
  emptyEl.classList.add('hidden');
  listEl.innerHTML = shops.map(shopCardHTML).join('');
  attachShopCardListeners();
}

function shopCardHTML(shop) {
  const status = shopStatus(shop);
  return `
    <div class="shop-card" data-id="${shop.id}">
      <div class="shop-card-left">
        <h4>${shop.name ?? 'Unnamed Shop'}</h4>
        <p>${shop.phone ?? ''} · ${shop.district ?? shop.city ?? '—'} · ${shop.shopType ?? ''}</p>
      </div>
      <span class="badge ${statusBadgeClass(status)}">${status}</span>
    </div>`;
}

function attachShopCardListeners() {
  document.querySelectorAll('.shop-card').forEach((card) => {
    card.addEventListener('click', () => openShopModal(card.dataset.id));
  });
}

// ── Shop Modal ────────────────────────────────────────────────────────────────
async function openShopModal(shopId) {
  const shop = allShops.find((s) => s.id === shopId);
  if (!shop) return;
  selectedShopId = shopId;

  const status = shopStatus(shop);
  document.getElementById('modal-shop-name').textContent = shop.name ?? 'Unnamed';
  document.getElementById('modal-phone').textContent = shop.phone ?? '—';
  document.getElementById('modal-district').textContent = shop.district ?? shop.city ?? '—';
  document.getElementById('modal-status-badge').textContent = status;
  document.getElementById('modal-status-badge').className = `badge ${statusBadgeClass(status)}`;
  document.getElementById('modal-type').textContent = shop.shopType ?? '—';
  document.getElementById('modal-joined').textContent = formatDate(shop.createdAt);
  document.getElementById('modal-trial-end').textContent = formatDate(shop.trialEndsAt);
  document.getElementById('modal-payment').textContent = shop.paymentVerified ? '✅ Verified' : '❌ Pending';
  document.getElementById('modal-orders').textContent = shop.totalOrders ?? 0;

  const isActive = shop.isActive !== false;
  document.getElementById('btn-deactivate').style.display = isActive ? 'block' : 'none';
  document.getElementById('btn-activate').style.display = isActive ? 'none' : 'block';

  hideFeedback();
  document.getElementById('shop-modal').classList.remove('hidden');
}

document.getElementById('modal-close').addEventListener('click', closeModal);
document.getElementById('shop-modal').addEventListener('click', (e) => {
  if (e.target === document.getElementById('shop-modal')) closeModal();
});

function closeModal() {
  document.getElementById('shop-modal').classList.add('hidden');
  selectedShopId = null;
}

document.getElementById('btn-verify-payment').addEventListener('click', async () => {
  if (!selectedShopId) return;
  await shopAction(async () => {
    await updateDoc(doc(db, 'shops', selectedShopId), { paymentVerified: true });
    document.getElementById('modal-payment').textContent = '✅ Verified';
    updateLocalShop(selectedShopId, { paymentVerified: true });
    showFeedback('Payment verified successfully.', true);
  });
});

document.getElementById('btn-extend-trial').addEventListener('click', async () => {
  if (!selectedShopId) return;
  await shopAction(async () => {
    const shop = allShops.find((s) => s.id === selectedShopId);
    const base =
      shop.trialEndsAt && shop.trialEndsAt.seconds * 1000 > Date.now()
        ? new Date(shop.trialEndsAt.seconds * 1000)
        : new Date();
    base.setDate(base.getDate() + 30);
    const newEnd = Timestamp.fromDate(base);
    await updateDoc(doc(db, 'shops', selectedShopId), { trialEndsAt: newEnd });
    updateLocalShop(selectedShopId, { trialEndsAt: newEnd });
    document.getElementById('modal-trial-end').textContent = formatDate(newEnd);
    showFeedback('Trial extended by 30 days.', true);
  });
});

document.getElementById('btn-deactivate').addEventListener('click', async () => {
  if (!selectedShopId || !confirm('Deactivate this shop?')) return;
  await shopAction(async () => {
    await updateDoc(doc(db, 'shops', selectedShopId), { isActive: false });
    updateLocalShop(selectedShopId, { isActive: false });
    document.getElementById('btn-deactivate').style.display = 'none';
    document.getElementById('btn-activate').style.display = 'block';
    const badge = document.getElementById('modal-status-badge');
    badge.textContent = 'Inactive';
    badge.className = 'badge badge-inactive';
    showFeedback('Shop deactivated.', true);
  });
});

document.getElementById('btn-activate').addEventListener('click', async () => {
  if (!selectedShopId) return;
  await shopAction(async () => {
    await updateDoc(doc(db, 'shops', selectedShopId), { isActive: true });
    updateLocalShop(selectedShopId, { isActive: true });
    document.getElementById('btn-deactivate').style.display = 'block';
    document.getElementById('btn-activate').style.display = 'none';
    const badge = document.getElementById('modal-status-badge');
    badge.textContent = 'Active';
    badge.className = 'badge badge-active';
    showFeedback('Shop activated.', true);
  });
});

async function shopAction(fn) {
  try {
    hideFeedback();
    await fn();
  } catch (err) {
    showFeedback('Error: ' + err.message, false);
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
function showScreen(id) {
  document.querySelectorAll('.screen').forEach((s) => s.classList.remove('active'));
  document.getElementById(id).classList.add('active');
}

function shopStatus(shop) {
  if (shop.isActive === false) return 'Inactive';
  if (shop.paymentVerified) return 'Active';
  return 'Trial';
}

function statusBadgeClass(status) {
  if (status === 'Active') return 'badge-active';
  if (status === 'Inactive') return 'badge-inactive';
  return 'badge-trial';
}

function formatDate(ts) {
  if (!ts) return '—';
  const d = ts.toDate ? ts.toDate() : new Date(ts);
  return d.toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' });
}

function updateLocalShop(id, updates) {
  const idx = allShops.findIndex((s) => s.id === id);
  if (idx !== -1) allShops[idx] = { ...allShops[idx], ...updates };
}

function showFeedback(msg, success) {
  const el = document.getElementById('modal-feedback');
  el.textContent = msg;
  el.className = `feedback-msg ${success ? 'feedback-success' : 'feedback-error'}`;
  el.classList.remove('hidden');
}

function hideFeedback() {
  document.getElementById('modal-feedback').classList.add('hidden');
}

function friendlyAuthError(code) {
  const map = {
    'auth/invalid-email': 'Invalid email address.',
    'auth/user-disabled': 'This account has been disabled.',
    'auth/user-not-found': 'No account found with this email.',
    'auth/wrong-password': 'Incorrect password.',
    'auth/invalid-credential': 'Incorrect email or password.',
    'auth/too-many-requests': 'Too many attempts. Please try again later.',
  };
  return map[code] ?? 'Sign in failed. Please try again.';
}
