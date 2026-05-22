# wekerala Web Platform — Complete Structure Reference

> Use this file to plan new features, understand click behaviors, and audit what exists.
> Last updated: 2026-05-12

---

## 1. What This Platform Is

**wekerala web** is a Next.js 15 App Router website that serves three audiences:

| Audience | What they see | URL |
|----------|--------------|-----|
| **Customers** | Browse + contact shops | `/` `/shops` `/shop` |
| **Shop owners** | Manage their listing, website, orders | `/control` |
| **Platform admins** | Approve shops, moderate content | `/admin` |

The platform is a **shop directory** — any type of shop in Kerala (grocery, hotel, restaurant, salon, pharmacy, etc.) registered under the `shops` Firestore collection. Other collections (services, theaters, hotels, restaurants, beauty, etc.) exist from a previous multi-category model and are still readable but no longer actively promoted in the UI.

---

## 2. Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Next.js 15 App Router (TypeScript) |
| Styling | Inline styles (no Tailwind in pages); shadcn/ui components available |
| State | React `useState` / `useEffect` (client components) |
| Database | Firebase Firestore (REST API — no firebase-admin SDK) |
| Auth | Firebase Auth (client-side via SDK) |
| Hosting | Vercel |
| Brand colors | `#283618` dark green, `#fefae0` cream, `#dda15e` orange |

**Key env vars (set in Vercel):**
```
NEXT_PUBLIC_FIREBASE_PROJECT_ID=shoplink-prod
NEXT_PUBLIC_FIREBASE_API_KEY=...
ADMIN_PASSWORD=...           # Admin panel login
```

---

## 3. Page Map

### Customer-Facing Pages

| URL | File | Purpose |
|-----|------|---------|
| `/` | `app/page.tsx` | Homepage — browse all shops |
| `/shops` | `app/shops/page.tsx` | Full shop listing with filters |
| `/shop?shopId={id}` | `app/shop/page.tsx` | Individual shop detail page |
| `/search` | `app/search/page.tsx` | Search results page |
| `/deals` | `app/deals/page.tsx` | Active deals/coupons listing |
| `/auth` | `app/auth/page.tsx` | Customer login (phone OTP / Google) |
| `/profile` | `app/profile/page.tsx` | Customer profile + order history |
| `/customer/orders` | `app/customer/orders/page.tsx` | Customer order history |
| `/subscription` | `app/subscription/page.tsx` | Subscription info page |

### Legacy Category Pages (kept, not promoted)

| URL | File | Collection |
|-----|------|-----------|
| `/services` | `app/services/page.tsx` | `services` |
| `/theaters` | `app/theaters/page.tsx` | `theaters` |
| `/hotels` | `app/hotels/page.tsx` | `hotels` |
| `/restaurants` | `app/restaurants/page.tsx` | `restaurants` |
| `/beauty` | `app/beauty/page.tsx` | `beauty` |
| `/doctors` | `app/doctors/page.tsx` | `doctors` |
| `/hospitals` | `app/hospitals/page.tsx` | `hospitals` |
| `/education` | `app/education/page.tsx` | `education` |
| `/home-services` | `app/home-services/page.tsx` | `homeServices` |
| `/listing/[collection]/[id]` | `app/listing/[collection]/[id]/page.tsx` | Any collection detail |

### Shop Owner Pages

| URL | File | Purpose |
|-----|------|---------|
| `/control` | `app/control/page.tsx` | Owner dashboard — orders, website, settings |
| `/control/website` | `app/control/website/page.tsx` | Website builder (WebView embed) |
| `/control/analytics` | `app/control/analytics/page.tsx` | Owner analytics view |
| `/list-me` | `app/list-me/page.tsx` | New shop registration form |
| `/sites/[shopId]` | `app/sites/[shopId]/page.tsx` | Owner's storefront preview |
| `/[slug]` | `app/[slug]/page.tsx` | Public shop storefront by slug |

### Admin Pages

| URL | File | Purpose |
|-----|------|---------|
| `/admin` | `app/admin/page.tsx` | Admin panel (password protected) |

---

## 4. Page-by-Page Click Behaviors

