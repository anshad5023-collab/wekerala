# wekerala App — Complete Structure Reference

> Use this file to plan features, fix bugs, and understand the app at a glance.
> Last updated: 2026-05-15 (analyzer clean — 0 issues in lib/)

---

## 1. What This App Is

**wekerala** is an Android app exclusively for **Kerala shop owners**. Customers do NOT use this app — they use the PWA storefront website. Owners use this app to manage orders, products, billing, credit (udhar), and customer relationships.

- **Package name:** `com.wekerala.app`
- **Firebase project:** `shoplink-prod`
- **Storefront URL pattern:** `{shopSlug}.wekerala.in` (served via Firebase Hosting)
- **Languages:** English + Malayalam (ml)

---

## 2. Tech Stack

| Layer | Technology |
|-------|-----------|
| UI Framework | Flutter (Android only) |
| State Management | Riverpod 2.x (`NotifierProvider`, `StreamProvider`, `Provider`) |
| Navigation | GoRouter 14.x |
| Backend | Firebase (Auth + Firestore + Storage + FCM + Remote Config) |
| Auth | Google Sign-In + Phone OTP (Firebase Auth) |
| Database | Cloud Firestore (real-time streams) |
| File Storage | Firebase Storage |
| Push Notifications | Firebase Cloud Messaging (FCM) |
| OTA Updates | Firebase Remote Config |
| Translations | JSON files (`assets/translations/en.json`, `ml.json`) |
| HTTP | `http` package (OpenFoodFacts API for barcode lookup) |
| Image | `image_picker` + `image_cropper` (1:1 ratio for products, 16:9 for banners) |

**Key packages:**
```yaml
flutter_riverpod: ^2.6.1
go_router: ^14.3.0
firebase_core / firebase_auth / cloud_firestore / firebase_storage / firebase_messaging / firebase_remote_config
google_sign_in: ^6.2.1  # serverClientId set to web OAuth client
flutter_animate: ^4.5.0
fl_chart: ^0.69.0
mobile_scanner: ^5.2.3  # barcode scan for product lookup + billing
speech_to_text: ^7.0.0  # voice order entry
flutter_local_notifications: ^17.2.0
share_plus: ^10.0.3
url_launcher: ^6.3.1
webview_flutter: ^4.10.0
qr_flutter: ^4.1.0
cached_network_image: ^3.4.1
shimmer: ^3.0.0
bluetooth_print: ^4.3.0   # Bluetooth thermal printer (58mm/80mm ESC/POS)
connectivity_plus: ^6.0.0 # Offline mode detection
permission_handler: ^11.0.0 # Bluetooth permissions
```

---

## 3. App Flow (User Journey)

```
Cold start
  └── SplashScreen (/splash)
        ├── Language not set → LanguageScreen (/language)
        │     └── → GoogleSignInScreen (/google-signin)
        ├── Not authenticated → GoogleSignInScreen (/google-signin)
        │     ├── New user (no businessTypes) → BusinessTypeScreen (/business/type)
        │     │     └── → ListingFormScreen (/business/listing-form)
        │     │           └── → BusinessHomeScreen (/business/home)
        │     └── Existing user → BusinessHomeScreen (/business/home)
        └── Authenticated → BusinessHomeScreen (/business/home)

BusinessHomeScreen — 4 tabs:
  ├── Home tab: Quick Actions + Orders overview
  ├── Web tab:  Live storefront preview
  ├── Analytics tab: Revenue & order metrics
  └── Settings tab: Shop config + navigation to all features
```

---

## 4. Complete Route Map

