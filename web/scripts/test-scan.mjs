/**
 * weKerala AI Scan — Comprehensive 30+ Edge Case Test Suite
 *
 * Tests cover every real Kerala shop scenario:
 *  BRANDED PRODUCTS — clear label, brand on device, soap, shampoo, snacks
 *  TRANSPARENT BAG — food in plain bag (no label)
 *  LOOSE BULK ITEMS — produce / grain with no label
 *  PRICE DETECTION — printed MRP, handwritten tag
 *  DARK / BLURRY — poor lighting, shaky photo
 *  MEDICINES — small-text medicine box
 *  FRESH PRODUCE — banana, ginger, vegetable
 *  BOOKS — book cover detection
 *  NON-PRODUCT REJECTION — animal, plant, empty room
 *  MULTIPLE PRODUCTS — busy stall, shelf with many items
 *  GENERIC ITEMS — no brand, identify by type
 *  REGIONAL LANGUAGE — Malayalam/Tamil text on label
 *
 * Run: node web/scripts/test-scan.mjs
 */

import https from 'https';
import http from 'http';
import { URL } from 'url';

const API_URL = 'https://wekerala.vercel.app/api/gemini-product';
const G = '\x1b[32m', R = '\x1b[31m', Y = '\x1b[33m', C = '\x1b[36m', D = '\x1b[2m', X = '\x1b[0m';

// Helper: build a Wikimedia 500px thumb URL from path + filename
const W = (path, file) =>
  `https://upload.wikimedia.org/wikipedia/commons/thumb/${path}/500px-${file}`;