### `/` — Homepage

**Header (sticky, dark green):**
- Logo "wekerala" → reloads `/`
- "Near me" button → (future: geolocation filter)
- "Login" button → navigates to `/auth`

**Hero section:**
- Search input → filters shop cards in real-time by name or category
- "Go" button → same as typing (triggers filter)
- District dropdown → shows all 14 Kerala districts; selecting one filters cards

**Category chips (horizontal scroll):**
- "All", "Grocery", "Restaurant", "Hotel", "Pharmacy", "Beauty", "Bakery", "Electronics", "Clothing", "Supermarket", "Stationery", "Hardware"
- Clicking a chip → filters shop cards to that category

**Shop cards:**
- Banner image area → navigates to `/shop?shopId={id}`
- Shop name → navigates to `/shop?shopId={id}`
- "📞 Call" button → opens `tel:{phone}` (device phone app)
- "💬 WhatsApp" button → opens WhatsApp with pre-filled message
- "View Shop →" button (shown when no phone) → navigates to `/shop?shopId={id}`
- "Open" badge → display only (from `isOpen` field)
- Rating badge → display only

**Bottom navigation:**
- 🏠 Home → `/`
- 🔍 Browse → `/shops`
- 🏪 My Shop → `/control`
- 📱 App → `/api/download-app` (APK download)

**Data source:** `GET /api/listings?collection=shops` → all shops, filtered client-side

---

### `/shops` — Browse Shops

**Header (sticky, dark green):**
- ← back arrow → navigates to `/`
- "Browse Shops" title
- Search input → filters shop cards in real-time
- ✕ clear button → clears search text
- "📍 All ▾" district button → shows district dropdown picker; selecting district filters cards

**Category filter chips:**
- Same 12 types as homepage; active chip is dark green

**Results count bar:**
- Shows `{n} shops in {district} · {type}` — updates as filters change

**Shop cards:** Same as homepage (banner, Call, WhatsApp, View Shop)

**Empty state:**
- "No shops match your filters" + "Clear filters" button → resets all 3 filters
- "No shops listed yet." shown when Firestore returns 0 docs

**Bottom navigation:** Same as homepage (Browse tab is active/bold)

**URL params read on load:** `?search=` and `?district=` (so homepage can deep-link)

**Data source:** `GET /api/listings?collection=shops`

---

### `/shop?shopId={id}` — Shop Detail

Individual shop page showing full details: banner, name, category, district, description, phone, WhatsApp link, products (if any), rating, hours, etc.

**Key interactions:**
- "📞 Call" → `tel:{phone}`
- "💬 WhatsApp" → `https://wa.me/{phone}?text=...`
- Back button → browser history back
- Products section → (if shop has products) shows product grid; "Add to cart" adds to cart-store

**Data source:** `GET /api/shop?shopId={id}`

---

### `/admin` — Admin Panel

**Login gate:**
- Password input (eye toggle to show/hide)
- "Login" button → validates vs `ADMIN_PASSWORD` env var via `/api/admin/shops`

**After login — 3 tabs:**

#### Shops Tab
- **2×2 stat grid:** Total Shops, Approved, Pending Approval, Blocked
- **Search input:** filters by shop name
- **Filter chips:** All / Approved / Pending / Blocked
- **Shop cards (one per shop):**
  - Logo/photo thumbnail, shop name, type, area, status badge
  - **"Approve" button** → PATCH `/api/admin/shops` `{action: 'approve', shopId, collection}`; updates `isApproved: true` in Firestore
  - **"Block" button** → PATCH `/api/admin/shops` `{action: 'block', shopId, collection}`; updates `isApproved: false`
  - **"WhatsApp" button** → opens `wa.me/{phone}` in new tab
  - **"View" button** → navigates to `/shop?shopId={id}` in new tab
  - **"Unpublish Website" button** → shows reason input; on confirm: PATCH `{action: 'unpublish_website', shopId, reason}` → sets `website.isPublished: false`
  - Multi-collection badge (green pill showing collection name)
- **"Export CSV" button** → downloads shop list as CSV
- **"Load all collections" button** → refetches with `?all=true` param to include all legacy collections