| Route | Screen | Auth Required | Notes |
|-------|--------|--------------|-------|
| `/splash` | SplashScreen | No | Entry point; redirects based on state |
| `/language` | LanguageScreen | No | First launch only |
| `/google-signin` | GoogleSignInScreen | No | Main sign-in screen |
| `/login` | LoginScreen | No | Phone OTP (legacy / optional) |
| `/verify` | OtpScreen | No | OTP verification; `extra: phoneNumber` |
| `/business/type` | BusinessTypeScreen | No | Select business category |
| `/business/listing-form` | ListingFormScreen | No | Fill shop/service details |
| `/business/home` | BusinessHomeScreen | No | Main hub (4 tabs) |
| `/website-builder` | WebsiteBuilderScreen | No | WebView; `extra: url` |
| `/onboard/type` | ShopTypeScreen | Yes | Shop onboarding step 1 |
| `/onboard/details` | ShopDetailsScreen | Yes | Shop onboarding step 2 |
| `/onboard/banner` | BannerUploadScreen | Yes | Shop onboarding step 3 |
| `/onboard/delivery` | DeliverySetupScreen | Yes | Shop onboarding step 4 |
| `/onboard/payment` | PaymentSetupScreen | Yes | Shop onboarding step 5 |
| `/onboard/done` | SetupCompleteScreen | Yes | Onboarding complete |
| `/orders` | OrdersListScreen | Yes | All orders with status tabs |
| `/orders/:id` | OrderDetailScreen | Yes | Single order; status actions |
| `/voice-order` | VoiceOrderScreen | Yes | Malayalam speech → order |
| `/products` | ProductsListScreen | Yes | Product catalog with filters |
| `/products/add` | AddProductScreen | Yes | Create product |
| `/products/:id` | AddProductScreen | Yes | Edit product |
| `/products/import` | ImportProductsScreen | Yes | Bulk import from Google Sheets |
| `/billing` | BillingScreen | Yes | POS quick billing screen |
| `/bill-history` | BillHistoryScreen | Yes | Past bills with date filter + search |
| `/bills/:billId` | BillDetailScreen | Yes | Full bill view; reprint; WhatsApp resend; `extra: BillModel` |
| `/credits` | CreditsScreen | Yes | Udhar book — open credits |
| `/credits/add` | AddCreditScreen | Yes | Add new udhar entry |
| `/customers` | CustomersScreen | Yes | Customer list + win-back |
| `/suppliers` | SuppliersListScreen | Yes | Supplier directory |
| `/suppliers/add` | AddSupplierScreen | Yes | Add/edit supplier; `extra: SupplierModel?` |
| `/suppliers/:supplierId` | SupplierDetailScreen | Yes | Supplier detail; call/WhatsApp; `extra: SupplierModel` |
| `/analytics` | AnalyticsScreen | Yes | Revenue & order metrics; WhatsApp daily summary |
| `/stock-alerts` | StockAlertsScreen | Yes | All low-stock products; update stock dialog |
| `/settings/shop` | ShopSettingsScreen | Yes | Edit shop profile + GSTIN + auto-send WhatsApp toggle |
| `/settings/account` | AccountSettingsScreen | Yes | Account settings |
| `/settings/staff` | StaffManagementScreen | Yes | Add/remove cashier/manager accounts; `extra: shopId` |
| `/settings/printer` | PrinterSettingsScreen | Yes | Pair Bluetooth thermal printer; test print |
| `/shops` | ManageShopsScreen | Yes | Multi-shop management (placeholder) |
| `/shops/new` | ShopTypeScreen | Yes | Add another shop |
| `/share` | ShareScreen | Yes | QR code + shareable link |
| `/help` | HelpScreen | Yes | FAQ + WhatsApp support |
| `/subscription` | SubscriptionScreen | Yes | Trial status + payment history |

---

## 5. Screen Catalog

### Auth & Onboarding
| Screen | File | Purpose |
|--------|------|---------|
| SplashScreen | `features/auth/screens/splash_screen.dart` | OTA check, auth redirect, language init |
| LanguageScreen | `features/auth/screens/language_screen.dart` | EN/ML selection; persists to SharedPreferences |
| GoogleSignInScreen | `features/auth/screens/google_signin_screen.dart` | Google OAuth; routes new vs existing users |
| LoginScreen | `features/auth/screens/login_screen.dart` | Phone number entry for OTP auth |
| OtpScreen | `features/auth/screens/otp_screen.dart` | 6-digit OTP verify; 60s countdown + resend |
| BusinessTypeScreen | `features/auth/screens/business_type_screen.dart` | Pick business category (shop/service/hotel etc.) |
| ListingFormScreen | `features/business/screens/listing_form_screen.dart` | Universal form for all business types |
| ShopTypeScreen | `features/onboarding/screens/shop_type_screen.dart` | Pick shop type (10 Kerala categories) |
| ShopDetailsScreen | `features/onboarding/screens/shop_details_screen.dart` | Name EN/ML, WhatsApp, address, district |
| BannerUploadScreen | `features/onboarding/screens/banner_upload_screen.dart` | Upload 16:9 banner image |
| DeliverySetupScreen | `features/onboarding/screens/delivery_setup_screen.dart` | Delivery type + min order |
| PaymentSetupScreen | `features/onboarding/screens/payment_setup_screen.dart` | Payment methods + UPI ID |
| SetupCompleteScreen | `features/onboarding/screens/setup_complete_screen.dart` | Onboarding done confirmation |

### Main Hub
| Screen | File | Purpose |
|--------|------|---------|
| BusinessHomeScreen | `features/business/screens/business_home_screen.dart` | 4-tab hub: Home, Web, Analytics, Settings |

**BusinessHomeScreen Home Tab contains:**
- Quick Actions row: Quick Bill / Udhar Book / Customers / Voice Order
- Recent orders with status filter chips (All / New / Pending / Done)
- Pull-to-refresh

**BusinessHomeScreen Settings Tab contains:**
- Shop Settings, Udhar Book, Customers, Share, Help, Subscription, Account Settings, Sign Out

### Orders
| Screen | File | Purpose |
|--------|------|---------|
| OrdersListScreen | `features/orders/screens/orders_list_screen.dart` | All orders; tabs: All/New/Confirmed/Processing/Ready/Delivered; Voice Order FAB |
| OrderDetailScreen | `features/orders/screens/order_detail_screen.dart` | Full order view; status action buttons; call/WhatsApp customer |
| VoiceOrderScreen | `features/orders/screens/voice_order_screen.dart` | Mic button; Malayalam/English speech to order items; create order |