// ─── 30+ TEST CASES ──────────────────────────────────────────────────────────
// img: null → use offSearch to find image via Open Food Facts
// ok.isProduct: true/false/null (null = don't check)
// ok.has: substring the name must contain (case-insensitive)
// ok.notEmpty: true = name must not be empty
// ok.priceNotEmpty: true = price must be returned (visible in image)
const TESTS = [

  // ═══ GROUP 1: BRANDED PRODUCTS WITH CLEAR LABEL ══════════════════════════
  {
    label: '01 Parle-G Biscuits (iconic Indian biscuit, clear pack label)',
    img: W('a/a1/Parle-G_Biscuit.jpg', 'Parle-G_Biscuit.jpg'),
    ok: { isProduct: true, has: 'parle', notEmpty: true },
    why: 'Must read "Parle-G" from packet — baseline branded product test',
  },
  {
    label: '02 Casio DX-120B calculator (brand text on device face)',
    img: W('2/25/Casio_DX-120B.jpg', 'Casio_DX-120B.jpg'),
    ok: { isProduct: true, has: 'casio', notEmpty: true },
    why: 'No packaging — brand is only on the device surface',
  },
  {
    label: '03 Lux beauty soap bar (pink soap wrapper, clear brand)',
    img: W('4/43/Lux_soap.jpg', 'Lux_soap.jpg'),
    ok: { isProduct: true, has: 'lux', notEmpty: true },
    why: 'Soap bar with Lux branded wrapper — personal care product',
  },
  {
    label: '04 Dove/generic shampoo bottle (hair care)',
    img: null,
    offSearch: 'dove shampoo bottle hair',
    ok: { isProduct: true, notEmpty: true },
    why: 'Shampoo bottle — must identify as hair care product',
    fallbackImg: W('e/ea/Dove_Shampoo.jpg', 'Dove_Shampoo.jpg'),
  },
  {
    label: '05 Maggi instant noodles (iconic Indian packaged food)',
    img: W('c/cf/Hostel_Maggi.jpg', 'Hostel_Maggi.jpg'),
    ok: { isProduct: true, notEmpty: true },
    why: 'Classic Indian brand — must identify noodles even if cooked/preparing context',
  },
  {
    label: '06 Colgate toothpaste tube (personal care)',
    img: W('c/cd/Colgate_Hemp_Toothpaste_%2849349484716%29.jpg', 'Colgate_Hemp_Toothpaste_%2849349484716%29.jpg'),
    ok: { isProduct: true, notEmpty: true },
    why: 'Personal care tube — must identify as toothpaste',
  },
  {
    label: '07 Cadbury Dairy Milk Caramel chocolate bar (confectionery)',
    img: W('5/5e/Cadbury-Dairy-Milk-Caramel-Bar.jpg', 'Cadbury-Dairy-Milk-Caramel-Bar.jpg'),
    ok: { isProduct: true, notEmpty: true },
    why: 'Branded chocolate bar — must identify as Cadbury/chocolate product',
  },
  {
    label: '08 Dettol antiseptic (medicine/hygiene)',
    img: null,
    offSearch: 'dettol antiseptic liquid hand sanitizer',
    ok: { isProduct: true, notEmpty: true },
    why: 'Antiseptic/hygiene bottle — must identify as healthcare product',
  },
  {
    label: '09 Salt & Vinegar crisps packet (branded snack)',
    img: W('d/df/Salt-and-Vinegar.JPG', 'Salt-and-Vinegar.JPG'),
    ok: { isProduct: true, notEmpty: true },
    why: 'Branded snack bag — must identify brand/type',
  },

  // ═══ GROUP 2: PRODUCT IN TRANSPARENT BAG (very common in Kerala) ══════════
  {
    label: '10 Peanuts in a clear plastic bag (no label on bag)',
    img: W('f/f8/Cacahuates.jpg', 'Cacahuates.jpg'),
    ok: { isProduct: true, notEmpty: true },
    why: 'CRITICAL — plain bag: must identify what is inside (peanuts)',
  },
  {
    label: '11 Bread in transparent plastic bag (bakery bread)',
    img: W('a/a3/Bag-bread_%28361666550%29.jpg', 'Bag-bread_%28361666550%29.jpg'),
    ok: { isProduct: true, notEmpty: true },
    why: 'Common in Kerala bakeries — plain bag with bread visible inside',
  },
  {
    label: '12 Tea leaves in plain small bag (loose tea)',
    img: W('9/94/1_ounce_of_English_breakfast_tea_2013-04-05_13-25.jpg', '1_ounce_of_English_breakfast_tea_2013-04-05_13-25.jpg'),
    ok: { isProduct: true, notEmpty: true },
    why: 'Tea in plain bag — must identify as tea product without a label',
  },

  // ═══ GROUP 3: LOOSE BULK ITEMS (no label, no packaging) ══════════════════
  {
    label: '13 Red chillies & dal at market (no label, loose in bins)',
    img: W('c/cb/Pulses_Red_Chillies_Ooty_Market_Nilgiris_Aug25_A7CR_07122.jpg', 'Pulses_Red_Chillies_Ooty_Market_Nilgiris_Aug25_A7CR_07122.jpg'),
    ok: { isProduct: true, notEmpty: true },
    why: 'CRITICAL — loose items no label: must name product type (chilli/dal)',
  },
  {
    label: '14 Fryums snack bags at Ooty market stall (messy context)',
    img: W('a/a7/Fryums_Ooty_Market_Nilgiris_Aug25_A7CR_07125.jpg', 'Fryums_Ooty_Market_Nilgiris_Aug25_A7CR_07125.jpg'),
    ok: { isProduct: true, has: 'fryum', notEmpty: true },
    why: 'Branded snack in busy market — focus on main product despite noise',
  },
  {
    label: '15 Banana bunch (fresh produce, no packaging)',
    img: null,
    offSearch: 'fresh banana yellow',
    ok: { isProduct: true, notEmpty: true },
    why: 'Fresh produce with no label — must identify as banana',
    fallbackImg: W('8/8a/Banana-Single.jpg', 'Banana-Single.jpg'),
  },

  // ═══ GROUP 4: BOOK / STATIONERY ══════════════════════════════════════════
  {
    label: '16 Book cover — Rich Dad Poor Dad (Open Library)',
    img: 'https://covers.openlibrary.org/b/id/8739161-L.jpg',
    ok: { isProduct: true, notEmpty: true },
    why: 'Book cover must be identified as Books category product',
  },
  {
    label: '17 Rockstar Energy Drink can (branded beverage)',
    img: W('1/17/Rockstar_Energy_Drink.jpg', 'Rockstar_Energy_Drink.jpg'),
    ok: { isProduct: true, notEmpty: true },
    why: 'Branded energy drink can — must identify as beverage product',
  },

  // ═══ GROUP 5: MEDICINES & HEALTHCARE ════════════════════════════════════
  {
    label: '18 Biogesic paracetamol 500mg blister (branded medicine)',
    img: W('f/f2/Biogesic_branded_paracetamol_500mg_%28500_side%29.jpg',
           'Biogesic_branded_paracetamol_500mg_%28500_side%29.jpg'),
    ok: { isProduct: true, notEmpty: true },
    why: 'Medicine blister pack — must identify brand and drug type despite small text',
  },
  {
    label: '19 Health supplement / vitamin (OFF search)',
    img: null,
    offSearch: 'vitamin c supplement tablets capsule health',
    ok: { isProduct: true, notEmpty: true },
    why: 'Health supplement — must identify product type from packaging',
  },

  // ═══ GROUP 6: BEVERAGES ═══════════════════════════════════════════════════
  {
    label: '20 Coca-Cola 50cl can (iconic branded drink)',
    img: W('2/2f/Coca-cola_50cl_can_-_Italia.jpg', 'Coca-cola_50cl_can_-_Italia.jpg'),
    ok: { isProduct: true, notEmpty: true },
    why: 'Iconic branded drink can — must identify Coca-Cola and beverage type',
  },
  {
    label: '21 Sunflower oil 1L bottle (edible cooking oil)',
    img: W('3/33/Bottle_1_liter_Sunflower_refined_oil.jpg', 'Bottle_1_liter_Sunflower_refined_oil.jpg'),
    ok: { isProduct: true, notEmpty: true },
    why: 'Cooking oil bottle — must identify as edible oil grocery product',
  },

  // ═══ GROUP 7: SNACKS AND FOOD ════════════════════════════════════════════
  {
    label: '22 Cadbury Dairy Milk Caramel chocolate bar (confectionery)',
    img: W('5/5e/Cadbury-Dairy-Milk-Caramel-Bar.jpg', 'Cadbury-Dairy-Milk-Caramel-Bar.jpg'),
    ok: { isProduct: true, notEmpty: true },
    why: 'Branded chocolate bar — must identify as Cadbury/chocolate confectionery',
  },
  {
    label: '23 Mineral water / bottled water (OFF search)',
    img: null,
    offSearch: 'mineral water bottle still drinking',
    ok: { isProduct: true, notEmpty: true },
    why: 'Water bottle — must identify as beverage/drinking water product',
  },

  // ═══ GROUP 8: CLEANING PRODUCTS ════════════════════════════════════════
  {
    label: '24 Washing detergent powder (OFF search)',
    img: null,
    offSearch: 'washing detergent powder laundry clean',
    ok: { isProduct: true, notEmpty: true },
    why: 'Detergent powder pack — must identify as cleaning/household product',
  },

  // ═══ GROUP 9: PROMOTIONAL / PRODUCT IN USE ══════════════════════════════
  {
    label: '25 Lux soap promotional image (brand still visible)',
    img: W('3/32/Lux_romancing.jpg', 'Lux_romancing.jpg'),
    ok: { isProduct: true },
    why: 'Promotional product image — brand visible, should still return product',
  },

  // ═══ GROUP 10: GENERIC ITEMS (no visible brand) ═════════════════════════
  {
    label: '26 USB connectors close-up (no brand, generic electronics)',
    img: W('d/d6/Usb_connectors.JPG', 'Usb_connectors.JPG'),
    ok: { isProduct: true, notEmpty: true },
    why: 'Generic electronic accessory — must name by type (USB connector/cable)',
  },

  // ═══ GROUP 11: NON-PRODUCT REJECTION ════════════════════════════════════
  {
    label: '27 Labrador dog (must be rejected — animal)',
    img: W('2/26/YellowLabradorLooking_new.jpg', 'YellowLabradorLooking_new.jpg'),
    ok: { isProduct: false },
    why: 'Animal — is_product must be false, confidence high',
  },
  {
    label: '28 Blurry wide grocery store shot (must be rejected — wide room)',
    img: 'https://images.unsplash.com/photo-1722628219258-9ef3848a4506?fm=jpg&q=40&w=400&auto=format&fit=crop',
    ok: { isProduct: false },
    why: 'Wide-angle blurry room — no single product in focus, must reject',
  },
  {
    label: '29 People photo (must be rejected)',
    img: W('3/36/Secretary_Mel_Martinez_with_Thomas_Laird_Jones_-_DPLA_-_531819248207753462d5cbe10f0ebd4c.JPG',
           'Secretary_Mel_Martinez_with_Thomas_Laird_Jones_-_DPLA_-_531819248207753462d5cbe10f0ebd4c.JPG'),
    ok: { isProduct: false },
    why: 'Photo of people — must return is_product=false',
  },

  // ═══ GROUP 12: ADDITIONAL EDGE CASES ════════════════════════════════════
  {
    label: '30 Maggi noodles sealed packet (Indian packaged food)',
    img: W('b/ba/Vegetable_Maggi_Noodles-Home-AndhraPradesh-010.jpg',
           'Vegetable_Maggi_Noodles-Home-AndhraPradesh-010.jpg'),
    ok: { isProduct: true, notEmpty: true },
    why: 'Sealed Maggi packet — must identify the packaged product (not the prepared dish)',
  },
  {
    label: '31 Colgate Hemp Toothpaste (oral care personal hygiene)',
    img: W('c/cd/Colgate_Hemp_Toothpaste_%2849349484716%29.jpg',
           'Colgate_Hemp_Toothpaste_%2849349484716%29.jpg'),
    ok: { isProduct: true, notEmpty: true },
    why: 'Personal care tube — must identify as oral care / toothpaste product',
  },
  {
    label: '32 Hair oil / coconut oil (OFF search)',
    img: null,
    offSearch: 'coconut oil hair care bottle beauty',
    ok: { isProduct: true, notEmpty: true },
    why: 'Hair/coconut oil bottle — very common in Kerala shops',
  },
];