#### Deals Tab
- Manage platform-level deals/announcements
- **Data source:** `GET/POST/DELETE /api/admin/deals`

#### Analytics Tab
- Platform stats: total listings, growth, activity
- **Data source:** `GET /api/admin/analytics`

**Auth mechanism:** All admin API calls send `x-admin-password: {password}` header; server validates against `ADMIN_PASSWORD` env var.

---

### `/control` — Owner Control Panel

**Login gate (if not authenticated):**
- Dark green "Login to Continue" button → triggers Firebase Auth flow

**After login — 3 tabs:**

#### Home Tab
- Business selector bar (top): shows active shop name + type; click → opens inline dropdown to switch shops
- **Order cards** (recent orders):
  - Status label (New / Confirmed / Processing / Ready / Delivered / Cancelled) with color coding
  - Customer name, items, total amount
  - Status action buttons: "Confirm" / "Ready" / "Mark Delivered" / "Cancel"
  - Each button → PATCH order status in Firestore

#### Web Tab
- **"Website Builder" link button** → navigates to `/control/website`
- **Shop URL card** → shows `{slug}.wekerala.in`; "Copy" button copies URL; "Open" opens in new tab
- **Live preview iframe** → embeds shop storefront
- **Coupons section:** list of active coupons; "Add Coupon" → form to create coupon; "Delete" removes coupon
- **Post a Deal section:** form to post a time-limited deal

#### Settings Tab
- **Edit Shop Profile** → navigates to shop settings form
- **Edit Products** → links to product management
- **Share / QR code** → generates QR for shop URL
- **Help / Support** → links to support contact
- **Sign Out** → Firebase Auth sign out

**Data sources:**
- Orders: `GET /api/orders?shopId={id}`
- Shop info: `GET /api/shop?shopId={id}`
- Coupons: `GET/POST/DELETE /api/coupons?shopId={id}`
- Deals: `GET/POST /api/deals`

---

### `/list-me` — New Shop Registration

Form for shop owners to register on the platform.

**Fields:** Shop name, shop type, WhatsApp number, district, address, description, banner image upload

**Submit → POST `/api/register`** → creates document in `shops` Firestore collection with `isApproved: false` (pending admin review)

---

## 5. API Routes

### Public APIs

| Method | Route | Purpose | Auth |
|--------|-------|---------|------|
| GET | `/api/listings` | Fetch shops/listings by collection | None |
| GET | `/api/shop` | Fetch single shop by `?shopId=` | None |
| GET | `/api/products` | Fetch products for a shop | None |
| GET | `/api/search` | Search across collections | None |
| GET | `/api/autocomplete` | Search autocomplete suggestions | None |
| GET | `/api/deals` | Active deals | None |
| GET | `/api/ratings` | Ratings for a listing | None |
| GET | `/api/download-app` | Redirect to APK download | None |

### Shop Owner APIs

| Method | Route | Purpose | Auth |
|--------|-------|---------|------|
| GET/POST | `/api/orders` | Shop orders | Firebase Auth |
| GET/POST | `/api/coupons` | Shop coupons | Firebase Auth |
| GET/PUT | `/api/website` | Shop website settings | Firebase Auth |
| GET | `/api/my-listings` | Owner's own listings | Firebase Auth |
| GET | `/api/analytics` | Shop analytics | Firebase Auth |
| POST | `/api/register` | Register new shop | None |
| POST | `/api/sheets-import` | Bulk product import | Firebase Auth |

### Customer APIs

| Method | Route | Purpose | Auth |
|--------|-------|---------|------|
| GET | `/api/customer/orders` | Customer order history | Firebase Auth |
| GET/POST | `/api/customer/addresses` | Saved addresses | Firebase Auth |
| GET/POST | `/api/bookmarks` | Saved/bookmarked shops | Firebase Auth |
| POST | `/api/coupon` | Validate coupon code | None |
| POST | `/api/order-status` | Track order | None |

### Admin APIs