### Products
| Screen | File | Purpose |
|--------|------|---------|
| ProductsListScreen | `features/products/screens/products_list_screen.dart` | Catalog with search, category filter, Low Stock filter chip; badges for expired/low stock; Stock Alerts button |
| AddProductScreen | `features/products/screens/add_product_screen.dart` | Create/edit product; barcode scan; 4 image sources; variants; stock; expiry; GST rate + HSN code |
| ImportProductsScreen | `features/products/screens/import_products_screen.dart` | Paste Google Sheets CSV or URL → bulk create products |
| StockAlertsScreen | `features/products/screens/stock_alerts_screen.dart` | All products below low-stock threshold; sorted by urgency; update stock dialog |

### Billing & Finance
| Screen | File | Purpose |
|--------|------|---------|
| BillingScreen | `features/billing/screens/billing_screen.dart` | POS: tap products → cart with GST breakdown → Cash/UPI/Udhar; barcode scan; GST receipt; auto WhatsApp send; Print button |
| BillHistoryScreen | `features/billing/screens/bill_history_screen.dart` | Browse past bills; Today/Week/Month/Custom date filter; search by customer; summary banner |
| BillDetailScreen | `features/billing/screens/bill_detail_screen.dart` | Full bill with GST breakdown; WhatsApp resend; Print (coming soon) |
| CreditsScreen | `features/credits/screens/credits_screen.dart` | Udhar book; outstanding total; WhatsApp reminder; mark paid; partial payment |
| AddCreditScreen | `features/credits/screens/add_credit_screen.dart` | Add new credit entry (name, phone, amount, note, due date) |

### Suppliers
| Screen | File | Purpose |
|--------|------|---------|
| SuppliersListScreen | `features/suppliers/screens/suppliers_list_screen.dart` | All suppliers; search; FAB to add |
| AddSupplierScreen | `features/suppliers/screens/add_supplier_screen.dart` | Add/edit supplier: name, phone, category tags, notes |
| SupplierDetailScreen | `features/suppliers/screens/supplier_detail_screen.dart` | Supplier info; Call button; WhatsApp button; edit; delete |

### Customers
| Screen | File | Purpose |
|--------|------|---------|
| CustomersScreen | `features/customers/screens/customers_screen.dart` | Customer list with total spent, last order, at-risk badge; win-back WhatsApp message |

### Analytics & Reports
| Screen | File | Purpose |
|--------|------|---------|
| AnalyticsScreen | `features/analytics/screens/analytics_screen.dart` | Today/week/month revenue + orders; completion rate; top 5 products; peak hours bar chart |

### Settings & Utility
| Screen | File | Purpose |
|--------|------|---------|
| ShopSettingsScreen | `features/settings/screens/shop_settings_screen.dart` | Edit all shop fields; GSTIN + GST business name; auto-send WhatsApp receipt toggle; theme; photos |
| AccountSettingsScreen | `features/settings/screens/account_settings_screen.dart` | Account-level settings |
| StaffManagementScreen | `features/settings/screens/staff_management_screen.dart` | Add/remove cashier and manager accounts by phone number |
| PrinterSettingsScreen | `features/settings/screens/printer_settings_screen.dart` | Bluetooth thermal printer pairing; device scan; test print |
| ManageShopsScreen | `features/shops/screens/manage_shops_screen.dart` | Multi-shop management (PLACEHOLDER — not implemented) |
| ShareScreen | `features/share/screens/share_screen.dart` | QR code + copy link + native share |
| HelpScreen | `features/help/screens/help_screen.dart` | FAQ accordion + WhatsApp support link |
| SubscriptionScreen | `features/subscription/screens/subscription_screen.dart` | Trial days remaining + payment history |
| WebsiteBuilderScreen | `features/website_builder/screens/website_builder_screen.dart` | WebView wrapper for external website builder |

### System
| Screen | File | Purpose |
|--------|------|---------|
| MaintenanceScreen | `features/update/maintenance_screen.dart` | Shown when Remote Config `maintenanceMode = true` |
| UpdateDialog | `features/update/update_dialog.dart` | Force/optional update prompt from Remote Config |

---

## 6. State Management (Providers)

### Auth
| Provider | Type | File |
|----------|------|------|
| `authProvider` | `NotifierProvider<AuthNotifier, AuthState>` | `providers/auth_provider.dart` |
| `authStateProvider` | `StreamProvider<User?>` | `providers/auth_provider.dart` |
| `googleAuthProvider` | `NotifierProvider<GoogleAuthNotifier, GoogleAuthState>` | `providers/google_auth_provider.dart` |
| `roleProvider` | (role notifier) | `providers/role_provider.dart` |

**AuthState statuses:** `initial | loading | otpSent | authenticated | unauthenticated | error`
**GoogleAuthState statuses:** `idle | loading | success | error`