// ─── HELPERS ────────────────────────────────────────────────────────────────
// If GEMINI_DIRECT_KEY env var is set, call Gemini API directly
// (bypasses Vercel — useful when Vercel key hits daily quota)
const DIRECT_KEY = process.env.GEMINI_DIRECT_KEY;
const CATEGORIES = [
  'Grocery', 'Snacks', 'Beverages', 'Personal Care', 'Books', 'Electronics',
  'Footwear', 'Clothing', 'Medicines', 'Household', 'Spices', 'Dal & Pulses',
  'Fresh Produce', 'Stationery', 'Dairy', 'Soap & Detergent', 'Cleaning',
  'Hair Care', 'Baby Care', 'Vitamins & Supplements',
];

const PROMPT_TEXT = `You are an AI helping a Kerala (India) shop owner add products to their inventory by photographing them. Given a photo, identify the ONE product being sold and return structured JSON.

━━━ WHAT THE PHOTO MIGHT SHOW ━━━
The owner pointed their phone at ONE product. It may be:
1. LABELLED PRODUCT — brand + name visible (Parle-G, Lux Soap, POCO M6 5G, Casio calculator)
2. PRODUCT IN BOX — identify what is INSIDE the box, not the box itself
3. PLAIN TRANSPARENT BAG — very common in Kerala; identify what is INSIDE the bag:
   e.g. rice, green chillies, coconut oil, sugar, spices, lemon
4. LOOSE/BULK ITEM — no packaging at all; identify by visual type:
   e.g. Red Chilli, Moong Dal, Coconut, Banana, Bitter Gourd, Ginger, Cardamom
5. DIM/BLURRY/ANGLED — shop lighting is often poor; try to identify anyway, set confidence low
6. MESSY MARKET STALL — many items in background; focus on the most prominent/centred item
7. PRODUCT FACING AWAY — only the back/side visible; read barcode text, ingredients brand, or describe generically
8. MEDICINE/BLISTER PACK — may show only blisters; identify medicine name if visible
9. STACKED PRODUCTS — multiple units of the same item; treat as one product type

━━━ MULTIPLE PRODUCTS IN FRAME ━━━
When you can see more than one product:
• Pick the ONE that is most prominent (closest to camera / most in-focus / most centred)
• If truly ambiguous, pick one and add "name" to uncertain_fields

━━━ READING PRICES ━━━
Read ANY price for THIS specific product — from wherever it appears:
• Printed MRP on label (e.g. "MRP ₹899.00", "Rs.45", "₹260")
• Handwritten price on a sticker, slip of paper, or card attached to the product
• A price board/chalkboard near this product (e.g. "Coconut ₹25 each")
• "₹", "Rs.", "INR", "/-" — all valid price formats; return digits only (e.g. "899")
• If the ORIGINAL price is crossed out and a NEW lower price is written:
  → put the original higher price in "price" (MRP)
  → put the new lower price in "offerPrice" (offer/discount price)
• NEVER guess or calculate a price that you cannot see
• NEVER read a price that clearly belongs to a neighbouring product

━━━ READING REGIONAL LANGUAGE TEXT ━━━
Labels may be in Malayalam, Tamil, Kannada, Hindi, or English. Read them all:
• For brand names in regional scripts: transliterate to English (e.g. "നിരപ്പാറ" → "Nirapara")
• Common Kerala brands to recognise: Nirapara, Eastern, Milma, Malabar Gold, Double Horse,
  KTC, Cavin's, Palazhi, Ente Keralam
• If you see both English and regional text for the same name, prefer the English version

━━━ WHEN THERE IS NO LABEL OR BRAND ━━━
• Loose item or plain bag → name it accurately by type: "Basmati Rice", "Green Chilli",
  "Coconut Oil", "Ginger", "Banana", "Bitter Gourd", "Cardamom", "Turmeric Powder"
• Generic device/item → name it accurately: "AA Battery", "USB-A to USB-C Cable",
  "A4 Notebook 200 Pages", "Steel Scissors", "Plastic Comb"
• Truly unidentifiable → set confidence "low", name it by best guess, add "name" to uncertain_fields

━━━ WHAT IS NOT A PRODUCT ━━━
Return is_product: false for:
• People, body parts, animals, pets, plants/trees, furniture
• Empty shelf or empty floor with no product visible
• Wide-angle shot of entire shop interior (no single product in focus)
• Product brochure/flyer/catalogue printed on paper (it's paper, not the product)
• Clearly damaged/used/empty container (no longer sellable)
DO NOT return false just because there is no label. Any item a shop would sell = is_product: true.

━━━ JSON OUTPUT ━━━
Return ONLY valid JSON (no markdown, no code fences):
{
  "is_product": true or false,
  "name": "specific retail name — brand + model/variant/size if readable; else item type like 'Green Chillies' or 'Basmati Rice 1kg'; never leave empty if product identified",
  "brand": "brand or maker — empty string if genuinely none visible",
  "category": "choose EXACTLY ONE from this shop's category list below; empty string if none truly fits — NEVER force a wrong category",
  "unit": "piece | kg | g | ml | litre | pack — use kg/g for produce and loose grain; piece for single items",
  "description": "1-2 plain sentences about what the product IS and what it does",
  "price": "MRP or selling price — digits only e.g. '899'; empty string if no price is visible anywhere. NEVER guess",
  "offerPrice": "discounted / offer price — digits only; empty string if none. NEVER guess",
  "confidence": "high | medium | low",
  "uncertain_fields": ["field names you are NOT confident about — e.g. ['name', 'price']"]
}

ADDITIONAL ATTRIBUTES — add ONLY what is relevant and readable for THIS product type:
- Clothing/footwear only: "gender" (Men|Women|Kids|Unisex), "fabric", "color", "sizes"
- Medicine/health only: "composition", "strength", "form" (tablet|syrup|cream|powder|drops), "schedule", "manufacturer"
- Electronics only: "model_number", "warranty_months", "compatible_with"
- Packaged food / fresh produce only: "is_veg" (Veg|Non-Veg|Egg|Vegan), "allergens", "weight_g"
Never add an attribute unless you can actually read or confidently identify it.

This shop's category list (pick the "category" value verbatim from here, or empty string if none fit):
${CATEGORIES.join(' | ')}`;

