# wekerala — Master Project Document
> Last Updated: 2026-05-02 | Owner: anshad5023@gmail.com | Brand: wekerala (was ShopLink)
> **This is the single source of truth. Read this before touching any code.**

Kerala local business directory + hosted shop storefront platform.

---

## TECH STACK

| Layer | Technology |
|---|---|
| Mobile app | Flutter (Android only, Dart) |
| State management | Riverpod 2.x + riverpod_annotation |
| Navigation | GoRouter 14.x |
| Web frontend | Next.js 16, React, TypeScript |
| Web styling | Tailwind CSS 4, shadcn/ui |
| Web state | Zustand |
| Backend / DB | Firebase Firestore (REST + SDK) |
| Auth | Firebase Auth — Phone OTP (owners), Google Sign-In (business owners) |
| Storage | Firebase Storage |
| Hosting | Vercel (Next.js web) |
| Fonts | Poppins (UI), Caveat (headings), JetBrains Mono (labels) |

---

## LIVE URLS

| What | URL |
|---|---|
| Web app | https://web-phi-puce-84.vercel.app |
| Demo shop | https://web-phi-puce-84.vercel.app?shopId=dEYgPmls3Occ3APLnxKt |
| Firebase project | shoplink-prod |
| Firebase console | https://console.firebase.google.com/project/shoplink-prod |

---

## CREDENTIALS & ENV

### Flutter `.env` (shoplink_app/.env)
```
STOREFRONT_BASE_URL=https://web-phi-puce-84.vercel.app
ADMIN_URL=https://shoplink-prod-admin.web.app
APP_VERSION=1.0.0
APK_STORAGE_PATH=apk/shoplink-latest.apk
USE_FIREBASE_EMULATOR=false
DEBUG_MODE=true
```

### Firebase
```
Project ID:  shoplink-prod
API key:     AIzaSyCFB9YZL3_bXjvRMoWaYFv8nTs_ote52GQ
Debug SHA-1: 3E:9D:0B:C8:E0:7D:14:DB:69:E3:A3:BC:7A:DA:48:29:E8:38:CE:6B (registered ✅)
```

### Vercel env vars needed
```
ADMIN_PASSWORD           ← admin panel password
NEXT_PUBLIC_FIREBASE_PROJECT_ID=shoplink-prod
NEXT_PUBLIC_FIREBASE_API_KEY=AIzaSyCFB9YZL3_bXjvRMoWaYFv8nTs_ote52GQ
NEXT_PUBLIC_BASE_URL=https://web-phi-puce-84.vercel.app
```
> NOTE: FIREBASE_SERVICE_ACCOUNT is NO LONGER NEEDED. Publish now uses Firestore REST PATCH.

---

## KEY COMMANDS

```bash
# Flutter — run on connected phone
cd shoplink_app
flutter run --dart-define-from-file=.env

# Flutter — build release APK (~14MB, NOT debug)
flutter build apk --release --dart-define-from-file=.env

# Web — deploy to Vercel
cd web && vercel --prod

# Firestore rules — deploy
firebase deploy --only firestore:rules --project shoplink-prod
```

---

## PHASES STATUS

| Phase | What | Status |
|---|---|---|
| 1 | Auth (Phone OTP, Google Sign-In, role selection) | ✅ Done |
| 2 | Onboarding (shop setup wizard) | ✅ Done |
| 3 | Product management (add/edit/hide/stock) | ✅ Done |
| 4 | Customer storefront (PWA) | ✅ Done |
| 5 | Orders + notifications | ✅ Done |
| 6 | Analytics, Share, Help | ✅ Done |
| 7 | OTA updates + admin panel | ✅ Done |
| 8 | Polish + pilot | ✅ Done |
| 9 | Investor upgrade — marketplace, admin panel v2 | ✅ Done |
| 10 | wekerala website design — 7 screens, wk components | ✅ Done |
| 11 | Role split, Google Sign-In, business listings, customer browse | ✅ Done |
| 12 | Owner dashboard web + Flutter BusinessHomeScreen 3-tab rewrite | ✅ Done |
| 13 | Website Builder — 3 themes, custom HTML, /sites/{shopId}, admin unpublish | ✅ Done |
| 14 | Bug fixes (activeShopId sync, publish API, WebView errors, back/browse buttons) | ✅ Done 2026-05-02 |
| 15 | Bug fixes + features (FCM, /shopname, WhatsApp orders, cart fix, analytics tab) | ✅ Done 2026-05-05 |
| 16 | Business type-specific schemas (services/theaters/hotels/restaurants/beauty) | ✅ Done |
| 16B | Website builder redesign — 10 themes, 4-tab builder, GA/Pixel/Tawk plugins | ✅ Done 2026-05-08 |
| 17 | Customer features (login, order history, saved addresses) | ⏳ Next |
| 18 | Owner dashboard upgrades (coupons, bulk edit, inventory) | ⏳ Planned |
| 19 | Monetization (subscription plans, Razorpay) | ⏳ Planned |