### Shop
| Provider | Type | File |
|----------|------|------|
| `onboardingProvider` | `NotifierProvider<OnboardingNotifier, OnboardingState>` | `providers/shop_provider.dart` |
| `shopStreamProvider(shopId)` | `StreamProvider.family<ShopModel, String>` | `providers/shop_provider.dart` |
| `activeShopIdProvider` | `FutureProvider<String>` | `providers/shop_provider.dart` |

### Products
| Provider | Type | File |
|----------|------|------|
| `productsStreamProvider(shopId)` | `StreamProvider.family<List<ProductModel>, String>` | `providers/products_provider.dart` |
| `productByBarcodeProvider({shopId, barcode})` | `Provider.family<ProductModel?, ...>` | `providers/products_provider.dart` |
| `lowStockProductsProvider(shopId)` | `Provider.family<List<ProductModel>, String>` | `providers/products_provider.dart` |
| `ProductRepository` | Static class | `providers/products_provider.dart` |

**ProductRepository methods:** `add`, `update`, `delete`, `setHidden`, `setOutOfStock`, `getById`, `batchAdd`

### Orders
| Provider | Type | File |
|----------|------|------|
| `ordersStreamProvider(shopId)` | `StreamProvider.family<List<OrderModel>, String>` | `providers/orders_provider.dart` |
| `orderDetailProvider((shopId, orderId))` | `StreamProvider.family` | `providers/orders_provider.dart` |
| `activeShopIdForOrdersProvider` | `FutureProvider` | `providers/orders_provider.dart` |

**Top-level functions:** `updateOrderStatus(shopId, orderId, newStatus)` — also upserts customer doc when status = 'delivered'

### Billing
| Provider | Type | File |
|----------|------|------|
| `billingProvider` | `NotifierProvider<BillingNotifier, BillingState>` | `providers/billing_provider.dart` |
| `dailyBillsStreamProvider(shopId)` | `StreamProvider.family` | `providers/billing_provider.dart` |
| `dailySalesSummaryProvider(shopId)` | `Provider.family<Map<String,double>, String>` | `providers/billing_provider.dart` |
| `billHistoryProvider({shopId, range})` | `StreamProvider.family` | `providers/billing_provider.dart` |

**BillingNotifier methods:** `addItem`, `removeItem`, `updateQty`, `setDiscount`, `clearCart`, `saveBill`
**BillingState computed:** `gstBreakdown` (per-slab CGST/SGST map), `totalTax`
**saveBill** now: computes GST breakdown → saves bill → decrements product stockQty in batch

### Credits (Udhar)
| Provider | Type | File |
|----------|------|------|
| `creditsStreamProvider(shopId)` | `StreamProvider.family<List<CreditModel>, String>` | `providers/credits_provider.dart` |
| `allCreditsStreamProvider(shopId)` | `StreamProvider.family<List<CreditModel>, String>` | `providers/credits_provider.dart` |
| `CreditsRepository` | Static class | `providers/credits_provider.dart` |

**CreditsRepository methods:** `add`, `markPaid`, `recordPartialPayment`, `delete`

### Customers
| Provider | Type | File |
|----------|------|------|
| `customersStreamProvider(shopId)` | `StreamProvider.family<List<CustomerModel>, String>` | `providers/customers_provider.dart` |
| `atRiskCustomersProvider(shopId)` | `Provider.family<List<CustomerModel>, String>` | `providers/customers_provider.dart` |

### Language
| Provider | Type | File |
|----------|------|------|
| `languageProvider` | (language notifier) | `providers/language_provider.dart` |
| `translationsProvider` | (translations map) | `providers/language_provider.dart` |
| `initialLanguageProvider` | `FutureProvider` | `providers/language_provider.dart` |

---

## 7. Data Models

### UserModel (`models/user_model.dart`)
```
userId          String
phone           String
name            String
language        String          // 'en' | 'ml'
createdAt       DateTime
shopIds         List<String>
activeShopId    String
googleUid       String?
email           String?
role            String?         // always 'owner'
businessTypes   List<String>?
tcAccepted      bool?
trialUsed       bool?
```

### ShopModel (`models/shop_model.dart`)
```
shopId                   String
ownerId                  String
shopName                 String
shopNameMl               String
shopSlug                 String
shopType                 String      // grocery|vegetable|bakery|pharmacy|meat|stationery|textile|electronics|hotel|general
ownerPhone               String
ownerWhatsApp            String
address                  String
district                 String      // 14 Kerala districts
bannerImageUrl           String
logoUrl                  String
isOpen                   bool
isActive                 bool
linkActive               bool
deliveryType             String      // both|delivery|pickup
minOrderValue            double
paymentMethods           List<String>  // cash|upi|card
upiId                    String
categories               List<String>
trialStartDate           DateTime?
trialEndDate             DateTime?
subscriptionStatus       String      // trial|active|expired
lastPaymentDate          DateTime?
createdAt                DateTime
totalOrders              int
fcmToken                 String
themeColor               String?     // hex color for storefront
deliveryTimeEstimate     String?
promotionalBanner        String?
announcementText         String?
productLayout            String?     // grid|list
externalUrl              String?
gstin                    String?     // 15-char GST number (only if registered)
gstBusinessName          String?     // Business name as on GST certificate
autoSendWhatsappReceipt  bool        // default false — auto-open WhatsApp after billing
// Business directory fields (Phase 15.2):
serviceTypes, photos, workingHours, priceRange, about,
avgRating, ratingCount, isVerified, isFeatured
```