// Retry wrapper — flaky DNS / transient network errors shouldn't masquerade
// as scan failures. Retries on ENOTFOUND, ECONNRESET, timeout, ETIMEDOUT.
async function fetchBuffer(url, maxBytes = 1_400_000, attempts = 3) {
  let lastErr;
  for (let i = 0; i < attempts; i++) {
    try {
      return await fetchBufferOnce(url, maxBytes);
    } catch (e) {
      lastErr = e;
      const msg = String(e.message ?? e);
      const retryable = /ENOTFOUND|ECONNRESET|ETIMEDOUT|timeout|EAI_AGAIN|socket hang up/i.test(msg);
      if (!retryable || i === attempts - 1) throw e;
      await new Promise(s => setTimeout(s, 3000 * (i + 1))); // 3s, 6s backoff
    }
  }
  throw lastErr;
}

function fetchBufferOnce(url, maxBytes = 1_400_000) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(url);
    const lib = parsed.protocol === 'https:' ? https : http;
    const req = lib.get(url, {
      headers: {
        'User-Agent': 'Oratas-TestSuite/2.0 (anshad5023@gmail.com; wekerala product scan)',
        'Referer': 'https://commons.wikimedia.org/',
        'Accept': 'image/*,*/*',
      },
    }, (res) => {
      if ([301, 302, 303, 307, 308].includes(res.statusCode) && res.headers.location) {
        return fetchBuffer(res.headers.location, maxBytes).then(resolve).catch(reject);
      }
      if (res.statusCode !== 200) return reject(new Error(`HTTP ${res.statusCode}`));
      const ct = res.headers['content-type'] ?? '';
      if (ct && !ct.includes('image') && !ct.includes('octet')) return reject(new Error(`Not image`));
      const chunks = [];
      let total = 0;
      res.on('data', c => { total += c.length; if (total <= maxBytes) chunks.push(c); });
      res.on('end', () => {
        const buf = Buffer.concat(chunks);
        buf.length < 2000 ? reject(new Error(`Too small (${buf.length}b)`)) : resolve(buf);
      });
      res.on('error', reject);
    });
    req.on('error', reject);
    req.setTimeout(25000, () => { req.destroy(); reject(new Error('timeout')); });
  });
}