| Method | Route | Purpose | Auth |
|--------|-------|---------|------|
| GET/PATCH | `/api/admin/shops` | List/approve/block shops | `x-admin-password` header |
| GET/POST/DELETE | `/api/admin/deals` | Manage deals | `x-admin-password` |
| GET | `/api/admin/analytics` | Platform stats | `x-admin-password` |
| GET/POST | `/api/admin/announcements` | Announcements | `x-admin-password` |
| GET/POST/DELETE | `/api/admin/badges` | Verified badges | `x-admin-password` |
| GET/POST | `/api/admin/featured` | Featured listings | `x-admin-password` |
| GET/POST | `/api/merchants` | Merchant management | `x-admin-password` |
| GET | `/api/merchant/[id]` | Single merchant detail | `x-admin-password` |
| GET | `/api/shops` | Shops list (alt endpoint) | None |
| GET | `/api/service-tags` | Service tag list | None |

---

## 6. Data Flow

```
Customer visits /
  └── page.tsx loads
        └── useEffect → GET /api/listings?collection=shops
              └── Firestore REST: GET .../shops?pageSize=200
                    └── normalizeShop() maps fields
                          └── WkListing[] → ShopCard components
                                └── Filter client-side by district/type/search

Admin visits /admin
  └── admin/page.tsx
        └── Login → stores password in component state (not localStorage)
              └── GET /api/admin/shops?all=true
                    └── Header: x-admin-password: {password}
                          └── Server validates vs ADMIN_PASSWORD env var
                                └── Fetches from all 10 Firestore collections
                                      └── normalizeShop/normalizeListing → ShopRow[]

Admin clicks "Approve"
  └── PATCH /api/admin/shops
        └── Body: {shopId, action: 'approve', collection: 'shops'}
              └── Firestore REST PATCH: isApproved=true
                    └── updateMask.fieldPaths=isApproved

Admin clicks "Unpublish Website"
  └── PATCH /api/admin/shops
        └── Body: {shopId, action: 'unpublish_website', reason}
              └── Firestore REST PATCH: website.isPublished=false, website.unpublishedAt, website.unpublishReason
                    └── updateMask.fieldPaths=website.isPublished (etc.)
```

---

## 7. Firestore Collections Used by Web

| Collection | Used By | Key Fields |
|-----------|---------|-----------|
| `shops` | Homepage, /shops, /shop, /admin, /control | `shopName`, `shopType`, `shopArea`, `bannerImageUrl`, `logoUrl`, `ownerWhatsApp`, `ownerPhone`, `isOpen`, `isApproved`, `avgRating`, `ratingCount`, `website{}` |
| `services` | Legacy /services page, admin | `name`, `category`, `district`, `phone`, `isActive` |
| `theaters` | Legacy /theaters page, admin | `name`, `theaterType`, `ticketPriceRange`, `isActive` |
| `hotels` | Legacy /hotels page, admin | `name`, `hotelCategory`, `pricePerNight`, `isActive` |
| `restaurants` | Legacy /restaurants page, admin | `name`, `cuisineTypes`, `isVeg`, `isActive` |
| `beauty` | Legacy /beauty page, admin | `name`, `serviceList`, `gender`, `isActive` |
| `doctors` | Legacy /doctors page, admin | `name`, `isActive` |
| `hospitals` | Legacy /hospitals page, admin | `name`, `isActive` |
| `education` | Legacy /education page, admin | `name`, `isActive` |
| `homeServices` | Legacy /home-services, admin | `name`, `isActive` |

**Note:** All collections except `shops` use `isActive` for approval; `shops` uses `isApproved`.

---

## 8. WkListing Type (shared across pages)

Defined in `app/api/listings/route.ts`:

```typescript
interface WkListing {
  id: string
  name: string
  category: string
  rating?: number
  reviews?: number
  photoUrl?: string
  tags: string[]
  district?: string
  isOpen?: boolean
  isVerified?: boolean
  href?: string
  location?: string
  description?: string
  externalUrl?: string
  serviceType?: string
  phone?: string
  // Hotels
  hotelCategory?: string; pricePerNight?: string; amenities?: string[]
  totalRooms?: number; checkIn?: string; checkOut?: string
  // Restaurants
  cuisineTypes?: string[]; diningOptions?: string[]; isVeg?: string
  avgCostForTwo?: string; specialities?: string[]
  // Beauty
  serviceList?: string[]; gender?: string
  homeVisitAvailable?: boolean; appointmentRequired?: boolean
  // Services
  priceRange?: string; availability?: string; serviceAreas?: string[]
  experience?: string
  // Theaters
  theaterType?: string; ticketPriceRange?: string
  facilities?: string[]; bookingUrl?: string
  // Screens count (theaters)
  screens?: number
}
```