### ProductModel (`models/product_model.dart`)
```
productId           String
nameEn              String
nameMl              String
category            String
price               double
offerPrice          double
unit                String      // piece|kg|g|litre|ml|dozen|box|packet|bundle|set
minQty              double
imageUrl            String
imageSource         String      // auto|owner|placeholder
isHidden            bool
isOutOfStock        bool
hasVariants         bool
variants            List<VariantModel>
createdAt           DateTime
updatedAt           DateTime
orderCount          int
stockQty            int?        // null = not tracking stock; auto-decremented on each bill save
lowStockThreshold   int         // default 5
expiryDate          DateTime?   // null = no expiry
barcode             String?     // EAN/UPC barcode for scanner lookup
gstRate             int         // 0 | 5 | 12 | 18 | 28 (default 0)
hsnCode             String?     // HSN/SAC code (4–8 digits, optional)
priceIncludesGst    bool        // true = MRP already includes GST (default true)

// Computed getters:
isLowStock          → stockQty != null && stockQty <= lowStockThreshold
isExpiringSoon      → expiryDate within 2 days
isExpired           → expiryDate before today
```

### VariantModel (`models/variant_model.dart`)
```
variantId    String
name         String
price        double
offerPrice   double
```

### OrderModel (`models/order_model.dart`)
```
orderId           String
shopId            String
orderNumber       int
status            String    // new|confirmed|processing|ready|delivered|cancelled
customerName      String
customerPhone     String
customerLocation  String
deliveryType      String    // delivery|pickup
orderNote         String
items             List<OrderItemModel>
totalAmount       double
paymentMethod     String    // cash|upi|card
paymentStatus     String    // paid|pending
createdAt         DateTime
updatedAt         DateTime
```

**OrderItemModel:** `productId, productName, variantName, qty, unit, price, itemNote, subtotal`

**Status flow:** new → confirmed → processing → ready → delivered (or cancelled at any step)

### CreditModel (`models/credit_model.dart`)
```
creditId        String
customerName    String
customerPhone   String
amount          double      // total credit given
paidAmount      double      // amount collected so far (default 0)
note            String
status          String      // open|partial|paid
createdAt       DateTime
dueDate         DateTime?

// Computed getters:
outstanding  → amount - paidAmount
isOverdue    → dueDate before today && status != 'paid'
```

### BillModel (`models/bill_model.dart`)
```
billId           String
shopId           String
items            List<BillItemModel>
totalAmount      double
discountAmount   double
finalAmount      double      // totalAmount - discountAmount + totalTax (if priceExcludesGst)
paymentMethod    String      // cash|upi|udhar
customerName     String
customerPhone    String
isUdhar          bool        // if true, also creates credit entry
createdAt        DateTime
gstBreakdown     Map<String, Map<String, double>>  // e.g. {"5": {"taxableAmount":100,"cgst":2.5,"sgst":2.5}}
totalTax         double      // sum of all CGST + SGST
gstinSnapshot    String?     // shop GSTIN at time of billing
```

**BillItemModel:** `productId, productName, qty, unit, price, subtotal, gstRate, hsnCode, priceIncludesGst`

### SupplierModel (`models/supplier_model.dart`)
```
supplierId   String
name         String
phone        String
categories   List<String>   // Grocery|Dairy|Bakery|Meat|Vegetables|Beverages|Household|Other
notes        String
createdAt    DateTime
```

### CustomerModel (`models/customer_model.dart`)
```
customerId      String      // customerPhone used as document ID
name            String
phone           String
totalOrders     int
totalSpent      double
lastOrderDate   DateTime
firstOrderDate  DateTime

// Computed getters:
isAtRisk  → lastOrderDate > 21 days ago
tag       → 'At Risk' | 'Regular' (10+ orders) | 'New'
```

---

## 8. Firestore Database Schema

```
users/
  {userId}/
    userId, phone, name, language, shopIds[], activeShopId,
    googleUid, email, role, businessTypes[], tcAccepted, trialUsed, createdAt

shops/
  {shopId}/
    [all ShopModel fields]

    products/
      {productId}/
        [all ProductModel fields]

    orders/
      {orderId}/
        [all OrderModel fields]

    bills/
      {billId}/
        [all BillModel fields]

    credits/
      {creditId}/
        [all CreditModel fields]

    customers/
      {customerPhone}/   ← customerPhone used as document ID
        [all CustomerModel fields]

    staff/
      {userId}/
        phone, role (cashier|manager), addedAt

    suppliers/
      {supplierId}/
        [all SupplierModel fields]

# Business directory collections (separate from shops):
services/{id}/...
theaters/{id}/...
hotels/{id}/...
restaurants/{id}/...
beauty/{id}/...
```