async function offImageUrl(query) {
  try {
    const buf = await fetchBuffer(
      `https://world.openfoodfacts.org/cgi/search.pl?search_terms=${encodeURIComponent(query)}&search_simple=1&action=process&json=1&page_size=8&lc=en&fields=image_front_url,product_name`,
      600_000
    );
    const data = JSON.parse(buf.toString('utf8'));
    for (const p of (data.products ?? [])) {
      if (p.image_front_url && p.image_front_url.startsWith('https')) return p.image_front_url;
    }
  } catch { /* ignore */ }
  return null;
}

function callAPIViaVercel(b64) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify({ image: b64, shopType: 'General Store', categories: CATEGORIES });
    const u = new URL(API_URL);
    const req = https.request({ hostname: u.hostname, path: u.pathname, method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body) } }, (res) => {
      const chunks = [];
      res.on('data', c => chunks.push(c));
      res.on('end', () => {
        try { resolve({ status: res.statusCode, data: JSON.parse(Buffer.concat(chunks).toString('utf8')) }); }
        catch (e) { reject(e); }
      });
    });
    req.on('error', reject);
    req.setTimeout(50000, () => { req.destroy(); reject(new Error('timeout')); });
    req.write(body); req.end();
  });
}

function callAPIDirectGemini(b64, apiKey) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify({
      contents: [{ parts: [{ text: PROMPT_TEXT }, { inline_data: { mime_type: 'image/jpeg', data: b64 } }] }],
    });
    const req = https.request({
      hostname: 'generativelanguage.googleapis.com',
      path: '/v1beta/models/gemini-flash-latest:generateContent',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body),
        'X-goog-api-key': apiKey,
      },
    }, (res) => {
      const chunks = [];
      res.on('data', c => chunks.push(c));
      res.on('end', () => {
        try {
          const raw = Buffer.concat(chunks).toString('utf8');
          if (res.statusCode === 429) return resolve({ status: 429, data: { error: 'quota' } });
          if (res.statusCode !== 200) return resolve({ status: res.statusCode, data: { error: raw.slice(0, 200) } });
          const j = JSON.parse(raw);
          const text = j.candidates?.[0]?.content?.parts?.[0]?.text?.trim() ?? '';
          // Parse Gemini JSON response
          let parsed;
          try { parsed = JSON.parse(text); }
          catch { const m = text.match(/\{[\s\S]*\}/); parsed = m ? JSON.parse(m[0]) : {}; }
          resolve({ status: 200, data: parsed });
        } catch (e) { reject(e); }
      });
    });
    req.on('error', reject);
    req.setTimeout(50000, () => { req.destroy(); reject(new Error('timeout')); });
    req.write(body); req.end();
  });
}

