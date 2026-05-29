const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onRequest } = require('firebase-functions/v2/https');
const { defineString } = require('firebase-functions/params');
const axios = require('axios');
const { initializeApp, getApps } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

// Initialize Firebase Admin only once
if (getApps().length === 0) {
  initializeApp();
}

// Meta WhatsApp Cloud API credentials
// Set via functions/.env — each shop can also override with their own credentials in Firestore
const META_VERIFY_TOKEN = defineString('META_VERIFY_TOKEN', { default: 'wekerala_webhook_secret' });
const META_PHONE_NUMBER_ID = defineString('META_PHONE_NUMBER_ID', { default: '' });
const META_ACCESS_TOKEN = defineString('META_ACCESS_TOKEN', { default: '' });
const GEMINI_API_KEY = defineString('GEMINI_API_KEY', { default: '' });

// ─── Helpers ────────────────────────────────────────────────────────────────

async function sendWhatsApp(toPhone, message, shopData = null, retries = 2) {
  const phoneNumberId = shopData?.whatsappPhoneNumberId || META_PHONE_NUMBER_ID.value();
  const accessToken = shopData?.whatsappAccessToken || META_ACCESS_TOKEN.value();

  if (!phoneNumberId || !accessToken) {
    console.error('[WA] Missing Meta credentials — set META_PHONE_NUMBER_ID and META_ACCESS_TOKEN in functions/.env');
    return false;
  }

  const digits = toPhone.replace(/\D/g, '');
  const e164 = digits.startsWith('91') && digits.length === 12
    ? digits
    : `91${digits.slice(-10)}`;

  console.log(`[WA] Sending to ${e164} via phone_number_id: ${phoneNumberId}`);

  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      const resp = await axios.post(
        `https://graph.facebook.com/v20.0/${phoneNumberId}/messages`,
        {
          messaging_product: 'whatsapp',
          to: e164,
          type: 'text',
          text: { body: message },
        },
        {
          headers: {
            Authorization: `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          timeout: 10000,
        }
      );
      console.log(`[WA] Meta response ${resp.status}:`, JSON.stringify(resp.data));
      return true;
    } catch (err) {
      const isLast = attempt === retries;
      console.error(`[WA] Meta send error (attempt ${attempt + 1}/${retries + 1}):`, err.response?.data ?? err.message);
      if (!isLast) await new Promise((r) => setTimeout(r, 1000 * (attempt + 1)));
    }
  }
  return false;
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
              isDueSoon = dueDate <= tomorrowUTC;
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

        // Send owner summary if any overdue credits exist
        if (overdueCredits.length > 0 && ownerPhone && ownerPhone.length >= 10) {
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

exports.whatsappWebhook = onRequest({ cors: true }, async (req, res) => {
  const db = getFirestore();

  // Meta webhook verification (GET request sent once when you register the webhook)
  if (req.method === 'GET') {
    const mode = req.query['hub.mode'];
    const token = req.query['hub.verify_token'];
    const challenge = req.query['hub.challenge'];
    if (mode === 'subscribe' && token === META_VERIFY_TOKEN.value()) {
      console.log('[Webhook] Meta verification successful');
      return res.status(200).send(challenge);
    }
    return res.status(403).send('Forbidden');
  }

  try {
    // 1. Parse Meta Cloud API payload
    const body = req.body;
    console.log('[Webhook] Raw body:', JSON.stringify(body).slice(0, 500));

    // Ignore status updates (delivery receipts, read receipts) — only process messages
    if (body.object !== 'whatsapp_business_account') {
      return res.sendStatus(200);
    }

    const change = body.entry?.[0]?.changes?.[0]?.value;
    const msg = change?.messages?.[0];

    if (!msg || msg.type !== 'text') {
      return res.sendStatus(200); // not a text message — ignore
    }

    const sender = msg.from;
    const messageText = msg.text?.body || '';
    const phoneNumberId = change?.metadata?.phone_number_id;

    if (!sender || !messageText) {
      console.warn('[Webhook] Could not extract sender/message');
      return res.sendStatus(200);
    }

    console.log('[Webhook] Extracted — sender:', sender, 'message:', messageText, 'phoneNumberId:', phoneNumberId);

    // 2. Find the shop that owns this Meta phone number
    let shopsSnap = phoneNumberId
      ? await db.collection('shops').where('whatsappPhoneNumberId', '==', phoneNumberId).limit(1).get()
      : { empty: true, docs: [] };

    if (shopsSnap.empty) {
      console.warn('[Webhook] No shop found for phoneNumberId:', phoneNumberId);
      return res.sendStatus(200);
    }

    const shopDoc = shopsSnap.docs[0];
    const shopId = shopDoc.id;
    const shop = shopDoc.data();

    // 3. Check AI settings — bail out early if AI is not enabled
    const aiSettings = shop.aiSettings || {};
    if (aiSettings.enabled !== true) {
      console.log(`[Webhook] AI not enabled for shop ${shopId}`);
      return res.json({ success: false });
    }

    const shopName = shop.shopName || shop.name || 'Our Shop';
    const ownerPhone = shop.ownerPhone || shop.phoneNumber || shop.phone || shop.ownerWhatsApp || '';
    const storefrontUrl = `https://wekerala.vercel.app/shop?shopId=${shopId}`;

    // 4. Fetch top 20 products (name, price, inStock only)
    const productsSnap = await db
      .collection('shops')
      .doc(shopId)
      .collection('products')
      .limit(20)
      .get();

    const products = productsSnap.docs.map((d) => {
      const p = d.data();
      return {
        name: p.productName || p.name || '',
        price: p.price || p.sellingPrice || 0,
        inStock: p.inStock !== undefined ? p.inStock : (p.stockQty > 0),
      };
    });

    // 5. Read last 5 messages from the AI chat history for this sender
    const chatDocRef = db
      .collection('shops')
      .doc(shopId)
      .collection('aiChats')
      .doc(sender);

    const chatSnap = await chatDocRef.get();
    const existingMessages = chatSnap.exists ? (chatSnap.data().messages || []) : [];
    const recentHistory = existingMessages.slice(-5);

    // 6. Keyword shortcuts — instant replies without Gemini
    const lowerMessage = messageText.toLowerCase();

    const matchKw = (keywords) => keywords.some((k) => lowerMessage.includes(k));

    const saveChat = (reply) => chatDocRef.set({
      messages: [...recentHistory, { role: 'user', text: messageText, ts: Date.now() }, { role: 'assistant', text: reply, ts: Date.now() }].slice(-5),
    }, { merge: true });

    if (matchKw(['price', 'rate', 'cost', 'how much', 'എത്ര', 'വില', 'നിരക്ക്']) && aiSettings.shareProductPrices) {
      const priceList = products.slice(0, 10)
        .map((p) => `• ${p.name} — ₹${p.price}${p.inStock ? '' : ' (out of stock)'}`)
        .join('\n');
      const reply = priceList
        ? `*${shopName} Products:*\n${priceList}\n\nOrder here: ${storefrontUrl}`
        : `Browse our products here: ${storefrontUrl}`;
      await sendWhatsApp(sender, reply, shop);
      await saveChat(reply);
      return res.sendStatus(200);
    }

    if (matchKw(['open', 'time', 'hours', 'close', 'when', 'സമയം', 'തുറക്കുന്ന']) && aiSettings.answerHoursQuestions) {
      const reply = `*${shopName}* hours: ${shop.workingHours || 'Please contact us for timings.'}`;
      await sendWhatsApp(sender, reply, shop);
      await saveChat(reply);
      return res.sendStatus(200);
    }

    if (matchKw(['delivery', 'deliver', 'charge', 'ഡെലിവറി']) && aiSettings.answerDeliveryQuestions) {
      const dc = shop.deliveryCharge || 0;
      const mo = shop.minOrderValue || 0;
      const reply = dc === 0
        ? `*${shopName}*: Free delivery! Min order ₹${mo}. Order: ${storefrontUrl}`
        : `*${shopName}*: Delivery ₹${dc}. Min order ₹${mo}. Order: ${storefrontUrl}`;
      await sendWhatsApp(sender, reply, shop);
      await saveChat(reply);
      return res.sendStatus(200);
    }

    if (matchKw(['order', 'buy', 'purchase', 'cart', 'ഓർഡർ', 'വാങ്ങ'])) {
      const reply = `To order from *${shopName}*, tap here: ${storefrontUrl}`;
      await sendWhatsApp(sender, reply, shop);
      await saveChat(reply);
      return res.sendStatus(200);
    }

    // Human hand-off keyword
    const handoffKeyword = aiSettings.humanHandoffKeyword
      ? aiSettings.humanHandoffKeyword.toLowerCase()
      : null;

    if (handoffKeyword && lowerMessage.includes(handoffKeyword)) {
      let handoffReply;
      if (!aiSettings.neverShareOwnerPhone && ownerPhone) {
        handoffReply = `Please contact us directly on WhatsApp: ${ownerPhone}`;
      } else {
        handoffReply = 'Please contact us directly.';
      }

      await sendWhatsApp(sender, handoffReply, shop);
      await saveChat(handoffReply);
      return res.sendStatus(200);
    }

    // 7. Build the Gemini system prompt dynamically from aiSettings
    const systemPrompt = `You are the WhatsApp assistant for ${shopName}.
Rules:
${aiSettings.shareProductPrices ? '- You CAN share product prices from the list below.' : '- NEVER mention specific prices. Say "please check our store for prices".'}
${aiSettings.shareStockStatus ? '- You CAN share stock availability.' : '- Do not discuss stock availability.'}
${aiSettings.neverShareOwnerPhone ? '- NEVER share the owner phone number under any circumstances.' : ''}
${aiSettings.neverShareOwnerAddress ? '- NEVER share the owner home/personal address.' : ''}
${aiSettings.neverDiscussCompetitors ? '- NEVER discuss or recommend competitor shops.' : ''}
${aiSettings.autoSendStorefrontLink ? `- Always end your reply with: "Order here: ${storefrontUrl}"` : ''}
${aiSettings.answerDeliveryQuestions ? `- Delivery charge: ₹${shop.deliveryCharge || 0}. Free above ₹${shop.freeDeliveryAbove || 0}.` : '- Do not answer delivery questions. Say "please contact us".'}
${aiSettings.answerHoursQuestions ? `- Store hours: ${shop.workingHours || 'Contact us for hours'}.` : ''}
${aiSettings.customInstructions ? aiSettings.customInstructions : ''}
Products list: ${JSON.stringify(products.map((p) => ({ name: p.name, price: p.price, inStock: p.inStock })))}
Keep replies short (under 100 words). Detect language and reply in the same language.`;

    // 8. Build Gemini request contents from chat history + new user message
    const historyContents = recentHistory.map((m) => ({
      role: m.role === 'assistant' ? 'model' : 'user',
      parts: [{ text: m.text }],
    }));

    const geminiPayload = {
      system_instruction: { parts: [{ text: systemPrompt }] },
      contents: [
        ...historyContents,
        { role: 'user', parts: [{ text: messageText }] },
      ],
    };

    // 9. Call Gemini 2.0 Flash API
    const GEMINI_KEY = GEMINI_API_KEY.value() || process.env.GEMINI_API_KEY;

    if (!GEMINI_KEY) {
      console.error('[Webhook] Missing GEMINI_API_KEY');
      await sendWhatsApp(sender, `I'll get back to you shortly. View our store: ${storefrontUrl}`, shop);
      return res.sendStatus(200);
    }

    const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${GEMINI_KEY}`;

    let aiReply;
    try {
      const geminiResp = await axios.post(geminiUrl, geminiPayload, {
        headers: { 'Content-Type': 'application/json' },
        timeout: 15000,
      });

      aiReply =
        geminiResp.data?.candidates?.[0]?.content?.parts?.[0]?.text ||
        `I'll get back to you shortly. View our store: ${storefrontUrl}`;
    } catch (geminiErr) {
      console.error('[Webhook] Gemini API error:', geminiErr.response?.data ?? geminiErr.message);
      aiReply = `I'll get back to you shortly. View our store: ${storefrontUrl}`;
    }

    // 10. Send the AI reply
    await sendWhatsApp(sender, aiReply, shop);
    await saveChat(aiReply);

    return res.sendStatus(200);

  } catch (err) {
    console.error('[Webhook] Unhandled error:', err.message);
    return res.sendStatus(200); // always 200 to Meta so it doesn't retry
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
            if (shop.ownerPhone) {
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

            // Notify owner
            if (ownerPhone.length >= 10) {
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

// ─── Function 14: Broadcast WhatsApp Message to Recent Customers ──────────────

const { onCall } = require('firebase-functions/v2/https');

exports.sendBroadcast = onCall({ maxInstances: 1 }, async (request) => {
  if (!request.auth) throw new Error('Unauthenticated');

  const { shopId, message } = request.data;
  if (!shopId || !message) throw new Error('Missing shopId or message');

  const db = getFirestore();
  const ninetyDaysAgo = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000);

  const ordersSnap = await db.collection('shops').doc(shopId)
    .collection('orders')
    .where('createdAt', '>=', Timestamp.fromDate(ninetyDaysAgo))
    .get();

  const phones = new Set();
  ordersSnap.forEach(doc => {
    const phone = doc.data().customerPhone;
    if (phone) phones.add(phone);
  });

  const phoneList = Array.from(phones).slice(0, 200);
  let sent = 0;
  let failed = 0;

  for (const phone of phoneList) {
    try {
      await sendWhatsApp(phone, message);
      sent++;
      await new Promise(r => setTimeout(r, 300));
    } catch (err) {
      failed++;
      console.error('Broadcast failed for', phone, err);
    }
  }

  // Log broadcast
  await db.collection('shops').doc(shopId).collection('broadcasts').add({
    message,
    sentAt: FieldValue.serverTimestamp(),
    recipientCount: sent,
    failedCount: failed,
  });

  return { sent, failed };
});
