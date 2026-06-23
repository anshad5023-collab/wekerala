/**
 * scan-batch3.mjs — tests pre-downloaded images from "test image/" folder
 * No Commons search needed — tests curated images directly.
 * Usage: GEMINI_DIRECT_KEY=key1,key2,key3 node web/scripts/scan-batch3.mjs
 */
import fs from 'fs';

const KEYS = (process.env.GEMINI_DIRECT_KEY ?? '').split(',').map(k => k.trim()).filter(Boolean);
let keyIdx = 0;

const CATS = 'Grocery | Snacks | Beverages | Personal Care | Medicines | Household | Spices | Dal & Pulses | Fresh Produce | Stationery | Dairy | Soap & Detergent | Hair Care | Fish & Meat | Kitchen & Utensils | Hardware & Tools | Cosmetics | Footwear | Clothing | Electronics | Bakery';

const routeSrc = fs.readFileSync('web/app/api/gemini-product/route.ts', 'utf8');
const pm = routeSrc.match(/return `([\s\S]*?)\$\{hint\}`/);
const PROMPT = (pm ? pm[1] : '') + `\n\nShop category list: ${CATS}`;

async function fetchRetry(url, opts = {}, n = 4) {
  for (let i = 0; i < n; i++) {
    try { return await fetch(url, opts); }
    catch { await new Promise(x => setTimeout(x, 5000 * (i + 1))); }
  }
  throw new Error('max retries');
}