---

## COMPLETE FOLDER STRUCTURE

```
shoplink/
├── SHOPLINK_MASTER_DOC.md          ← THIS FILE — single source of truth
├── FEATURE_QUESTIONS.md            ← 140 feature planning questions (answer before Phase 15)
├── firestore.rules                 ← Firestore security rules (deploy with firebase CLI)
├── shoplink_project/               ← Old project templates (mostly empty now)
│
├── shoplink_app/                   ← Flutter Android app
│   ├── .env                        ← Local env vars (never commit)
│   ├── pubspec.yaml                ← All Flutter dependencies
│   ├── CLAUDE.md                   ← Claude Code session instructions (auto-read)
│   ├── lib/
│   │   ├── main.dart               ← App entry point, Firebase init, ProviderScope
│   │   ├── core/
│   │   │   ├── constants/
│   │   │   │   ├── app_colors.dart         ← ALL colors (primary=#283618, accent=#dda15e, bg=#fefae0)
│   │   │   │   ├── app_config.dart         ← Reads .env via flutter_dotenv (storefrontBaseUrl, etc.)
│   │   │   │   └── app_strings.dart        ← Static strings (non-translated)
│   │   │   ├── router/
│   │   │   │   └── app_router.dart         ← ALL GoRouter routes — see ROUTES section below
│   │   │   ├── services/
│   │   │   │   ├── storage_service.dart    ← Firebase Storage upload (banners, product images)
│   │   │   │   └── ota_update_service.dart ← OTA APK update check from Firebase Storage
│   │   │   ├── theme/
│   │   │   │   └── app_theme.dart          ← MaterialTheme config, fonts (Poppins via google_fonts)
│   │   │   └── utils/
│   │   │       ├── validators.dart         ← Form validation (phone, name, etc.)
│   │   │       ├── slug_generator.dart     ← Firestore-unique URL slugs for shops
│   │   │       ├── sheets_parser.dart      ← Parses Google Sheets CSV for product import
│   │   │       └── image_matcher.dart      ← Unsplash API image search by product name
│   │   │
│   │   ├── models/
│   │   │   ├── shop_model.dart             ← ShopModel: all shop fields + toFirestore/fromFirestore
│   │   │   ├── product_model.dart          ← ProductModel: name, price, unit, category, images, stock
│   │   │   ├── order_model.dart            ← OrderModel: items, status, timestamps, delivery
│   │   │   └── user_model.dart             ← UserModel: uid, role, businessTypes[], shopIds[]
│   │   │
│   │   ├── providers/
│   │   │   ├── auth_provider.dart          ← authStateProvider: Stream<User?> from Firebase Auth
│   │   │   ├── role_provider.dart          ← roleProvider: 'customer'|'business' stored in SharedPreferences
│   │   │   ├── language_provider.dart      ← languageProvider: 'en'|'ml' + tr() translation helper
│   │   │   ├── shop_provider.dart          ← onboardingProvider (shop creation wizard state)
│   │   │   │                                  shopStreamProvider(shopId) → real-time shop data
│   │   │   │                                  activeShopIdProvider → reads activeShopId from users/{uid}
│   │   │   └── products_provider.dart      ← productsStreamProvider(shopId) → real-time product list
│   │   │                                      ProductRepository: setHidden(), setOutOfStock(), delete()
│   │   │
│   │   ├── shared/
│   │   │   └── widgets/
│   │   │       ├── app_button.dart         ← Reusable primary button with loading state
│   │   │       ├── shimmer_list.dart       ← Shimmer loading placeholder for lists
│   │   │       └── no_internet_widget.dart ← No internet error widget with retry callback
│   │   │
│   │   └── features/
│   │       │
│   │       ├── auth/screens/
│   │       │   ├── splash_screen.dart          ← Logo + checks auth → routes to correct screen
│   │       │   ├── language_screen.dart         ← EN/ML picker → saves to SharedPreferences → /role-select
│   │       │   ├── role_selection_screen.dart   ← "I'm a Customer" / "I own a business" buttons
│   │       │   ├── login_screen.dart            ← Phone number input → sends OTP → /verify
│   │       │   ├── otp_screen.dart              ← 6-digit OTP input → verifies with Firebase
│   │       │   ├── google_signin_screen.dart    ← Google Sign-In button for business owners
│   │       │   └── business_type_screen.dart   ← Select: Shop / Service / Theater / Hotel / etc.
│   │       │
│   │       ├── onboarding/screens/
│   │       │   ├── shop_type_screen.dart        ← Select shop category (Grocery, Pharmacy, etc.)
│   │       │   ├── shop_details_screen.dart     ← Name, address, district, phone number
│   │       │   ├── banner_upload_screen.dart    ← Upload banner image (image_picker + Firebase Storage)
│   │       │   ├── delivery_setup_screen.dart   ← Delivery type (pickup/delivery/both) + min order
│   │       │   ├── payment_setup_screen.dart    ← Payment methods (cash/UPI/card) + UPI ID
│   │       │   └── setup_complete_screen.dart   ← Success screen → /business/home
│   │       │
│   │       ├── business/screens/
│   │       │   ├── listing_form_screen.dart     ← Form for non-shop businesses (service/hotel/etc.)
│   │       │   └── business_home_screen.dart    ← Main owner dashboard — 3-tab bottom nav:
│   │       │                                        Tab 0 (Home): last 20 orders (shops) or listing card
│   │       │                                        Tab 1 (Web): Add Products, Copy/Share URL, WebView preview
│   │       │                                        Tab 2 (Settings): all settings + sign out
│   │       │                                       AppBar: ← back | Shop Name ▾ | 🌐 browse
│   │       │
│   │       ├── website_builder/screens/
│   │       │   └── website_builder_screen.dart  ← Full-screen WebView → /control/website?shopId=X&uid=Y
│   │       │                                        Has error handling + Retry button (fixed Phase 14)
│   │       │
│   │       ├── customer/screens/
│   │       │   ├── customer_home_screen.dart    ← Category grid (shops/services/theaters/etc.)
│   │       │   ├── customer_listings_screen.dart← List of businesses by category with search
│   │       │   └── customer_business_screen.dart← WebView for shop storefront URL
│   │       │
│   │       ├── orders/screens/
│   │       │   ├── orders_list_screen.dart      ← Real-time orders list with status color badges
│   │       │   └── order_detail_screen.dart     ← Single order: items, customer, status update buttons
│   │       │
│   │       ├── products/screens/
│   │       │   ├── products_list_screen.dart    ← Search/filter products, toggle hidden/stock, tap to edit
│   │       │   ├── add_product_screen.dart      ← Add or edit product (name EN/ML, price, image, category)
│   │       │   └── import_products_screen.dart  ← Import from Google Sheets CSV URL
│   │       │
│   │       ├── analytics/screens/
│   │       │   └── analytics_screen.dart        ← Order stats, revenue chart (fl_chart), top products, peak hours
│   │       │
│   │       ├── settings/screens/
│   │       │   ├── shop_settings_screen.dart    ← Edit shop details, delivery, payments, external website URL
│   │       │   └── account_settings_screen.dart ← Edit profile, phone number
│   │       │
│   │       ├── share/screens/
│   │       │   └── share_screen.dart            ← QR code (qr_flutter), copy link, share via share_plus
│   │       │
│   │       ├── help/screens/
│   │       │   └── help_screen.dart             ← FAQ, contact support WhatsApp link
│   │       │
│   │       ├── subscription/screens/
│   │       │   └── subscription_screen.dart     ← Plans UI (not yet wired to payments)
│   │       │
│   │       ├── shops/screens/
│   │       │   └── manage_shops_screen.dart     ← Manage multiple shop accounts
│   │       │
│   │       └── update/
│   │           └── (OTA update check logic)
│   │
│   └── android/app/
│       ├── build.gradle.kts        ← targetSdk=34, minSdk=23, minifyEnabled=true (Phase 14)
│       ├── proguard-rules.pro      ← Flutter + Firebase ProGuard rules
│       ├── google-services.json    ← Firebase Android config
│       └── src/main/res/values-v35/styles.xml ← windowOptOutEdgeToEdgeEnforcement=true
│
└── web/                            ← Next.js 16 storefront + wekerala discovery
    ├── package.json
    ├── next.config.ts
    ├── tailwind.config.ts
    ├── app/
    │   ├── layout.tsx              ← Root layout, global fonts, metadata
    │   ├── page.tsx                ← wekerala home — category tiles, search, featured shops
    │   ├── shop/page.tsx           ← Single shop storefront (legacy, redirects to /sites/)
    │   ├── shops/page.tsx          ← Browse all shops with filters
    │   ├── services/page.tsx       ← Browse services
    │   ├── theaters/page.tsx       ← Browse theaters
    │   ├── hotels/page.tsx         ← Browse hotels
    │   ├── restaurants/page.tsx    ← Browse restaurants
    │   ├── beauty/page.tsx         ← Browse beauty salons
    │   ├── sites/[shopId]/page.tsx ← Published business website renderer (server component)
    │   │                              Reads Firestore REST → renders theme or "Coming Soon"
    │   ├── [slug]/page.tsx         ← Shop by slug (e.g. /antonyskitchen)
    │   ├── admin/page.tsx          ← Admin panel (password gated)
    │   │                              Sections: Shops (approve/block), Websites (unpublish)
    │   ├── control/
    │   │   ├── page.tsx            ← Owner dashboard: Orders tab, Products tab, Website tab
    │   │   └── website/page.tsx    ← Website builder wizard (3 steps: theme → edit → publish)
    │   └── api/
    │       ├── shop/route.ts       ← GET /api/shop?shopId=X — returns shop data
    │       ├── shops/route.ts      ← GET /api/shops?collection=shops&district=X — list with filters
    │       ├── listings/route.ts   ← GET /api/listings?collection=services — non-shop businesses
    │       ├── orders/route.ts     ← GET /api/orders?shopId=X — order list for owner
    │       ├── my-listings/route.ts← GET /api/my-listings?uid=X — owner's all listings
    │       ├── products/route.ts   ← GET /api/products?shopId=X — product list
    │       ├── sheets-import/route.ts ← POST — import products from Google Sheets
    │       ├── order-status/route.ts  ← PATCH — update order status (confirm/deliver/cancel)
    │       ├── analytics/route.ts  ← GET /api/analytics?shopId=X — order stats
    │       ├── register/route.ts   ← POST — register new business listing
    │       ├── website/route.ts    ← GET: shop config for builder
    │       │                          POST: publish website via Firestore REST PATCH (no firebase-admin needed)
    │       └── admin/shops/route.ts← PATCH /api/admin/shops — approve/block/unpublish
    │
    ├── components/
    │   ├── shop/                   ← Shop storefront components (FloatingCartBar, ProductGrid, Header)
    │   ├── wk/                     ← wekerala UI components (WkNav, WkHero, WkCard, WkFooter)
    │   ├── marketplace/            ← Marketplace components (ShopCard, CategoryTile, SearchBar)
    │   ├── ui/                     ← shadcn/ui components (Button, Input, Card, Label, Switch, Textarea)
    │   └── themes/
    │       ├── ModernTheme.tsx     ← White/minimal theme for /sites/[shopId]
    │       ├── BoldTheme.tsx       ← Dark #1a1a2e theme
    │       └── TraditionalTheme.tsx← Kerala cream theme
    │
    └── lib/
        ├── auth-store.ts           ← Zustand: uid + phone (set from URL params in website builder)
        ├── cart-store.ts           ← Zustand: cart items, total, shopId
        ├── filter-store.ts         ← Zustand: category/district filters for listings
        ├── firebase.ts             ← Firebase client SDK init (for customer storefront)
        ├── firebase-admin.ts       ← firebase-admin init (used only in admin unpublish route)
        ├── firestore-rest.ts       ← Firestore REST API helpers (parseValue, parseFields, etc.)
        ├── products.ts             ← Product fetch helpers
        ├── translations.ts         ← EN/ML translation strings for web
        └── wk-constants.ts         ← wekerala design tokens, category list, district list
```