---

## 9. Firebase Services

| Service | Usage |
|---------|-------|
| **Firebase Auth** | Phone OTP + Google Sign-In |
| **Firestore** | All app data (real-time streams) |
| **Storage** | Product images, banners, logos |
| **FCM** | Push notifications for new orders |
| **Remote Config** | OTA updates: `appVersion`, `forceUpdate`, `maintenanceMode`, `maintenanceMessage` |
| **Hosting** | Customer PWA storefront + admin panel |

**Firebase project:** `shoplink-prod` (project number: 482080959600)
**Android app ID:** `1:482080959600:android:25b5b83610dea37d8398b5`
**SHA-1 registered:** `3e9d0bc8e07d14db69e3a3bc7ada4829e838ce6b` (debug keystore)

---

## 10. File Structure

```
wekerala_app/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── firebase_options.dart
│   │
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_colors.dart       # Color palette
│   │   │   ├── app_config.dart       # App version, URLs
│   │   │   └── app_strings.dart
│   │   ├── router/
│   │   │   └── app_router.dart       # GoRouter config (28 routes)
│   │   ├── services/
│   │   │   ├── fcm_service.dart             # Push notification setup
│   │   │   ├── local_notification_service.dart  # 9 PM daily sales notification
│   │   │   ├── connectivity_service.dart    # Online/offline stream (connectivity_plus)
│   │   │   ├── print_service.dart           # Bluetooth ESC/POS thermal printer
│   │   │   ├── sales_summary_service.dart   # Daily sales summary for WhatsApp
│   │   │   ├── ota_service.dart             # Remote Config update check
│   │   │   └── storage_service.dart         # Firebase Storage upload
│   │   ├── theme/
│   │   │   └── app_theme.dart
│   │   └── utils/
│   │       ├── image_matcher.dart    # Auto-match product images
│   │       ├── sheets_parser.dart    # Parse Google Sheets CSV
│   │       ├── slug_generator.dart   # Generate shop URL slugs
│   │       └── validators.dart
│   │
│   ├── models/
│   │   ├── bill_model.dart        # + gstBreakdown, totalTax, gstinSnapshot; BillItemModel + gstRate, hsnCode
│   │   ├── credit_model.dart
│   │   ├── customer_model.dart
│   │   ├── order_model.dart
│   │   ├── product_model.dart     # + barcode, gstRate, hsnCode, priceIncludesGst
│   │   ├── shop_model.dart        # + gstin, gstBusinessName, autoSendWhatsappReceipt
│   │   ├── supplier_model.dart    # NEW — supplier directory
│   │   ├── user_model.dart
│   │   └── variant_model.dart
│   │
│   ├── providers/
│   │   ├── auth_provider.dart
│   │   ├── billing_provider.dart    # + dailySalesSummaryProvider, billHistoryProvider, GST compute, stock decrement
│   │   ├── credits_provider.dart
│   │   ├── customers_provider.dart
│   │   ├── google_auth_provider.dart
│   │   ├── language_provider.dart
│   │   ├── orders_provider.dart
│   │   ├── products_provider.dart   # + productByBarcodeProvider, lowStockProductsProvider
│   │   ├── role_provider.dart       # + staffRoleProvider, isCashierProvider, kRoleOwner/Cashier/Manager
│   │   ├── shop_provider.dart
│   │   └── suppliers_provider.dart  # NEW — suppliersStreamProvider, SuppliersRepository
│   │
│   ├── shared/
│   │   └── widgets/
│   │       ├── app_button.dart
│   │       ├── app_text_field.dart
│   │       ├── loading_overlay.dart
│   │       └── shimmer_list.dart
│   │
│   └── features/
│       ├── analytics/screens/analytics_screen.dart
│       ├── auth/screens/
│       │   ├── splash_screen.dart
│       │   ├── language_screen.dart
│       │   ├── google_signin_screen.dart
│       │   ├── login_screen.dart
│       │   ├── otp_screen.dart
│       │   └── business_type_screen.dart
│       ├── billing/screens/
│       │   ├── billing_screen.dart       # POS billing + GST + barcode + print
│       │   ├── bill_history_screen.dart  # Past bills with date filter
│       │   └── bill_detail_screen.dart   # Full bill view + WhatsApp resend
│       ├── business/screens/
│       │   ├── business_home_screen.dart             # Main hub
│       │   └── listing_form_screen.dart
│       ├── credits/screens/
│       │   ├── credits_screen.dart                   # Udhar book
│       │   └── add_credit_screen.dart
│       ├── customers/screens/customers_screen.dart   # Win-back
│       ├── help/screens/help_screen.dart
│       ├── onboarding/screens/
│       │   ├── shop_type_screen.dart
│       │   ├── shop_details_screen.dart
│       │   ├── banner_upload_screen.dart
│       │   ├── delivery_setup_screen.dart
│       │   ├── payment_setup_screen.dart
│       │   └── setup_complete_screen.dart
│       ├── orders/screens/
│       │   ├── orders_list_screen.dart
│       │   ├── order_detail_screen.dart
│       │   └── voice_order_screen.dart               # Malayalam speech to order
│       ├── products/screens/
│       │   ├── products_list_screen.dart    # + Stock Alerts button in AppBar
│       │   ├── add_product_screen.dart      # + GST rate picker, HSN code, priceIncludesGst toggle
│       │   ├── import_products_screen.dart
│       │   └── stock_alerts_screen.dart     # NEW — low-stock list with update dialog
│       ├── settings/screens/
│       │   ├── shop_settings_screen.dart          # + GSTIN, auto-send WhatsApp, Printer Setup tile, Staff tile
│       │   ├── account_settings_screen.dart
│       │   ├── staff_management_screen.dart        # NEW — cashier/manager accounts
│       │   └── printer_settings_screen.dart        # NEW — Bluetooth thermal printer pairing
│       ├── suppliers/screens/
│       │   ├── suppliers_list_screen.dart          # NEW
│       │   ├── add_supplier_screen.dart            # NEW
│       │   └── supplier_detail_screen.dart         # NEW
│       ├── share/screens/share_screen.dart
│       ├── shops/screens/manage_shops_screen.dart    # PLACEHOLDER
│       ├── subscription/screens/subscription_screen.dart
│       ├── update/
│       │   ├── maintenance_screen.dart
│       │   └── update_dialog.dart
│       └── website_builder/screens/website_builder_screen.dart
│
├── assets/
│   └── translations/
│       ├── en.json
│       └── ml.json
│
├── android/
│   └── app/
│       ├── google-services.json      # Firebase config (com.wekerala.app)
│       ├── build.gradle.kts          # minSdk=23, targetSdk=34
│       └── src/main/
│           ├── AndroidManifest.xml
│           └── kotlin/com/wekerala/app/MainActivity.kt
│
├── _waste/                           # Archived — safe to delete
│   ├── _archived/                    # Old customer-facing screens
│   │   ├── auth/role_selection_screen.dart
│   │   ├── customer/screens/         # 7 customer screens
│   │   └── onboarding/service_tags_screen.dart
│   ├── platforms/                    # Unused platforms
│   │   ├── linux/
│   │   ├── macos/
│   │   └── windows/
│   └── generate_all.js               # Old codegen utility
│
├── admin/                            # Vanilla JS admin web panel
├── storefront/                       # Vanilla JS customer PWA
├── .github/workflows/                # CI/CD pipelines (5 workflows)
├── analysis_options.yaml
├── CLAUDE.md                         # Dev guidelines for Claude Code
├── STRUCTURE.md                      # This file
├── firebase.json
├── firestore.rules
├── firestore.indexes.json
├── storage.rules
├── pubspec.yaml
└── Makefile
```

