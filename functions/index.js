const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onRequest } = require('firebase-functions/v2/https');
const { defineString } = require('firebase-functions/params');
const axios = require('axios');
const { initializeApp, getApps } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');

// Initialize Firebase Admin only once
if (getApps().length === 0) {
  initializeApp();
}

// Set these via: firebase functions:secrets:set GUPSHUP_API_KEY
// and:          firebase functions:secrets:set GUPSHUP_APP_NAME
const GUPSHUP_API_KEY = defineString('GUPSHUP_API_KEY', { default: '' });
const GUPSHUP_APP_NAME = defineString('GUPSHUP_APP_NAME', { default: '' });
const GUPSHUP_SOURCE_PHONE = defineString('GUPSHUP_SOURCE_PHONE', { default: '15559725142' });
const GUPSHUP_BASE_URL = 'https://api.gupshup.io/wa/api/v1/msg';

// ─── Helpers ────────────────────────────────────────────────────────────────

async function sendWhatsApp(phone, message, retries = 2) {
  const apiKey = GUPSHUP_API_KEY.value();
  const appName = GUPSHUP_APP_NAME.value();
  console.log(`[WA] Sending to ${phone}, apiKey present: ${!!apiKey}, appName: ${appName}`);
  if (!apiKey || !appName) {
    console.error('[WA] Missing Gupshup credentials — check functions/.env');
    return false;
  }
  const digits = phone.replace(/\D/g, '').slice(-10);
  if (digits.length < 10) {
    console.error(`[WA] Invalid phone number: ${phone}`);
    return false;
  }
  const e164 = `91${digits}`;
  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      const params = new URLSearchParams({
        channel: 'whatsapp',
        source: GUPSHUP_SOURCE_PHONE.value(),
        destination: e164,
        message: JSON.stringify({ type: 'text', text: message }),
        'src.name': appName,
      });
      const resp = await axios.post(GUPSHUP_BASE_URL, params, {
        headers: { apikey: apiKey },
        timeout: 10000,
      });
      console.log(`[WA] Gupshup response ${resp.status}:`, JSON.stringify(resp.data));
      return true;
    } catch (err) {
      const isLast = attempt === retries;
      console.error(`[WA] Send error (attempt ${attempt + 1}/${retries + 1}):`, err.response?.data ?? err.message);
      if (!isLast) await new Promise((r) => setTimeout(r, 1000 * (attempt + 1)));
    }
  }
  return false;
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

    const itemNames = (order.items || []).map((i) => i.productName);
    const topItems = itemNames.slice(0, 3).join(', ');
    const moreItems = itemNames.length > 3 ? ` +${itemNames.length - 3} more` : '';

    const msg =
      `🛍 *New Order #${order.orderNumber}*\n` +
      `Customer: ${order.customerName}\n` +
      `Phone: ${order.customerPhone}\n` +
      `Items: ${topItems}${moreItems}\n` +
      `Total: ₹${Math.round(order.totalAmount)}\n\n` +
      `Open weKerala app to confirm.`;

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

      if (!customerPhone || customerPhone.length < 10) return null;

      const db = getFirestore();
      const shopDoc = await db.collection('shops').doc(shopId).get();
      const shopName = (shopDoc.data() && (shopDoc.data().shopName || shopDoc.data().name)) || 'Your Shop';

      const statusMessages = {
        confirmed: `✅ Order Confirmed!\n\nHi ${customerName}, your order at *${shopName}* has been confirmed!\n\nOrder Total: ₹${orderTotal}\n\nWe'll update you when it's ready. Thank you! 🙏`,
        preparing: `👨‍🍳 Order Being Prepared!\n\nHi ${customerName}, your order at *${shopName}* is now being prepared. Almost ready! ⏱️`,
        ready: `🎉 Order Ready!\n\nHi ${customerName}, your order at *${shopName}* is READY for pickup/delivery!\n\nOrder Total: ₹${orderTotal}\n\nThank you for your order! 🙏`,
        delivered: `✅ Order Delivered!\n\nHi ${customerName}, your order from *${shopName}* has been delivered!\n\nThank you for shopping with us. We hope to see you again! 🛍️`,
        cancelled: `❌ Order Cancelled\n\nHi ${customerName}, unfortunately your order at *${shopName}* has been cancelled.\n\nPlease contact us for more details or to reorder.`,
        out_for_delivery: `🚗 Out for Delivery!\n\nHi ${customerName}, your order from *${shopName}* is on its way! Expect delivery soon. 🎁`,
      };

      const message = statusMessages[newStatus];
      if (!message) return null;

      try {
        await sendWhatsApp(customerPhone, message);
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
        console.error('[onOrderStatusChange] Failed to send WhatsApp:', err.message);
      }

      return null;
    } catch (err) {
      console.error('[onOrderStatusChange] Unhandled error:', err.message);
      return null;
    }
  }
);