---

## ALL FLUTTER ROUTES

| Route | Screen | Auth Required | Notes |
|---|---|---|---|
| `/splash` | SplashScreen | No | Checks auth → redirects |
| `/language` | LanguageScreen | No | EN/ML picker |
| `/role-select` | RoleSelectionScreen | No | Customer or Business |
| `/login` | LoginScreen | No | Phone OTP |
| `/verify` | OtpScreen | No | extra: phoneNumber |
| `/google-signin` | GoogleSignInScreen | No | Business owner flow |
| `/business/type` | BusinessTypeScreen | No | Shop/Service/Theater/etc. |
| `/business/listing-form` | ListingFormScreen | No | Non-shop form |
| `/business/home` | BusinessHomeScreen | No (Google auth) | Main owner dashboard |
| `/website-builder` | WebsiteBuilderScreen | No | extra: url string |
| `/customer/home` | CustomerHomeScreen | No | Category browse |
| `/customer/listings/:collection` | CustomerListingsScreen | No | param: collection |
| `/customer/business` | CustomerBusinessScreen | No | extra: {url, name} |
| `/onboard/type` | ShopTypeScreen | Phone auth | Shop category |
| `/onboard/details` | ShopDetailsScreen | Phone auth | Shop info form |
| `/onboard/banner` | BannerUploadScreen | Phone auth | Banner image |
| `/onboard/delivery` | DeliverySetupScreen | Phone auth | Delivery config |
| `/onboard/payment` | PaymentSetupScreen | Phone auth | Payment config |
| `/onboard/done` | SetupCompleteScreen | Phone auth | Success |
| `/orders` | OrdersListScreen | Phone auth | All orders |
| `/orders/:id` | OrderDetailScreen | Phone auth | param: orderId |
| `/products` | ProductsListScreen | Phone auth | Uses activeShopIdProvider |
| `/products/add` | AddProductScreen | Phone auth | Add new product |
| `/products/import` | ImportProductsScreen | Phone auth | Google Sheets import |
| `/products/:id` | AddProductScreen | Phone auth | Edit existing product |
| `/analytics` | AnalyticsScreen | Phone auth | Uses activeShopIdProvider |
| `/settings/shop` | ShopSettingsScreen | Phone auth | Uses activeShopIdProvider |
| `/settings/account` | AccountSettingsScreen | Phone auth | |
| `/shops` | ManageShopsScreen | Phone auth | Multiple shops |
| `/share` | ShareScreen | Phone auth | QR + link sharing |
| `/help` | HelpScreen | Phone auth | FAQ |
| `/subscription` | SubscriptionScreen | Phone auth | Plans (not wired yet) |