**Field mapping for `shops` collection** (`normalizeShop`):
- `shopName` → `name`
- `shopType` → `category`
- `shopArea` / `district` → `district`
- `bannerImageUrl` → `photoUrl` (fallback: `logoUrl`)
- `ownerWhatsApp` / `ownerPhone` → `phone`
- `shopNameMl` / `address` → `description`
- `avgRating` → `rating`
- `ratingCount` → `reviews`

---

## 9. File Structure

```
web/
├── app/
│   ├── layout.tsx                    # Root layout, fonts, metadata
│   ├── page.tsx                      # Homepage (/)
│   ├── shops/page.tsx                # Browse all shops (/shops)
│   ├── shop/page.tsx                 # Shop detail (/shop?shopId=)
│   ├── search/page.tsx               # Search results
│   ├── deals/page.tsx                # Deals listing
│   ├── auth/page.tsx                 # Customer auth
│   ├── profile/page.tsx              # Customer profile
│   ├── list-me/page.tsx              # Shop registration
│   ├── subscription/page.tsx         # Subscription info
│   │
│   ├── admin/
│   │   ├── page.tsx                  # Admin panel (3 tabs)
│   │   ├── DealsTab.tsx              # Deals management sub-component
│   │   ├── AnalyticsTab.tsx          # Analytics sub-component
│   │   ├── ServiceTagsTab.tsx        # (legacy — not shown in UI)
│   │   ├── SectorsTab.tsx            # (legacy)
│   │   ├── BadgesTab.tsx             # (legacy)
│   │   ├── FeaturedTab.tsx           # (legacy)
│   │   └── AnnouncementsTab.tsx      # (legacy)
│   │
│   ├── control/
│   │   ├── page.tsx                  # Owner dashboard (3 tabs)
│   │   ├── website/page.tsx          # Website builder
│   │   └── analytics/page.tsx        # Owner analytics
│   │
│   ├── customer/
│   │   └── orders/page.tsx           # Customer order history
│   │
│   ├── listing/[collection]/[id]/
│   │   └── page.tsx                  # Generic listing detail (legacy)
│   │
│   ├── sites/[shopId]/page.tsx       # Shop storefront by shopId
│   ├── [slug]/page.tsx               # Shop storefront by slug
│   │
│   └── api/
│       ├── listings/route.ts         # GET: fetch listings from any collection
│       ├── shop/route.ts             # GET: single shop
│       ├── products/route.ts         # GET: shop products
│       ├── search/route.ts           # GET: search
│       ├── autocomplete/route.ts     # GET: autocomplete
│       ├── deals/route.ts            # GET: deals
│       ├── ratings/route.ts          # GET/POST: ratings
│       ├── register/route.ts         # POST: new shop registration
│       ├── orders/route.ts           # GET/POST: orders (owner)
│       ├── customer/
│       │   ├── orders/route.ts       # GET: customer orders
│       │   └── addresses/route.ts    # GET/POST: addresses
│       ├── coupons/route.ts          # GET/POST/DELETE: shop coupons
│       ├── coupon/route.ts           # POST: validate coupon
│       ├── website/route.ts          # GET/PUT: website settings
│       ├── my-listings/route.ts      # GET: owner listings
│       ├── analytics/route.ts        # GET: shop analytics
│       ├── bookmarks/route.ts        # GET/POST: bookmarks
│       ├── order-status/route.ts     # POST: order tracking
│       ├── sheets-import/route.ts    # POST: bulk product import
│       ├── service-tags/route.ts     # GET: service tags
│       ├── download-app/route.ts     # GET: redirect to APK
│       ├── shops/route.ts            # GET: shops list (alt)
│       ├── merchants/route.ts        # GET/POST: merchants (admin)
│       ├── merchant/[id]/route.ts    # GET: single merchant (admin)
│       └── admin/
│           ├── shops/route.ts        # GET/PATCH: approve/block shops
│           ├── deals/route.ts        # GET/POST/DELETE: deals
│           ├── analytics/route.ts    # GET: platform stats
│           ├── announcements/route.ts
│           ├── badges/route.ts
│           └── featured/route.ts
│
├── components/
│   ├── shop/
│   │   ├── floating-cart-bar.tsx     # Sticky cart summary bar
│   │   ├── product-grid.tsx          # Shop product grid
│   │   ├── search-bar.tsx            # Search input component
│   │   └── search-overlay.tsx        # Full-screen search overlay
│   ├── theme-provider.tsx            # Next-themes provider
│   └── ui/                           # shadcn/ui components (accordion, badge, button, card, dialog, drawer, input, select, sheet, table, tabs, toast, tooltip, etc.)
│
├── lib/
│   ├── cart-store.ts                 # Zustand cart state
│   ├── filter-store.ts               # Zustand filter state
│   ├── utils.ts                      # cn() utility
│   └── wk-constants.ts               # KERALA_DISTRICTS, SHOP_TYPES, colors
│
├── hooks/
│   ├── use-mobile.ts                 # isMobile hook
│   └── use-toast.ts                  # Toast hook
│
├── public/                           # Static assets
├── package.json
├── next.config.ts
├── tsconfig.json
└── STRUCTURE.md                      # This file
```

