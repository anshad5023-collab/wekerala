# WeKerala: Master Automation Blueprint
**The Complete Plan to Automate Every Aspect of a Kerala Shop**

*Date: 2026-05-21 | Version: 1.0 | Status: Actionable Roadmap*

---

## Executive Summary

WeKerala is already more capable than any competitor has achieved: a 2,038-line POS/billing engine, Malayalam voice ordering with Gemini AI, AI-powered reorder suggestions, festival campaign broadcasting, KOT printing for restaurants, and a complete Udhar/credit tracking system — all in a single Flutter app backed by Firebase.

**The gap is not features. The gap is automation.**

Everything that exists today requires a human to tap a button. The target state is a shop that runs largely on its own: bills auto-generated from voice, reminders sent automatically, GST filed from data already captured, orders routed without owner intervention, suppliers notified when stock drops, and the owner receiving a nightly WhatsApp summary while sitting at home.

This blueprint covers **13 automation domains**, maps current implementation status to target state, and assigns each domain to a specialized implementation agent.

---

## Section 1: Current Implementation Status

### What Is Already Built (Do Not Rebuild)

| Domain | Screen / Component | Lines | Status |
|--------|-------------------|-------|--------|
| POS Billing | billing_screen.dart | 2,038 | ✅ Complete |
| GST Calculation | billing_screen + BillModel | — | ✅ Built (CGST/SGST/HSN) |
| Voice Order (Gemini) | voice_order_screen.dart | 924 | ✅ Built |
| AI Reorder Suggestions | reorder_screen.dart | 498 | ✅ Built |
| Festival Campaigns | festival_screen.dart | 632 | ✅ Built |
| KOT / Kitchen Tickets | kot_screen.dart | 622 | ✅ Built |
| Thermal Printer | printer_settings_screen.dart | 405 | ✅ Built |
| Udhar / Credit Tracking | credits_screen.dart | 1,256 | ✅ Complete |
| Customer Analytics | customers_screen.dart | 991 | ✅ Built |
| Staff Roles (Owner/Cashier/Manager) | staff_management_screen.dart | 430 | ✅ Built |
| Barcode Scanning | mobile_scanner package | — | ✅ Package installed |
| Order Notifications | Cloud Function onOrderCreated | — | ✅ Live (Gupshup) |
| Supplier Management | suppliers screens | 957 | ✅ Built |
| Stock Alerts | stock_alerts_screen.dart | 428 | ✅ Built |
| At-Risk Customer Detection | customers_screen | — | ✅ 21-day logic built |
| Website Builder | 3 themes, 5-tab builder | — | ✅ Built |
| Analytics Dashboard | analytics_screen.dart | 720 | ✅ Built |
| GSTR-1 Screen | gstr1_screen.dart | 447 | ⚠️ UI exists, export incomplete |
| Subscription UI | subscription_screen.dart | 458 | ⚠️ UI only, no payment |

### Critical Gaps (Must Build)

| Gap | Impact | Priority |
|-----|--------|----------|
| Day-end WhatsApp summary | Owner sees value daily = habit formation | P0 |
| GST GSTR-1 PDF export | Mandatory for all GST shops | P0 |
| UPI QR code on printed bills | Closes payment loop instantly | P0 |
| Udhar payment reminder automation | Daily ₹2,000+ recovered per shop | P0 |
| WhatsApp customer ordering bot | Removes #1 friction (manual order entry) | P1 |
| ONDC seller integration | Opens 400+ city marketplace, 0% listing fee | P1 |
| Razorpay subscription payments | WeKerala earns ₹199-499/shop/month | P1 |
| Offline-first with Hive/Isar | Rural shops in Wayanad, Idukki can use app | P1 |
| Customer-facing app (Phase 17) | Customer login, order history, saved addresses | P2 |
| Auto purchase order to supplier | Closes procurement loop | P2 |
| Google Business Profile sync | Free discovery for shop owners | P2 |
| Expiry date alerts | Prevents ₹10,000+ annual waste per pharmacy | P2 |

---

## Section 2: The 13 Automation Domains

---

### Domain 1: Billing & Invoice Automation

**Vision:** A bill is created in under 30 seconds. It is auto-sent to the customer on WhatsApp. A UPI QR is printed on the bill. GST is calculated automatically. The bill goes into GSTR-1 without any human action.

**Current state:** Billing screen complete. GST calculation complete. Bill saved to Firestore. WhatsApp receipt exists but manual.

