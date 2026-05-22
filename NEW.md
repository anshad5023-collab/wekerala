# weKerala — Deep Research, Full Audit & Rebuild Plan
> Created: 2026-05-22 | Status: Research complete, ready for implementation
> Do NOT touch existing code until each section is approved and ordered.
> All planned changes live here first — code changes come after.

---

## PART 1 — WHAT WE FOUND (Competitive Research)

### Who the Best Competitors Are

| App | Why Shops Use It | What We Can Steal |
|-----|-----------------|-------------------|
| **Vyapar** | 50+ report types, offline-first, free Android | Report formats, GST export to JSON |
| **myBillBook** | Staff payroll, loyalty program, bulk WhatsApp marketing | Loyalty points, bulk WhatsApp, iOS support |
| **Khatabook** | 13 languages, best udhar UX, 24/7 support | Udhar UX patterns, language-first design |
| **OkCredit** | Completely free, zero friction, Malayalam | Zero-friction onboarding |
| **Udhaar App** | Only app with cash denomination counter | Cash counting feature (UNIQUE opportunity) |
| **Just Billing** | Fastest counter POS, restaurant KOT, multi-location | KOT mode, counter speed |
| **Gofrugal** | First app on ONDC, weighing scale integration | ONDC flow, weighing scale |
| **Dukaan** | Fastest online store creation, zero commission | Store creation speed |
| **Zoho Books** | Best GST compliance, e-invoice, bank reconciliation | GST export formats |
| **PhonePe Business** | SmartSpeaker in Malayalam, 47M merchants | Payment integration |

### The Big Insight: What No App Does That We Can Own
1. **Malayalam-first** — every app has Malayalam as an afterthought. We make it the default.
2. **WhatsApp Commerce Loop** — customer orders via WhatsApp chat (no app install needed)
3. **Cash Denomination Counter** — end-of-day: count your ₹500s, ₹200s etc → auto-calculates total vs expected. Zero apps do this. Kerala kirana owners will love it.
4. **Daily WhatsApp Summary to Owner at 6 PM** — "Today: 47 bills | ₹18,450 | Top: Parle-G" — already partially built, needs polish.
5. **Weighing Scale Integration** — for grocery/vegetable shops (USB/Bluetooth scale)
6. **Medical Shop Mode** — batch + expiry mandatory, schedule drug tracking, near-expiry clearance report

### What Makes Shop Owners Actually Pay (Research Finding)
1. GST filing made easy (saves CA fees)
2. Counter speed under 5 seconds per bill
3. WhatsApp bill sharing (customers expect it now)
4. Inventory theft prevention
5. Automated credit recovery reminders
6. Daily profit visibility in one glance
7. Offline operation (no internet = no business)
8. Price: ₹800–₹2,000/year is the sweet spot

### GST Rules for 2025-26 (Non-Negotiable Compliance)
- HSN mandatory: 4-digit for turnover < ₹5Cr, 6-digit for > ₹5Cr
- CGST/SGST/IGST breakdown per line item
- E-invoice (IRN + QR) for turnover > ₹5 crore
- 30-day reporting limit if turnover > ₹10 crore
- New HSN tax rates effective September 22, 2025 — app must auto-update
- GSTR-1 JSON export (not just PDF) — accountants need this
- Invoice retention: 72 months

---

## PART 2 — EVERY BUG FOUND (Full Audit)

### 2A. Flutter App — 25 Issues Found

#### CRITICAL (Must fix before any user touches the app)

**BUG-01 | Billing → Udhar doesn't create Customer record**
- File: `lib/features/billing/screens/billing_screen.dart` ~line 140
- Problem: Bill saved as Udhar, credit entry created, but CustomerModel in `shops/{id}/customers/` is never created/updated
- Effect: Customer list is empty even after dozens of bills; customer history broken; win-back feature useless
- Fix needed: After `saveBill()`, if paymentMethod == 'udhar', upsert customer doc with name, phone, totalSpent, lastOrderDate

