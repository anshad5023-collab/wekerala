const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onRequest, onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineString } = require('firebase-functions/params');
const axios = require('axios');
const { initializeApp, getApps } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

// Initialize Firebase Admin only once
if (getApps().length === 0) {
  initializeApp();
}

// ── Credentials (set in functions/.env) ────────────────────────────────────
const META_VERIFY_TOKEN  = defineString('META_VERIFY_TOKEN',  { default: 'wekerala_webhook_secret' });
const META_PHONE_NUMBER_ID = defineString('META_PHONE_NUMBER_ID', { default: '' });
const META_ACCESS_TOKEN    = defineString('META_ACCESS_TOKEN',    { default: '' });
const GEMINI_API_KEY       = defineString('GEMINI_API_KEY',       { default: '' });
const RAZORPAY_KEY_ID      = defineString('RAZORPAY_KEY_ID',      { default: '' });
const RAZORPAY_KEY_SECRET  = defineString('RAZORPAY_KEY_SECRET',  { default: '' });
const RAZORPAY_WEBHOOK_SECRET = defineString('RAZORPAY_WEBHOOK_SECRET', { default: '' });

// ─── Helpers ────────────────────────────────────────────────────────────────

/**
 * Sends a WhatsApp message via Meta Cloud API.
 * Uses the per-shop whatsappPhoneNumberId if set; falls back to platform META_PHONE_NUMBER_ID.
 * Each shop owner adds their own Phone Number ID in Settings → WhatsApp Notifications.
 */
async function sendWhatsApp(toPhone, message, shopData = null, retries = 2) {
  const digits = toPhone.replace(/\D/g, '');
  const e164 = digits.startsWith('91') && digits.length === 12
    ? digits : `91${digits.slice(-10)}`;

  const phoneNumberId = shopData?.whatsappPhoneNumberId || META_PHONE_NUMBER_ID.value();
  const accessToken   = shopData?.whatsappAccessToken   || META_ACCESS_TOKEN.value();

  if (!phoneNumberId || !accessToken) {
    console.error('[WA] Missing META_PHONE_NUMBER_ID or META_ACCESS_TOKEN. Add them to functions/.env or in AI Settings.');
    return false;
  }

  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      const resp = await axios.post(
        `https://graph.facebook.com/v20.0/${phoneNumberId}/messages`,
        { messaging_product: 'whatsapp', to: e164, type: 'text', text: { body: message } },
        {
          headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
          timeout: 10000,
        }
      );
      console.log(`[WA/Meta] Sent to ${e164}: ${resp.status}`);
      return true;
    } catch (err) {
      const isLast = attempt === retries;
      console.error(`[WA/Meta] Error (attempt ${attempt + 1}):`, err.response?.data ?? err.message);
      if (!isLast) await new Promise((r) => setTimeout(r, 1000 * (attempt + 1)));
    }
  }
  return false;
}

/**
 * Checks if a WhatsApp notification preference is enabled for a shop.
 * Returns defaultVal when owner hasn't configured it yet.
 */
function isPrefOn(shopData, key, defaultVal) {
  const val = shopData?.whatsappSettings?.[key];
  if (val === undefined || val === null) return defaultVal;
  return val === true;
}

/**
 * Sends a Firebase Cloud Messaging push to a web browser token.
 * Used for customer order status updates when they've opted in via the storefront.
 */
async function sendWebPush(token, title, body, data = {}) {
  if (!token) return false;
  try {
    await getMessaging().send({
      token,
      notification: { title, body },
      data: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])),
      webpush: {
        notification: {
          icon: '/icons/icon-192x192.png',
          badge: '/icons/icon-192x192.png',
          vibrate: [200, 100, 200],
        },
        fcmOptions: { link: data.orderId && data.shopId ? `/shop?shopId=${data.shopId}&view=tracking&orderId=${data.orderId}` : '/' },
      },
    });
    return true;
  } catch (err) {
    // Token may be expired/revoked — log but don't crash
    console.error('[WebPush] Failed:', err.message);
    return false;
  }
}

/**
 * Returns the UTC Date range that corresponds to today (IST midnight → IST 23:59:59.999).
 */
function getTodayISTRange() {
  const now = new Date();
  const istOffset = 5.5 * 60 * 60 * 1000; // UTC+5:30 in ms
  const istNow = new Date(now.getTime() + istOffset);
  // Midnight IST today in IST local time
  const startOfDayIST = new Date(
    Date.UTC(istNow.getUTCFullYear(), istNow.getUTCMonth(), istNow.getUTCDate())
  );
  const startUTC = new Date(startOfDayIST.getTime() - istOffset);
  const endUTC = new Date(startUTC.getTime() + 24 * 60 * 60 * 1000 - 1);
  return { startUTC, endUTC };
}

/**
 * Returns the UTC Date range for the previous calendar month (IST).
 */
function getLastMonthISTRange() {
  const now = new Date();
  const istOffset = 5.5 * 60 * 60 * 1000;
  const istNow = new Date(now.getTime() + istOffset);

  const year = istNow.getUTCFullYear();
  const month = istNow.getUTCMonth(); // 0-indexed current month in IST

  // First day of last month (IST midnight)
  const firstDayLastMonth = new Date(Date.UTC(year, month - 1, 1));
  // First day of current month (IST midnight)
  const firstDayThisMonth = new Date(Date.UTC(year, month, 1));

  const startUTC = new Date(firstDayLastMonth.getTime() - istOffset);
  const endUTC = new Date(firstDayThisMonth.getTime() - istOffset - 1);
  return { startUTC, endUTC, year, month: month - 1 }; // month is 0-indexed last month
}

/**
 * Given an array of bill documents, compute the most frequently occurring
 * product name across all bill items.
 */
function findTopProduct(bills) {
  const freq = {};
  for (const bill of bills) {
    for (const item of bill.items || []) {
      const name = item.productName || item.name || 'Unknown';
      freq[name] = (freq[name] || 0) + (item.quantity || 1);
    }
  }
  if (Object.keys(freq).length === 0) return 'N/A';
  return Object.entries(freq).sort((a, b) => b[1] - a[1])[0][0];
}

/**
 * Given an array of bill documents, compute the top N products by frequency.
 * Returns an array of product name strings.
 */
function findTopProducts(bills, n = 3) {
  const freq = {};
  for (const bill of bills) {
    for (const item of bill.items || []) {
      const name = item.productName || item.name || 'Unknown';
      freq[name] = (freq[name] || 0) + (item.quantity || 1);
    }
  }
  return Object.entries(freq)
    .sort((a, b) => b[1] - a[1])
    .slice(0, n)
    .map(([name]) => name);
}

/**
 * Format a Date object (or Firestore Timestamp) as DD/MM/YYYY.
 */
function formatDate(dateOrTimestamp) {
  const d =
    dateOrTimestamp && typeof dateOrTimestamp.toDate === 'function'
      ? dateOrTimestamp.toDate()
      : new Date(dateOrTimestamp);
  const day = String(d.getDate()).padStart(2, '0');
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const year = d.getFullYear();
  return `${day}/${month}/${year}`;
}

/**
 * Month name lookup (0-indexed).
 */
const MONTH_NAMES = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

// ─── Function 7: ONDC Webhook — receives orders from the ONDC network ────────

// ONDC uses the Beckn protocol. Buyer apps (Swiggy, Meesho, Juspay) send
// on_confirm / on_cancel actions here when an ONDC order is placed or cancelled.
// URL: https://us-central1-shoplink-prod.cloudfunctions.net/ondcWebhook
exports.ondcWebhook = onRequest({ cors: true }, async (req, res) => {
  const body = req.body;
  const action = body?.context?.action;

  try {
    if (action === 'on_confirm') {
      await handleOndcOrder(body);
      res.json({ message: { ack: { status: 'ACK' } } });
    } else if (action === 'on_cancel') {
      await handleOndcCancellation(body);
      res.json({ message: { ack: { status: 'ACK' } } });
    } else {
      // Always acknowledge unknown actions so the network doesn't retry
      res.json({ message: { ack: { status: 'ACK' } } });
    }
  } catch (err) {
    console.error('ONDC webhook error:', err.message);
    // Still ACK — ONDC network should not retry on our internal errors
    res.json({ message: { ack: { status: 'ACK' } } });
  }
});