// ─── Gemini API Key ──────────────────────────────────────────────────────────
// Set via: firebase functions:secrets:set GEMINI_API_KEY
const GEMINI_API_KEY = defineString('GEMINI_API_KEY', { default: '' });

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

// ─── Function 8: WhatsApp Webhook — Gupshup inbound + Gemini AI auto-reply ───

exports.whatsappWebhook = onRequest({ cors: true }, async (req, res) => {
  const db = getFirestore();

  try {
    // 1. Parse body — Gupshup sends form-encoded OR JSON depending on format
    let body = req.body;
    const rawBody = req.rawBody ? req.rawBody.toString() : '';
    console.log('[Webhook] Content-Type:', req.headers['content-type']);
    console.log('[Webhook] Raw body:', rawBody.slice(0, 500));

    // If body is empty, try parsing rawBody manually
    if (!body || Object.keys(body).length === 0) {
      try {
        if (rawBody.startsWith('{') || rawBody.startsWith('[')) {
          body = JSON.parse(rawBody);
        } else {
          // form-encoded: key=value&key2=value2
          body = Object.fromEntries(new URLSearchParams(rawBody));
          // Gupshup v2 sends payload as a JSON string inside form field
          if (body.payload && typeof body.payload === 'string') {
            body.payload = JSON.parse(body.payload);
          }
        }
      } catch (e) {
        console.error('[Webhook] Body parse error:', e.message);
      }
    }

    console.log('[Webhook] Parsed body keys:', Object.keys(body || {}));

    let sender, messageText, appName;

    // Gupshup v2 form-encoded: payload is a JSON object with source + payload.text
    if (body.payload && (body.payload.source || body.payload.sender)) {
      sender = body.payload.source || body.payload.sender?.phone;
      messageText = body.payload.payload?.text || body.payload.payload?.caption || body.payload.text || '';
      appName = body.app || body['app.name'] || body.appName;
    } else if (body.mobile) {
      // Gupshup v1
      sender = body.mobile;
      messageText = body.message;
      appName = body.appName;
    } else if (body.entry?.[0]) {
      // Meta/v3 format
      const change = body.entry[0]?.changes?.[0]?.value;
      const msg = change?.messages?.[0];
      if (msg) {
        sender = msg.from;
        messageText = msg.text?.body || '';
        appName = change?.metadata?.display_phone_number || body.appName;
      }
    }

    if (!sender || !messageText) {
      console.warn('[Webhook] Could not extract fields. Body:', JSON.stringify(body).slice(0, 300));
      return res.json({ success: false });
    }

    console.log('[Webhook] Extracted — sender:', sender, 'message:', messageText, 'app:', appName);

    // 2. Query Firestore shops collection to find the shop that owns this Gupshup app
    // Try matching by gupshupAppName first, then fall back to whatsappNumber
    let shopsSnap = appName
      ? await db.collection('shops').where('gupshupAppName', '==', appName).limit(1).get()
      : { empty: true, docs: [] };

    if (shopsSnap.empty) {
      console.warn('[Webhook] No shop found for gupshupAppName:', appName);
      return res.json({ success: false });
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

    // 6. Check for human hand-off keyword before calling Gemini
    const lowerMessage = messageText.toLowerCase();
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

      await sendWhatsApp(sender, handoffReply);

      // Save this exchange to chat history
      const updatedMessages = [
        ...recentHistory,
        { role: 'user', text: messageText, ts: Date.now() },
        { role: 'assistant', text: handoffReply, ts: Date.now() },
      ].slice(-5);

      await chatDocRef.set({ messages: updatedMessages }, { merge: true });

      return res.json({ success: true });
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
      await sendWhatsApp(sender, `I'll get back to you shortly. View our store: ${storefrontUrl}`);
      return res.json({ success: false });
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

    // 10. Send the AI reply via WhatsApp
    await sendWhatsApp(sender, aiReply);

    // 11. Save updated conversation — keep only the last 5 messages
    const updatedMessages = [
      ...recentHistory,
      { role: 'user', text: messageText, ts: Date.now() },
      { role: 'assistant', text: aiReply, ts: Date.now() },
    ].slice(-5);

    await chatDocRef.set({ messages: updatedMessages }, { merge: true });

    return res.json({ success: true });

  } catch (err) {
    console.error('[Webhook] Unhandled error:', err.message);

    // Best-effort fallback reply — extract sender from body for the error path
    try {
      const fallbackSender = req.body.mobile;

      if (fallbackSender) {
        // Try to build a storefront URL if we can — use a generic fallback if not
        let fallbackUrl = 'https://wekerala.vercel.app';
        try {
          const db2 = getFirestore();
          const snap = await db2
            .collection('shops')
            .where('gupshupAppName', '==', req.body.appName)
            .limit(1)
            .get();
          if (!snap.empty) {
            fallbackUrl = `https://wekerala.vercel.app/shop?shopId=${snap.docs[0].id}`;
          }
        } catch (_) { /* ignore */ }

        await sendWhatsApp(fallbackSender, `I'll get back to you shortly. View our store: ${fallbackUrl}`);
      }
    } catch (fallbackErr) {
      console.error('[Webhook] Fallback send error:', fallbackErr.message);
    }

    return res.json({ success: false });
  }
});

// ─── Function 10: Daily Sales Summary (8 PM IST = 14:30 UTC) ─────────────────

exports.dailySalesSummary = onSchedule(
  { schedule: '30 14 * * *', timeZone: 'UTC' },
  async () => {
    const db = getFirestore();
    const shops = await db.collection('shops').get();
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);

    for (const shopDoc of shops.docs) {
      try {
        const shop = shopDoc.data();
        if (!shop.ownerPhone) continue;

        const ordersSnap = await db.collection('shops').doc(shopDoc.id)
          .collection('orders')
          .where('createdAt', '>=', Timestamp.fromDate(todayStart))
          .get();

        if (ordersSnap.empty) continue;

        let totalRevenue = 0;
        const productCount = {};
        ordersSnap.forEach(o => {
          const d = o.data();
          totalRevenue += d.total || d.totalAmount || 0;
          (d.items || []).forEach(item => {
            productCount[item.name] = (productCount[item.name] || 0) + (item.quantity || 1);
          });
        });

        const top3 = Object.entries(productCount).sort((a, b) => b[1] - a[1]).slice(0, 3);
        const topStr = top3.map(([name, qty]) => `• ${name} × ${qty}`).join('\n');

        const message = `📊 *Today's Sales — ${shop.shopName || 'Your Shop'}*\n\nOrders: ${ordersSnap.size}\nRevenue: ₹${Math.round(totalRevenue)}\n\n🏆 Top Products:\n${topStr || 'N/A'}\n\nDashboard: https://wekerala.vercel.app/shop?shopId=${shopDoc.id}`;
        await sendWhatsApp(shop.ownerPhone, message);
        await new Promise(r => setTimeout(r, 500));
      } catch (err) {
        console.error('Daily summary error for shop', shopDoc.id, err.message);
      }
    }
  }
);

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
          .where('stock', '<=', 0)
          .get();

        if (productsSnap.empty) continue;

        const alertsRef = db.collection('shops').doc(shopDoc.id).collection('sentAlerts');
        const toAlert = [];

        for (const pDoc of productsSnap.docs) {
          const alertDoc = await alertsRef.doc(pDoc.id).get();
          if (alertDoc.exists && alertDoc.data().sentAt.toDate() > sixHoursAgo) continue;
          toAlert.push(pDoc.data().name || pDoc.id);
          await alertsRef.doc(pDoc.id).set({ sentAt: FieldValue.serverTimestamp() });
        }

        if (toAlert.length === 0) continue;

        const itemList = toAlert.map(n => `• ${n} — OUT OF STOCK`).join('\n');
        const message = `⚠️ *Low Stock Alert — ${shop.shopName}*\n\nThese items need restocking:\n${itemList}\n\nUpdate: https://wekerala.vercel.app/control/website?shopId=${shopDoc.id}`;
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
    if (pointsEarned <= 0 || !order.customerPhone) return null;

    await db
      .collection('shops').doc(shopId)
      .collection('customers').doc(order.customerPhone)
      .set({
        name: order.customerName || 'Customer',
        phone: order.customerPhone,
        loyaltyPoints: FieldValue.increment(pointsEarned),
        totalSpent: FieldValue.increment(orderTotal),
        lastOrderAt: FieldValue.serverTimestamp(),
      }, { merge: true });

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