**BUG-02 | Firestore rules allow public write to config/deals/serviceTags**
- File: `wekerala_app/firestore.rules` lines 82-87
- Problem: `allow write: if true` on `/config/`, `/deals/`, `/serviceTags/` — anyone on the internet can write to these
- Effect: Anyone can inject malicious config, fake deals, spam service tags
- Fix: Change to `allow write: if false` (admin writes via Firebase Console or Admin SDK only)

**BUG-03 | Orders can be deleted by owner**
- File: `wekerala_app/firestore.rules` line 35
- Problem: `allow delete: if isOwner(shopId)` — owner can delete orders to hide records
- Effect: Tax fraud possible; no audit trail
- Fix: `allow delete: if false` — use soft deletes (status: 'archived') instead

**BUG-04 | Bill amounts can be modified after creation**
- File: `wekerala_app/firestore.rules` ~line 53
- Problem: No field-level protection on bills — owner can change finalAmount after customer paid
- Fix: Restrict updates to only non-financial fields; freeze amounts on creation

**BUG-05 | Daily sales summary schedule is wrong**
- File: `functions/index.js` line 313
- Problem: `schedule: '30 16 * * *'` sends at 10:00 PM IST — spec says 9:30 PM IST
- Fix: Change to `schedule: '0 16 * * *'` (4:00 PM UTC = 9:30 PM IST)