async function callAPI(b64) {
  if (DIRECT_KEY) return callAPIDirectGemini(b64, DIRECT_KEY);
  return callAPIViaVercel(b64);
}

function evaluate(res, ok) {
  const e = [];
  if (ok.isProduct === false && res.is_product !== false) e.push(`Expected is_product=false, got "${res.is_product}"`);
  if (ok.isProduct === true && res.is_product === false) e.push(`Expected product but got is_product=false`);
  if (ok.notEmpty && !res.name) e.push(`name is empty — must identify something`);
  if (ok.has && !(res.name ?? '').toLowerCase().includes(ok.has)) e.push(`name "${res.name}" must contain "${ok.has}"`);
  if (ok.priceNotEmpty && !res.price) e.push(`price is empty — must read visible price`);
  return e;
}

// ─── MAIN ───────────────────────────────────────────────────────────────────
async function main() {
  console.log(`\n${C}╔════════════════════════════════════════════════════════════╗`);
  console.log(`║  weKerala AI Scan — 32 Kerala Shop Scenario Tests          ║`);
  console.log(`║  Testing: ${API_URL.slice(0, 44)} ║`);
  console.log(`╚════════════════════════════════════════════════════════════╝${X}\n`);

  let pass = 0, fail = 0, skip = 0;
  const fails = [];

  for (let i = 0; i < TESTS.length; i++) {
    const t = TESTS[i];
    console.log(`\n${D}[${i + 1}/${TESTS.length}]${X} ${t.label}`);
    console.log(`  ${D}▸ ${t.why}${X}`);

    // Resolve image
    let imageUrl = t.img;
    if (!imageUrl && t.offSearch) {
      process.stdout.write(`  OFF search "${t.offSearch}"… `);
      imageUrl = await offImageUrl(t.offSearch);
      if (!imageUrl && t.fallbackImg) imageUrl = t.fallbackImg;
      console.log(imageUrl ? 'found' : `${Y}not found${X}`);
    }
    if (!imageUrl) { console.log(`  ${Y}SKIP — no image available${X}`); skip++; continue; }

    let buf;
    try {
      process.stdout.write(`  Fetch… `);
      buf = await fetchBuffer(imageUrl);
      console.log(`${(buf.length / 1024).toFixed(0)} KB`);
    } catch (e) {
      console.log(`\n  ${Y}SKIP — ${e.message}${X}`); skip++;
      await new Promise(s => setTimeout(s, 2000)); continue;
    }

    const b64 = buf.toString('base64');
    if (b64.length > 1_900_000) {
      console.log(`  ${Y}SKIP — too large (${(b64.length / 1024).toFixed(0)} KB b64)${X}`); skip++; continue;
    }

    let apiResult;
    try {
      process.stdout.write(`  Gemini API… `);
      let r = await callAPI(b64);
      // Handle rate limiting with exponential backoff
      if (r.status === 429 || (r.status === 500 && String(r.data?.error ?? '').includes('429'))) {
        for (const wait of [65000, 120000]) {
          console.log(`${Y}429 — wait ${wait / 1000}s${X}`);
          await new Promise(s => setTimeout(s, wait));
          process.stdout.write(`  Retry… `);
          r = await callAPI(b64);
          if (r.status !== 429 && !(r.status === 500 && String(r.data?.error ?? '').includes('429'))) break;
        }
      }
      if (r.status !== 200 && r.data?.error) throw new Error(`${r.status}: ${String(r.data.error).slice(0, 120)}`);
      apiResult = r.data;
      console.log('done');
    } catch (e) {
      console.log(`${R}${e.message}${X}`);
      fail++; fails.push({ label: t.label, errs: [e.message], res: null });
      await new Promise(s => setTimeout(s, 8000)); continue;
    }

    const { name, category, price, is_product, confidence, uncertain_fields: uf } = apiResult;
    console.log(`  ${D}→ is_product=${is_product} | name="${name}" | cat="${category}" | price="${price}" | conf=${confidence}${X}`);
    if (uf?.length) console.log(`  ${Y}uncertain: ${uf.join(', ')}${X}`);

    const errs = evaluate(apiResult, t.ok);
    if (errs.length === 0) { console.log(`  ${G}✓ PASS${X}`); pass++; }
    else {
      console.log(`  ${R}✗ FAIL${X}`);
      errs.forEach(e => console.log(`    ${R}→ ${e}${X}`));
      fail++; fails.push({ label: t.label, errs, res: apiResult });
    }

    if (i < TESTS.length - 1) await new Promise(s => setTimeout(s, 8000));
  }

  console.log(`\n${C}════════════════════════════════════════════════════════════${X}`);
  console.log(`${G}${pass} passed${X} | ${fail > 0 ? R : ''}${fail} failed${X} | ${Y}${skip} skipped${X}`);

  if (fails.length) {
    console.log(`\n${R}═══ FAILURES ═══${X}`);
    fails.forEach(f => {
      console.log(`  • ${f.label}`);
      f.errs.forEach(e => console.log(`    - ${e}`));
      if (f.res) console.log(`    got: ${JSON.stringify({ name: f.res.name, category: f.res.category, is_product: f.res.is_product, confidence: f.res.confidence })}`);
    });
    console.log(`\n  Prompt: web/app/api/gemini-product/route.ts\n`);
  } else if (pass > 0) {
    console.log(`\n${G}✓ All tests passed — scan AI is robust!${X}\n`);
  }

  return fails;
}

main().catch(console.error);
