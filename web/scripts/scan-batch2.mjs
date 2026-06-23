/**
 * scan-batch2.mjs — harder Kerala shop scenarios (batch 2)
 * Loose produce, spices, fish varieties, fancy shop products.
 */
import fs from 'fs';
import os from 'os';

// Keys come from GEMINI_DIRECT_KEY env var (same as test-scan.mjs)
// Usage: GEMINI_DIRECT_KEY=key1,key2 node web/scripts/scan-batch2.mjs
const KEYS = (process.env.GEMINI_DIRECT_KEY ?? '').split(',').map(k => k.trim()).filter(Boolean);
let keyIdx = 0;
const CATS = 'Grocery | Snacks | Beverages | Personal Care | Medicines | Household | Spices | Dal & Pulses | Fresh Produce | Stationery | Dairy | Soap & Detergent | Hair Care | Fish & Meat | Kitchen & Utensils | Hardware & Tools | Cosmetics | Footwear | Clothing | Electronics';

const routeSrc = fs.readFileSync('web/app/api/gemini-product/route.ts', 'utf8');
const pm = routeSrc.match(/return `([\s\S]*?)\$\{hint\}`/);
const PROMPT = (pm ? pm[1] : '') + `\n\nShop category list: ${CATS}`;

async function fetchRetry(url, opts = {}, n = 5) {
  for (let i = 0; i < n; i++) {
    try { return await fetch(url, opts); }
    catch { await new Promise(x => setTimeout(x, 5000 * (i + 1))); }
  }
  throw new Error('max retries');
}

async function getCommons(query) {
  const url = 'https://commons.wikimedia.org/w/api.php?action=query&generator=search' +
    '&gsrsearch=' + encodeURIComponent(query) + '&gsrnamespace=6&gsrlimit=15' +
    '&prop=imageinfo&iiprop=url|mime&iiurlwidth=500&format=json';
  const DISH_RX = /curry|mutton|biryani|cooked|fried|recipe|plate|bowl|meal|restaurant|cafe|prepared|stew|soup|salad|sauce|garnish|_curry|_masala|_fry|_rice_dish|skewer|grill|bbq|barbecue|roast|baked|roasted|grilled|smoked|_food_|street_food|cake|pastry|dessert|pudding|pizza|burger|sandwich/i;
  try {
    const d = await fetchRetry(url).then(r => r.json());
    for (const p of Object.values(d.query?.pages ?? {})) {
      const ii = p.imageinfo?.[0];
      if (!ii?.thumburl || !/jpe?g/i.test(ii.mime ?? '')) continue;
      if (/logo|icon|svg|diagram|map|chart/i.test(ii.thumburl)) continue;
      if (DISH_RX.test(ii.thumburl)) continue;   // skip cooked food dishes
      return ii.thumburl;
    }
  } catch {}
  return null;
}

async function scanBuf(buf) {
  for (let attempt = 0; attempt < KEYS.length * 3; attempt++) {
    const key = KEYS[keyIdx % KEYS.length];
    let r;
    try {
      r = await fetchRetry('https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-goog-api-key': key },
        body: JSON.stringify({
          contents: [{ parts: [{ text: PROMPT }, { inline_data: { mime_type: 'image/jpeg', data: buf.toString('base64') } }] }]
        }),
      });
    } catch { await new Promise(x => setTimeout(x, 8000)); continue; }
    if (r.status === 429) { keyIdx++; await new Promise(x => setTimeout(x, 12000)); continue; }
    if (r.status === 503) { await new Promise(x => setTimeout(x, 12000)); continue; }
    if (!r.ok) return { error: 'HTTP ' + r.status };
    const j = await r.json();
    const text = j.candidates?.[0]?.content?.parts?.[0]?.text?.trim() ?? '';
    try { return JSON.parse(text); }
    catch { const m = text.match(/\{[\s\S]*\}/); return m ? JSON.parse(m[0]) : { raw: text.slice(0, 120) }; }
  }
  return { error: 'exhausted' };
}