async function scanFile(filePath) {
  const buf = fs.readFileSync(filePath);
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

// [label, file, expectProduct, notes]
const TESTS = [
  // === Kerala staples ===
  ['Jackfruit (tropical)', '26-jackfruit.jpg', true],
  ['Cardamom pods', '27-cardamom.jpg', true],
  ['Black pepper corns', '28-pepper.jpg', true],
  ['Red lentils / masoor dal', '29-dal.jpg', true],
  ['White rice grains', '30-rice.jpg', true],
  ['Rohu fish (Kerala carp)', '107-rohu.jpg', true],
  ['Mackerel (ayala)', '109-mackerel.jpg', true],
  ['Tilapia fish', '108-tilapia.jpg', true],
  ['Garlic cloves', '111-garlic.jpg', true],
  ['Sesame seeds (til)', '113-sesame.jpg', true],
  ['Mustard seeds (rai)', '114-mustard.jpg', true],
  ['Fenugreek seeds (methi)', '115-fenugreek.jpg', true],
  ['Coriander seeds', '116-coriander.jpg', true],
  ['Cumin seeds (jeera)', '118-cumin.jpg', true],
  ['Mango (fresh fruit)', '73-mango.jpg', true],
  ['Onion (raw vegetable)', '75-onion.jpg', true],
  ['Potato (raw vegetable)', '76-potato.jpg', true],
  ['Tomato (fresh)', '84-tomato.jpg', true],
  ['Wheat flour / atta bag', '77-flour.jpg', true],
  // === Packaged / branded ===
  ['Milk packet (dairy)', '69-milk.jpg', true],
  ['Sunflower cooking oil', '86-oil.jpg', true],
  ['Anchor butter block', '98-butter.jpg', true],
  ['Orange juice carton', '97-juice.jpg', true],
  ['Panadol / paracetamol blister', '87-paracetamol.jpg', true],
  ['Cough syrup bottle', '44-syrup.jpg', true],
  ['Dettol antiseptic', '93-dettol.jpg', true],
  ['Nivea cream tin', '94-nivea.jpg', true],
  ['Vaseline petroleum jelly', '95-vaseline.jpg', true],
  // === Stationery / tools ===
  ['Pencil (stationery)', '91-pencil.jpg', true],
  ['Fish-shaped rubber eraser', '101-eraser.jpg', true],
  ['Office stapler', '102-stapler.jpg', true],
  ['Box of matches', '90-matches.jpg', true],
  ['Steel kitchen knife', '71-knife.jpg', true],
  ['Claw hammer (hardware)', '81-hammer.jpg', true],
  ['AA battery (alkaline)', '82-battery2.jpg', true],
  // === Electronics ===
  ['Motorola Android phone', '119-phone.jpg', true],
  ['Nokia 3310 (2017)', '120-nokia.jpg', true],
  ['AKG earphones', '122-earphones.jpg', true],
  ['USB cable', '80-usb.jpg', true],
  // === Cosmetics / personal care ===
  ['Lakme lipstick (Indian brand)', '31-lipstick.jpg', true],
  ['Hair oil bottle', '72-hair-oil.jpg', true],
  ['Sandalwood soap bar', '70-soap.jpg', true],
  ['Leather shoe', '79-leather-shoe.jpg', true],
  ['Flip-flops / sandals', '88-sandals.jpg', true],
  ['White T-shirt (clothing)', '85-tshirt.jpg', true],
  // === REJECT cases (AI must say is_product:false) ===
  ['Dog portrait (REJECT)', '89-dog-reject.jpg', false],
  ['Cat in bush (REJECT)', '39-cat-reject.jpg', false],
  ['Potted plant (REJECT)', '40-plant-reject.jpg', false],
  ['Wide shop interior (REJECT)', '22-shop-reject.jpg', false],
];

console.log('\n╔══════════════════════════════════════════════════════════╗');
console.log('║  BATCH 3 — Pre-downloaded images (no Commons search)    ║');
console.log(`╚══════════════════════════════════════════════════════════╝\n`);

if (!KEYS.length) {
  console.error('ERROR: Set GEMINI_DIRECT_KEY=key1,key2,key3 before running');
  process.exit(1);
}

let pass = 0, fail = 0, skip = 0;
const failures = [];

for (let i = 0; i < TESTS.length; i++) {
  const [label, file, expectProduct] = TESTS[i];
  const filePath = `test image/${file}`;
  console.log(`[${i + 1}/${TESTS.length}] ${label}`);

  if (!fs.existsSync(filePath)) {
    console.log(`  SKIP — file not found: ${filePath}\n`);
    skip++;
    continue;
  }

  const kb = Math.round(fs.statSync(filePath).size / 1024);
  console.log(`  file: ${file} (${kb}KB)`);

  const res = await scanFile(filePath);
  if (res.error) {
    console.log(`  ERROR: ${res.error}\n`);
    fail++;
    continue;
  }

  const gotProduct = res.is_product !== false;
  const name = res.name ?? '';
  console.log(`  → ${gotProduct ? 'PRODUCT' : 'NOT PRODUCT'} | ${name || '(empty)'} | ${res.category} | conf:${res.confidence}`);

  const ok = (gotProduct === expectProduct) && (!expectProduct || name.length > 0);
  if (ok) {
    console.log(`  ✓ PASS\n`);
    pass++;
  } else {
    const why = gotProduct !== expectProduct
      ? `expected is_product=${expectProduct}, got ${res.is_product}`
      : 'name is empty';
    console.log(`  ✗ FAIL — ${why}\n`);
    fail++;
    failures.push({ label, why, res, file });
  }

  if (i < TESTS.length - 1) await new Promise(r => setTimeout(r, 5000));
}

console.log('='.repeat(60));
console.log(`Batch 3: ${pass} PASS | ${fail} FAIL | ${skip} SKIP  (of ${TESTS.length})`);

if (failures.length) {
  console.log('\n═══ FAILURES needing prompt fix ═══');
  failures.forEach(f => {
    console.log(`  ✗ ${f.label}`);
    console.log(`    ${f.why}`);
    console.log(`    AI: name="${f.res.name}" is_product=${f.res.is_product} conf=${f.res.confidence}`);
  });
  fs.writeFileSync('test image/scan-failures-batch3.json', JSON.stringify(failures, null, 2));
  console.log('\nFailures saved to: test image/scan-failures-batch3.json');
}