async function handleOndcOrder(body) {
  const db = getFirestore();
  const order = body?.message?.order;
  if (!order) return;

  const ondcOrderId = order.id;
  const items = (order.items || []).map((item) => ({
    productId: item.id,
    productName: item.descriptor?.name || 'Unknown',
    qty: item.quantity?.count || 1,
    unit: 'pcs',
    price: parseFloat(item.price?.value || '0'),
    subtotal:
      parseFloat(item.price?.value || '0') * (item.quantity?.count || 1),
    gstRate: 0,
    hsnCode: '',
    priceIncludesGst: true,
  }));

  const totalAmount = parseFloat(order.quote?.price?.value || '0');
  const customerName =
    order.fulfillments?.[0]?.customer?.person?.name || 'ONDC Customer';
  const customerPhone =
    order.fulfillments?.[0]?.customer?.contact?.phone || '';
  const providerId = order.provider?.id;

  // Find which WeKerala shop owns this ONDC provider ID
  const shopsSnap = await db
    .collection('shops')
    .where('ondcSellerId', '==', providerId)
    .limit(1)
    .get();

  if (shopsSnap.empty) {
    console.error('No shop found for ONDC provider ID:', providerId);
    return;
  }

  const shopDoc = shopsSnap.docs[0];
  const shopId = shopDoc.id;
  const shopData = shopDoc.data();
  const orderNumber = (shopData.totalOrders || 0) + 1;

  const wekeralaOrder = {
    orderId: ondcOrderId,
    shopId,
    orderNumber,
    status: 'new',
    source: 'ondc',
    ondcOrderId,
    customerName,
    customerPhone,
    customerLocation:
      order.fulfillments?.[0]?.stops?.[0]?.location?.address?.door || '',
    deliveryType: 'delivery',
    orderNote: `ONDC Order via ${body?.context?.bap_id || 'ONDC Network'}`,
    items,
    totalAmount,
    paymentMethod: 'online',
    paymentStatus: order.payment?.status === 'PAID' ? 'paid' : 'pending',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };

  await db
    .collection('shops')
    .doc(shopId)
    .collection('orders')
    .doc(ondcOrderId)
    .set(wekeralaOrder);

  await db.collection('shops').doc(shopId).update({
    totalOrders: FieldValue.increment(1),
  });

  // Notify shop owner via WhatsApp
  const ownerPhone = shopData.ownerPhone || shopData.ownerWhatsApp || '';
  if (ownerPhone && ownerPhone.length >= 10) {
    const itemSummary = items.slice(0, 3).map(i => i.productName).join(', ');
    const more = items.length > 3 ? ` +${items.length - 3} more` : '';
    const msg =
      `🌐 *ONDC Order #${orderNumber}*\n` +
      `Customer: ${customerName}\n` +
      `Items: ${itemSummary}${more}\n` +
      `Total: ₹${Math.round(totalAmount)}\n\n` +
      `Open weKerala app to confirm. ✅`;
    await sendWhatsApp(ownerPhone, msg, shopData);
  }

  console.log(`ONDC order ${ondcOrderId} created for shop ${shopId}`);
}

async function handleOndcCancellation(body) {
  const db = getFirestore();
  const orderId = body?.message?.order_id;
  const providerId = body?.message?.descriptor?.code;

  if (!orderId) return;

  const shopsSnap = await db
    .collection('shops')
    .where('ondcSellerId', '==', providerId)
    .limit(1)
    .get();

  if (shopsSnap.empty) return;
  const shopId = shopsSnap.docs[0].id;

  await db
    .collection('shops')
    .doc(shopId)
    .collection('orders')
    .doc(orderId)
    .update({ status: 'cancelled', updatedAt: new Date().toISOString() });

  console.log(`ONDC order ${orderId} cancelled for shop ${shopId}`);
}

// ─── Function 1: Existing — New Order Notification ──────────────────────────

// Fires when a new order is created in any shop
exports.onOrderCreated = onDocumentCreated(
  'shops/{shopId}/orders/{orderId}',
  async (event) => {
    const order = event.data?.data();
    if (!order) return;

    const shopId = event.params.shopId;

    const db = getFirestore();
    const shopSnap = await db.collection('shops').doc(shopId).get();
    const shop = shopSnap.data();
    if (!shop) return;

    const ownerPhone = shop.ownerPhone || shop.phoneNumber || shop.phone || shop.ownerWhatsApp || '';
    console.log(`[Order] shopId=${shopId}, ownerPhone=${ownerPhone}`);
    if (!ownerPhone || ownerPhone.length < 10) {
      console.error(`[Order] No valid phone found for shop ${shopId}`);
      return;
    }
    // Preference check — New Order Alert is OFF by default (owners prefer in-app push)
    if (!isPrefOn(shop, 'newOrderAlert', false)) return;

    const itemNames = (order.items || []).map((i) => i.productName || i.name);
    const topItems = itemNames.slice(0, 3).join(', ');
    const moreItems = itemNames.length > 3 ? ` +${itemNames.length - 3} more` : '';
    const deliveryEmoji = order.deliveryType === 'pickup' ? '🏪 Pickup' : '🚚 Delivery';
    const paymentLabel = { cash: '💵 Cash', upi: '📱 UPI', online: '🌐 Online', udhar: '📒 Udhar' }[order.paymentMethod] || order.paymentMethod || 'Unknown';

    const msg =
      `🛍 *New Order #${order.orderNumber}*\n` +
      `Customer: ${order.customerName}\n` +
      `Phone: ${order.customerPhone}\n` +
      `Items: ${topItems}${moreItems}\n` +
      `Total: ₹${Math.round(order.totalAmount || order.total || 0)}\n` +
      `Type: ${deliveryEmoji} | Payment: ${paymentLabel}\n\n` +
      `Open weKerala app to confirm. ✅`;

    await sendWhatsApp(ownerPhone, msg);
  }
);

// ─── Function 2: Daily Sales Summary (9:30 PM IST) ───────────────────────────

exports.sendDailySalesSummary = onSchedule(
  { schedule: '30 21 * * *', timeZone: 'Asia/Kolkata' },
  async () => {
    const db = getFirestore();
    const { startUTC, endUTC } = getTodayISTRange();

    const shopsSnap = await db.collection('shops').get();

    for (const shopDoc of shopsSnap.docs) {
      try {
        const shop = shopDoc.data();
        const shopId = shopDoc.id;
        const shopName = shop.shopName || shop.name || 'Your Shop';
        const ownerPhone = shop.ownerPhone || shop.phoneNumber || shop.phone || shop.ownerWhatsApp || '';

        if (!ownerPhone || ownerPhone.length < 10) continue;
        if (!isPrefOn(shop, 'dailySummary', true)) continue;

        // Query today's bills
        const billsSnap = await db
          .collection('shops')
          .doc(shopId)
          .collection('bills')
          .where('createdAt', '>=', startUTC)
          .where('createdAt', '<=', endUTC)
          .get();

        const bills = billsSnap.docs.map((d) => d.data());
        const billCount = bills.length;

        // Skip shops with no sales today
        if (billCount === 0) continue;

        let totalSales = 0;
        let cashTotal = 0;
        let upiTotal = 0;
        let udharTotal = 0;

        for (const bill of bills) {
          const amount = bill.finalAmount || bill.totalAmount || 0;
          totalSales += amount;
          const method = (bill.paymentMethod || '').toLowerCase();
          if (method === 'cash') cashTotal += amount;
          else if (method === 'upi') upiTotal += amount;
          else if (method === 'udhar') udharTotal += amount;
        }

        const topProduct = findTopProduct(bills);

        // Low stock products
        const lowStockThreshold = shop.lowStockThreshold || 5;
        const lowStockSnap = await db
          .collection('shops')
          .doc(shopId)
          .collection('products')
          .where('stockQty', '!=', null)
          .where('stockQty', '<=', lowStockThreshold)
          .limit(3)
          .get();

        const lowStockList =
          lowStockSnap.docs.length > 0
            ? lowStockSnap.docs
                .map((d) => {
                  const p = d.data();
                  return `${p.productName || p.name} (${p.stockQty} left)`;
                })
                .join(', ')
            : 'All good!';

        const msg =
          `📊 *Today's Summary — ${shopName}*\n\n` +
          `💰 Sales: ₹${Math.round(totalSales)} (${billCount} bills)\n` +
          `💵 Cash: ₹${Math.round(cashTotal)} | 📱 UPI: ₹${Math.round(upiTotal)} | 📒 Udhar: ₹${Math.round(udharTotal)}\n` +
          `🏆 Top item: ${topProduct}\n` +
          `⚠️ Low stock: ${lowStockList}\n\n` +
          `Powered by weKerala`;

        await sendWhatsApp(ownerPhone, msg);
        console.log(`Daily summary sent for shop ${shopId}`);
      } catch (err) {
        console.error(`Error sending daily summary for shop ${shopDoc.id}:`, err.message);
      }
    }
  }
);