**What needs to be automated:**

1.1 **Quick Freeform Billing** (no catalog required)
- Type item name + price → bill generated
- No need to add product to catalog first
- Target: first bill within 90 seconds of first login

1.2 **UPI QR on Thermal Print**
- Print UPI QR (shopUpiId) on every bill
- Customer scans → pays → payment status auto-updates
- Stack: qr_flutter (already installed) + bluetooth_print (already installed)

1.3 **Auto WhatsApp Receipt**
- When bill saved with customerPhone → auto-send formatted bill to WhatsApp via Gupshup
- No tap required (toggle in settings)
- Already partially designed (autoSendWhatsappReceipt field in ShopModel)

1.4 **GSTR-1 Monthly PDF Export**
- Aggregate all bills in a month by HSN code and GST rate
- Generate GSTR-1 JSON (government format) + human-readable PDF
- File directly via GSTN API or export for CA
- Already: gstr1_screen.dart exists with UI, needs export logic

1.5 **Bill Number Auto-Sequencing**
- FY-wise sequential bill number (e.g., WK/2526/001)
- Resets April 1 each year
- Already: orderNumber field exists on orders; bills need same

**Agent Assignment:** Agent 2 (GST & Billing)

---

### Domain 2: WhatsApp Automation Engine

**Vision:** The shop owner's WhatsApp is their business dashboard. Every important event arrives as a WhatsApp message without any manual action: new orders, low stock, payment received, daily sales, Udhar reminders.

**Current state:** One Cloud Function (onOrderCreated) sends order notification. Nothing else is automated.

**What needs to be automated:**

2.1 **Day-End Sales Summary** (9:30 PM daily)
- Firebase Scheduled Cloud Function (Cloud Scheduler)
- Message: "📊 Today's Summary — Vineeth Stores\n💰 Sales: ₹8,420 (42 bills)\n💵 Cash: ₹5,200 | 📱 UPI: ₹2,100 | 📒 Udhar: ₹1,120\n🏆 Top item: Coconut Oil (18 pcs)\n⚠️ Low stock: Rice (3 kg), Bread (2 pcs)"

2.2 **Udhar Payment Reminder** (daily at 10 AM)
- Query all credits where dueDate <= tomorrow AND status != paid
- Send reminder to customer: "Namaste! Your Udhar at [Shop] is ₹X. Due: [date]. Pay: [UPI QR]"
- Send alert to owner: "[Customer] owes ₹X. Due today."

2.3 **Low Stock Alert**
- Trigger: When stockQty drops to or below lowStockThreshold during billing
- Immediate WhatsApp to owner: "⚠️ Low Stock: Rice only 3 kg left. Tap to reorder."
- Can be a Firestore trigger (onUpdate) on product doc

2.4 **Order Status Notification to Customer**
- When owner changes order status (confirmed/ready/delivered)
- Auto-send WhatsApp to customer with current status + ETA
- Already triggered in web control panel; needs Cloud Function on Firestore update

2.5 **Monthly Business Report** (1st of each month, 8 AM)
- Revenue comparison (this month vs last month)
- Top 5 products, new customers, Udhar outstanding
- Delivered as WhatsApp message + PDF link

2.6 **Expiry Alert** (7 days before expiry)
- Query products where expiryDate <= 7 days from now
- WhatsApp alert to owner: "⚠️ Expiry Alert: Bread (15 pcs) expires in 3 days."

**Implementation:** Firebase Scheduled Cloud Functions + Gupshup API (already configured)
**Agent Assignment:** Agent 1 (WhatsApp Automation)

---

### Domain 3: Inventory & Stock Automation

**Vision:** The shop never runs out of a product because the system predicts and alerts before it happens. Stock is tracked automatically from every bill. Supplier is notified automatically.

**Current state:** Stock decrement on bill save (built). Low stock alerts screen (built). Barcode package installed. AI reorder suggestions (built with Gemini).

**What needs to be automated:**

3.1 **Barcode Scan → Bill Item**
- mobile_scanner (already in pubspec) used in billing_screen
- Scan barcode → auto-add product to cart at correct price
- If barcode unknown → "Add new product" flow

3.2 **Expiry Date Tracking**
- expiryDate field already in ProductModel
- Alert Cloud Function (covered in Domain 2)
- Expiring items highlighted red in product list