---

## FIRESTORE DATA MODELS

### `users/{uid}`
```
{
  uid: string
  role: 'customer' | 'business'
  googleUid: string           ← from Google Sign-In
  businessTypes: string[]     ← ['shops', 'services', ...]
  shopIds: string[]           ← IDs in 'shops' collection
  activeShopId: string        ← currently selected shop (synced by BusinessHomeScreen)
  trialUsed: boolean
  createdAt: Timestamp
}
```

### `shops/{shopId}`
```
{
  shopId: string
  ownerId: string             ← uid of owner
  shopName: string
  shopNameMl: string          ← Malayalam name
  shopSlug: string            ← unique URL slug (e.g. "antonyskitchen")
  shopType: string            ← 'Grocery', 'Pharmacy', etc.
  ownerPhone: string
  ownerWhatsApp: string
  address: string
  district: string
  bannerImageUrl: string
  logoUrl: string
  isOpen: boolean
  isActive: boolean           ← admin can set false to block
  linkActive: boolean
  deliveryType: 'pickup' | 'delivery' | 'both'
  minOrderValue: number
  paymentMethods: string[]    ← ['cash', 'upi', 'card']
  upiId: string
  categories: string[]        ← product categories for this shop
  trialStartDate: Timestamp
  trialEndDate: Timestamp
  subscriptionStatus: 'trial' | 'active' | 'expired'
  createdAt: Timestamp
  totalOrders: number
  fcmToken: string
  website: {                  ← null if no website built
    isPublished: boolean
    themeId: 'modern' | 'bold' | 'traditional' | 'custom'
    siteName: string
    tagline: string
    aboutText: string
    primaryColor: string      ← hex color
    sections: string[]        ← ['hero', 'products', 'about', 'contact']
    whatsappEnabled: boolean
    whatsappNumber: string
    customHtml: string        ← only for custom theme
    publishedAt: string       ← ISO date string
    unpublishedAt: string     ← set by admin
    unpublishReason: string   ← set by admin
  }
}
```