---

## 10. Firestore Security Rules Summary

**`shops` collection** allows unauthenticated PATCH of:
- `website` map fields (for website builder)
- `isApproved` field (for admin panel without firebase-admin)

**All other collections** (services, theaters, hotels, restaurants, beauty, realestate, doctors, hospitals, education, homeServices) allow unauthenticated PATCH of:
- `isActive` field (for admin panel)

All other writes require `request.auth.uid == resource.data.ownerId`.

**Deploy rules:** `firebase deploy --only firestore:rules --project shoplink-prod`

---

## 11. Features Status

| Feature | Status | Notes |
|---------|--------|-------|
| Homepage — shop listing | ✅ Working | Swiggy-style cards, real-time client filter |
| Browse page (`/shops`) | ✅ Working | Search + district + category filters |
| Shop detail page | ✅ Working | Full info, Call/WhatsApp buttons |
| Admin — approve/block | ✅ Working | Firestore REST PATCH, no firebase-admin needed |
| Admin — unpublish website | ✅ Working | Updates `website.isPublished` via REST PATCH |
| Admin — CSV export | ✅ Working | Client-side CSV generation |
| Admin — multi-collection view | ✅ Working | Loads all 10 collections; `collection` badge on each card |
| Owner control panel | ✅ Working | 3 tabs: Home (orders), Web, Settings |
| Owner — order management | ✅ Working | Status workflow buttons |
| Owner — coupons | ✅ Working | Create/delete coupons |
| Owner — website builder | ✅ Working | Links to `/control/website` |
| Shop registration (`/list-me`) | ✅ Working | Creates shop with `isApproved: false` |
| Customer auth | ✅ Working | Firebase Auth (phone OTP / Google) |
| Customer orders | ✅ Working | Order history at `/customer/orders` |
| Deal management (admin) | ✅ Working | `DealsTab` component |
| Platform analytics (admin) | ✅ Working | `AnalyticsTab` component |
| Ratings / reviews | ⚠️ API exists | `/api/ratings` route exists; UI integration incomplete |
| Bookmarks | ⚠️ API exists | `/api/bookmarks` route exists; UI integration incomplete |
| Search page | ⚠️ Exists | `/search` page exists; depth of integration unknown |
| Geolocation "Near me" | ❌ Not built | Button exists on homepage; no geolocation logic |
| Push notifications (web) | ❌ Not built | No FCM web setup |
| Multi-language (web) | ❌ Not built | English only on web |
| Product ordering (web) | ⚠️ Partial | Cart store exists; end-to-end ordering flow not verified |

---

## 12. Upgrade Roadmap