3.3 **Auto Purchase Order Generation**
- When stock drops below threshold → suggest purchase order to supplier
- Format: "Dear [Supplier], Please send: Rice 50 kg, Coconut Oil 12L. — [Shop Name]"
- One-tap send via WhatsApp to supplier's phone

3.4 **Stock Valuation Report**
- Real-time: Total inventory value = Σ(stockQty × price)
- By category breakdown
- Accessible from analytics screen

3.5 **Batch / Lot Tracking** (pharmacies)
- batchNumber field already in ProductModel
- UI to enter batch on product receive
- Expiry-by-batch reporting

**Agent Assignment:** Part of Agent 2 (GST & Billing handles barcode integration)

---

### Domain 4: GST & Tax Automation

**Vision:** A shop owner who previously dreaded GST filing now clicks one button each month. WeKerala has already captured every HSN code, every rate, every transaction — GSTR-1 is generated automatically.

**Current state:** GST rates, HSN codes, CGST/SGST stored on every bill. gstr1_screen.dart has UI. Export logic incomplete.

**What needs to be automated:**

4.1 **GSTR-1 B2C Aggregate Report**
- Group bills by HSN code and GST rate
- Calculate taxable value, CGST, SGST for each slab
- Format: Table with HSN | Description | Qty | Taxable Value | CGST | SGST | Total

4.2 **GSTR-1 JSON Export** (government format)
- Generate valid GSTR-1 JSON schema
- Allow download or email to CA

4.3 **GSTR-1 PDF Export**
- Human-readable PDF with shop name, GSTIN, period
- Summary table + detailed transaction list
- WhatsApp share to CA

4.4 **Monthly Tax Liability Summary**
- Total tax collected (CGST + SGST) this month
- Breakdown by 0%/5%/12%/18%/28% slabs
- "Your tax liability for [Month]: ₹X"

4.5 **HSN Code Auto-Suggest**
- As owner types product name → suggest HSN code from master list
- 5,000+ common retail HSN codes database
- Reduces manual HSN lookup effort

4.6 **Composition Scheme Support**
- 1-6% flat GST on turnover (no input credit)
- Different bill format (no CGST/SGST split)
- Toggle in GST settings

**Agent Assignment:** Agent 2 (GST & Billing)

---

### Domain 5: Customer Relationship Automation (CRM)

**Vision:** Every customer is known. The shop proactively reaches customers who haven't visited in 3 weeks. New customers get a welcome message. Loyal customers get special offers. No manual tracking required.

**Current state:** Customer analytics, at-risk detection (21-day), and tag system (New/Regular/At Risk) fully built. Festival campaign screen built. WhatsApp bulk send built.

**What needs to be automated:**

5.1 **Auto At-Risk Campaign** (weekly, Monday 10 AM)
- Find customers with isAtRisk = true
- Auto-send festival_screen style WhatsApp: "Hi [Name], we miss you at [Shop]! Come back for ₹50 off today."
- Track if customer orders within 7 days → re-tag as Regular

5.2 **New Customer Welcome** (within 1 hour of first order)
- Cloud Function trigger on new customer document
- WhatsApp: "Welcome to [Shop]! Your first order is confirmed. UPI: [id] if paying online."

5.3 **Anniversary / Birthday Greeting**
- If shop captures customer birthday → send Onam/birthday greeting
- Festival_screen templates already exist

5.4 **Loyalty Points System**
- ₹100 spent = 1 point
- 100 points = ₹10 off
- Track in CustomerModel (add loyaltyPoints field)
- Show on customer WhatsApp receipt: "You have 45 points = ₹4.50 off next order"

5.5 **Customer Lifetime Value Dashboard**
- CustomerModel already has totalSpent, totalOrders, lastOrderDate
- Analytics screen addition: Top 10 customers by LTV
- "Rajan has spent ₹47,000 in 6 months. 23 orders."

5.6 **Auto SMS/WhatsApp Udhar Statement** (monthly)
- On 1st of each month → send each customer their Udhar statement
- "Your account at [Shop]: ₹3,200 outstanding. Bills: [list]."

**Agent Assignment:** Agent 1 (WhatsApp Automation handles triggers)

---

### Domain 6: Payment Automation

**Vision:** The owner never chases payments. UPI is on every bill. Udhar reminders go automatically. Payment confirmation arrives on WhatsApp.

**Current state:** UPI ID stored in ShopModel. qr_flutter installed. Udhar tracking complete. No UPI QR on bills. No auto-reminders.

**What needs to be automated:**

