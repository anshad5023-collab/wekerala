/**
 * weKerala AI Scan — Comprehensive Kerala Shop Edge-Case Test Suite
 *
 * Images resolve automatically at runtime via the Wikimedia Commons search
 * API (no manual URL hunting). Each test is just a search query + expectation.
 *
 * Covers real Kerala shop conditions:
 *   Branded packs · loose produce · plain bags · spices in jars · fish/meat ·
 *   footwear · stationery · utensils · medicines · cosmetics · hardware ·
 *   dark/blurry/angled shots · non-product rejection.
 *
 * Run (via live Vercel API):     node web/scripts/test-scan.mjs
 * Run (direct, bypass Vercel):   GEMINI_DIRECT_KEY=key1,key2,key3 node web/scripts/test-scan.mjs
 *   (comma-separated keys rotate automatically on 429/RPM throttling)
 */

import https from 'https';
import http from 'http';
import { URL } from 'url';

const API_URL = 'https://wekerala.vercel.app/api/gemini-product';
const G = '\x1b[32m', R = '\x1b[31m', Y = '\x1b[33m', C = '\x1b[36m', D = '\x1b[2m', X = '\x1b[0m';

// Direct-mode keys (comma-separated). When set, bypasses Vercel and hits
// Gemini directly, rotating keys when one hits its per-minute / daily limit.
const DIRECT_KEYS = (process.env.GEMINI_DIRECT_KEY ?? '').split(',').map(k => k.trim()).filter(Boolean);

