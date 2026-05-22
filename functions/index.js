const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onRequest } = require('firebase-functions/v2/https');
const { defineString } = require('firebase-functions/params');
const axios = require('axios');
const { initializeApp, getApps } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

// Initialize Firebase Admin only once
if (getApps().length === 0) {
  initializeApp();
}

// Set these via: firebase functions:secrets:set GUPSHUP_API_KEY
// and:          firebase functions:secrets:set GUPSHUP_APP_NAME
const GUPSHUP_API_KEY = defineString('GUPSHUP_API_KEY', { default: '' });
const GUPSHUP_APP_NAME = defineString('GUPSHUP_APP_NAME', { default: '' });
const GUPSHUP_BASE_URL = 'https://api.gupshup.io/wa/api/v1/msg';

// ─── Helpers ────────────────────────────────────────────────────────────────

async function sendWhatsApp(phone, message) {
  const apiKey = GUPSHUP_API_KEY.value();
  const appName = GUPSHUP_APP_NAME.value();
  console.log(`[WA] Sending to ${phone}, apiKey present: ${!!apiKey}, appName: ${appName}`);
  if (!apiKey || !appName) {
    console.error('[WA] Missing Gupshup credentials — check functions/.env');
    return;
  }
  const e164 = phone.startsWith('91') ? phone : `91${phone}`;
  try {
    const params = new URLSearchParams({
      channel: 'whatsapp',
      source: '15559725142',
      destination: e164,
      message: JSON.stringify({ type: 'text', text: message }),
      'src.name': appName,
    });
    const resp = await axios.post(GUPSHUP_BASE_URL, params, {
      headers: { apikey: apiKey },
    });
    console.log(`[WA] Gupshup response ${resp.status}:`, JSON.stringify(resp.data));
  } catch (err) {
    console.error('[WA] Send error:', err.response?.data ?? err.message);
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
    totalOrders: (shopData.totalOrders || 0) + 1,
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

// ─── Function 2: Daily Sales Summary (9:30 PM IST = 16:30 UTC) ──────────────

exports.sendDailySalesSummary = onSchedule(
  { schedule: '30 16 * * *', timeZone: 'Asia/Kolkata' },
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

// ─── Function 5: Order Status → Customer WhatsApp ────────────────────────────

exports.onOrderStatusChanged = onDocumentUpdated(
  'shops/{shopId}/orders/{orderId}',
  async (event) => {
    try {
      const newData = event.data.after.data();
      const oldData = event.data.before.data();

      if (!newData || !oldData) return;

      const newStatus = newData.status;
      const oldStatus = oldData.status;

      // Only send if status actually changed
      if (newStatus === oldStatus) return;

      const customerPhone = newData.customerPhone || '';
      if (!customerPhone || customerPhone.length < 10) return;

      const shopId = event.params.shopId;
      const db = getFirestore();

      const shopSnap = await db.collection('shops').doc(shopId).get();
      const shop = shopSnap.data();
      const shopName = (shop && (shop.shopName || shop.name)) || 'your shop';

      let msg = null;

      switch (newStatus) {
        case 'confirmed':
          msg = `✅ Your order at ${shopName} has been confirmed! We're preparing it now.`;
          break;
        case 'ready': {
          const deliveryType = newData.deliveryType || '';
          const pickupNote =
            deliveryType === 'pickup' ? 'Please collect it.' : 'Out for delivery soon.';
          msg = `🎉 Your order at ${shopName} is ready! ${pickupNote}`;
          break;
        }
        case 'delivered':
          msg = `✅ Order delivered! Thank you for shopping at ${shopName}. 🙏`;
          break;
        case 'cancelled':
          msg = `❌ Your order at ${shopName} has been cancelled. Contact us for details.`;
          break;
        default:
          // Skip unknown/intermediate statuses
          return;
      }

      if (msg) {
        await sendWhatsApp(customerPhone, msg);
        console.log(
          `Order status message (${newStatus}) sent for order ${event.params.orderId} in shop ${shopId}`
        );
      }
    } catch (err) {
      console.error('Error in onOrderStatusChanged:', err.message);
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