6.1 **UPI QR on Every Bill**
- Generate QR for amount: upi://pay?pa=[upiId]&pn=[shopName]&am=[amount]&tn=[billId]
- Print on thermal receipt
- Display on screen for customer to scan
- Package: qr_flutter (already installed)

6.2 **Payment Link Generation**
- Short URL with payment details
- Send via WhatsApp: "Pay ₹450 via UPI: [link]"

6.3 **Payment Confirmation Webhook**
- When UPI payment confirmed (via Razorpay/PayU) → mark bill as paid
- WhatsApp to customer: "Payment received ₹450. Thank you!"
- WhatsApp to owner: "₹450 received from [customer] for bill [id]"

6.4 **Udhar Aging Report**
- Credits grouped by age: 0-7 days, 8-21 days, 22-30 days, 30+ days
- 30+ days = danger zone, highlighted red
- Total at-risk Udhar amount shown prominently

6.5 **Auto Udhar Settlement via UPI**
- Customer receives WhatsApp with amount + UPI QR
- On payment → Udhar status auto-updated to 'paid'

6.6 **Razorpay Subscription Integration**
- Shop owner pays ₹199/499 per month
- Subscription screen (already exists) hooks into Razorpay
- Auto-enable Pro features on payment confirmation
- Auto-reminder 3 days before expiry

**Agent Assignment:** Agent 3 (UPI Payment Collection)

---

### Domain 7: AI Agent & Voice Ordering

**Vision:** A customer sends a WhatsApp voice message in Malayalam: "ഒരു കിലോ അരി, 2 litre coconut oil വേണം". The AI parses it, finds the products, creates the order, sends a confirmation to the customer, and notifies the shop — all without any human touching the order.

**Current state:** voice_order_screen.dart (924 lines) with speech_to_text + Gemini AI parsing. This is the INSIDE the app for the owner. The gap is the CUSTOMER-FACING WhatsApp bot.

**What needs to be automated:**

7.1 **Customer WhatsApp Bot** (the big one)
- Customer texts the shop's WhatsApp number
- Webhook (Cloud Function) receives message → sends to Gemini
- Gemini parses intent: "show catalog", "order X", "check status", "pay Udhar"
- Response sent back via Gupshup API
- Order created in Firestore → triggers existing notification to owner

7.2 **Malayalam NLP Order Parsing**
- Already built in VoiceOrderScreen with Gemini
- Reuse same Gemini prompt for WhatsApp text (not just voice)
- Handles: "oru kilo arri, randu coconut oil" (code-switched Malayalam-English)
- Confidence threshold: if <70% → ask customer to confirm

7.3 **Catalog Browse via WhatsApp**
- Customer sends "list" or "products" → bot sends category list
- Customer sends "grocery" → bot sends top 10 products with prices
- Customer sends product name → bot sends price + "Reply 1 to add"

7.4 **Order Status via WhatsApp**
- Customer sends order number → bot returns current status
- Automatically sent when status changes (Domain 2)

7.5 **Voice Bill Entry (Owner)**
- Owner speaks: "1 kilo rice, 2 bread, 1 coconut oil"
- VoiceOrderScreen (already built) creates cart items
- Extends to auto-save bill with single tap

7.6 **AI Supplier Order Drafting**
- ReorderScreen (already built) suggests what to reorder
- Add: "Send reorder WhatsApp to supplier" button
- Formats WhatsApp message with quantities and sends

**Architecture:**
```
Customer WhatsApp → Gupshup Webhook → Cloud Function → Gemini API
→ Parse intent → Query Firestore → Create order/send response
```

**Agent Assignment:** Agent 5 (AI WhatsApp Bot — separate due to complexity)

---

### Domain 8: Marketing Automation

**Vision:** The shop runs seasonal promotions, sends weekly offers, and announces new products — all without the owner typing a single message.

**Current state:** festival_screen.dart (632 lines) — pre-built festival templates, customer filtering, bulk WhatsApp. Manual trigger only.

**What needs to be automated:**

8.1 **Auto Festival Calendar**
- System knows Kerala festivals: Onam (Sep), Vishu (Apr), Christmas (Dec 25), Bakrid, Eid, etc.
- 3 days before festival → remind owner to run campaign
- One tap → send to all customers

8.2 **New Product Announcement**
- When owner adds new product → offer to broadcast to customers
- "New product added: Fresh Pineapple ₹40/kg. Announce to customers?"
- One-tap WhatsApp broadcast

