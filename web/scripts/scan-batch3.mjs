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
  // === More produce / household ===
  ['Bitter gourd (karela)', '126-karela.jpg', true],
  ['Green peas (vegetable)', '125-peas.jpg', true],
  ['Laptop computer', '121-laptop.jpg', true],
  ['Table fan (electric)', '127-fan.jpg', true],
  ['Scissors (stationery)', '131-scissors.jpg', true],
  ['Bread loaf (bakery)', '105-bread.jpg', true],
  ['Water bottle (PET)', '99-water.jpg', true],
  // === More Kerala specifics ===
  ['Vicks VapoRub jar', '96-vicks.jpg', true],
  ['Tamarind fruit (raw)', '132-tamarind.jpg', true],
  ['Byadgi red chilli powder', '134-chilli-powder.jpg', true],
  ['Tender coconut (green)', '135-tender-coconut.jpg', true],
  ['Indian rupee notes (REJECT)', '136-money-reject.jpg', false],
  ['Torch / flashlight', '129-torch.jpg', true],
  // === More household / health ===
  ['Casio calculator', '138-casio.jpg', true],
  ['Horlicks health drink', '139-horlicks.jpg', true],
  ['Toothbrush (oral care)', '142-toothbrush.jpg', true],
  ['Electric clothes iron', '128-iron.jpg', true],
  ['Writing journal / diary', '130-diary.jpg', true],
  // === Snacks / food products ===
  ['Instant noodles packet (Ramen)', '143-noodles.jpg', true],
  ['Popcorn snack bag', '144-popcorn.jpg', true],
  ['Biscuit / cracker pack', '145-biscuit.jpg', true],
  ['Chocolate bar', '146-chocolate.jpg', true],
  // === Personal care ===
  ['Hair conditioner bottle', '149-conditioner.jpg', true],
  ['Razor (Gillette)', '150-razor.jpg', true],
  ['Sanitary pad pack', '151-sanitary.jpg', true],
  // === More fresh produce ===
  ['Banana bunch (yellow)', '157-banana.jpg', true],
  ['Green chilli pepper', '155-green-chilli.jpg', true],
  ['Brinjal / eggplant (purple)', '156-brinjal.jpg', true],
  ['Peanuts / groundnuts', '110-peanut.jpg', true],
  ['Dried coconut / copra', '112-dry-coconut.jpg', true],
  // === Beverages ===
  ['Sprite soft drink bottle', '158-sprite.jpg', true],
  ['Pepsi cola can', '159-pepsi.jpg', true],
  // === Cleaning / household ===
  ['Washing powder box', '154-detergent.jpg', true],
  ['Toothpaste tube', '153-colgate.jpg', true],
  // === Pantry staples ===
  ['Ghee (clarified butter jar)', '187-ghee.jpg', true],
  ['Wheat grains', '186-wheat.jpg', true],
  ['Table salt (iodised)', '190-salt.jpg', true],
  ['Coconut milk (tetra pack)', '200-coconut-milk.jpg', true],
  // === Kerala / Indian daily-use ===
  ['Sewing thread roll', '191-thread.jpg', true],
  ['Earthen clay pot (Kerala)', '193-clay-pot.jpg', true],
  ['Medicine blister strip', '194-medicine-strip.jpg', true],
  ['Bindi stickers (puja/fashion)', '196-bindis.jpg', true],
  ['Earthenware pots — Kerala shop', '197-clay-kerala.jpg', true],
  ['Kumkum powder (red sindoor)', '199-kumkum.jpg', true],
  // === Indian / Kerala specific ===
  ['Coconut oil with raw coconut', '175-coconut-oil.jpg', true],
  ['Camphor cubes (puja item)', '177-camphor.jpg', true],
  ['Turmeric powder (haldi)', '178-turmeric.jpg', true],
  ['Incense sticks (agarbatti)', '176-agarbatti.jpg', true],
  ['Cricket bat (sports)', '179-cricket-bat.jpg', true],
  ['Playing cards deck', '180-cards.jpg', true],
  ['Talcum powder tin', '181-talc.jpg', true],
  // === More stationery / household ===
  ['KitKat chocolate bar', '162-kitkat.jpg', true],
  ['Scotch / sticky tape roll', '167-tape.jpg', true],
  ['Staple remover (office)', '168-staple-remover.jpg', true],
  ['Plastic ruler (stationery)', '169-ruler.jpg', true],
  ['Surgical face mask', '166-facemask.jpg', true],
  ['Super glue / adhesive tube', '163-fevicol.jpg', true],
  ['Safety pins pack', '171-safety-pin.jpg', true],
  ['Rubber bands pack', '173-rubber-band.jpg', true],
  ['Nail clipper / cutter', '183-nail-cutter.jpg', true],
  ['Hair comb (plastic)', '184-comb.jpg', true],
  ['Advent / wax candle', '164-candle.jpg', true],
  ['Kerosene / oil lamp', '165-kerosene.jpg', true],
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