// ─── Function 3: Udhar Payment Reminder (10 AM IST = 04:30 UTC) ─────────────

exports.sendUdharReminders = onSchedule(
  { schedule: '30 4 * * *', timeZone: 'Asia/Kolkata' },
  async () => {
    const db = getFirestore();
    const now = new Date();
    const istOffset = 5.5 * 60 * 60 * 1000;
    const istNow = new Date(now.getTime() + istOffset);

    // "Tomorrow" in IST — used as the cutoff for due date alerts
    const tomorrowIST = new Date(
      Date.UTC(istNow.getUTCFullYear(), istNow.getUTCMonth(), istNow.getUTCDate() + 1)
    );
    const tomorrowUTC = new Date(tomorrowIST.getTime() - istOffset);

    // "Today" midnight UTC (for overdue check)
    const todayIST = new Date(
      Date.UTC(istNow.getUTCFullYear(), istNow.getUTCMonth(), istNow.getUTCDate())
    );
    const todayUTC = new Date(todayIST.getTime() - istOffset);

    const shopsSnap = await db.collection('shops').get();

    for (const shopDoc of shopsSnap.docs) {
      try {
        const shop = shopDoc.data();
        const shopId = shopDoc.id;
        const shopName = shop.shopName || shop.name || 'Your Shop';
        const ownerPhone = shop.ownerPhone || shop.phoneNumber || shop.phone || shop.ownerWhatsApp || '';

        // Reminder gap: how many days before due date to remind the customer (default 7)
        const reminderDays = shop.whatsappSettings?.udharReminderDays ?? 7;
        const reminderCutoff = new Date(todayUTC.getTime() + reminderDays * 24 * 60 * 60 * 1000);

        // Fetch all unpaid credits
        const creditsSnap = await db
          .collection('shops')
          .doc(shopId)
          .collection('credits')
          .where('status', '!=', 'paid')
          .get();

        if (creditsSnap.empty) continue;

        const overdueCredits = [];
        let totalOverdue = 0;

        for (const creditDoc of creditsSnap.docs) {
          try {
            const credit = creditDoc.data();
            const customerPhone = credit.customerPhone || '';
            const customerName = credit.customerName || 'Customer';
            const outstanding = credit.outstanding || credit.amount || 0;
            const dueDateRaw = credit.dueDate;

            // Determine if due date exists and whether it's overdue or due soon
            let dueDate = null;
            let isDueSoon = false;
            let isOverdue = false;
            let formattedDue = 'Not set';

            if (dueDateRaw) {
              dueDate =
                typeof dueDateRaw.toDate === 'function'
                  ? dueDateRaw.toDate()
                  : new Date(dueDateRaw);
              isDueSoon = dueDate <= reminderCutoff; // within owner-configured reminder window
              isOverdue = dueDate < todayUTC;
              formattedDue = isOverdue ? 'Overdue' : formatDate(dueDate);
            }

            // Send reminder to customer if due soon or overdue
            if ((isDueSoon || isOverdue) && customerPhone && customerPhone.length >= 10) {
              const customerMsg =
                `🔔 Payment Reminder\n\n` +
                `Hi ${customerName}, your Udhar at *${shopName}* is pending.\n` +
                `Amount: ₹${Math.round(outstanding)}\n` +
                `Due: ${formattedDue}\n\n` +
                `Please pay at your earliest convenience.`;

              await sendWhatsApp(customerPhone, customerMsg);
            }

            // Track overdue credits for owner summary
            if (isOverdue) {
              totalOverdue += outstanding;
              const daysDiff = dueDate
                ? Math.floor((todayUTC - dueDate) / (1000 * 60 * 60 * 24))
                : 0;
              overdueCredits.push({ customerName, outstanding, daysDiff });
            }
          } catch (creditErr) {
            console.error(
              `Error processing credit ${creditDoc.id} for shop ${shopId}:`,
              creditErr.message
            );
          }
        }

        // Send owner summary if any overdue credits exist and pref is on
        if (overdueCredits.length > 0 && ownerPhone && ownerPhone.length >= 10 && isPrefOn(shop, 'udharOverdueSummary', true)) {
          const overdueList = overdueCredits
            .map(
              (c) =>
                `• ${c.customerName} — ₹${Math.round(c.outstanding)} (${c.daysDiff}d overdue)`
            )
            .join('\n');

          const ownerMsg =
            `⚠️ *Overdue Udhar — ${shopName}*\n\n` +
            `${overdueCredits.length} customers have overdue payments:\n` +
            `${overdueList}\n\n` +
            `Total overdue: ₹${Math.round(totalOverdue)}`;

          await sendWhatsApp(ownerPhone, ownerMsg);
        }

        console.log(`Udhar reminders processed for shop ${shopId}`);
      } catch (err) {
        console.error(`Error processing udhar reminders for shop ${shopDoc.id}:`, err.message);
      }
    }
  }
);

// ─── Function 4: Low Stock Alert (Firestore trigger on product update) ───────

exports.onProductStockUpdate = onDocumentUpdated(
  'shops/{shopId}/products/{productId}',
  async (event) => {
    try {
      const newData = event.data.after.data();
      const oldData = event.data.before.data();

      if (!newData || !oldData) return;

      const newQty = newData.stockQty;
      const oldQty = oldData.stockQty;

      // Only trigger if stockQty actually changed
      if (newQty === oldQty) return;

      // Only trigger if stockQty went DOWN (not a restock)
      if (newQty >= oldQty) return;

      // Only trigger if stockQty is tracked and low
      if (newQty === null || newQty === undefined) return;

      const lowStockThreshold = newData.lowStockThreshold || 5;
      if (newQty > lowStockThreshold) return;

      const shopId = event.params.shopId;
      const db = getFirestore();

      const shopSnap = await db.collection('shops').doc(shopId).get();
      const shop = shopSnap.data();
      if (!shop) return;

      const ownerPhone = shop.ownerPhone || shop.phoneNumber || shop.phone || shop.ownerWhatsApp || '';
      if (!ownerPhone || ownerPhone.length < 10) return;
      if (!isPrefOn(shop, 'lowStockAlert', true)) return;

      const shopName = shop.shopName || shop.name || 'Your Shop';
      const productName = newData.productName || newData.name || 'Product';
      const unit = newData.unit || 'units';

      const msg =
        `⚠️ *Low Stock Alert — ${shopName}*\n\n` +
        `${productName} is running low!\n` +
        `Remaining: ${newQty} ${unit}\n` +
        `Threshold: ${lowStockThreshold} ${unit}\n\n` +
        `Time to reorder? Open weKerala app.`;

      await sendWhatsApp(ownerPhone, msg);
      console.log(`Low stock alert sent for product ${event.params.productId} in shop ${shopId}`);
    } catch (err) {
      console.error('Error in onProductStockUpdate:', err.message);
    }
  }
);