8.3 **Weekly Offers Auto-Send** (Sunday 10 AM)
- Owner marks products as "offer" (offerPrice field already exists)
- Cloud Function compiles offer list → sends to all active customers
- Format: "🛒 This Week's Deals at [Shop]: Rice ₹48/kg (was ₹55), ..."

8.4 **Google Business Profile Integration**
- Auto-post new products/offers to Google Business Profile
- Update shop hours automatically
- Collect Google Reviews via WhatsApp (post-delivery message)

8.5 **Social Media Post Generator**
- Generate Canva-style product images (Gemini image API)
- WhatsApp/Instagram ready format
- Festival greeting cards with shop branding

**Agent Assignment:** Agent 1 (WhatsApp Automation includes marketing triggers)

---

### Domain 9: Analytics & Business Intelligence

**Vision:** Every morning the owner knows exactly how the business is doing without opening the app. The numbers are delivered on WhatsApp. The app shows deeper analysis when needed.

**Current state:** analytics_screen.dart (720 lines) — daily revenue, bill count, payment breakdown, charts. No automated delivery. No weekly/monthly reports.

**What needs to be automated:**

9.1 **Nightly Sales Summary** (Domain 2.1 covers delivery)
- Already have data: dailySalesSummaryProvider in billingProvider
- Need: Cloud Function to read today's bills at 9:30 PM and send

9.2 **Weekly Performance Report** (Monday 8 AM)
- Last 7 days: revenue trend, top products, new customers
- Compare to previous week: ▲12% revenue, ▼3 customers
- Delivered via WhatsApp + in-app dashboard

9.3 **Monthly P&L Statement**
- Revenue (from bills) vs Cost (from supplier payments if tracked)
- Gross profit per category
- Cash vs UPI vs Udhar breakdown
- PDF export via email/WhatsApp

9.4 **Bento Grid KPI Dashboard** (Flutter redesign)
- Current analytics screen is charts-only
- Redesign as bento grid: Revenue tile (2x1), Orders (1x1), Avg Bill (1x1), Revenue chart (3x1), Top Product (2x1), Low Stock (2x1)
- Design tokens: Deep Forest Green #1B4332, Bright Green #52B788

9.5 **Cashier Performance Tracking**
- Bills per cashier per day
- Average bill value per cashier
- Hours worked (if login/logout tracked)

9.6 **Product Performance Matrix**
- Sell-through rate, reorder frequency, margin per product
- "Dead stock" flag: products not sold in 30 days

**Agent Assignment:** Improvements to analytics_screen.dart — part of Agent 2

---

### Domain 10: Supplier & Procurement Automation

**Vision:** When stock runs low, the supplier is automatically notified. Purchase orders are tracked. Supplier payments are recorded.

**Current state:** Supplier management complete (list, add, edit, contact). No procurement automation.

**What needs to be automated:**

10.1 **Auto Reorder WhatsApp to Supplier**
- ReorderScreen already suggests items to reorder (Gemini)
- Add: "Send Purchase Order" button
- Formats and sends WhatsApp to supplier with item list

10.2 **Purchase Order Tracking**
- New Firestore collection: shops/{shopId}/purchaseOrders
- Status: sent → acknowledged → delivered → paid
- Link to supplier document

10.3 **Supplier Payment Tracking**
- Track amounts paid to each supplier
- Pending payments dashboard
- WhatsApp receipt to supplier on payment

10.4 **Price Comparison**
- If shop has 2+ suppliers for same category
- Show price per unit comparison
- Recommend cheapest for standard items

10.5 **Delivery Schedule Tracking**
- Supplier delivery days (e.g., Tuesdays/Fridays)
- Alert owner day before: "[Supplier] delivery tomorrow. Confirm?"
- Pre-filled order based on current low-stock

**Data model additions:**
```dart
// shops/{shopId}/purchaseOrders/{poId}
class PurchaseOrder {
  String poId;
  String supplierId;
  String supplierName;
  List<POItem> items;  // {productId, productName, qty, unit, estimatedPrice}
  String status;  // draft | sent | acknowledged | delivered | paid
  double totalAmount;
  DateTime createdAt;
  DateTime expectedDelivery;
}
```

**Agent Assignment:** Extend Agent 1 (supplier WhatsApp) + new Firestore work

---

### Domain 11: ONDC Integration

**Vision:** Every WeKerala shop is automatically visible on the ONDC network (400+ cities, government-backed). Orders from ONDC flow into the WeKerala dashboard exactly like WhatsApp orders.