**BUG-06 | Missing Firestore indexes — queries will fail in production**
- File: `wekerala_app/firestore.indexes.json`
- Missing indexes:
  1. `shops` collection: `shopSlug ASC + isActive ASC` (storefront can't load shops)
  2. `products` collection: `isHidden ASC + category ASC + nameEn ASC` (product filter fails)
  3. `bills` collection: `shopId ASC + createdAt DESC` (bill history slow/broken)
- Effect: Storefront returns empty results; billing history crashes for large shops

---

#### HIGH (Breaks features, confuses users)

**BUG-07 | No UPI error when UPI ID not configured**
- File: `billing_screen.dart` ~line 98
- Problem: User selects UPI payment → no QR shown, no error, bill saved as UPI "paid" silently
- Fix: Before showing payment dialog, check `shop.upiId.isNotEmpty` — if empty, show "Please set UPI ID in Shop Settings" dialog

**BUG-08 | Orders cannot be edited or deleted**
- File: `order_detail_screen.dart`
- Problem: No edit/delete on orders — if customer calls to change an item, owner has no way to fix it
- Fix: Add "Edit Order" for orders in 'new' status only; add "Cancel" with reason picker

**BUG-09 | Voice Order parser fails silently**
- File: `voice_order_screen.dart` lines 208-249
- Problem: Parser only handles "2 kg rice" format. "Rice 2 kg" or "two kilo rice" returns empty items with no error
- Fix: Show parsed items as editable chips before saving; "0 items found" message if parsing fails; allow manual add

**BUG-10 | GST calculated before discount (mathematically wrong)**
- File: `billing_screen.dart` ~line 70
- Problem: Tax calculated on pre-discount price. Legally, discount should reduce taxable amount first
- Fix: `taxableAmount = (price * qty) - proportional_discount`; recalculate GST on net taxable amount

**BUG-11 | Credits payment doesn't update Bill/Order record**
- File: `credits_screen.dart` lines 818-828
- Problem: Mark as paid → only CreditModel updated. Original bill still shows 'udhar'. Order shows 'payment pending'
- Fix: When credit marked paid/partial, find linked bill and update `paymentMethod` and `paymentStatus`

**BUG-12 | ONDC order items not validated**
- File: `functions/index.js` lines 174-185
- Problem: ONDC webhook doesn't check if item names exist — malformed ONDC payload creates orders with "Unknown" items
- Fix: Validate `item.descriptor.name` exists; if not, reject with 400 and log

**BUG-13 | totalOrders has race condition**
- File: `functions/index.js` line 239
- Problem: `shopData.totalOrders + 1` — two simultaneous orders lose one increment
- Fix: Replace with `FieldValue.increment(1)` from Firebase Admin SDK

**BUG-14 | Order ID collision on storefront**
- File: `web/storefront/js/checkout.js` line 128
- Problem: `orderId = shopId + '_' + Date.now()` — two customers ordering same millisecond = same ID = data overwrite
- Fix: Use `db.collection(...).doc().id` (Firestore auto-generated ID)

**BUG-15 | Print button hardcoded disabled**
- File: `bill_detail_screen.dart` lines 176-189
- Problem: Print button shows "Coming soon" tooltip. Users tap it, nothing happens. Confusing.
- Fix: Either implement print (PrintService already exists) or hide the button entirely

---

#### MEDIUM (Bad experience, missing logic)

**BUG-16 | Offer price can be higher than regular price**
- File: `add_product_screen.dart` ~line 473
- Fix: Validate `offerPrice <= price` before saving

**BUG-17 | Out-of-stock products can be added to cart**
- File: `billing_screen.dart` product panel
- Fix: Disable "Add" button if `product.isOutOfStock == true`; show "Out of stock" label

**BUG-18 | No cancellation reason captured**
- File: `orders_list_screen.dart` ~line 340
- Fix: Show reason picker on cancel: "Customer cancelled" / "Out of stock" / "Delivery issue" / "Other"

**BUG-19 | Customer tags never updated**
- File: `customers_screen.dart` ~line 95
- Problem: `tag` field ('At Risk', 'Regular', 'New') computed but never auto-updated based on real order data
- Fix: Compute tag live from `lastOrderDate` and `totalOrders` on CustomerModel (getter, not stored field)

**BUG-20 | WhatsApp phone not validated on shop settings**
- File: `shop_settings_screen.dart` ~line 53
- Fix: Strip non-digits, validate 10-digit Indian number before saving

**BUG-21 | Customer phone not normalized on storefront checkout**
- File: `web/storefront/js/checkout.js` line 38
- Problem: "+91 98765 43210" fails regex `/^\d{10}$/`
- Fix: `const normalized = phone.replace(/\D/g, '').slice(-10)`

**BUG-22 | Per-item notes lost during checkout**
- File: `product-detail.js` line 79 + `checkout.js` line 165
- Problem: Customer adds note on product ("no onion") — note captured in product-detail but not passed to cart, not saved to order
- Fix: Pass `itemNote` through cart storage and into `OrderItemModel`

**BUG-23 | Bill History has no export**
- File: `bill_history_screen.dart`
- Problem: GST summary visible but no way to export for accountant
- Fix: Add "Export PDF" and "Share on WhatsApp" buttons to GST summary section

**BUG-24 | Analytics has no caching**
- File: `analytics_screen.dart` ~line 46
- Problem: All calculations run fresh on every open — slow on large datasets
- Fix: Cache daily summary in a `shops/{id}/analytics/today` document, update on each bill save

**BUG-25 | app_name translation mismatch**
- File: `assets/translations/ml.json` line 2
- Problem: en.json says "weKerala", ml.json says "ഷോപ്പ്‌ലിങ്ക്" (old name "ShopLink")
- Fix: Update ml.json `app_name` to "വീകേരള" (weKerala in Malayalam)

---

### 2B. Web Storefront / Cloud Functions — 10 More Issues

**BUG-26 | Storefront Firebase query has no composite index**
- Queries `shopSlug + isActive` but no index → will return error for shops with many documents
- Add to `firestore.indexes.json`

**BUG-27 | WhatsApp API retry missing**
- `sendWhatsApp()` in Cloud Functions fails silently if Gupshup is down
- Add retry with exponential backoff (max 3 attempts)

**BUG-28 | Order stock not decremented when order confirmed**
- Billing screen decrements stock on bill save, but orders from storefront don't decrement stock
- Add stock decrement in `onOrderCreated` or `onOrderStatusChanged` (when status = 'confirmed')

**BUG-29 | Admin panel has no auth check**
- Any signed-in user can access admin panel — should check `isAdmin` field in user document

**BUG-30 | HTML pages not cache-controlled**
- Static assets cached for 1 year (good), but HTML not set to no-cache
- Can cause users seeing stale pages after deployment
- Add `Cache-Control: no-cache` header for `index.html` in firebase.json

---

## PART 3 — MISSING FEATURES (What Needs to Be Built)

### Priority 1 — Without These, App Is Incomplete

| # | Feature | Why Needed | Competitor Who Has It |
|---|---------|-----------|----------------------|
| F-01 | **Cash Denomination Counter** | End-of-day cash counting: count notes/coins → auto-totals → shows variance | Only Udhaar App — huge differentiator |
| F-02 | **Notification Settings Screen** | Users can't control which WhatsApp/push notifications they get | Vyapar, myBillBook |
| F-03 | **GSTR-1 JSON Export** | Accountants need JSON not just PDF to upload to GST portal | Zoho Books, myBillBook |
| F-04 | **Bill Edit / Void** | After saving a bill, can't fix mistakes | Vyapar, Just Billing |
| F-05 | **Barcode Save on Add Product** | Field exists in model, UI wiring broken — can't save barcode | Vyapar |
| F-06 | **UPI Payment QR on Billing** | Select UPI → show QR code for customer to scan | All major billing apps |
| F-07 | **Customer Order History** | On storefront, customers can't see their past orders | Dukaan, Swiggy |
| F-08 | **Product Search on Billing Screen** | POS should have search-by-name so owner can find products fast | Vyapar, Just Billing |

### Priority 2 — Significantly Better With These

| # | Feature | Why Needed |
|---|---------|-----------|
| F-09 | **Loyalty Points System** | Customers earn points → redeem as discount → retention | myBillBook has it |
| F-10 | **Bulk WhatsApp Marketing** | Send offer message to all customers at once | myBillBook has it |
| F-11 | **Profit & Loss Report** | Daily/monthly P&L — #1 thing owners ask for | Vyapar, Zoho |
| F-12 | **Supplier Payment Tracking** | How much owed to each supplier; payment due dates | Vyapar |
| F-13 | **Multi-location / Multi-shop** | Currently placeholder — owners with 2 shops need this | Vyapar, Just Billing |
| F-14 | **Restaurant/KOT Mode** | Table-based ordering → KOT to kitchen → settle | Just Billing |
| F-15 | **Weighing Scale Integration** | Bluetooth/USB scale for grocery/vegetable shops | Gofrugal |
| F-16 | **Medical Shop Mode** | Batch mandatory, expiry mandatory, schedule drug flag | No mobile app does this well |
| F-17 | **Tally XML Export** | Shops whose CA uses Tally need this format | Vyapar |
| F-18 | **Customer Payment History on Storefront** | Login → see all past orders + bill PDFs | Dukaan |
| F-19 | **Product Reviews on Storefront** | Star rating + comment per product | Every e-commerce |
| F-20 | **WhatsApp Catalog** | Customer sends "Hi" → auto-reply with shop catalog link | WhatsApp Business API |

### Priority 3 — Nice to Have

| # | Feature |
|---|---------|
| F-21 | Dead stock report (products with 0 sales in 30 days) |
| F-22 | Subscription/Razorpay payment integration |
| F-23 | Staff payroll / attendance tracking |
| F-24 | SEO meta tags on shop pages (for Google discoverability) |
| F-25 | PWA offline support for storefront |
| F-26 | Product bundle pricing (buy 3 get 1 free) |
| F-27 | Referral program for shops |
| F-28 | Platform analytics for admin (total GMV, active shops, etc.) |

---

## PART 4 — SETTINGS THAT MUST EXIST (Every Setting Missing Today)

### Shop Settings (currently too sparse)
- [ ] Business hours per day (Monday–Sunday, open/close time)
- [ ] Holiday mode (mark closed for a day with message)
- [ ] Minimum order value (separate for delivery vs pickup)
- [ ] Delivery radius (km) with map picker
- [ ] Delivery charges (flat / per km / free above amount)
- [ ] Auto-confirm orders (skip 'new' → go straight to 'confirmed')
- [ ] Low stock default threshold (global, overridable per product)
- [ ] GST registration toggle (if not registered, hide GST fields)
- [ ] Invoice number prefix (e.g., "WK-" + sequential number)
- [ ] Invoice footer message (custom text on every bill)
- [ ] Language for customer-facing messages (WhatsApp in EN or ML)

### Notification Settings (currently 0 settings — everything or nothing)
- [ ] New order: WhatsApp ON/OFF, Push ON/OFF
- [ ] Order status changes: WhatsApp to customer ON/OFF
- [ ] Low stock alert: threshold X items, WhatsApp ON/OFF
- [ ] Expiry alert: X days before, WhatsApp ON/OFF
- [ ] Daily summary: time picker, WhatsApp ON/OFF
- [ ] Udhar reminder: X days before due, WhatsApp ON/OFF
- [ ] Weekly dead stock report: ON/OFF

### Billing Settings (currently 0 settings)
- [ ] Discount before or after GST toggle
- [ ] Round off final bill (nearest rupee) ON/OFF
- [ ] Auto-print on bill save ON/OFF
- [ ] Auto-WhatsApp receipt ON/OFF (currently in shop settings but needs to be here)
- [ ] Default payment method (cash / UPI / card)
- [ ] Show/hide GST on customer receipt
- [ ] UPI ID (move from shop settings to billing settings)

### Product Settings
- [ ] Default GST rate for new products
- [ ] Default unit
- [ ] Auto-image lookup ON/OFF
- [ ] Barcode scanner sound ON/OFF
- [ ] Show offer price by default ON/OFF

---

## PART 5 — FEATURE-BY-FEATURE IMPROVEMENT PLAN

### Billing Screen — 8 improvements needed
1. Fix GST calculation after discount (BUG-10)
2. Block adding out-of-stock items (BUG-17)
3. Fix udhar → create customer record (BUG-01)
4. UPI error if not configured (BUG-07)
5. Add product search bar at top of product grid
6. Add "Quick Amount" buttons (₹10, ₹20, ₹50, ₹100, ₹500) for cash received
7. Show change amount after cash received (e.g., "Give back ₹30")
8. Bill edit/void within 24 hours

### Orders Screen — 6 improvements needed
1. Add edit for 'new' status orders
2. Add cancellation reason picker
3. Show customer phone/location on order card
4. Add "Print KOT" button for restaurant mode
5. Bulk status update (select multiple orders → confirm all)
6. Order search by customer name or phone number (already exists, verify it works)

### Products Screen — 5 improvements needed
1. Fix barcode save in add_product (BUG-05, field exists, wiring broken)
2. Add "Create Reorder List" button — generates list of all low-stock items for supplier
3. Bulk price update (select multiple → increase price by X%)
4. Product duplication button (clone product, change name)
5. Add batch number and expiry date as required fields option (for medical shops)

### Customers Screen — 4 improvements needed
1. Fix customer tags (live computed, not stored)
2. Add "Send Festival Offer" per customer
3. Add filter: All / At Risk / Regular / New
4. Show total outstanding credit per customer

### Credits/Udhar Screen — 4 improvements needed
1. Fix: mark paid should update original bill (BUG-11)
2. Add: filter by overdue only
3. Add: bulk send reminder to all overdue customers in one tap
4. Add: late fee setting + auto-calculate if configured

### Analytics Screen — 5 improvements needed
1. Add caching (BUG-24)
2. Add P&L section (sales - estimated cost = profit)
3. Add payment method breakdown chart (cash vs UPI vs udhar pie chart)
4. Add export to WhatsApp (daily summary already exists but needs polish)
5. Add GSTR-1 export button (JSON + PDF)

### Voice Orders — 3 improvements needed
1. Show parsed items as editable list before saving (BUG-09)
2. Match parsed names against real product inventory (fuzzy match)
3. Support "cancel last item" voice command

### WhatsApp Integration — 4 improvements needed
1. Fix API URL (done — was /wa, now /sm)
2. Add notification settings screen so owners can control what gets sent
3. Add WhatsApp templates for: payment receipt, festive offer, due reminder
4. Add opt-out handling (if customer replies STOP, remove from list)

---

## PART 6 — IMPLEMENTATION ORDER (When You Come Back)

### Phase A — Critical Bugs (do these first, nothing else until done)
- [ ] BUG-02: Fix Firestore rules (public write vulnerability)
- [ ] BUG-06: Add missing Firestore indexes
- [ ] BUG-05: Fix daily sales schedule time in Cloud Functions
- [ ] BUG-01: Billing udhar → create customer record
- [ ] BUG-10: Fix GST calculation after discount
- [ ] BUG-25: Fix app_name in ml.json

### Phase B — High Priority Features
- [ ] F-01: Cash denomination counter (huge differentiator — build this)
- [ ] F-03: GSTR-1 JSON export
- [ ] F-05: Fix barcode save on add product
- [ ] F-06: UPI QR on billing
- [ ] F-08: Product search on billing screen
- [ ] Add all missing Settings screens (Notification Settings, Billing Settings)

### Phase C — Quality & Polish
- [ ] All 8 billing screen improvements
- [ ] All 6 order screen improvements
- [ ] All 5 product screen improvements
- [ ] Fix storefront: phone normalization, item notes, order ID
- [ ] Fix admin panel auth check
- [ ] Add HTML cache-control headers

### Phase D — New Features
- [ ] Loyalty points system
- [ ] Bulk WhatsApp marketing
- [ ] P&L report
- [ ] Customer order history on storefront
- [ ] Restaurant/KOT mode

---

## PART 7 — FILES TO CHANGE (Quick Reference)

| File | What Needs to Change |
|------|---------------------|
| `wekerala_app/firestore.rules` | Fix public write rules (BUG-02, 03, 04) |
| `wekerala_app/firestore.indexes.json` | Add 3 missing indexes (BUG-06) |
| `functions/index.js` | Schedule fix, race condition fix, retry on WhatsApp, ONDC validation |
| `lib/features/billing/screens/billing_screen.dart` | Customer creation, GST fix, out-of-stock block, product search, UPI check |
| `lib/features/billing/screens/bill_detail_screen.dart` | Wire up print button |
| `lib/features/orders/screens/order_detail_screen.dart` | Add edit/cancel with reason |
| `lib/features/orders/screens/voice_order_screen.dart` | Show parsed items before save |
| `lib/features/products/screens/add_product_screen.dart` | Fix barcode save, offer price validation |
| `lib/features/credits/screens/credits_screen.dart` | Update bill on payment, bulk reminder |
| `lib/features/customers/screens/customers_screen.dart` | Fix live tags, add filters |
| `lib/features/analytics/screens/analytics_screen.dart` | Add caching, P&L, GSTR-1 export |
| `lib/features/settings/screens/shop_settings_screen.dart` | Add all missing settings |
| `assets/translations/ml.json` | Fix app_name, verify all keys |
| `web/storefront/js/checkout.js` | Phone normalization, order ID fix |
| `wekerala_app/firebase.json` | Add HTML cache-control header |
| **NEW FILE** `lib/features/settings/screens/notification_settings_screen.dart` | All notification toggles |
| **NEW FILE** `lib/features/billing/screens/cash_counter_screen.dart` | Cash denomination counter |
| **NEW FILE** `lib/features/settings/screens/billing_settings_screen.dart` | Billing preferences |

---

## PART 8 — DESIGN PRINCIPLES FOR REBUILD

These apply to every screen we touch going forward:

1. **Every screen must have 3 states**: loading (shimmer), error (retry button), empty (Lottie animation + action button)
2. **Every form must validate before save**: no silent failures
3. **Every destructive action needs confirmation dialog**
4. **Every WhatsApp send must show status**: "Sent ✓" or "Failed — Retry"
5. **Every setting must be in the right Settings section**: not buried in a random screen
6. **Malayalam must be equal quality**: not a translation afterthought
7. **Offline must degrade gracefully**: cached data shown with "last updated X ago" banner
8. **Numbers must be formatted**: ₹1,23,456 not ₹123456; dates in dd MMM yyyy

---

*Last updated: 2026-05-22 | Research by: Competitive Analysis + Full Code Audit*
*Next step: Review this file, order the phases, then start Phase A.*