// ─── Function 9: Order Status Change → Rich Customer WhatsApp Notification ───

// Fires whenever an order document is updated under any shop.
// Sends a richer, status-specific WhatsApp message to the customer.
// Uses the v1 Admin SDK style (admin.firestore) via a local alias so it works
// alongside the existing v2-style functions in this file.
exports.onOrderStatusChange = onDocumentUpdated(
  'shops/{shopId}/orders/{orderId}',
  async (event) => {
    try {
      const before = event.data.before.data();
      const after = event.data.after.data();

      if (!before || !after) return null;
      if (before.status === after.status) return null; // no status change

      const { shopId, orderId } = event.params;
      const customerPhone = after.customerPhone || '';
      const customerName = after.customerName || 'Customer';
      const newStatus = after.status;
      const orderTotal = after.total || after.totalAmount || 0;

      // Rate-limit: skip if this exact status was already sent within the last 2 minutes
      if (after.lastNotifiedStatus === newStatus && after.lastNotifiedAt) {
        const lastNotifiedAt = typeof after.lastNotifiedAt.toDate === 'function'
          ? after.lastNotifiedAt.toDate()
          : new Date(after.lastNotifiedAt);
        if (Date.now() - lastNotifiedAt.getTime() < 2 * 60 * 1000) {
          console.log(`[onOrderStatusChange] Skipping duplicate notification for status "${newStatus}" (sent <2 min ago)`);
          return null;
        }
      }

      if (!customerPhone || customerPhone.length < 10) return null;

      const db = getFirestore();
      const shopDoc = await db.collection('shops').doc(shopId).get();
      const shopName = (shopDoc.data() && (shopDoc.data().shopName || shopDoc.data().name)) || 'Your Shop';

      const shopId2 = shopId; // alias for clarity inside template literal
      const statusMessages = {
        confirmed: `✅ *Order Confirmed!*\n\nHi ${customerName}, your order at *${shopName}* has been confirmed! 🎉\n\nOrder Total: ₹${orderTotal}\n\nWe'll update you once it's ready. Thank you! 🙏`,
        preparing: `👨‍🍳 *Order Being Prepared!*\n\nHi ${customerName}, your order at *${shopName}* is now being prepared.\n\nAlmost ready — hang tight! ⏱️`,
        ready: `🎉 *Order Ready!*\n\nHi ${customerName}, your order at *${shopName}* is READY for pickup/delivery!\n\nOrder Total: ₹${orderTotal}\n\nThank you for your patience! 🙏`,
        delivered: `✅ *Order Delivered!*\n\nHi ${customerName}, your order from *${shopName}* has been delivered!\n\nThank you for shopping with us. We'd love to see you again! 🛍️\n\nOrder online anytime: https://wekerala.app/shop/${shopId2}`,
        cancelled: `❌ *Order Cancelled*\n\nHi ${customerName}, your order at *${shopName}* has been cancelled.\n\nWe're sorry for the inconvenience. Please contact us to reorder.\n\nShop again: https://wekerala.app/shop/${shopId2}`,
        out_for_delivery: `🚗 *Out for Delivery!*\n\nHi ${customerName}, your order from *${shopName}* is on its way! 🚀\n\nExpect delivery very soon. Get ready! 🎁`,
      };

      const message = statusMessages[newStatus];
      if (!message) return null;

      try {
        // Send WhatsApp to customer
        await sendWhatsApp(customerPhone, message);

        // Also send browser push notification if customer opted in
        const webPushToken = after.webPushToken || '';
        if (webPushToken) {
          const pushTitles = {
            confirmed: '✅ Order Confirmed!',
            preparing: '👨‍🍳 Being Prepared!',
            ready: '🎉 Order Ready!',
            out_for_delivery: '🚗 On the Way!',
            delivered: '✅ Delivered!',
            cancelled: '❌ Order Cancelled',
          };
          const pushBodies = {
            confirmed: `Your order at ${shopName} is confirmed.`,
            preparing: `Your order at ${shopName} is being prepared.`,
            ready: `Your order at ${shopName} is ready!`,
            out_for_delivery: `Your order from ${shopName} is out for delivery!`,
            delivered: `Your order from ${shopName} has been delivered. Thank you!`,
            cancelled: `Your order at ${shopName} has been cancelled.`,
          };
          await sendWebPush(
            webPushToken,
            pushTitles[newStatus] ?? 'Order Update',
            pushBodies[newStatus] ?? `Order status: ${newStatus}`,
            { shopId, orderId }
          );
        }

        // Log the notification on the order document
        await db
          .collection('shops').doc(shopId)
          .collection('orders').doc(orderId)
          .update({
            lastNotifiedAt: FieldValue.serverTimestamp(),
            lastNotifiedStatus: newStatus,
          });
        console.log(`[onOrderStatusChange] Notified ${customerPhone} — status: ${newStatus}, order: ${orderId}`);
      } catch (err) {
        console.error('[onOrderStatusChange] Failed to send notification:', err.message);
      }

      return null;
    } catch (err) {
      console.error('[onOrderStatusChange] Unhandled error:', err.message);
      return null;
    }
  }
);

// ─── Function 6: Monthly Business Report (1st of month, 8 AM IST = 02:30 UTC) ─

exports.sendMonthlyReport = onSchedule(
  { schedule: '30 2 1 * *', timeZone: 'Asia/Kolkata' },
  async () => {
    const db = getFirestore();
    const { startUTC, endUTC, year, month } = getLastMonthISTRange();

    const monthName = MONTH_NAMES[month];

    const shopsSnap = await db.collection('shops').get();

    for (const shopDoc of shopsSnap.docs) {
      try {
        const shop = shopDoc.data();
        const shopId = shopDoc.id;
        const shopName = shop.shopName || shop.name || 'Your Shop';
        const ownerPhone = shop.ownerPhone || shop.phoneNumber || shop.phone || shop.ownerWhatsApp || '';

        if (!ownerPhone || ownerPhone.length < 10) continue;
        if (!isPrefOn(shop, 'monthlyReport', true)) continue;

        // Query last month's bills
        const billsSnap = await db
          .collection('shops')
          .doc(shopId)
          .collection('bills')
          .where('createdAt', '>=', startUTC)
          .where('createdAt', '<=', endUTC)
          .get();

        const bills = billsSnap.docs.map((d) => d.data());
        const billCount = bills.length;

        let totalRevenue = 0;
        let cashTotal = 0;
        let upiTotal = 0;
        let udharTotal = 0;
        let collectedUdhar = 0;

        for (const bill of bills) {
          const amount = bill.finalAmount || bill.totalAmount || 0;
          totalRevenue += amount;
          const method = (bill.paymentMethod || '').toLowerCase();
          if (method === 'cash') cashTotal += amount;
          else if (method === 'upi') upiTotal += amount;
          else if (method === 'udhar') udharTotal += amount;
          // Collected udhar = bills where paymentMethod was udhar but marked collected,
          // or separate field — use udhar total as a proxy
        }
        collectedUdhar = udharTotal;

        // Top 3 products
        const top3 = findTopProducts(bills, 3);
        while (top3.length < 3) top3.push('—');
        const [product1, product2, product3] = top3;

        // New customers: customers whose firstOrderDate is within last month
        const newCustomersSnap = await db
          .collection('shops')
          .doc(shopId)
          .collection('customers')
          .where('firstOrderDate', '>=', startUTC)
          .where('firstOrderDate', '<=', endUTC)
          .get();
        const newCustomerCount = newCustomersSnap.size;

        // Total outstanding Udhar
        const outstandingSnap = await db
          .collection('shops')
          .doc(shopId)
          .collection('credits')
          .where('status', '!=', 'paid')
          .get();

        let totalOutstanding = 0;
        for (const creditDoc of outstandingSnap.docs) {
          const credit = creditDoc.data();
          totalOutstanding += credit.outstanding || credit.amount || 0;
        }

        const msg =
          `📈 *Monthly Report — ${shopName}*\n` +
          `*${monthName} ${year}*\n\n` +
          `💰 Revenue: ₹${Math.round(totalRevenue)} (${billCount} bills)\n` +
          `💵 Cash: ₹${Math.round(cashTotal)}\n` +
          `📱 UPI: ₹${Math.round(upiTotal)}\n` +
          `📒 Collected Udhar: ₹${Math.round(collectedUdhar)}\n\n` +
          `🏆 Top Products:\n` +
          `1. ${product1}\n` +
          `2. ${product2}\n` +
          `3. ${product3}\n\n` +
          `👥 New Customers: ${newCustomerCount}\n` +
          `📒 Outstanding Udhar: ₹${Math.round(totalOutstanding)}\n\n` +
          `Great work this month! 🎉\n` +
          `Powered by weKerala`;

        await sendWhatsApp(ownerPhone, msg);
        console.log(`Monthly report sent for shop ${shopId}`);
      } catch (err) {
        console.error(`Error sending monthly report for shop ${shopDoc.id}:`, err.message);
      }
    }
  }
);