**Current state:** Not built. ONDC architecture referenced in deep-dive docs.

**What needs to be automated:**

11.1 **ONDC Seller Onboarding**
- Register shop as ONDC seller via eSamudaay/Mystore SNP API
- Map WeKerala product catalog to ONDC format (BPP catalog schema)
- Auto-publish catalog to ONDC network

11.2 **ONDC Order Routing**
- Webhook receives ONDC orders
- Auto-creates order in shops/{shopId}/orders with source='ondc'
- Same notification flow as WhatsApp orders

11.3 **ONDC Catalog Sync**
- When product added/updated/deleted in WeKerala → sync to ONDC catalog
- Price changes propagate immediately

11.4 **ONDC Order Fulfillment**
- Status updates from WeKerala → pushed back to ONDC network
- Logistics integration (Dunzo, Porter, Shadowfax)

11.5 **ONDC Revenue Tracking**
- Separate ONDC revenue line in analytics
- Commission calculation (WeKerala takes 1-2% of ONDC orders)

**Implementation approach:**
- Partner with eSamudaay (existing ONDC SNP) for protocol handling
- WeKerala acts as MSN (Merchant Subscriber Node)
- Gupshup already has ONDC integration module

**Agent Assignment:** Agent 5 (ONDC Integration)

---

### Domain 12: Digital Presence Automation

**Vision:** The shop's website always reflects current prices, current stock, and current offers — without the owner doing anything.

**Current state:** Website builder complete (3 themes, 5-tab builder). Products displayed on storefront. Manual publish required.

**What needs to be automated:**

12.1 **Auto Product Sync to Website**
- When product updated in Flutter app → website storefront reflects immediately
- Already true via Firestore real-time (storefront reads from same products collection)

12.2 **Auto Offer Banner on Website**
- When owner sets offerPrice → hero banner auto-shows "Sale: [Product]!"
- Festival banners auto-change on festival dates (Onam, Christmas, etc.)

12.3 **Custom Domain Setup**
- Instead of wekerala.vercel.app/sites/[shopId]
- Connect custom domain (e.g., vineethtextiles.com)
- One-tap domain pointing via Cloudflare/Vercel

12.4 **Google Business Profile Auto-Update**
- Sync shop hours from ShopModel.isOpen
- Post new products as Google Business posts
- Reply to reviews via WeKerala dashboard

12.5 **SEO Optimization**
- Auto-generate meta descriptions from product catalog
- sitemap.xml auto-generated
- Structured data (Schema.org Product markup) auto-added

12.6 **10 Themes (from Phase 16B)**
- Website builder already has 10 theme categories
- All themes should be fully implemented (currently 3 are functional)

**Agent Assignment:** Website builder extensions — not in current 90-day sprint

---

### Domain 13: Operations & Staff Automation

**Vision:** Staff can only do what they are authorized to do. Every shift has a record. Cash is counted automatically.

**Current state:** Staff roles built (owner/cashier/manager). Role-based tab visibility built. No shift tracking.

**What needs to be automated:**

13.1 **Shift Open/Close**
- Cashier opens shift → records time, opening cash balance
- Cashier closes shift → app shows: bills created, cash collected, UPI collected, total
- Owner receives shift summary on WhatsApp

13.2 **Cash Drawer Reconciliation**
- At close: expected cash = opening balance + cash sales - cash payments to suppliers
- Difference flagged immediately

13.3 **Staff Sales Performance**
- Bills per cashier per day (already trackable via billedBy field — add this)
- Average bill size, fastest billing time

13.4 **Owner Approval Required Actions**
- Discount > 10% requires owner PIN
- Bill cancellation requires owner approval
- Refund always requires owner approval

13.5 **Daily Cashier Report on WhatsApp**
- End of cashier shift → WhatsApp to owner: "Shift summary: 47 bills, ₹8,200 cash, ₹3,100 UPI"

**Agent Assignment:** Add billedBy field to BillModel + shift Cloud Function

---

## Section 3: 90-Day Implementation Roadmap

### Week 1-2: Foundation (P0 — Ship These First)

| Task | Agent | ETA |
|------|-------|-----|
| Day-end WhatsApp summary Cloud Function | Agent 1 | Day 3 |
| UPI QR code on billing screen + thermal print | Agent 3 | Day 4 |
| GST GSTR-1 PDF generation | Agent 2 | Day 7 |
| Udhar payment reminder Cloud Function | Agent 1 | Day 7 |
| Low stock WhatsApp alert (Firestore trigger) | Agent 1 | Day 10 |
| Order status → customer WhatsApp automation | Agent 1 | Day 10 |