### `shops/{shopId}/products/{productId}`
```
{
  productId: string
  shopId: string
  nameEn: string
  nameMl: string
  price: number
  offerPrice: number          ← 0 if no offer
  unit: string                ← 'kg', 'pcs', 'litre', etc.
  category: string
  imageUrl: string
  isHidden: boolean
  isOutOfStock: boolean
  createdAt: Timestamp
}
```

### `shops/{shopId}/orders/{orderId}`
```
{
  orderId: string
  shopId: string
  items: [{ productId, nameEn, price, quantity, unit }]
  totalAmount: number
  customerName: string
  customerPhone: string
  deliveryAddress: string
  deliveryType: 'pickup' | 'delivery'
  paymentMethod: string
  status: 'new' | 'confirmed' | 'ready' | 'delivered' | 'cancelled'
  createdAt: Timestamp | string   ← both formats exist (use _parseDate())
  updatedAt: Timestamp | string
}
```

### Non-shop collections (same structure)
- `services/{id}` — services (repair, cleaning, etc.)
- `theaters/{id}` — cinemas
- `hotels/{id}` — hotels
- `restaurants/{id}` — restaurants
- `beauty/{id}` — salons/spas
- `realestate/{id}` — properties

All have: `{ ownerId, name, district, address, phone, description, imageUrl, isActive }`