// ─── Function 8: WhatsApp Webhook — Meta Cloud API inbound + Gemini AI auto-reply ───
//
// Improvements over v1:
// • Immediate 200 ACK to Meta (prevents retries / duplicate AI replies)
// • Message deduplication by msg.id (idempotent even under retries)
// • Rate limiting — max 10 messages/hour per sender (abuse protection)
// • HumanMode state — owner takeover pauses AI for 24h; then auto-resets
// • Owner handoff alert — WhatsApp to owner when customer requests handoff
// • Warm AI persona, no rigid keyword shortcuts (Gemini handles all queries)
// • Top 50 products in context (was 20)
// • 250-word reply limit (was 100), temperature 0.7 for natural tone
// • Chat history expanded to last 10 turns (was 5)
// • Usage logging per shop/month

exports.whatsappWebhook = onRequest({ timeoutSeconds: 60, cors: true }, async (req, res) => {
  const db = getFirestore();

  // Meta webhook verification (GET)
  if (req.method === 'GET') {
    const mode = req.query['hub.mode'];
    const token = req.query['hub.verify_token'];
    const challenge = req.query['hub.challenge'];
    if (mode === 'subscribe' && token === META_VERIFY_TOKEN.value()) {
      console.log('[Webhook] Meta verification OK');
      return res.status(200).send(challenge);
    }
    return res.status(403).send('Forbidden');
  }

  // Acknowledge immediately — prevents Meta from retrying after 20s
  res.sendStatus(200);

  try {
    // 1. Parse Meta payload
    const body = req.body;

    if (body.object !== 'whatsapp_business_account') return;

    const change = body.entry?.[0]?.changes?.[0]?.value;
    const msg = change?.messages?.[0];
    if (!msg || msg.type !== 'text') return; // ignore delivery receipts, images, etc.

    const msgId         = msg.id;
    const sender        = msg.from;
    const messageText   = (msg.text?.body || '').trim();
    const phoneNumberId = change?.metadata?.phone_number_id;

    if (!sender || !messageText || !msgId) return;

    // ── 2. Deduplication — prevents double replies from Meta retries ──────────
    const dedupRef = db.collection('processedWaMessages').doc(msgId);
    const alreadyDone = await dedupRef.get();
    if (alreadyDone.exists) {
      console.log('[Webhook] Duplicate msg skipped:', msgId);
      return;
    }
    await dedupRef.set({ ts: FieldValue.serverTimestamp(), sender });

    // ── 3. Find shop ──────────────────────────────────────────────────────────
    const shopsSnap = phoneNumberId
      ? await db.collection('shops').where('whatsappPhoneNumberId', '==', phoneNumberId).limit(1).get()
      : { empty: true, docs: [] };

    if (shopsSnap.empty) {
      console.warn('[Webhook] No shop for phoneNumberId:', phoneNumberId);
      return;
    }

    const shopDoc  = shopsSnap.docs[0];
    const shopId   = shopDoc.id;
    const shop     = shopDoc.data();
    const aiSettings = shop.aiSettings || {};

    if (aiSettings.enabled !== true) return;

    const shopName      = shop.shopName || shop.name || 'Our Shop';
    const ownerPhone    = shop.ownerPhone || shop.phoneNumber || shop.phone || shop.ownerWhatsApp || '';
    const storefrontUrl = `https://wekerala.vercel.app/shop?shopId=${shopId}`;

    // ── 4. Load chat state for this sender ────────────────────────────────────
    const chatRef  = db.collection('shops').doc(shopId).collection('aiChats').doc(sender);
    const chatSnap = await chatRef.get();
    const chatData = chatSnap.exists ? chatSnap.data() : {};
    const allHistory    = chatData.messages || [];
    const recentHistory = allHistory.slice(-10);

    // ── 5. HumanMode — owner has taken over; AI silent for 24h ───────────────
    if (chatData.humanMode === true) {
      const setAt = chatData.humanModeSetAt ? chatData.humanModeSetAt.toMillis() : 0;
      if (Date.now() - setAt < 24 * 60 * 60 * 1000) {
        console.log(`[Webhook] HumanMode active for ${sender}`);
        return;
      }
      await chatRef.set({ humanMode: false }, { merge: true }); // auto-expire after 24h
    }

    // ── 6. Rate limiting — max 10 messages per sender per hour ───────────────
    const hourAgo = Date.now() - 60 * 60 * 1000;
    const recentCount = recentHistory.filter(m => m.role === 'user' && m.ts > hourAgo).length;
    if (recentCount >= 10) {
      await sendWhatsApp(sender, `You've sent many messages. Please wait a bit before trying again 🙏`, shop);
      return;
    }

    const lowerMsg = messageText.toLowerCase();

    // ── 7. Handoff keyword — pause AI, alert owner ────────────────────────────
    const handoffKeyword = (aiSettings.humanHandoffKeyword || '').toLowerCase().trim();
    if (handoffKeyword && lowerMsg.includes(handoffKeyword)) {
      const customerReply = `I'm connecting you with the *${shopName}* team right now. They'll reply to you shortly! 🙏`;
      await sendWhatsApp(sender, customerReply, shop);

      if (ownerPhone && ownerPhone.length >= 10) {
        const displayNumber = sender.startsWith('91') ? `+${sender}` : sender;
        await sendWhatsApp(
          ownerPhone,
          `📲 *A customer wants to speak with you!*\n\nNumber: ${displayNumber}\nMessage: "${messageText}"\n\nAI is now paused for this customer for 24 hours. Reply directly to their number above.`,
          shop
        );
      }

      await chatRef.set({
        humanMode: true,
        humanModeSetAt: FieldValue.serverTimestamp(),
        messages: [...recentHistory,
          { role: 'user', text: messageText, ts: Date.now() },
          { role: 'assistant', text: customerReply, ts: Date.now() },
        ].slice(-10),
        lastMessageAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      return;
    }

    // ── 8. Fetch top 50 products for AI context ───────────────────────────────
    const productsSnap = await db
      .collection('shops').doc(shopId)
      .collection('products')
      .limit(50)
      .get();

    const products = productsSnap.docs
      .map(d => {
        const p = d.data();
        return {
          name: p.productName || p.name || '',
          price: p.price || p.sellingPrice || 0,
          unit: p.unit || '',
          inStock: p.inStock !== undefined ? p.inStock : ((p.stockQty ?? 1) > 0),
        };
      })
      .filter(p => p.name);

    // ── 9. Build warm, human AI system prompt ─────────────────────────────────
    const langRule = (() => {
      const lang = aiSettings.replyLanguage || 'auto';
      if (lang === 'malayalam') return 'Always reply in Malayalam (natural conversational script, not formal).';
      if (lang === 'english')   return 'Always reply in English.';
      return 'Detect the language the customer used and reply in that same language. For Malayalam, use natural informal script.';
    })();

    const productsContext = aiSettings.shareProductPrices
      ? `Products available:\n${products.map(p => `- ${p.name}${p.price ? ` ₹${p.price}${p.unit ? '/' + p.unit : ''}` : ''}${!p.inStock ? ' [out of stock]' : ''}`).join('\n')}`
      : 'Do not share specific prices — say "please check our store for current prices."';

    const systemPrompt = `You are a warm, friendly shop assistant at *${shopName}* in Kerala, India.

Your personality:
- Speak naturally, like a real helpful person at the shop — NOT like a bot or menu system
- Be genuinely warm and helpful. Use casual, friendly language.
- ${langRule}
- Vary your openings: "Sure!", "ആ, ഉണ്ട്!", "Of course!", "Let me help!" — don't always start the same way
- Answer questions directly and completely — if someone asks about multiple items, answer all of them
- Only share the store link when the customer is clearly ready to order or browse
- If you don't know the answer (e.g. about a product not in the list), honestly say "I'm not sure, let me have the team check for you"

Shop information:
- Shop name: ${shopName}
- Working hours: ${shop.workingHours || 'Contact the shop for hours'}
${aiSettings.answerDeliveryQuestions
  ? `- Delivery charge: ₹${shop.deliveryCharge || 0}. Min order: ₹${shop.minOrderValue || 0}. Free delivery above ₹${shop.freeDeliveryAbove || 0}.`
  : '- Do not discuss delivery specifics. Say "please contact the shop for delivery info."'}
- Store link (share when customer wants to order): ${storefrontUrl}

${productsContext}
${!aiSettings.shareStockStatus ? 'Do not discuss stock status or availability.' : ''}
${aiSettings.neverShareOwnerPhone ? '⚠️ NEVER share the owner\'s personal phone number.' : ''}
${aiSettings.neverShareOwnerAddress ? '⚠️ NEVER share the owner\'s personal or home address.' : ''}
${aiSettings.neverDiscussCompetitors ? '⚠️ Never recommend, mention, or compare competitor shops.' : ''}
${aiSettings.customInstructions ? `\nSpecial instructions from the shop owner:\n${aiSettings.customInstructions}` : ''}

Keep your reply under 250 words. Be helpful and human.`;

    // ── 10. Build Gemini request with conversation history ────────────────────
    const historyContents = recentHistory.map(m => ({
      role: m.role === 'assistant' ? 'model' : 'user',
      parts: [{ text: m.text }],
    }));

    const geminiPayload = {
      system_instruction: { parts: [{ text: systemPrompt }] },
      contents: [...historyContents, { role: 'user', parts: [{ text: messageText }] }],
      generationConfig: { temperature: 0.7, maxOutputTokens: 400 },
    };

    // ── 11. Call Gemini 2.0 Flash ─────────────────────────────────────────────
    const GEMINI_KEY = GEMINI_API_KEY.value() || process.env.GEMINI_API_KEY;

    let aiReply = `I'll get back to you shortly! Browse our store here: ${storefrontUrl}`;

    if (!GEMINI_KEY) {
      console.error('[Webhook] Missing GEMINI_API_KEY');
    } else {
      try {
        const geminiResp = await axios.post(
          `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${GEMINI_KEY}`,
          geminiPayload,
          { headers: { 'Content-Type': 'application/json' }, timeout: 15000 }
        );
        aiReply = geminiResp.data?.candidates?.[0]?.content?.parts?.[0]?.text || aiReply;
      } catch (geminiErr) {
        console.error('[Webhook] Gemini error:', geminiErr.response?.data ?? geminiErr.message);
      }
    }

    // ── 12. Send reply and save history ──────────────────────────────────────
    await sendWhatsApp(sender, aiReply, shop);

    await chatRef.set({
      messages: [...recentHistory,
        { role: 'user',      text: messageText, ts: Date.now() },
        { role: 'assistant', text: aiReply,      ts: Date.now() },
      ].slice(-10),
      lastMessageAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    // ── 13. Log usage ─────────────────────────────────────────────────────────
    const monthKey = new Date().toISOString().slice(0, 7);
    db.collection('shops').doc(shopId).collection('waUsage').doc(monthKey)
      .set({ aiReplies: FieldValue.increment(1), updatedAt: FieldValue.serverTimestamp() }, { merge: true })
      .catch(() => {});

    console.log(`[Webhook] Replied to ${sender} for shop ${shopId}`);

  } catch (err) {
    console.error('[Webhook] Unhandled error:', err.message);
  }
});

// Function 10 (dailySalesSummary) was removed — duplicate of sendDailySalesSummary (Function 2).
// sendDailySalesSummary at 9:30 PM IST is the canonical daily summary.

// ─── Function 11: Check Reorder Alerts (every 6 hours) ───────────────────────

exports.checkReorderAlerts = onSchedule(
  { schedule: '0 */6 * * *', timeZone: 'UTC' },
  async () => {
    const db = getFirestore();
    const shops = await db.collection('shops').get();
    const sixHoursAgo = new Date(Date.now() - 6 * 60 * 60 * 1000);

    for (const shopDoc of shops.docs) {
      try {
        const shop = shopDoc.data();
        if (!shop.ownerPhone) continue;
        if (!isPrefOn(shop, 'reorderAlert', false)) continue; // OFF by default — can be spammy

        const productsSnap = await db.collection('shops').doc(shopDoc.id)
          .collection('products')
          .where('stockQty', '<=', 0)
          .get();

        if (productsSnap.empty) continue;

        const alertsRef = db.collection('shops').doc(shopDoc.id).collection('sentAlerts');
        const toAlert = [];

        for (const pDoc of productsSnap.docs) {
          const alertDoc = await alertsRef.doc(pDoc.id).get();
          if (alertDoc.exists && alertDoc.data().sentAt.toDate() > sixHoursAgo) continue;
          toAlert.push(pDoc.data().productName || pDoc.data().name || pDoc.id);
          await alertsRef.doc(pDoc.id).set({ sentAt: FieldValue.serverTimestamp() });
        }

        if (toAlert.length === 0) continue;

        const itemList = toAlert.map(n => `• ${n} — OUT OF STOCK`).join('\n');
        const message = `⚠️ *Out of Stock Alert — ${shop.shopName || 'Your Shop'}*\n\nThese items need restocking:\n${itemList}\n\nOpen weKerala app to update stock.`;
        await sendWhatsApp(shop.ownerPhone, message);
        await new Promise(r => setTimeout(r, 300));
      } catch (err) {
        console.error('Reorder alert error for shop', shopDoc.id, err.message);
      }
    }
  }
);

// ─── Function 12: Add Loyalty Points on New Order ────────────────────────────

exports.addLoyaltyPoints = onDocumentCreated(
  'shops/{shopId}/orders/{orderId}',
  async (event) => {
    const order = event.data?.data();
    if (!order) return null;

    const { shopId } = event.params;
    const db = getFirestore();
    const shopDoc = await db.collection('shops').doc(shopId).get();
    const loyaltySettings = shopDoc.data()?.loyaltySettings;
    if (!loyaltySettings?.enabled) return null;

    const orderTotal = order.total || order.totalAmount || 0;
    const pointsEarned = Math.floor((orderTotal / 100) * (loyaltySettings.pointsPerHundred || 10));
    if (!order.customerPhone) return null;

    const customerRef = db
      .collection('shops').doc(shopId)
      .collection('customers').doc(order.customerPhone);

    const customerSnap = await customerRef.get();

    if (!customerSnap.exists) {
      // First order — create full record
      await customerRef.set({
        customerId: order.customerPhone,
        name: order.customerName || 'Customer',
        phone: order.customerPhone,
        totalOrders: 1,
        totalSpent: orderTotal,
        loyaltyPoints: pointsEarned > 0 ? pointsEarned : 0,
        lastOrderDate: FieldValue.serverTimestamp(),
        firstOrderDate: FieldValue.serverTimestamp(),
      });
    } else {
      // Existing customer — increment
      const updates = {
        totalOrders: FieldValue.increment(1),
        totalSpent: FieldValue.increment(orderTotal),
        lastOrderDate: FieldValue.serverTimestamp(),
      };
      if (order.customerName) updates.name = order.customerName;
      if (pointsEarned > 0) updates.loyaltyPoints = FieldValue.increment(pointsEarned);
      await customerRef.update(updates);
    }

    return null;
  }
);

// ─── Function 13: Process Flash Sales (every 5 minutes) ──────────────────────

exports.processFlashSales = onSchedule(
  { schedule: '*/5 * * * *', timeZone: 'UTC' },
  async () => {
    const db = getFirestore();
    const now = Timestamp.now();
    const shops = await db.collection('shops').get();

    for (const shopDoc of shops.docs) {
      try {
        const salesSnap = await db.collection('shops').doc(shopDoc.id)
          .collection('flashSales')
          .where('startTime', '<=', now)
          .where('expired', '!=', true)
          .get();

        for (const saleDoc of salesSnap.docs) {
          const sale = saleDoc.data();
          const isActive = sale.endTime.toDate() > new Date();

          if (!isActive) {
            // Expire: reset products
            if (sale.productIds?.length) {
              for (const pid of sale.productIds) {
                await db.collection('shops').doc(shopDoc.id).collection('products').doc(pid)
                  .update({ onSale: false, salePrice: FieldValue.delete() });
              }
            }
            await saleDoc.ref.update({ expired: true });
            continue;
          }

          // Active: apply discount + broadcast once
          if (sale.productIds?.length) {
            for (const pid of sale.productIds) {
              const pDoc = await db.collection('shops').doc(shopDoc.id).collection('products').doc(pid).get();
              if (!pDoc.exists) continue;
              const price = pDoc.data().price || 0;
              const salePrice = Math.round(price * (1 - (sale.discountPercent || 0) / 100));
              await pDoc.ref.update({ onSale: true, salePrice });
            }
          }

          if (!sale.broadcastSent) {
            const shop = shopDoc.data();
            if (shop.ownerPhone && isPrefOn(shop, 'flashSaleAlert', true)) {
              const url = `https://wekerala.vercel.app/shop?shopId=${shopDoc.id}`;
              const msg = `🔥 *FLASH SALE at ${shop.shopName}!*\n\nGet ${sale.discountPercent}% OFF — Limited time only!\n\nShop now: ${url}`;
              await sendWhatsApp(shop.ownerPhone, msg).catch(() => {});
            }
            await saleDoc.ref.update({ broadcastSent: true });
          }
        }
      } catch (err) {
        console.error('Flash sale error for shop', shopDoc.id, err.message);
      }
    }
  }
);

// ─── Function 15: Auto-Cancel Stale Orders (every 30 minutes) ────────────────
// Orders stuck in 'new' status for >45 minutes with no owner action are
// auto-cancelled and both the customer and owner receive a WhatsApp notification.

exports.autoCancelStaleOrders = onSchedule(
  { schedule: '*/30 * * * *', timeZone: 'Asia/Kolkata' },
  async () => {
    const db = getFirestore();
    const cutoff = new Date(Date.now() - 45 * 60 * 1000); // 45 minutes ago

    const shopsSnap = await db.collection('shops').get();

    for (const shopDoc of shopsSnap.docs) {
      try {
        const shop = shopDoc.data();
        const shopId = shopDoc.id;
        const shopName = shop.shopName || shop.name || 'Your Shop';
        const ownerPhone = shop.ownerPhone || shop.phoneNumber || shop.phone || shop.ownerWhatsApp || '';

        // Find orders that are still 'new' and older than 45 minutes
        const staleSnap = await db
          .collection('shops').doc(shopId)
          .collection('orders')
          .where('status', '==', 'new')
          .where('createdAt', '<=', Timestamp.fromDate(cutoff))
          .get();

        if (staleSnap.empty) continue;

        for (const orderDoc of staleSnap.docs) {
          try {
            const order = orderDoc.data();

            await orderDoc.ref.update({
              status: 'cancelled',
              cancelReason: 'Auto-cancelled: no response from shop within 45 minutes',
              updatedAt: FieldValue.serverTimestamp(),
            });

            // Notify customer
            const customerPhone = order.customerPhone || '';
            if (customerPhone.length >= 10) {
              await sendWhatsApp(
                customerPhone,
                `❌ *Order Cancelled*\n\nHi ${order.customerName || 'there'}, your order #${order.orderNumber} at *${shopName}* was auto-cancelled because the shop did not respond within 45 minutes.\n\nWe apologise for the inconvenience. Please try ordering again.`
              );
            }

            // Notify owner (respects preference)
            if (ownerPhone.length >= 10 && isPrefOn(shop, 'autoCancelAlert', true)) {
              await sendWhatsApp(
                ownerPhone,
                `⚠️ *Order Auto-Cancelled*\n\nOrder #${order.orderNumber} from ${order.customerName || 'a customer'} was auto-cancelled after 45 minutes with no action.\n\nPlease respond to new orders promptly in weKerala. 🙏`
              );
            }

            console.log(`[autoCancelStaleOrders] Cancelled order ${orderDoc.id} in shop ${shopId}`);
          } catch (err) {
            console.error(`[autoCancelStaleOrders] Error cancelling order ${orderDoc.id}:`, err.message);
          }
        }
      } catch (err) {
        console.error(`[autoCancelStaleOrders] Error processing shop ${shopDoc.id}:`, err.message);
      }
    }
  }
);

// ─── Function 14: Broadcast WhatsApp Message to All Customers ────────────────
// Called from Flutter app BroadcastScreen via FirebaseFunctions.httpsCallable.
// Uses the customers collection (populated when orders are confirmed) as source
// of truth — falls back to scanning recent orders if customers collection is empty.

exports.sendBroadcast = onCall({ maxInstances: 1 }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Login required');

  const { shopId, message } = request.data;
  if (!shopId || typeof message !== 'string' || !message.trim()) {
    throw new HttpsError('invalid-argument', 'Missing shopId or message');
  }
  if (message.length > 4096) {
    throw new HttpsError('invalid-argument', 'Message exceeds 4096 characters');
  }

  const db = getFirestore();

  // Get shop data for per-shop WhatsApp credentials
  const shopSnap = await db.collection('shops').doc(shopId).get();
  if (!shopSnap.exists) throw new HttpsError('not-found', 'Shop not found');
  const shop = shopSnap.data();

  // Primary: customers collection (accurate, built from confirmed orders)
  const customersSnap = await db.collection('shops').doc(shopId).collection('customers').get();
  const phones = new Set();

  if (!customersSnap.empty) {
    customersSnap.forEach(doc => {
      const p = doc.data().phone || doc.id;
      if (p && p.replace(/\D/g, '').length >= 10) phones.add(p);
    });
  }

  // Fallback: scan orders from last 90 days (string ISO date comparison)
  if (phones.size === 0) {
    const cutoff = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000).toISOString();
    const ordersSnap = await db.collection('shops').doc(shopId)
      .collection('orders')
      .where('createdAt', '>=', cutoff)
      .get();
    ordersSnap.forEach(doc => {
      const phone = doc.data().customerPhone;
      if (phone && phone.replace(/\D/g, '').length >= 10) phones.add(phone);
    });
  }

  const phoneList = Array.from(phones).slice(0, 300);
  if (phoneList.length === 0) return { sent: 0, failed: 0, message: 'No customers found' };

  let sent = 0;
  let failed = 0;

  for (let i = 0; i < phoneList.length; i++) {
    const ok = await sendWhatsApp(phoneList[i], message, shop);
    if (ok) sent++; else failed++;
    // Respect WhatsApp rate limits: ~80 msg/min = pause 800ms every 10 msgs
    if ((i + 1) % 10 === 0 && i < phoneList.length - 1) {
      await new Promise(r => setTimeout(r, 800));
    }
  }

  await db.collection('shops').doc(shopId).collection('broadcasts').add({
    message,
    sentAt: FieldValue.serverTimestamp(),
    recipientCount: phoneList.length,
    sentCount: sent,
    failedCount: failed,
  });

  console.log(`[sendBroadcast] shop=${shopId} total=${phoneList.length} sent=${sent} failed=${failed}`);
  return { sent, failed };
});

// ─── Function 15: Stock Depleted Alert ───────────────────────────────────────
// (defined below)

// ─── Function 16: Create Razorpay Subscription Order ─────────────────────────
// Called from Flutter subscription screen to get a Razorpay order_id.
// Once the user pays in the Razorpay checkout, the webhook (Function 17)
// auto-activates the subscription.

exports.createRazorpayOrder = onCall({ maxInstances: 5 }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Login required');

  const keyId = RAZORPAY_KEY_ID.value();
  const keySecret = RAZORPAY_KEY_SECRET.value();
  if (!keyId || !keySecret) {
    throw new HttpsError('failed-precondition',
      'Razorpay not configured. Add RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET to functions/.env');
  }

  const { shopId, planMonths = 1 } = request.data;
  if (!shopId) throw new HttpsError('invalid-argument', 'Missing shopId');

  const amountPaise = 99900 * planMonths; // ₹999 per month in paise

  const auth = Buffer.from(`${keyId}:${keySecret}`).toString('base64');
  const resp = await axios.post(
    'https://api.razorpay.com/v1/orders',
    {
      amount: amountPaise,
      currency: 'INR',
      receipt: `sub_${shopId}_${Date.now()}`,
      notes: { shopId, planMonths: String(planMonths) },
    },
    { headers: { Authorization: `Basic ${auth}`, 'Content-Type': 'application/json' } }
  );

  console.log(`[Razorpay] Order created: ${resp.data.id} for shop ${shopId}`);
  return { orderId: resp.data.id, amount: amountPaise, keyId };
});

// ─── Function 17: Razorpay Payment Webhook ───────────────────────────────────
// Razorpay calls this URL after a successful payment.
// Configure in Razorpay Dashboard → Webhooks → Add Webhook
// URL: https://us-central1-<project-id>.cloudfunctions.net/razorpayWebhook
// Events to subscribe: payment.captured

exports.razorpayWebhook = onRequest({ cors: true }, async (req, res) => {
  if (req.method !== 'POST') { res.status(405).send('Method Not Allowed'); return; }

  const secret = RAZORPAY_WEBHOOK_SECRET.value();
  if (secret) {
    const crypto = require('crypto');
    const signature = req.headers['x-razorpay-signature'] || '';
    const body = JSON.stringify(req.body);
    const expected = crypto.createHmac('sha256', secret).update(body).digest('hex');
    if (signature !== expected) {
      console.error('[Razorpay Webhook] Invalid signature');
      res.status(400).send('Invalid signature');
      return;
    }
  }

  const event = req.body.event;
  const payment = req.body.payload?.payment?.entity;

  if (event === 'payment.captured' && payment) {
    const shopId = payment.notes?.shopId;
    const planMonths = parseInt(payment.notes?.planMonths || '1', 10);
    if (!shopId) { res.status(200).send('ok'); return; }

    const db = getFirestore();
    const now = new Date();
    const expiresAt = new Date(now);
    expiresAt.setMonth(expiresAt.getMonth() + planMonths);

    await db.collection('shops').doc(shopId).update({
      subscriptionStatus: 'active',
      subscriptionStartDate: Timestamp.fromDate(now),
      subscriptionExpiresAt: Timestamp.fromDate(expiresAt),
      lastPaymentId: payment.id,
      lastPaymentAmount: payment.amount / 100,
    });

    // Notify shop owner
    const shopSnap = await db.collection('shops').doc(shopId).get();
    const shop = shopSnap.data();
    const ownerPhone = shop?.ownerPhone || shop?.ownerWhatsApp || '';
    if (ownerPhone && ownerPhone.length >= 10) {
      await sendWhatsApp(ownerPhone,
        `✅ *Subscription Activated!*\n\nThank you for subscribing to weKerala. Your subscription is active until ${expiresAt.toLocaleDateString('en-IN')}.\n\nEnjoy all features! 🎉`,
        shop);
    }

    console.log(`[Razorpay Webhook] Subscription activated for shop ${shopId} until ${expiresAt}`);
  }

  res.status(200).json({ received: true });
});
// Fires when a product's stockQty transitions from >0 to <=0.
// Sends a WhatsApp alert to the shop owner so they can restock immediately.

exports.onStockDepleted = onDocumentUpdated(
  'shops/{shopId}/products/{productId}',
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after) return;

    const wasAboveZero = (before.stockQty ?? -1) > 0;
    const isNowZero = (after.stockQty ?? -1) <= 0;
    if (!wasAboveZero || !isNowZero) return;

    const shopId = event.params.shopId;
    const db = getFirestore();
    const shopSnap = await db.collection('shops').doc(shopId).get();
    const shop = shopSnap.data();
    if (!shop) return;

    const ownerPhone = shop.ownerPhone || shop.ownerWhatsApp || '';
    if (!ownerPhone || ownerPhone.length < 10) return;

    const name = after.nameEn || after.productName || after.name || 'Unknown product';
    const msg =
      `⚠️ *Out of Stock Alert*\n\n` +
      `*${name}* just ran out of stock at *${shop.shopName || 'your shop'}*.\n\n` +
      `Update stock in weKerala app to continue selling this product.`;

    await sendWhatsApp(ownerPhone, msg, shop);
    console.log(`[StockAlert] ${name} (${event.params.productId}) hit zero in shop ${shopId}`);
  }
);