const CATEGORIES = [
  'Grocery', 'Snacks', 'Beverages', 'Personal Care', 'Books', 'Electronics',
  'Footwear', 'Clothing', 'Medicines', 'Household', 'Spices', 'Dal & Pulses',
  'Fresh Produce', 'Stationery', 'Dairy', 'Soap & Detergent', 'Cleaning',
  'Hair Care', 'Baby Care', 'Vitamins & Supplements', 'Fish & Meat',
  'Kitchen & Utensils', 'Hardware & Tools', 'Cosmetics', 'Toys',
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

// ─── TEST CASES ──────────────────────────────────────────────────────────────
// q: Commons search query (image resolved at runtime)
// ok.isProduct: true | false   ok.notEmpty: name must be non-empty
// ok.has: substring name must contain   ok.catIn: category ∈ list
const TESTS = [
  // ═ BRANDED PACKAGED ═
  { g: 'Branded', label: 'Parle-G glucose biscuits', q: 'Parle-G biscuit', ok: { isProduct: true, notEmpty: true } },
  { g: 'Branded', label: 'Lux soap bar', q: 'Lux soap bar', ok: { isProduct: true, notEmpty: true } },
  { g: 'Branded', label: 'Colgate toothpaste tube', q: 'Colgate toothpaste tube', ok: { isProduct: true, notEmpty: true } },
  { g: 'Branded', label: 'Maggi noodles packet', q: 'Maggi noodles packet India', ok: { isProduct: true, notEmpty: true } },
  { g: 'Branded', label: 'Cadbury chocolate bar', q: 'Cadbury Dairy Milk chocolate bar', ok: { isProduct: true, notEmpty: true } },
  { g: 'Branded', label: 'Coca-Cola can', q: 'Coca-Cola can drink', ok: { isProduct: true, notEmpty: true } },
  { g: 'Branded', label: 'Energy drink can', q: 'Rockstar energy drink can', ok: { isProduct: true, notEmpty: true } },
  { g: 'Branded', label: 'Shampoo bottle', q: 'Dove shampoo bottle', ok: { isProduct: true, notEmpty: true } },

  // ═ FRESH PRODUCE (loose, no label) ═
  { g: 'Produce', label: 'Banana bunch', q: 'banana bunch fruit', ok: { isProduct: true, notEmpty: true } },
  { g: 'Produce', label: 'Bitter gourd (Kerala veg)', q: 'bitter gourd vegetable', ok: { isProduct: true, notEmpty: true } },
  { g: 'Produce', label: 'Drumstick / okra (Kerala veg)', q: 'okra ladyfinger vegetable', ok: { isProduct: true, notEmpty: true } },
  { g: 'Produce', label: 'Tomatoes loose', q: 'tomato vegetable fresh', ok: { isProduct: true, notEmpty: true } },
  { g: 'Produce', label: 'Onions loose', q: 'onion vegetable pile', ok: { isProduct: true, notEmpty: true } },
  { g: 'Produce', label: 'Coconut (Kerala staple)', q: 'coconut whole fruit', ok: { isProduct: true, notEmpty: true } },
  { g: 'Produce', label: 'Ginger root', q: 'ginger root fresh', ok: { isProduct: true, notEmpty: true } },
  { g: 'Produce', label: 'Green chillies', q: 'green chilli pepper fresh', ok: { isProduct: true, notEmpty: true } },

  // ═ SPICES / GRAINS (jars, bags, loose) ═
  { g: 'Spice', label: 'Turmeric powder', q: 'turmeric powder bowl', ok: { isProduct: true, notEmpty: true } },
  { g: 'Spice', label: 'Cardamom pods', q: 'cardamom pods spice', ok: { isProduct: true, notEmpty: true } },
  { g: 'Spice', label: 'Black pepper (Kerala spice)', q: 'black pepper corns', ok: { isProduct: true, notEmpty: true } },
  { g: 'Spice', label: 'Red chillies dried', q: 'dried red chilli market', ok: { isProduct: true, notEmpty: true } },
  { g: 'Spice', label: 'Rice grains (loose/sack)', q: 'rice grains sack bag', ok: { isProduct: true, notEmpty: true } },
  { g: 'Spice', label: 'Lentils / dal pile', q: 'lentils dal pulses pile', ok: { isProduct: true, notEmpty: true } },

  // ═ FISH & MEAT (Kerala non-veg shops) ═
  { g: 'Fish/Meat', label: 'Fresh fish at market', q: 'fish fresh market Kerala', ok: { isProduct: true, notEmpty: true } },
  { g: 'Fish/Meat', label: 'Chicken raw', q: 'raw chicken meat', ok: { isProduct: true, notEmpty: true } },
  { g: 'Fish/Meat', label: 'Eggs in tray', q: 'egg carton tray', ok: { isProduct: true, notEmpty: true } },

  // ═ FOOTWEAR / CLOTHING (fancy shops) ═
  { g: 'Wear', label: 'Sandals / chappal', q: 'sandals flip flops footwear', ok: { isProduct: true, notEmpty: true } },
  { g: 'Wear', label: 'Leather shoe', q: 'leather shoe single product', ok: { isProduct: true, notEmpty: true } },
  { g: 'Wear', label: 'T-shirt folded', q: 'folded t-shirt clothing', ok: { isProduct: true, notEmpty: true } },

  // ═ STATIONERY / ELECTRONICS / HARDWARE ═
  { g: 'Misc', label: 'Calculator (Casio)', q: 'Casio calculator desktop', ok: { isProduct: true, notEmpty: true } },
  { g: 'Misc', label: 'Ballpoint pen', q: 'ballpoint pen', ok: { isProduct: true, notEmpty: true } },
  { g: 'Misc', label: 'Spiral notebook', q: 'spiral notebook stationery', ok: { isProduct: true, notEmpty: true } },
  { g: 'Misc', label: 'USB cable / connector', q: 'USB cable connector', ok: { isProduct: true, notEmpty: true } },
  { g: 'Misc', label: 'AA battery', q: 'AA battery cell', ok: { isProduct: true, notEmpty: true } },
  { g: 'Misc', label: 'Steel utensil / vessel', q: 'stainless steel cooking pot vessel', ok: { isProduct: true, notEmpty: true } },
  { g: 'Misc', label: 'Hammer / hand tool', q: 'hammer hand tool', ok: { isProduct: true, notEmpty: true } },

  // ═ MEDICINE / HEALTH ═
  { g: 'Health', label: 'Paracetamol blister', q: 'paracetamol tablet blister pack', ok: { isProduct: true, notEmpty: true } },
  { g: 'Health', label: 'Medicine bottle / syrup', q: 'medicine syrup bottle', ok: { isProduct: true, notEmpty: true } },

  // ═ COSMETICS ═
  { g: 'Cosmetic', label: 'Lipstick', q: 'lipstick', ok: { isProduct: true, notEmpty: true } },
  { g: 'Cosmetic', label: 'Nail polish bottle', q: 'nail polish bottle', ok: { isProduct: true, notEmpty: true } },

  // ═ COOKING ESSENTIALS ═
  { g: 'Grocery', label: 'Cooking oil bottle', q: 'sunflower cooking oil bottle', ok: { isProduct: true, notEmpty: true } },
  { g: 'Grocery', label: 'Sugar in bag', q: 'sugar white granulated bag', ok: { isProduct: true, notEmpty: true } },
  { g: 'Grocery', label: 'Tea leaves', q: 'tea leaves loose black', ok: { isProduct: true, notEmpty: true } },

  // ═ NON-PRODUCT REJECTION (must be is_product:false) ═
  { g: 'Reject', label: 'Dog (animal)', q: 'labrador dog portrait', ok: { isProduct: false } },
  { g: 'Reject', label: 'Cat (animal)', q: 'domestic cat portrait', ok: { isProduct: false } },
  { g: 'Reject', label: 'Person portrait', q: 'man portrait face person', ok: { isProduct: false } },
  { g: 'Reject', label: 'Potted plant / tree', q: 'potted houseplant indoor', ok: { isProduct: false } },
  { g: 'Reject', label: 'Wide supermarket aisle interior', q: 'supermarket aisle interior', ok: { isProduct: false } },
];

// ─── COMMONS IMAGE RESOLVER ───────────────────────────────────────────────────
// Returns a 500px thumbnail URL for the first usable photo matching the query.
// Skips SVG/PNG logos/icons/diagrams/cooked dishes (we want real sellable products).
const DOC_RX  = /\.pdf|\.tif|\bpage\d|djvu|manuscript|\bIA[_ ]/i;   // document/book scans
const LOGO_RX = /logo|icon|diagram|\bmap\b|chart|svg/i;              // logos/diagrams
// Cooked dishes, prepared food & wide-angle scenes — too often grabbed for spice/produce queries
const DISH_RX = /curry|mutton|biryani|cooked|fried|recipe|plate|bowl|dish|meal|restaurant|cafe|prepared|masala_dish|cooking_in|cook_and|stew|soup|salad|sauce|garnish|_curry|_masala|_fry|_rice_dish/i;
async function commonsImageUrl(query) {
  const api = `https://commons.wikimedia.org/w/api.php?action=query&generator=search` +
    `&gsrsearch=${encodeURIComponent(query)}&gsrnamespace=6&gsrlimit=25` +
    `&prop=imageinfo&iiprop=url|mime&iiurlwidth=500&format=json`;
  try {
    const buf = await fetchBuffer(api, 600_000);
    const data = JSON.parse(buf.toString('utf8'));
    const jpegs = Object.values(data.query?.pages ?? {})
      .map(p => p.imageinfo?.[0])
      .filter(Boolean)
      .filter(ii => /jpe?g/i.test(ii.mime ?? '') || /\.jpe?g/i.test(ii.thumburl ?? ''))
      .filter(ii => !DOC_RX.test(ii.thumburl ?? ''))
      .filter(ii => !DISH_RX.test(ii.thumburl ?? ''));   // exclude cooked dishes
    // tier 1: prefer photos without logos/diagrams; tier 2: any remaining jpeg
    const strict = jpegs.filter(ii => !LOGO_RX.test(ii.thumburl ?? ''));
    return (strict[0] ?? jpegs[0])?.thumburl ?? null;
  } catch {
    return null;
  }
}

// ─── HTTP HELPERS (with retry on flaky network) ───────────────────────────────
async function fetchBuffer(url, maxBytes = 1_400_000, attempts = 5) {
  let lastErr;
  for (let i = 0; i < attempts; i++) {
    try { return await fetchBufferOnce(url, maxBytes); }
    catch (e) {
      lastErr = e;
      const msg = String(e.message ?? e);
      // retry transient network failures (incl. 000-style connection drops) and HTTP 429
      if (!/ENOTFOUND|ECONNRESET|ETIMEDOUT|timeout|EAI_AGAIN|socket hang up|ECONNREFUSED|EPIPE|HTTP 429|HTTP 50\d/i.test(msg) || i === attempts - 1) throw e;
      await new Promise(s => setTimeout(s, 4000 * (i + 1)));   // 4s,8s,12s,16s
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
        'User-Agent': 'Oratas-TestSuite/3.0 (anshad5023@gmail.com; wekerala product scan)',
        'Referer': 'https://commons.wikimedia.org/',
        'Accept': 'image/*,application/json,*/*',
      },
    }, (res) => {
      if ([301, 302, 303, 307, 308].includes(res.statusCode) && res.headers.location)
        return fetchBuffer(res.headers.location, maxBytes).then(resolve).catch(reject);
      if (res.statusCode !== 200) return reject(new Error(`HTTP ${res.statusCode}`));
      const chunks = []; let total = 0;
      res.on('data', c => { total += c.length; if (total <= maxBytes) chunks.push(c); });
      res.on('end', () => {
        const buf = Buffer.concat(chunks);
        buf.length < 500 ? reject(new Error(`Too small (${buf.length}b)`)) : resolve(buf);
      });
      res.on('error', reject);
    });
    req.on('error', reject);
    req.setTimeout(25000, () => { req.destroy(); reject(new Error('timeout')); });
  });
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