---

## AUTH FLOWS

```
CUSTOMER:
  App open → /splash → /language → /role-select → [Customer] → /customer/home
  No login required. Browse anonymously.

BUSINESS OWNER (new):
  /role-select → [Business] → /google-signin → Google OAuth
  → /business/type → /business/listing-form (non-shop) OR /onboard/type...done → /business/home

BUSINESS OWNER (returning):
  /splash → detects auth → /business/home directly

WEBSITE BUILDER:
  BusinessHomeScreen Settings tab → "Create a Website"
  → /website-builder (WebView loads: https://web-phi-puce-84.vercel.app/control/website?shopId=X&uid=Y)
  URL params are read by the page on mount via useSearchParams()
```

---

## WEBSITE BUILDER FLOW

```
Step 1 — Theme Picker
  [Modern] [Bold] [Traditional] [Custom AI]
  → Click any → themeId set → Step 2

Step 2a — Edit Form (for Modern/Bold/Traditional)
  Site Name, Tagline, About, Primary Color (color picker)
  Sections: [hero] [products] [about] [contact] (checkboxes)
  WhatsApp Button toggle + number
  [Preview Site] → opens /sites/{shopId}?preview=true in new tab
  [Next →] → Step 3

Step 2b — Custom AI
  [Read-only AI prompt textarea]
  [Copy Prompt] → copies to clipboard
  "Paste into ChatGPT/Gemini → copy HTML → paste below"
  [HTML textarea to paste into]
  [Validate HTML] → checks for <html> tag
  [Next →] → Step 3

Step 3 — Publish
  Summary card: Theme, Site Name, Sections
  [Publish My Website] → POST /api/website → saves website map to shops/{shopId}
  Success: shows live URL https://web-phi-puce-84.vercel.app/sites/{shopId}
  Error: shows error message
  [← Back] → returns to Step 2
```

### Published site (`/sites/{shopId}`)
- Server component (SSR)
- Fetches shop + products from Firestore REST API
- If `website.isPublished !== true` → shows "Coming Soon" page
- `themeId='modern'` → renders `<ModernTheme />`
- `themeId='bold'` → renders `<BoldTheme />`
- `themeId='traditional'` → renders `<TraditionalTheme />`
- `themeId='custom'` → renders HTML in sandboxed `<iframe srcdoc="...">`

---

## SCREEN WIREFRAMES

### BusinessHomeScreen (Flutter)

```
┌─────────────────────────────────────────┐
│ ← [Shop Name ▾]              [🌐 Globe] │  ← AppBar
├─────────────────────────────────────────┤
│                                         │
│          [TAB CONTENT]                  │
│                                         │
├─────────────────────────────────────────┤
│    🏠 Home    🌐 Web    ⚙️ Settings      │  ← Bottom nav
└─────────────────────────────────────────┘

HOME TAB (shops):
  Last 20 orders, newest first
  Each row: [Order #] [Customer] [Amount] [Status badge]
  Status colors: new=amber, confirmed=green, delivered=blue, cancelled=red

HOME TAB (non-shops):
  Business info card with name, address, contact

WEB TAB:
  [+ Add Products]  [📋 Copy]  [📤 Share]
  ─────────────────────────────────
  URL: https://web-phi-puce-84.vercel.app?shopId=...
  ─────────────────────────────────
  Live Preview (scaled WebView 55%)
    ┌─────────────────────────┐
    │   [Shop website live]   │
    └─────────────────────────┘

SETTINGS TAB:
  STORE
    🏪 Shop Settings
    📊 Analytics
    📤 Share My Listing
  BUSINESS
    ➕ Add Another Listing
    🌐 Create a Website  (shops only)
  ACCOUNT
    👤 Account Settings
  [Sign Out] (red button)
```

### Website Builder (Flutter WebView → Next.js)