### Priority 1 — Complete Core Features
1. **"Near me" geolocation** — Use `navigator.geolocation`; save lat/lng on each shop; filter by distance radius (5/10/20 km)
2. **Ratings UI** — Add star rating widget to shop detail page; write to `/api/ratings`
3. **Bookmarks** — Add ❤️ button to ShopCard; sync with `/api/bookmarks`; show saved shops in `/profile`
4. **Customer ordering flow** — Wire floating cart bar → checkout → `/api/orders` POST → WhatsApp order confirmation

### Priority 2 — Shop Owner Improvements
5. **Shop profile edit form** — `/control/settings` page with form to update `shopName`, `shopArea`, `bannerImageUrl`, `isOpen`, etc.
6. **Product management** — `/control/products` page: list, add, edit, delete products; upload images to Firebase Storage
7. **Owner analytics** — Improve `/control/analytics` with real charts (orders over time, top products)
8. **Coupon campaign tool** — Create coupons with expiry, discount type (fixed/percent), usage limit

### Priority 3 — Platform Growth
9. **SEO optimization** — Add `generateMetadata()` to shop detail pages; sitemap.xml; structured data (JSON-LD)
10. **WhatsApp Business API** — Auto-send order updates to customer via WhatsApp; replace manual owner forwarding
11. **Multi-language** — Add Malayalam translations; use `next-i18next` or `next-intl`; detect browser language
12. **Push notifications (web)** — FCM web SDK; notify owners of new orders even when tab closed
13. **Shop verification badge** — Admin can toggle `isVerified`; shows blue tick on shop card
14. **Featured listings** — Admin marks `isFeatured`; homepage shows featured shops in carousel above regular list
15. **Daily deals section** — Homepage carousel for time-limited deals; auto-expires using `expiryAt` timestamp

### Priority 4 — Monetization
16. **Subscription paywall** — Lock features (website builder, analytics) for shops with expired trial; Razorpay integration
17. **Promoted listings** — Paid boost for shops to appear at top of category/district results
18. **Platform commission** — Track orders placed through web; calculate platform fee on delivered orders

### Priority 5 — Technical Improvements
19. **Pagination** — Currently loads 200 docs per collection; add cursor-based pagination for large datasets
20. **Image optimization** — Use `next/image` instead of `<img>` for automatic WebP + sizing
21. **Error boundaries** — Add React error boundaries around shop listing sections
22. **Offline support** — Service Worker + cache for homepage shop list; show stale data when offline
23. **Admin auth upgrade** — Replace plaintext `ADMIN_PASSWORD` with Firebase Auth role claim for admins

---

## 13. Adding a New Page — Checklist

1. Create `app/{route}/page.tsx` with `'use client'` if using hooks
2. Add data fetching in `useEffect` → call relevant `/api/...` route
3. Add the page to the bottom nav if it's a main destination
4. Add the route to this STRUCTURE.md page map (Section 3)
5. If it needs a new API: create `app/api/{endpoint}/route.ts`
6. If it writes to Firestore: update `firestore.rules` to allow the new field
7. Deploy rules: `firebase deploy --only firestore:rules --project shoplink-prod`
8. Test on mobile viewport (max-width 480px — this is a mobile-first PWA)

---

## 14. Brand & Design Tokens

```
Colors:
  --green-dark:   #283618   (headers, active buttons, CTA)
  --cream:        #fefae0   (text on dark green backgrounds)
  --orange:       #dda15e   (accent, highlights)
  --bg:           #f8f9fa   (page background)
  --card:         #ffffff   (card backgrounds)
  --text-primary: #111827
  --text-muted:   #6b7280
  --border:       #e5e7eb
  --success:      #22c55e   (Open badge, WhatsApp button)
  --warning:      #f59e0b

Typography:
  Logo/brand:     Caveat (cursive Google font)
  Body:           System sans-serif (no custom font loaded for body)

Layout:
  Max-width:      480px (mobile-first; centered on desktop)
  Border-radius:  16px (cards), 10px (inputs/buttons), 20px (chips/badges)
  Card shadow:    0 1px 4px rgba(0,0,0,0.10)
```