---

## 11. App Color Palette

```dart
primary       = #283618  // Dark forest green (AppBar, buttons, FABs)
primaryLight  = #3D5226  // Lighter green
accent        = #DDA15E  // Warm orange (Udhar, highlights)
background    = #FEFAE0  // Warm cream (Scaffold background)
surface       = #ECE6C2  // Deeper cream (cards, inputs)
textPrimary   = #1A1A0E  // Near-black warm
textSecondary = #A8A08A  // Muted warm grey
error         = #D32F2F  // Red
success       = #43A047  // Green
```

---

## 12. Features Status

| Feature | Status | Notes |
|---------|--------|-------|
| Google Sign-In | ✅ Working | Fixed: registered `com.wekerala.app` in Firebase |
| Phone OTP Auth | ✅ Working | Legacy / optional path |
| Shop Onboarding (5 steps) | ✅ Working | Type → Details → Banner → Delivery → Payment |
| Product CRUD | ✅ Working | Variants, barcode scan, auto-image, GST rate, HSN code |
| Bulk Product Import | ✅ Working | Google Sheets CSV |
| Orders (real-time) | ✅ Working | Status flow + WhatsApp customer |
| Voice Orders (Malayalam) | ✅ Working | speech_to_text 7.x |
| Quick Billing / POS | ✅ Working | Cash/UPI/Udhar; GST breakdown; barcode scan; WhatsApp receipt; Print |
| GST Billing (P1) | ✅ Built | CGST/SGST per slab; HSN codes; GSTIN on receipts; legally compliant format |
| Thermal Printer (P2) | ✅ Built | Bluetooth ESC/POS; PrintService; printer settings screen; Print button in receipt |
| Bill History (P3) | ✅ Built | Date filter (Today/Week/Month/Custom); search; reprint; WhatsApp resend |
| Barcode in Billing (P4) | ✅ Built | Scan barcode → auto-add product to cart |
| Offline Mode (P5) | ✅ Built | Firestore offline cache enabled; ConnectivityService; bills sync on reconnect |
| WhatsApp Receipt (P6) | ✅ Built | Auto-send toggle in settings; Malayalam footer "നന്ദി! വീണ്ടും വരൂ 🙏" |
| Daily Sales Summary (P7) | ✅ Built | 9 PM notification; WhatsApp summary button in analytics; SalesSummaryService |
| Staff Login (P8) | ✅ Built | Owner/Cashier/Manager roles; cashier sees only Billing + Orders tabs |
| Stock Tracking in Billing (P9) | ✅ Built | stockQty auto-decremented on bill save; low-stock alerts screen |
| Supplier Management (P10) | ✅ Built | Full CRUD; call/WhatsApp buttons; linked to shop subcollection |
| Udhar (Credit) Tracker | ✅ Working | Outstanding total; WhatsApp reminder; partial pay |
| Customer Database | ✅ Working | Auto-built from delivered orders |
| Customer Win-Back | ✅ Working | At-risk = no order in 21 days; WhatsApp message |
| Low Stock Alerts | ✅ Working | Badge on product list + dedicated alerts screen with update dialog |
| Expiry Date Tracking | ✅ Working | expiryDate field; badge 2 days before |
| Analytics Dashboard | ✅ Working | Today/week/month; top products; peak hours; WhatsApp daily summary |
| QR Share | ✅ Working | Shop link + QR code |
| Push Notifications | ✅ Working | FCM for new orders |
| OTA Updates | ✅ Working | Remote Config version check |
| Multi-language (EN/ML) | ✅ Working | JSON translations |
| Shop Settings | ✅ Working | Theme, banner, photos, GSTIN, auto-WhatsApp receipt toggle |
| Desktop / Windows POS | ✅ Built | Responsive layout (NavigationRail sidebar ≥700px); side-by-side billing POS |
| Multi-shop Management | ⚠️ Placeholder | `/shops` screen shows "Phase 2" |
| Account Settings | ⚠️ Minimal | Screen exists but sparse |
| Subscription / Payments | ⚠️ UI only | No payment gateway integrated |