```
┌─────────────────────────────────────────┐
│ ✕             My Website                │  ← AppBar
├─────────────────────────────────────────┤
│ ████████████████░░░░░░░░ Step 2 of 3   │  ← Progress
├─────────────────────────────────────────┤
│                                         │
│  STEP 1 — Choose Theme                  │
│  ┌──────────┐  ┌──────────────────────┐ │
│  │ Modern   │  │ Bold                 │ │
│  │ Clean    │  │ Dark & powerful      │ │
│  └──────────┘  └──────────────────────┘ │
│  ┌──────────┐  ┌──────────────────────┐ │
│  │Traditional│ │ Custom AI            │ │
│  │Kerala    │  │ Your own design      │ │
│  └──────────┘  └──────────────────────┘ │
│                                         │
│  STEP 2 — Edit (non-custom)             │
│  Site Name: [____________]              │
│  Tagline:   [____________]              │
│  About:     [______________]            │
│             [______________]            │
│  Color: [■] ← color picker             │
│  Sections: [✓hero] [✓products] ...     │
│  WhatsApp:  [toggle] ON                 │
│  Number:   [____________]              │
│  [Preview Site]  [Next →]              │
│                                         │
│  STEP 2 — Custom AI                     │
│  [AI Prompt textarea (read-only)]       │
│  [Copy Prompt]                          │
│  "Paste into ChatGPT → paste HTML"     │
│  [HTML textarea]                        │
│  [Validate HTML]  [Next →]             │
│                                         │
│  STEP 3 — Publish                       │
│  Theme: modern  Name: My Shop          │
│  Sections: hero, products, about        │
│  [Publish My Website]                   │
│  ✅ Your site is live!                  │
│  https://...vercel.app/sites/abc123     │
│  [Copy URL]  [← Back]                  │
└─────────────────────────────────────────┘
```

---

## CRITICAL GOTCHAS