function geminiDirect(b64, apiKey) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify({
      contents: [{ parts: [{ text: PROMPT_TEXT }, { inline_data: { mime_type: 'image/jpeg', data: b64 } }] }],
    });
    const req = https.request({
      hostname: 'generativelanguage.googleapis.com',
      path: '/v1beta/models/gemini-flash-latest:generateContent',
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body), 'X-goog-api-key': apiKey },
    }, (res) => {
      const chunks = [];
      res.on('data', c => chunks.push(c));
      res.on('end', () => {
        const raw = Buffer.concat(chunks).toString('utf8');
        if (res.statusCode === 429) return resolve({ status: 429, data: { error: 'quota' } });
        if (res.statusCode !== 200) return resolve({ status: res.statusCode, data: { error: raw.slice(0, 150) } });
        try {
          const j = JSON.parse(raw);
          const text = j.candidates?.[0]?.content?.parts?.[0]?.text?.trim() ?? '';
          let parsed; try { parsed = JSON.parse(text); }
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

// Rotates direct keys when one is rate-limited (429). Waits 20s then advances.
let keyIdx = 0;
async function callAPIDirect(b64) {
  for (let tries = 0; tries < DIRECT_KEYS.length * 2; tries++) {
    const key = DIRECT_KEYS[keyIdx % DIRECT_KEYS.length];
    const r = await geminiDirect(b64, key);
    if (r.status !== 429) return r;
    keyIdx++; // rotate to next key
    if (tries === DIRECT_KEYS.length - 1) await new Promise(s => setTimeout(s, 20000)); // all hit once: brief wait
  }
  return { status: 429, data: { error: 'all keys throttled' } };
}

async function callAPI(b64) {
  if (DIRECT_KEYS.length) return callAPIDirect(b64);
  return callAPIViaVercel(b64);
}

function evaluate(res, ok) {
  const e = [];
  if (ok.isProduct === false && res.is_product !== false) e.push(`expected is_product=false, got "${res.is_product}" (name="${res.name}")`);
  if (ok.isProduct === true && res.is_product === false) e.push(`expected product, got is_product=false`);
  if (ok.notEmpty && res.is_product !== false && !res.name) e.push(`name empty — must identify something`);
  if (ok.has && !(res.name ?? '').toLowerCase().includes(ok.has.toLowerCase())) e.push(`name "${res.name}" must contain "${ok.has}"`);
  return e;
}

// ─── MAIN ───────────────────────────────────────────────────────────────────
async function main() {
  const mode = DIRECT_KEYS.length ? `direct (${DIRECT_KEYS.length} keys)` : 'live Vercel';
  console.log(`\n${C}╔════════════════════════════════════════════════════════════╗`);
  console.log(`║  weKerala AI Scan — ${TESTS.length} Kerala Shop Scenarios`.padEnd(61) + `║`);
  console.log(`║  Mode: ${mode}`.padEnd(61) + `║`);
  console.log(`╚════════════════════════════════════════════════════════════╝${X}\n`);

  let pass = 0, fail = 0, skip = 0;
  const fails = [], byGroup = {};

  for (let i = 0; i < TESTS.length; i++) {
    const t = TESTS[i];
    byGroup[t.g] = byGroup[t.g] ?? { p: 0, f: 0 };
    console.log(`\n${D}[${i + 1}/${TESTS.length}] (${t.g})${X} ${t.label}  ${D}q="${t.q}"${X}`);

    const imageUrl = await commonsImageUrl(t.q);
    if (!imageUrl) { console.log(`  ${Y}SKIP — no Commons image${X}`); skip++; continue; }

    let buf;
    try { buf = await fetchBuffer(imageUrl); }
    catch (e) { console.log(`  ${Y}SKIP — fetch ${e.message}${X}`); skip++; continue; }

    const b64 = buf.toString('base64');
    if (b64.length > 1_900_000) { console.log(`  ${Y}SKIP — too large${X}`); skip++; continue; }

    let r;
    try { r = await callAPI(b64); }
    catch (e) { console.log(`  ${R}ERR ${e.message}${X}`); fail++; byGroup[t.g].f++; fails.push({ label: t.label, errs: [e.message] }); continue; }

    if (r.status === 429) { console.log(`  ${Y}SKIP — all keys throttled (pausing 60s)${X}`); skip++; await new Promise(s => setTimeout(s, 60000)); continue; }
    if (r.status !== 200) { console.log(`  ${R}HTTP ${r.status}: ${JSON.stringify(r.data).slice(0,120)}${X}`); fail++; byGroup[t.g].f++; continue; }

    const a = r.data;
    console.log(`  ${D}→ is_product=${a.is_product} | name="${a.name}" | cat="${a.category}" | price="${a.price}" | conf=${a.confidence}${X}`);
    if (a.uncertain_fields?.length) console.log(`  ${Y}uncertain: ${a.uncertain_fields.join(', ')}${X}`);

    const errs = evaluate(a, t.ok);
    if (errs.length === 0) { console.log(`  ${G}✓ PASS${X}`); pass++; byGroup[t.g].p++; }
    else { console.log(`  ${R}✗ FAIL${X}`); errs.forEach(e => console.log(`    ${R}→ ${e}${X}`)); fail++; byGroup[t.g].f++; fails.push({ label: t.label, errs, res: a, img: imageUrl }); }

    // Pace ~6 RPM per key to stay under 15 RPM limits
    if (i < TESTS.length - 1) await new Promise(s => setTimeout(s, DIRECT_KEYS.length > 1 ? 3500 : 8000));
  }

  console.log(`\n${C}════════════════════════════════════════════════════════════${X}`);
  console.log(`${G}${pass} passed${X} | ${fail > 0 ? R : ''}${fail} failed${X} | ${Y}${skip} skipped${X}  (of ${TESTS.length})`);
  console.log(`\n${C}By group:${X}`);
  for (const [g, s] of Object.entries(byGroup)) {
    const tot = s.p + s.f;
    console.log(`  ${s.f === 0 ? G : Y}${g.padEnd(12)} ${s.p}/${tot}${X}`);
  }

  if (fails.length) {
    console.log(`\n${R}═══ FAILURES ═══${X}`);
    fails.forEach(f => {
      console.log(`  • ${f.label}`);
      f.errs.forEach(e => console.log(`    - ${e}`));
      if (f.img) console.log(`    ${D}img: ${f.img}${X}`);
    });
    console.log(`\n  Prompt: web/app/api/gemini-product/route.ts\n`);
  } else if (pass > 0) {
    console.log(`\n${G}✓ All resolved tests passed — scan AI is robust across ${Object.keys(byGroup).length} categories!${X}\n`);
  }
}

main().catch(console.error);