---

## 13. Known Bugs / Tech Debt

1. **ManageShopsScreen** — Shows placeholder text. Multi-shop switching not implemented.
2. **Voice Order parser** — Simple regex; doesn't match against real product names from shop inventory (just freeform text).
3. **BillingScreen → Udhar path** — Creates a credit entry but does NOT automatically populate CustomerModel. Manual link needed.
4. **Account Settings** — Screen exists but mostly empty.
5. **Subscription screen** — Shows trial UI but no Razorpay/payment integration.
6. **Barcode field in add_product_screen** — `_BarcodeScannerPage` exists but scanned value is not saved to `product.barcode` yet. ProductModel has the field; UI wiring still needed.
7. **Thermal printer (P2)** — Requires physical Android device + Bluetooth thermal printer to test. Not testable on emulator.
8. **Bill detail screen** — `taxable` value from gstBreakdown map uses key `'taxable'`; verify key matches what billing_provider writes (may be `'taxableAmount'`).
9. **Staff role guard** — `isCashierProvider` uses `FutureProvider` (not stream); role changes require app restart to take effect.

---

## 14. Environment Variables (`.env`)

```
UNSPLASH_ACCESS_KEY=...       # Auto product image lookup
GOOGLE_SHEETS_API_KEY=...     # Bulk product import
SHOPLINK_UPI_ID=...           # Platform UPI for payments
SUPPORT_WHATSAPP=...          # Help screen WhatsApp number
STOREFRONT_BASE_URL=...       # Base URL for customer storefront
```

---

## 15. Build & Deploy

```bash
# Install dependencies
flutter pub get

# Analyze for errors
flutter analyze --no-pub

# Build debug APK (for testing)
flutter build apk --debug

# Build release APK
flutter build apk --release

# Install on connected device via ADB (PowerShell)
$adb = 'C:\Users\DELL\AppData\Local\Android\Sdk\platform-tools\adb.exe'
& $adb install -r 'build\app\outputs\flutter-apk\app-debug.apk'

# Deploy Firebase rules
firebase deploy --only firestore:rules,storage --project shoplink-prod

# Deploy storefront
firebase deploy --only hosting --project shoplink-prod
```

**GitHub Actions (auto on push to main):**
- `build-apk.yml` — Builds release APK
- `deploy-storefront.yml` — Deploys customer PWA
- `deploy-rules.yml` — Deploys Firestore + Storage rules
- `deploy_admin.yml` — Deploys admin panel
- `test.yml` — Runs Flutter tests

---

## 16. Adding a New Feature — Checklist

1. Create model in `lib/models/`
2. Create provider in `lib/providers/`
3. Create screen(s) in `lib/features/{feature}/screens/`
4. Add route in `lib/core/router/app_router.dart`
5. Add navigation entry in `business_home_screen.dart` (Settings tab or Home quick actions)
6. Add translations to `assets/translations/en.json` + `ml.json`
7. Add Firestore schema to this document
8. Build APK + test on phone