### Week 3-4: Core Automation (P1 — Growth Enablers)

| Task | Agent | ETA |
|------|-------|-----|
| Customer WhatsApp bot v1 (text orders) | Agent 5 | Day 20 |
| Auto purchase order WhatsApp to supplier | Agent 1 | Day 14 |
| Razorpay subscription integration | Agent 3 | Day 21 |
| GSTR-1 JSON export (government format) | Agent 2 | Day 21 |
| Monthly business report Cloud Function | Agent 1 | Day 21 |
| Auto at-risk customer win-back campaign | Agent 1 | Day 18 |

### Week 5-8: AI & Intelligence (P1 — Competitive Moat)

| Task | Agent | ETA |
|------|-------|-----|
| Malayalam WhatsApp bot with Gemini | Agent 5 | Day 40 |
| Catalog browse via WhatsApp | Agent 5 | Day 45 |
| Customer-facing app Phase 17 | Agent 4 | Day 35 |
| Loyalty points system | Agent 4 | Day 45 |
| New product broadcast automation | Agent 1 | Day 30 |
| Weekly offer auto-send (Sunday) | Agent 1 | Day 30 |

### Week 9-12: Scale (P2 — Market Expansion)

| Task | Agent | ETA |
|------|-------|-----|
| ONDC seller integration | Agent 5 | Day 60 |
| Google Business Profile sync | — | Day 70 |
| Expiry alert Cloud Function | Agent 1 | Day 50 |
| Purchase order tracking (Firestore) | — | Day 55 |
| Offline-first with Hive/Isar | — | Day 75 |
| Custom domain for website | — | Day 80 |

---

## Section 4: Agent Deployment Plan

### Agent 1: WhatsApp Automation Engine
**Files to create/modify:**
- `functions/index.js` — Add 6 new Cloud Functions
- `wekerala_app/lib/features/settings/` — WhatsApp settings toggles

**Cloud Functions to build:**
```javascript
// 1. Daily Sales Summary (9:30 PM every day)
exports.sendDailySalesSummary = onSchedule("30 21 * * *", async (event) => { ... })

// 2. Udhar Payment Reminder (10 AM daily)  
exports.sendUdharReminders = onSchedule("0 10 * * *", async (event) => { ... })

// 3. Low Stock Alert (Firestore trigger on product update)
exports.onProductStockUpdate = onDocumentUpdated("shops/{shopId}/products/{productId}", ...)

// 4. Order Status → Customer WhatsApp (Firestore trigger)
exports.onOrderStatusChange = onDocumentUpdated("shops/{shopId}/orders/{orderId}", ...)

// 5. Monthly Business Report (1st of month, 8 AM)
exports.sendMonthlyReport = onSchedule("0 8 1 * *", async (event) => { ... })

// 6. At-Risk Customer Campaign (Monday 10 AM)
exports.sendAtRiskCampaign = onSchedule("0 10 * * 1", async (event) => { ... })
```

---

### Agent 2: GST & Billing Export
**Files to create/modify:**
- `wekerala_app/lib/features/billing/screens/gstr1_screen.dart` — Add export logic
- `wekerala_app/lib/features/billing/models/gstr1_model.dart` — New model
- `wekerala_app/lib/features/billing/services/pdf_service.dart` — PDF generation

**Key implementation:**
- Use `pdf` Flutter package for PDF generation
- GSTR-1 schema: B2C summary grouped by HSN + rate
- Export as PDF + JSON
- WhatsApp share via share_plus (already installed)

---

### Agent 3: UPI Payment Collection
**Files to create/modify:**
- `wekerala_app/lib/features/billing/screens/billing_screen.dart` — Add UPI QR display
- `wekerala_app/lib/features/billing/widgets/upi_qr_widget.dart` — New widget
- `wekerala_app/lib/features/settings/screens/` — Razorpay subscription

**UPI QR format:**
```
upi://pay?pa={upiId}&pn={shopName}&am={amount}&tn={billId}&cu=INR
```

---

### Agent 4: Customer-Facing Phase 17
**Files to create/modify:**
- `web/app/customer/` — Customer login, order history, addresses
- `web/app/api/customer/` — Customer API routes (already partially built)
- `wekerala_app/lib/features/customer/` — Customer-facing Flutter screens