1. **`FloatingCartBar`** prop is `onClick` (NOT `onCartClick`)
2. **`ProductGrid`** requires `onProductClick` prop
3. **`Header`** requires `shopNameMl` + `logoUrl`
4. **Flutter date parsing** — `_parseDate()` in OrderModel handles both Firestore Timestamp AND ISO strings
5. **Firestore REST API** is used in Next.js (not SDK) — all helpers are in `web/lib/firestore-rest.ts`
6. **Website publish** — uses Firestore REST PATCH with `updateMask.fieldPaths=website`. No firebase-admin needed.
7. **`activeShopId`** in `users/{uid}` must stay in sync — `BusinessHomeScreen._load()` updates it on startup. This is what feeds `activeShopIdProvider` for Products/Analytics/Settings screens.
8. **`params`** in Next.js 16 dynamic routes is `Promise<{shopId}>` — must `await params`
9. **Firestore rule** — `shops/{shopId}` has a special `allow update` for `website` field only (no auth required, ownership verified server-side)
10. **APK size** — debug APK is 100-200MB (normal). Release universal APK is ~55-60MB (all ABIs). Single-ABI (`--split-per-abi --target-platform android-arm64`) is ~15MB. Download button on website uses the universal APK.
11. **`/shopname` URLs** — `[slug]/page.tsx` is now a server component that queries Firestore by `shopSlug` field and renders the full site. `/sites/[shopId]` still works too. Update share URL shown to owners if needed.
12. **FCM token** — saved to `shops/{shopId}.fcmToken` by `FcmService.init()` called from `_syncActiveShopId()` in BusinessHomeScreen. Notification sent from `web/app/api/orders/route.ts` POST handler via `firebase-admin/messaging`.
13. **Auto-WhatsApp on order** — `handleConfirmOrder` in `web/app/shop/page.tsx` opens `wa.me/{ownerWhatsApp}` with full order bill BEFORE the `await` (so browser doesn't block it).
14. **Preview bypass** — `/sites/[shopId]?preview=true` skips the `isPublished` check. Used by the website builder "Preview Site" button.

---

## KNOWN BUGS LOG

| Bug | Root Cause | Status | Fixed In |
|---|---|---|---|
| Website builder "page couldn't load" first time | No `onWebResourceError` handler in WebsiteBuilderScreen | ✅ Fixed | Phase 14 |
| Custom theme step shows nothing | `shop &&` guard blocked UI when fetch pending; no `.catch()` | ✅ Fixed | Phase 14 |
| Publish shows "FIREBASE_SERVICE_ACCOUNT not configured" | API used firebase-admin SDK; env var not set in Vercel | ✅ Fixed | Phase 14 — now uses REST PATCH |
| Add Products "something went wrong" | `activeShopIdProvider` returned null; `BusinessHomeScreen` never synced `activeShopId` | ✅ Fixed | Phase 14 |
| Analytics/Settings appear unconnected | Same root cause as above | ✅ Fixed | Phase 14 |
| No back button on BusinessHomeScreen | No `leading` in AppBar | ✅ Fixed | Phase 14 — goes to /role-select |
| No browse button for wekerala website | Not implemented | ✅ Fixed | Phase 14 — globe icon in AppBar |
| App appears 200MB | User was viewing debug APK; release universal APK is ~57MB | ✅ Explained | Phase 14 + minify enabled |
| 4 unused packages bloating build | firebase_messaging, connectivity_plus, csv, flutter_local_notifications never imported | ✅ Fixed | Phase 14 — removed from pubspec.yaml |
| FloatingCartBar hiding "Place Order" button | FloatingCartBar rendered on cart page (fixed bottom-4 z-40) covered the sticky checkout bar | ✅ Fixed | Phase 15 — removed FloatingCartBar from cart page render |
| Blank delivery info bar on storefront | `<div>` rendered unconditionally even with no delivery data | ✅ Fixed | Phase 15 — wrapped in condition |
| Live preview "Coming Soon" | `/sites/[shopId]` blocked on `isPublished !== true` with no preview bypass | ✅ Fixed | Phase 15 — `?preview=true` param skips check |
| Splash too slow | `Future.delayed(2s)` hardcoded | ✅ Fixed | Phase 15 — reduced to 500ms |
| Analytics buried in Settings | No direct tab | ✅ Fixed | Phase 15 — 4th bottom nav tab (pushes /analytics) |
| No shop logo in AppBar | AppBar title was text-only | ✅ Fixed | Phase 15 — CachedNetworkImage before name |
| Settings save silently failed | No catch block on Firestore update | ✅ Fixed | Phase 15 — red snackbar shows error |

---

## wekerala DESIGN TOKENS

| Token | Value | Usage |
|---|---|---|
| `--wk-paper` | `#283618` | Dark green — primary/AppBar |
| `--wk-ink` | `#fefae0` | Cream — background |
| `--wk-sticky` | `#dda15e` | Orange — accent/CTA |
| Font UI | Poppins | All body text |
| Font heading | Caveat | Display/hero headings |
| Font labels | JetBrains Mono | Prices, codes |

Flutter equivalents: `AppColors.primary=#283618`, `AppColors.background=#fefae0`, `AppColors.accent=#dda15e`

---

## PHASE 16 — DONE (Business Type-Specific Schemas)

Each non-shop business type now stores and displays type-specific fields:

### `services/{id}` extra fields
`serviceType`, `experience`, `priceRange`, `availability` (On-call/By Appointment/Both), `serviceAreas` (string[])

### `theaters/{id}` extra fields
`theaterType`, `screens` (number), `ticketPriceRange`, `facilities` (string[]), `bookingUrl`

### `hotels/{id}` extra fields
`hotelCategory`, `pricePerNight`, `amenities` (string[]), `totalRooms`, `checkIn`, `checkOut`

### `restaurants/{id}` extra fields
`cuisineTypes` (string[]), `diningOptions` (string[]), `isVeg` (Veg/Non-Veg/Both), `avgCostForTwo`, `specialities` (string[])

### `beauty/{id}` extra fields
`serviceList` (string[]), `gender` (Ladies/Gents/Unisex), `homeVisitAvailable` (bool), `appointmentRequired` (bool), `priceRange`

**Files changed:**
- `web/app/api/register/route.ts` — switch(collection) stores type-specific fields
- `web/app/api/listings/route.ts` — WkListing interface + normalizeListing extended
- `web/components/wk/wk-card.tsx` — `extraInfo` prop (shown in accent color below category)
- `web/components/wk/listing-page.tsx` — `buildCardInfo()` builds extraInfo+tags per collection
- `shoplink_app/lib/features/business/screens/listing_form_screen.dart` — type-specific form sections with dropdowns, chips, radio, switches

---

## PHASE 17 — WHAT TO BUILD NEXT (Customer Features)

1. Customer login — Firebase Auth phone OTP for customers (currently anonymous)
2. Link placed orders to customer uid (store `customerUid` on order doc)
3. Customer order history screen — `/customer/orders` shows past orders by phone/uid
4. Saved addresses — store in `users/{uid}/addresses`
5. Favorites/wishlist — store in `users/{uid}/favorites` (shopId list)