const TESTS = [
  ['Coconut whole (Kerala staple)', 'coconut palm fruit husk brown', '23-coconut.jpg', true],
  ['Bitter gourd (karela)', 'bitter gourd vegetable market', '24-bittergourd.jpg', true],
  ['Ginger root loose', 'ginger root fresh market', '25-ginger.jpg', true],
  ['Jackfruit whole tropical', 'jackfruit whole tropical fruit', '26-jackfruit.jpg', true],
  ['Cardamom pods spice', 'cardamom pods green spice', '27-cardamom.jpg', true],
  ['Black pepper pile', 'black pepper corns pile Kerala', '28-pepper.jpg', true],
  ['Red lentils dal pile', 'red lentils dry raw masoor dal uncooked', '29-dal.jpg', true],
  ['White rice grains', 'rice grains white pile', '30-rice.jpg', true],
  ['Lipstick cosmetics', 'lipstick product beauty', '31-lipstick.jpg', true],
  ['Nail polish bottle', 'nail polish bottle color beauty', '32-nailpolish.jpg', true],
  ['Dove shampoo bottle', 'Dove shampoo bottle personal care', '33-shampoo.jpg', true],
  ['Colgate toothpaste', 'Colgate toothpaste tube red white dental', '34-colgate.jpg', true],
  ['Sugar packaged bag', 'sugar white packaged 1kg', '35-sugar.jpg', true],
  ['Tea leaves Red Label', 'tea leaves Red Label Brooke Bond', '36-tea.jpg', true],
  ['Spiral notebook', 'spiral notebook stationery school', '37-notebook.jpg', true],
  ['Ballpoint pen', 'ballpoint pen write', '38-pen.jpg', true],
  ['Cat portrait (REJECT)', 'domestic cat pet portrait', '39-cat-reject.jpg', false],
  ['Potted plant (REJECT)', 'potted houseplant indoor', '40-plant-reject.jpg', false],
  ['Prawns seafood fresh', 'prawns raw fresh seafood uncooked', '42-prawns.jpg', true],
  ['Sardine fish fresh', 'sardine fish fresh market India', '43-sardine.jpg', true],
  ['Cough syrup bottle', 'cough syrup medicine bottle', '44-syrup.jpg', true],
  // Kerala shop edge case: cooked dish — shop owner accidentally photographed food
  // Uses the 11-turmeric.jpg already downloaded (Odia mutton curry image)
  // AI must say is_product:false because it is a cooked dish, not a sellable item
];

if (!fs.existsSync('test image')) fs.mkdirSync('test image');

let pass = 0, fail = 0, skip = 0;
const failures = [];

console.log('\n╔══════════════════════════════════════════════════╗');
console.log('║  BATCH 2 — Harder Kerala Scenarios              ║');
console.log('║  Loose produce · spices · fish · fancy shop     ║');
console.log(`╚══════════════════════════════════════════════════╝\n`);

for (let i = 0; i < TESTS.length; i++) {
  const [label, q, file, expectProduct] = TESTS[i];
  console.log(`[${i + 1}/${TESTS.length}] ${label}`);

  const imgUrl = await getCommons(q);
  if (!imgUrl) { console.log('  SKIP — no image\n'); skip++; continue; }
  console.log('  url:', imgUrl.slice(0, 90));

  let buf;
  try {
    const r = await fetchRetry(imgUrl, { headers: { 'User-Agent': 'Oratas/1.0', 'Referer': 'https://commons.wikimedia.org/' } });
    buf = Buffer.from(await r.arrayBuffer());
  } catch (e) { console.log('  SKIP — download:', e.message, '\n'); skip++; continue; }

  fs.writeFileSync(`test image/${file}`, buf);
  console.log('  saved:', file, Math.round(buf.length / 1024) + 'KB');

  const res = await scanBuf(buf);
  if (res.error) { console.log('  ERROR:', res.error, '\n'); fail++; continue; }

  const gotProduct = res.is_product !== false;
  const name = res.name ?? '';
  console.log('  →', gotProduct ? 'PRODUCT' : 'NOT PRODUCT', '|', name || '(empty)', '|', res.category, '| conf:', res.confidence);

  const ok = (gotProduct === expectProduct) && (!expectProduct || name.length > 0);
  if (ok) {
    console.log('  ✓ PASS\n');
    pass++;
  } else {
    const why = gotProduct !== expectProduct
      ? `expected is_product=${expectProduct}, got ${res.is_product}`
      : 'name is empty';
    console.log(`  ✗ FAIL — ${why}\n`);
    fail++;
    failures.push({ label, why, res, file });
  }

  if (i < TESTS.length - 1) await new Promise(r => setTimeout(r, 7000));
}

console.log('='.repeat(52));
console.log(`Batch 2: ${pass} PASS | ${fail} FAIL | ${skip} SKIP  (of ${TESTS.length})`);

if (failures.length) {
  console.log('\nFAILURES needing prompt fix:');
  failures.forEach(f => {
    console.log(`  ✗ ${f.label}`);
    console.log(`    ${f.why}`);
    console.log(`    AI said: name="${f.res.name}" is_product=${f.res.is_product} conf=${f.res.confidence}`);
  });
}

if (failures.length) {
  const failPath = `test image/scan-failures.json`;
  const prev = (() => {
    try { return JSON.parse(fs.readFileSync(failPath, 'utf8')); } catch { return []; }
  })();
  fs.writeFileSync(failPath, JSON.stringify([...prev, ...failures], null, 2));
  console.log('\nFailures saved to:', failPath);
}
console.log('\nImages saved to: test image/');