---

### Agent 5: AI WhatsApp Bot (Malayalam)
**Architecture:**
```
Gupshup Incoming Webhook → Cloud Function → Gemini 1.5 Flash
→ Intent Classification → Firestore Query/Write → Gupshup Send
```

**Files to create:**
- `functions/whatsapp-bot.js` — Main bot handler
- `functions/gemini-parser.js` — Order parsing logic
- `functions/catalog-formatter.js` — WhatsApp catalog response formatter

---

## Section 5: Revenue Impact by Domain

| Domain | Monthly Revenue Added (at 1,000 shops) |
|--------|---------------------------------------|
| Subscription (Razorpay) | ₹2-5 lakh/month |
| ONDC commission (1-2%) | ₹50k-2 lakh/month |
| WhatsApp API pass-through | Cost center (₹0.14-1.09/message) |
| Lending (BNPL to shop owners) | ₹1-3 lakh/month (Month 18+) |
| Featured listings/ads | ₹50k/month |
| **Total at 1,000 shops** | **₹4-11 lakh/month (₹50L-1.3Cr ARR)** |

---

## Section 6: Data Model Additions Required

### New Fields on Existing Models

```dart
// BillModel — add:
String billedBy;  // userId of cashier who created bill
int billNumber;   // Sequential bill number (WK/2526/001)
String source;    // 'pos' | 'voice' | 'whatsapp' | 'ondc'

// ProductModel — add:
String supplierId;  // Link to primary supplier
double costPrice;   // Purchase price (for margin calculation)

// ShopModel — add:
String whatsappBotEnabled;  // true/false
String mondlyAPIKey;        // for future advanced NLP
Map<String, bool> automationSettings;  // toggle each automation
```

### New Collections

```
shops/{shopId}/purchaseOrders/{poId}
  supplierId, items[], status, totalAmount, createdAt, expectedDelivery

shops/{shopId}/shifts/{shiftId}
  cashierId, openTime, closeTime, openingCash, bills[], totalCash, totalUPI

shops/{shopId}/loyaltyPoints/{customerId}
  points, lastUpdated, transactions[]

platform/ondcConfig
  sellerId, sellerApp, catalogLastSync, totalONDCOrders
```

---

## Section 7: The 5-Year Automation Vision

### 2026 (Year 1): Foundation
- Every shop has: GST billing, auto-WhatsApp reports, UPI on bills
- Automation rate: 40% of daily tasks automated
- Shops: 1,000 | ARR: ₹25 lakh

### 2027 (Year 2): Intelligence
- AI WhatsApp bot handles 70% of customer orders without owner
- ONDC live — shops sell to all of Kerala without delivery logistics
- Automation rate: 65% of daily tasks automated
- Shops: 5,000 | ARR: ₹1.5 crore

### 2028 (Year 3): Scale
- WeKerala AI predicts: what to order, who will buy, what price to set
- Voice-first POS — owner speaks, app bills, reports auto-generated
- Automation rate: 80% of daily tasks automated
- Shops: 20,000 | ARR: ₹7 crore

### 2029 (Year 4): Expansion
- Tamil Nadu launch (Tamil language support)
- Bank lending integration — WeKerala data used for shop loans
- Automation rate: 85%
- Shops: 60,000 | ARR: ₹25 crore

### 2030 (Year 5): AI Operating System
- WeKerala IS the shop's brain
- Buys, sells, bills, files taxes, markets — automatically
- Shop owner's job: choose strategy, meet customers
- Automation rate: 90%
- Shops: 1.5 lakh | ARR: ₹75 crore

---

## Section 8: The Single Most Important Insight

**WeKerala has already built more than any competitor.**

The real competitor is not Vyapar or Khatabook. The real competitor is **inertia** — the shop owner who keeps using a paper notebook because no one has sat with them and shown them that WeKerala works.

Every automation in this blueprint serves one purpose: **reduce the owner's effort until zero is required**. The moment WeKerala runs the shop better than the owner can run it manually, adoption becomes inevitable.

The path: Quick Start (30-second first bill) → Day-End Summary (daily habit) → GST auto-filing (saves 3 hours/month) → AI takes orders (saves 2 hours/day) → Owner becomes the strategist, not the operator.

**That is the AI-powered shop of Kerala's future. WeKerala builds it.**

---

*Last updated: 2026-05-21 | Next review: 2026-06-21*
*All 13 automation domains documented. 5 agents deployed.*