// ── Customer Win-Back Messages ────────────────────────────────────────────────
// Runs daily at 10:00 AM IST. For each shop, sends a re-engagement WhatsApp
// to customers who haven't purchased in 30+ days and haven't been messaged
// in the last 7 days. Capped at 50 messages per shop per run.
exports.sendWinBackMessages = onSchedule(
  { schedule: '0 10 * * *', timeZone: 'Asia/Kolkata' },
  async () => {
    const db = getFirestore();
    const now = new Date();
    const thirtyDaysAgo = new Date(now - 30 * 24 * 60 * 60 * 1000);
    const sevenDaysAgo  = new Date(now - 7  * 24 * 60 * 60 * 1000);
    const MAX_PER_SHOP  = 50;

    const shopsSnap = await db.collection('shops').get();
    let totalSent = 0;

    for (const shopDoc of shopsSnap.docs) {
      const shop = shopDoc.data();
      const shopId = shopDoc.id;

      // Only message shops with an active WhatsApp subscription
      if (shop.subscriptionStatus !== 'active') continue;

      const customersSnap = await db
        .collection('shops').doc(shopId)
        .collection('customers')
        .where('lastOrderDate', '<', thirtyDaysAgo)
        .limit(MAX_PER_SHOP)
        .get();

      let shopSent = 0;
      for (const custDoc of customersSnap.docs) {
        const cust = custDoc.data();
        const phone = cust.phone || cust.customerPhone || custDoc.id;
        if (!phone || phone.length < 10) continue;

        // Skip if we messaged this customer in the last 7 days
        const lastWinBack = cust.winBackSentAt?.toDate?.() || null;
        if (lastWinBack && lastWinBack > sevenDaysAgo) continue;

        const name = cust.name || cust.customerName || 'there';
        const shopName = shop.shopName || 'our shop';
        const msg =
          `Hi ${name}! 👋\n\n` +
          `We miss you at *${shopName}*! It's been a while since your last visit.\n\n` +
          `Come back and shop with us — we have fresh stock and great deals waiting for you! 🛒\n\n` +
          `Order online: ${shop.storeUrl || 'Visit us in store'}\n\n` +
          `_Reply STOP to unsubscribe from messages._`;

        try {
          await sendWhatsApp(phone, msg, shop);
          await custDoc.ref.update({ winBackSentAt: now });
          shopSent++;
          totalSent++;
        } catch (err) {
          console.error(`[WinBack] Failed for ${phone} in shop ${shopId}:`, err.message);
        }
      }

      if (shopSent > 0) {
        console.log(`[WinBack] Sent ${shopSent} messages for shop ${shopId}`);
      }
    }

    console.log(`[WinBack] Total sent: ${totalSent}`);
  }
);
