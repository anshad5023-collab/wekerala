/**
 * scan-user-photos.mjs
 * Scans the user's own Kerala shop photos saved in 'test image/'
 * These are real product photos from the user's fancy shop.
 *
 * Usage: GEMINI_DIRECT_KEY=key1,key2 node web/scripts/scan-user-photos.mjs
 */
import fs from 'fs';
import path from 'path';

const KEYS = (process.env.GEMINI_DIRECT_KEY ?? '').split(',').map(k => k.trim()).filter(Boolean);
let keyIdx = 0;
const CATS = 'Grocery | Snacks | Beverages | Personal Care | Medicines | Household | Spices | Dal & Pulses | Fresh Produce | Stationery | Dairy | Soap & Detergent | Hair Care | Fish & Meat | Kitchen & Utensils | Hardware & Tools | Cosmetics | Footwear | Clothing | Electronics | Books | Baby Care | Vitamins & Supplements | Toys';

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

async function scanBuf(buf, mime = 'image/jpeg') {
  for (let attempt = 0; attempt < KEYS.length * 3; attempt++) {
    const key = KEYS[keyIdx % KEYS.length];
    let r;
    try {
      r = await fetchRetry('https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-goog-api-key': key },
        body: JSON.stringify({
          contents: [{ parts: [{ text: PROMPT }, { inline_data: { mime_type: mime, data: buf.toString('base64') } }] }]
        }),
      });
    } catch (e) { console.log('  net err:', e.message); await new Promise(x => setTimeout(x, 8000)); continue; }
    if (r.status === 429) { console.log('  429 — rotating key'); keyIdx++; await new Promise(x => setTimeout(x, 12000)); continue; }
    if (r.status === 503) { await new Promise(x => setTimeout(x, 12000)); continue; }
    if (!r.ok) return { error: 'HTTP ' + r.status };
    const j = await r.json();
    const text = j.candidates?.[0]?.content?.parts?.[0]?.text?.trim() ?? '';
    try { return JSON.parse(text); }
    catch { const m = text.match(/\{[\s\S]*\}/); return m ? JSON.parse(m[0]) : { raw: text.slice(0, 200) }; }
  }
  return { error: 'all keys exhausted' };
}

const PHOTOS = [
  {
    file: 'WhatsApp Image 2026-06-20 at 12.22.14 PM 3.jpeg',
    desc: 'POCO M6 5G smartphone box (yellow box, "Made in India")',
    expect: 'POCO M6 5G | Electronics | is_product:true',
  },
  {
    file: 'WhatsApp Image 2026-06-20 at 12.23.09 PM.jpeg',
    desc: 'Exam Point Kerala textbook back cover (₹260, ISBN visible)',
    expect: 'Book/Textbook | Stationery | price:260 | is_product:true',
  },
  {
    file: 'WhatsApp Image 2026-06-20 at 12.23.50 PM.jpeg',
    desc: "Pond's Dreamflower Fragrant Talc (Arabic+English label, hand holding)",
    expect: "Pond's Dreamflower Talc | Personal Care | is_product:true",
  },
  {
    file: 'WhatsApp Image 2026-06-20 at 12.23.51 PM 2.jpeg',
    desc: 'Sportz sneaker (held in hand; POCO & Triggr box visible in background)',
    expect: 'Sportz Sneaker/Shoe | Footwear | is_product:true (shoe, not POCO box)',
  },
  {
    file: "WhatsApp Image 2026-06-20 at 12.23.51 PM.jpeg",
    desc: '"World\'s Greatest Speeches" book (cover shows Gandhi/Kennedy/MLK/Churchill/Mao)',
    expect: "Book: World's Greatest Speeches | Books/Stationery | is_product:true",
  },
];

if (!KEYS.length) {
  console.error('Error: set GEMINI_DIRECT_KEY=key1,key2 before running');
  process.exit(1);
}

console.log('\n╔══════════════════════════════════════════════════════════╗');
console.log('║  USER SHOP PHOTOS — Real Kerala Fancy Shop Products     ║');
console.log('╚══════════════════════════════════════════════════════════╝\n');

for (let i = 0; i < PHOTOS.length; i++) {
  const { file, desc, expect } = PHOTOS[i];
  const filePath = path.join('test image', file);
  console.log(`[${i + 1}/${PHOTOS.length}] ${desc}`);
  console.log(`  Expected: ${expect}`);

  if (!fs.existsSync(filePath)) { console.log('  SKIP — file not found\n'); continue; }
  const buf = fs.readFileSync(filePath);
  console.log(`  Image size: ${Math.round(buf.length / 1024)}KB`);

  const res = await scanBuf(buf);
  if (res.error) { console.log(`  ERROR: ${res.error}\n`); continue; }

  console.log(`  → is_product: ${res.is_product}`);
  console.log(`  → name: "${res.name}"`);
  console.log(`  → brand: "${res.brand}"`);
  console.log(`  → category: "${res.category}"`);
  console.log(`  → price: "${res.price || '(none)'}"`);
  console.log(`  → confidence: ${res.confidence}`);
  if (res.uncertain_fields?.length) console.log(`  → uncertain: ${res.uncertain_fields.join(', ')}`);
  if (res.model_number) console.log(`  → model: ${res.model_number}`);

  const pass = res.is_product !== false && res.name && res.name.length > 0;
  console.log(pass ? '  ✓ PASS\n' : '  ✗ FAIL — is_product=false or name empty\n');

  if (i < PHOTOS.length - 1) await new Promise(r => setTimeout(r, 8000));
}

console.log('Done. Check results above for any prompt issues.');
