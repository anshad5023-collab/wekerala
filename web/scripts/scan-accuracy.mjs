/**
 * scan-accuracy.mjs — Accuracy test: checks if AI returns CORRECT SPECIFIC DETAILS
 * not just "detected a product" but "detected THE RIGHT product with RIGHT attributes".
 *
 * Each test has:
 *   label       — human-readable description
 *   file        — image file in "test image/"
 *   expect      — object with fields the AI MUST return correctly
 *   forbidden   — fields the AI must NOT include at all
 *   mustReject  — true if the image is NOT a product (animal, money, interior, etc.)
 *
 * Field matching rules:
 *   String values  → case-insensitive substring match (e.g. "dove" matches "Dove Shampoo")
 *   Array values   → AI value must match one of the array options (OR logic)
 *   null           → field must be present and non-empty (any value is ok)
 *
 * Usage: GEMINI_DIRECT_KEY=key1,key2,key3 node web/scripts/scan-accuracy.mjs
 */
import fs from 'fs';

const KEYS = (process.env.GEMINI_DIRECT_KEY ?? '').split(',').map(k => k.trim()).filter(Boolean);
let keyIdx = 0;

const CATS = 'Grocery | Snacks | Beverages | Personal Care | Medicines | Household | Spices | Dal & Pulses | Fresh Produce | Stationery | Dairy | Soap & Detergent | Hair Care | Fish & Meat | Kitchen & Utensils | Hardware & Tools | Cosmetics | Footwear | Clothing | Electronics | Bakery';

const routeSrc = fs.readFileSync('web/app/api/gemini-product/route.ts', 'utf8');
const pm = routeSrc.match(/return `([\s\S]*?)\$\{hint\}`/);
const PROMPT = (pm ? pm[1] : '') + `\n\nShop category list: ${CATS}`;

async function fetchRetry(url, opts, n = 4) {
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
      r = await fetchRetry('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent', {
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

// Check if AI value matches expected value
// expected: string → AI value must contain it (case-insensitive)
// expected: array  → AI value must match one of the options
// expected: null   → field must exist and be non-empty
function fieldMatches(aiVal, expected) {
  if (aiVal === undefined || aiVal === null || aiVal === '') return false;
  const aiStr = String(aiVal).toLowerCase().trim();
  if (expected === null) return aiStr.length > 0;
  if (Array.isArray(expected)) return expected.some(e => aiStr.includes(e.toLowerCase()));
  return aiStr.includes(String(expected).toLowerCase());
}

// ═══════════════════════════════════════════════════════════════════
// TEST CASES — each image has KNOWN CORRECT ANSWERS
// We know these because we can look at the images ourselves.
// ═══════════════════════════════════════════════════════════════════
const TESTS = [

  // ── REJECT CASES (not a product) ──────────────────────────────
  {
    label: 'Dog portrait → must be rejected',
    file: '89-dog-reject.jpg',
    mustReject: true,
  },
  {
    label: 'Cat in bush → must be rejected',
    file: '39-cat-reject.jpg',
    mustReject: true,
  },
  {
    label: 'Potted plant → must be rejected',
    file: '40-plant-reject.jpg',
    mustReject: true,
  },
  {
    label: 'Wide shop interior → must be rejected',
    file: '22-shop-reject.jpg',
    mustReject: true,
  },
  {
    label: 'Indian rupee notes → must be rejected (money is not a product)',
    file: '136-money-reject.jpg',
    mustReject: true,
  },

  // ── BOOKS — must NOT get color/gender ─────────────────────────
  {
    label: 'DC Books novel → category Books, has author/publisher, NO color or gender',
    file: '130-diary.jpg',
    expect: {
      category: ['Books', 'Stationery'],
    },
    forbidden: ['color', 'gender', 'for'],
  },

  // ── PERSONAL CARE ─────────────────────────────────────────────
  {
    label: 'Dove shampoo → brand Dove, has hair_type, has volume_ml, NO gender/color',
    file: '230-shampoo.jpg',
    expect: {
      brand: 'dove',
      category: ['Personal Care', 'Hair Care'],
      hair_type: null,      // must have some hair_type value
      volume_ml: null,      // must have some volume_ml value
    },
    forbidden: ['gender', 'color', 'composition'],
  },
  {
    label: 'Hair conditioner → has hair_type + volume_ml, NO gender/color',
    file: '231-conditioner.jpg',
    expect: {
      category: ['Personal Care', 'Hair Care'],
      hair_type: null,
      volume_ml: null,
    },
    forbidden: ['gender', 'color'],
  },
  {
    label: 'Face wash → has skin_type + volume_ml, NO gender/color',
    file: '232-face-wash.jpg',
    expect: {
      category: ['Personal Care', 'Cosmetics'],
      skin_type: null,
      volume_ml: null,
    },
    forbidden: ['gender', 'color'],
  },
  {
    label: 'Sunscreen → has spf + skin_type + volume_ml, NO gender/color',
    file: '233-sunscreen.jpg',
    expect: {
      category: ['Personal Care', 'Cosmetics'],
      spf: null,
    },
    forbidden: ['gender', 'color'],
  },
  {
    label: 'Deodorant spray → has gender + volume_ml, NO composition',
    file: '234-deodorant.jpg',
    expect: {
      category: ['Personal Care'],
      gender: null,
      volume_ml: null,
    },
    forbidden: ['composition'],
  },
  {
    label: 'Matte nail polish → has shade or finish (Matte), NO gender/color field',
    file: '235-nail-polish.jpg',
    expect: {
      category: ['Personal Care', 'Cosmetics'],
      finish: ['Matte', 'Glossy', 'Satin'],   // any valid finish is acceptable
    },
    forbidden: ['gender', 'composition'],
  },
  {
    label: 'Toothpaste Colgate → brand Colgate, has weight or variant, NO gender',
    file: '153-colgate.jpg',
    expect: {
      brand: 'colgate',
      category: ['Personal Care'],
    },
    forbidden: ['gender', 'color', 'composition'],
  },
  {
    label: 'Gilette razor → has blade_count + gender (Men), NO color',
    file: '150-razor.jpg',
    expect: {
      category: ['Personal Care'],
      blade_count: null,
      gender: ['Men', 'Male'],
    },
    forbidden: ['color', 'composition'],
  },
  {
    label: 'Sanitary pad → has pad_size, NO gender/color/composition',
    file: '151-sanitary.jpg',
    expect: {
      category: ['Personal Care'],
      pad_size: null,
    },
    forbidden: ['gender', 'color', 'composition'],
  },
  {
    label: 'Lakme lipstick → has shade or finish, NO gender field',
    file: '31-lipstick.jpg',
    expect: {
      brand: ['lakme', 'lak'],
      category: ['Cosmetics', 'Personal Care'],
    },
    forbidden: ['gender', 'composition'],
  },
  {
    label: 'Vaseline petroleum jelly → brand Vaseline, category Personal Care',
    file: '95-vaseline.jpg',
    expect: {
      brand: 'vaseline',
      category: ['Personal Care', 'Medicines'],
    },
    forbidden: ['gender', 'composition', 'is_veg'],
  },
  {
    label: 'Nivea cream tin → brand Nivea, category Personal Care, NO gender',
    file: '94-nivea.jpg',
    expect: {
      brand: 'nivea',
      category: ['Personal Care'],
    },
    forbidden: ['gender', 'composition', 'is_veg'],
  },

  // ── MEDICINES ─────────────────────────────────────────────────
  {
    label: 'Paracetamol blister → has composition (Paracetamol), form=tablet, has manufacturer',
    file: '87-paracetamol.jpg',
    expect: {
      category: ['Medicines'],
      composition: 'paracetamol',
      form: 'tablet',
    },
    forbidden: ['color', 'gender', 'is_veg'],
  },
  {
    label: 'Cough syrup bottle → form=syrup, has composition, NO color/gender',
    file: '44-syrup.jpg',
    expect: {
      category: ['Medicines'],
      form: ['syrup', 'liquid'],
    },
    forbidden: ['color', 'gender', 'is_veg'],
  },
  {
    label: 'Medicine blister strip → has composition or form=tablet, NO color/gender',
    file: '194-medicine-strip.jpg',
    expect: {
      category: ['Medicines'],
    },
    forbidden: ['color', 'gender', 'is_veg'],
  },
  {
    label: 'Dettol antiseptic → brand Dettol, category Medicines or Household',
    file: '93-dettol.jpg',
    expect: {
      brand: 'dettol',
      category: ['Medicines', 'Household', 'Personal Care'],
    },
    forbidden: ['gender', 'is_veg'],
  },
  {
    label: 'Vicks VapoRub jar → brand Vicks, category Medicines',
    file: '96-vicks.jpg',
    expect: {
      brand: 'vicks',
      category: ['Medicines', 'Personal Care'],
    },
    forbidden: ['gender', 'is_veg', 'color'],
  },

  // ── FOOD — FRESH PRODUCE ──────────────────────────────────────
  {
    label: 'Mango → is_veg=Veg, category Fresh Produce',
    file: '73-mango.jpg',
    expect: {
      category: ['Fresh Produce', 'Grocery'],
      is_veg: 'veg',
    },
    forbidden: ['gender', 'model_number', 'author'],
  },
  {
    label: 'Onion → is_veg=Veg, category Fresh Produce',
    file: '75-onion.jpg',
    expect: {
      category: ['Fresh Produce', 'Grocery'],
      is_veg: 'veg',
    },
    forbidden: ['gender', 'model_number', 'color'],
  },
  {
    label: 'Potato → is_veg=Veg, category Fresh Produce',
    file: '76-potato.jpg',
    expect: {
      category: ['Fresh Produce', 'Grocery'],
      is_veg: 'veg',
    },
    forbidden: ['gender', 'model_number', 'color'],
  },
  {
    label: 'Tomato → is_veg=Veg, category Fresh Produce',
    file: '84-tomato.jpg',
    expect: {
      category: ['Fresh Produce', 'Grocery'],
      is_veg: 'veg',
    },
    forbidden: ['gender', 'model_number'],
  },
  {
    label: 'Banana bunch → is_veg=Veg, category Fresh Produce, NO color/gender',
    file: '157-banana.jpg',
    expect: {
      category: ['Fresh Produce', 'Grocery'],
      is_veg: 'veg',
    },
    forbidden: ['color', 'gender', 'model_number'],
  },
  {
    label: 'Bitter gourd (karela) → is_veg=Veg, category Fresh Produce',
    file: '126-karela.jpg',
    expect: {
      category: ['Fresh Produce', 'Grocery'],
      is_veg: 'veg',
    },
    forbidden: ['gender', 'color', 'model_number'],
  },
  {
    label: 'Green chilli → is_veg=Veg, category Fresh Produce, name contains chilli/pepper',
    file: '155-green-chilli.jpg',
    expect: {
      category: ['Fresh Produce', 'Grocery', 'Spices'],
      is_veg: 'veg',
      name: ['chilli', 'chili', 'pepper', 'green pepper'],
    },
    forbidden: ['gender', 'model_number'],
  },
  {
    label: 'Brinjal/eggplant → is_veg=Veg, category Fresh Produce',
    file: '156-brinjal.jpg',
    expect: {
      category: ['Fresh Produce', 'Grocery'],
      is_veg: 'veg',
      name: ['brinjal', 'eggplant', 'aubergine'],
    },
    forbidden: ['gender', 'model_number'],
  },
  {
    label: 'Eggs (carton) → is_veg=Egg or Non-Veg, category Fresh Produce or Grocery',
    file: '280-eggs.jpg',
    expect: {
      category: ['Fresh Produce', 'Grocery', 'Dairy'],
      is_veg: ['egg', 'non-veg'],
    },
    forbidden: ['gender', 'model_number', 'color'],
  },

  // ── FISH / MEAT ───────────────────────────────────────────────
  {
    label: 'Rohu fish → is_veg=Non-Veg, category Fish & Meat',
    file: '107-rohu.jpg',
    expect: {
      category: ['Fish', 'Meat', 'Fish & Meat'],
      is_veg: 'non-veg',
    },
    forbidden: ['gender', 'model_number', 'color'],
  },
  {
    label: 'Mackerel (ayala) → is_veg=Non-Veg, category Fish & Meat',
    file: '109-mackerel.jpg',
    expect: {
      category: ['Fish', 'Meat', 'Fish & Meat'],
      is_veg: 'non-veg',
    },
    forbidden: ['gender', 'model_number'],
  },

  // ── PACKAGED FOOD ─────────────────────────────────────────────
  {
    label: 'Milk packet → is_veg=Veg, category Dairy, has volume_ml',
    file: '69-milk.jpg',
    expect: {
      category: ['Dairy'],
      is_veg: 'veg',
      volume_ml: null,
    },
    forbidden: ['gender', 'color', 'model_number'],
  },
  {
    label: 'Butter block → is_veg=Veg, category Dairy or Grocery, has weight_g',
    file: '98-butter.jpg',
    expect: {
      category: ['Dairy', 'Grocery'],
      is_veg: 'veg',
    },
    forbidden: ['gender', 'color', 'model_number'],
  },
  {
    label: 'Sunflower cooking oil → is_veg=Veg, category Grocery, has volume_ml',
    file: '86-oil.jpg',
    expect: {
      category: ['Grocery'],
      is_veg: 'veg',
      volume_ml: null,
    },
    forbidden: ['gender', 'color', 'model_number'],
  },
  {
    label: 'Wheat flour bag → is_veg=Veg, category Grocery, has weight_g',
    file: '77-flour.jpg',
    expect: {
      category: ['Grocery'],
      is_veg: 'veg',
    },
    forbidden: ['gender', 'color', 'model_number'],
  },
  {
    label: 'Biscuit pack → is_veg field present, category Snacks or Grocery',
    file: '145-biscuit.jpg',
    expect: {
      category: ['Snacks', 'Grocery', 'Bakery'],
      is_veg: null,
    },
    forbidden: ['gender', 'color', 'model_number'],
  },
  {
    label: 'KitKat chocolate → is_veg present, category Snacks, has weight_g',
    file: '162-kitkat.jpg',
    expect: {
      brand: ['kitkat', 'nestle'],
      category: ['Snacks', 'Grocery'],
      is_veg: null,
    },
    forbidden: ['gender', 'color', 'model_number'],
  },
  {
    label: 'Instant noodles → is_veg present, category Snacks or Grocery',
    file: '143-noodles.jpg',
    expect: {
      category: ['Snacks', 'Grocery'],
      is_veg: null,
    },
    forbidden: ['gender', 'color', 'model_number'],
  },
  {
    label: 'Banana chips (Kerala snack) → is_veg=Veg, category Snacks',
    file: '217-banana-chips.jpg',
    expect: {
      category: ['Snacks', 'Grocery'],
      is_veg: 'veg',
      name: ['banana', 'chips'],
    },
    forbidden: ['gender', 'color', 'model_number'],
  },
  {
    label: 'Orange juice carton → is_veg=Veg, category Beverages, has volume_ml',
    file: '97-juice.jpg',
    expect: {
      category: ['Beverages'],
      is_veg: 'veg',
      volume_ml: null,
    },
    forbidden: ['gender', 'color', 'model_number'],
  },
  {
    label: 'Sprite soft drink → is_veg=Veg, category Beverages, brand Sprite',
    file: '158-sprite.jpg',
    expect: {
      brand: ['sprite', 'coca-cola', 'coke'],
      category: ['Beverages'],
      is_veg: 'veg',
    },
    forbidden: ['gender', 'model_number'],
  },
  {
    label: 'Washing powder → category Household or Soap & Detergent, has weight_g',
    file: '154-detergent.jpg',
    expect: {
      category: ['Household', 'Soap & Detergent'],
    },
    forbidden: ['gender', 'is_veg', 'model_number'],
  },
  {
    label: 'Horlicks health drink → brand Horlicks, is_veg=Veg, has weight_g, has variant',
    file: '139-horlicks.jpg',
    expect: {
      brand: 'horlicks',
      category: ['Beverages', 'Grocery'],
      is_veg: 'veg',
    },
    forbidden: ['gender', 'color', 'model_number'],
  },
  {
    label: 'Ghee jar → is_veg=Veg, category Dairy or Grocery, has weight_g',
    file: '187-ghee.jpg',
    expect: {
      category: ['Dairy', 'Grocery'],
      is_veg: 'veg',
      name: ['ghee', 'clarified butter'],
    },
    forbidden: ['gender', 'color', 'model_number'],
  },
  {
    label: 'Table salt → is_veg=Veg, category Grocery or Spices, has weight_g',
    file: '190-salt.jpg',
    expect: {
      category: ['Grocery', 'Spices'],
      is_veg: 'veg',
      name: ['salt', 'iodised', 'iodized'],
    },
    forbidden: ['gender', 'color', 'model_number'],
  },
  {
    label: 'Tea bags → is_veg=Veg, category Beverages or Grocery',
    file: '282-tea.jpg',
    expect: {
      category: ['Beverages', 'Grocery'],
      is_veg: 'veg',
      name: ['tea'],
    },
    forbidden: ['gender', 'color', 'model_number'],
  },

  // ── SPICES ────────────────────────────────────────────────────
  {
    label: 'Turmeric powder → is_veg=Veg, category Spices, name contains turmeric/haldi',
    file: '178-turmeric.jpg',
    expect: {
      category: ['Spices'],
      is_veg: 'veg',
      name: ['turmeric', 'haldi'],
    },
    forbidden: ['gender', 'color', 'model_number'],
  },
  {
    label: 'Chilli powder → is_veg=Veg, category Spices, name contains chilli',
    file: '134-chilli-powder.jpg',
    expect: {
      category: ['Spices'],
      is_veg: 'veg',
      name: ['chilli', 'chili', 'pepper'],
    },
    forbidden: ['gender', 'color', 'model_number'],
  },
  {
    label: 'Mustard seeds → is_veg=Veg, category Spices or Grocery',
    file: '114-mustard.jpg',
    expect: {
      category: ['Spices', 'Grocery'],
      is_veg: 'veg',
      name: ['mustard'],
    },
    forbidden: ['gender', 'color', 'model_number'],
  },
  {
    label: 'Cardamom pods → is_veg=Veg, category Spices',
    file: '27-cardamom.jpg',
    expect: {
      category: ['Spices', 'Grocery'],
      is_veg: 'veg',
      name: ['cardamom', 'elaichi'],
    },
    forbidden: ['gender', 'model_number'],
  },
  {
    label: 'Coconut oil with raw coconut → is_veg=Veg, category Grocery',
    file: '175-coconut-oil.jpg',
    expect: {
      category: ['Grocery'],
      is_veg: 'veg',
      name: ['coconut', 'oil'],
    },
    forbidden: ['gender', 'color', 'model_number'],
  },

  // ── ELECTRONICS ───────────────────────────────────────────────
  {
    label: 'Motorola Android phone → category Electronics, has model_number, has color',
    file: '119-phone.jpg',
    expect: {
      category: ['Electronics'],
      model_number: null,
      color: null,
    },
    forbidden: ['is_veg', 'author', 'gender', 'composition'],
  },
  {
    label: 'Laptop computer → category Electronics, has model_number, has warranty_months',
    file: '121-laptop.jpg',
    expect: {
      category: ['Electronics'],
    },
    forbidden: ['is_veg', 'author', 'gender', 'composition'],
  },
  {
    label: 'AKG earphones → category Electronics, has model_number or compatible_with',
    file: '122-earphones.jpg',
    expect: {
      category: ['Electronics'],
    },
    forbidden: ['is_veg', 'author', 'gender', 'composition'],
  },
  {
    label: 'Computer keyboard → category Electronics, has model_number or compatible_with',
    file: '270-keyboard.jpg',
    expect: {
      category: ['Electronics'],
    },
    forbidden: ['is_veg', 'author', 'gender', 'composition'],
  },
  {
    label: 'USB pen drive → category Electronics, has compatible_with (USB)',
    file: '272-pendrive.jpg',
    expect: {
      category: ['Electronics'],
      compatible_with: ['usb', 'usb 3', 'usb 2'],
    },
    forbidden: ['is_veg', 'author', 'gender', 'composition'],
  },
  {
    label: 'AA battery → category Electronics or Household, has compatible_with (AA)',
    file: '82-battery2.jpg',
    expect: {
      compatible_with: ['aa', 'alkaline'],
    },
    forbidden: ['is_veg', 'author', 'gender', 'composition', 'color'],
  },
  {
    label: 'USB cable → category Electronics, has compatible_with',
    file: '80-usb.jpg',
    expect: {
      category: ['Electronics'],
      compatible_with: null,
    },
    forbidden: ['is_veg', 'author', 'gender', 'composition'],
  },
  {
    label: 'Casio calculator → brand Casio, category Electronics or Stationery',
    file: '138-casio.jpg',
    expect: {
      brand: 'casio',
      category: ['Electronics', 'Stationery'],
    },
    forbidden: ['is_veg', 'author', 'gender', 'composition'],
  },
  {
    label: 'Table fan → category Electronics, has model_number or wattage, NO gender/is_veg',
    file: '127-fan.jpg',
    expect: {
      category: ['Electronics'],
    },
    forbidden: ['is_veg', 'author', 'gender', 'composition'],
  },

  // ── SPORTS ────────────────────────────────────────────────────
  {
    label: 'Cricket bat → has wood_type (Kashmir Willow), has size, NO color/gender',
    file: '240-cricket-bat.jpg',
    expect: {
      name: ['cricket bat', 'bat'],
      wood_type: ['kashmir', 'willow', 'english'],
    },
    forbidden: ['gender', 'composition', 'is_veg', 'color'],
  },
  {
    label: 'Red cricket ball → has ball_type (Leather), color=Red, NO gender',
    file: '241-cricket-ball.jpg',
    expect: {
      name: ['cricket ball', 'ball'],
      ball_type: ['leather', 'cricket'],
      color: ['red', 'crimson'],
    },
    forbidden: ['gender', 'composition', 'is_veg'],
  },
  {
    label: 'Badminton racket → has material (Aluminium/Carbon), NO color/gender',
    file: '242-badminton.jpg',
    expect: {
      name: ['badminton', 'racket', 'racquet'],
      material: ['aluminium', 'aluminum', 'carbon', 'steel'],
    },
    forbidden: ['gender', 'composition', 'is_veg', 'color'],
  },
  {
    label: 'Feather shuttlecock → has shuttle_type (Feather), NO color/gender',
    file: '243-shuttlecock.jpg',
    expect: {
      name: ['shuttlecock', 'shuttle', 'birdie'],
      shuttle_type: ['feather', 'nylon', 'synthetic'],
    },
    forbidden: ['gender', 'composition', 'is_veg'],
  },
  {
    label: 'Football → has size (3/4/5), has material, NO gender/composition',
    file: '244-football.jpg',
    expect: {
      name: ['football', 'soccer ball', 'ball'],
      material: null,
    },
    forbidden: ['gender', 'composition', 'is_veg'],
  },
  {
    label: 'Basketball → has size (5/6/7), has material, NO gender/composition',
    file: '245-basketball.jpg',
    expect: {
      name: ['basketball', 'ball'],
      material: null,
    },
    forbidden: ['gender', 'composition', 'is_veg'],
  },
  {
    label: 'Carrom board → has size, has material, NO color/gender/is_veg',
    file: '246-carrom.jpg',
    expect: {
      name: ['carrom', 'carom'],
      material: null,
    },
    forbidden: ['gender', 'composition', 'is_veg', 'color'],
  },
  {
    label: 'Chess set → has material (Plastic), has size, NO color/gender/is_veg',
    file: '247-chess.jpg',
    expect: {
      name: ['chess'],
      material: ['plastic', 'wood', 'metal'],
    },
    forbidden: ['gender', 'composition', 'is_veg'],
  },
  {
    label: 'Table tennis bat (DHS) → has rubber_type or brand DHS, NO color/gender',
    file: '248-tt-bat.jpg',
    expect: {
      name: ['table tennis', 'ping pong', 'bat', 'paddle', 'racket'],
    },
    forbidden: ['gender', 'composition', 'is_veg'],
  },
  {
    label: 'Playing cards deck → has card_type, NO color/gender/is_veg',
    file: '180-cards.jpg',
    expect: {
      name: ['playing cards', 'cards', 'deck'],
      card_type: null,
    },
    forbidden: ['gender', 'composition', 'is_veg'],
  },

  // ── TOOLS ─────────────────────────────────────────────────────
  {
    label: 'Claw hammer → has head_material (Steel), has weight_g or name=Hammer, NO color',
    file: '81-hammer.jpg',
    expect: {
      name: ['hammer'],
      head_material: ['steel', 'iron', 'metal'],
    },
    forbidden: ['gender', 'composition', 'is_veg', 'color'],
  },
  {
    label: 'Phillips screwdriver → has screw_type (Phillips), NO color/gender/is_veg',
    file: '250-screwdriver.jpg',
    expect: {
      name: ['screwdriver'],
      screw_type: ['phillips', 'flat', 'cross', 'torx', 'multi'],
    },
    forbidden: ['gender', 'composition', 'is_veg', 'color'],
  },
  {
    label: 'Combination pliers → has plier_type, NO color/gender/is_veg',
    file: '251-pliers.jpg',
    expect: {
      name: ['pliers', 'plier'],
      plier_type: null,
    },
    forbidden: ['gender', 'composition', 'is_veg', 'color'],
  },
  {
    label: 'Adjustable wrench → has wrench_type (Adjustable), NO color/gender/is_veg',
    file: '252-wrench.jpg',
    expect: {
      name: ['wrench', 'spanner'],
      wrench_type: ['adjustable', 'open', 'ring'],
    },
    forbidden: ['gender', 'composition', 'is_veg', 'color'],
  },
  {
    label: 'Tape measure → has length_m, NO color/gender/is_veg',
    file: '253-tape-measure.jpg',
    expect: {
      name: ['tape', 'measure', 'measuring tape'],
      length_m: null,
    },
    forbidden: ['gender', 'composition', 'is_veg'],
  },

  // ── KITCHEN ───────────────────────────────────────────────────
  {
    label: 'Iron skillet/kadai → has material (Iron/Cast Iron), NO gender/is_veg',
    file: '260-kadai.jpg',
    expect: {
      name: ['skillet', 'kadai', 'pan', 'wok', 'cookware'],
      material: ['iron', 'cast iron', 'steel', 'aluminium'],
    },
    forbidden: ['gender', 'is_veg', 'color'],
  },
  {
    label: 'Tawa/griddle → has material, NO gender/is_veg',
    file: '261-tawa.jpg',
    expect: {
      name: ['tawa', 'griddle', 'pan', 'dosa'],
      material: null,
    },
    forbidden: ['gender', 'is_veg', 'color'],
  },
  {
    label: 'Steel tiffin/lunchbox → has material (Steel), has compartments, NO gender/is_veg',
    file: '262-lunchbox.jpg',
    expect: {
      name: ['tiffin', 'lunch box', 'lunchbox', 'container'],
      material: ['steel', 'stainless', 'plastic', 'aluminium'],
    },
    forbidden: ['gender', 'is_veg', 'color'],
  },
  {
    label: 'Thermos flask → has capacity_ml, has material, NO gender/is_veg',
    file: '263-thermos.jpg',
    expect: {
      name: ['thermos', 'flask', 'bottle', 'vacuum flask'],
      capacity_ml: null,
    },
    forbidden: ['gender', 'is_veg', 'color'],
  },
  {
    label: 'Pressure cooker → has capacity_litres, has material (Steel/Aluminium)',
    file: '206-pressure-cooker.jpg',
    expect: {
      name: ['pressure cooker', 'cooker'],
      capacity_litres: null,
      material: ['aluminium', 'stainless steel', 'steel'],
    },
    forbidden: ['gender', 'is_veg', 'color'],
  },
  {
    label: 'Steel kitchen knife → has blade_material, has knife_type, NO gender/is_veg',
    file: '71-knife.jpg',
    expect: {
      name: ['knife', 'blade', 'chopper'],
      blade_material: ['stainless steel', 'carbon steel', 'steel'],
    },
    forbidden: ['gender', 'is_veg', 'color'],
  },
  {
    label: 'Cooking spatula → has material (Steel/Plastic/Wood), NO gender/is_veg',
    file: '211-spatula.jpg',
    expect: {
      name: ['spatula', 'ladle', 'spoon', 'turner'],
      material: null,
    },
    forbidden: ['gender', 'is_veg', 'color'],
  },
  {
    label: 'Drinking glass/tumbler → has material, has capacity_ml, NO gender/is_veg',
    file: '214-glass.jpg',
    expect: {
      name: ['glass', 'tumbler', 'cup'],
      material: null,
    },
    forbidden: ['gender', 'is_veg'],
  },
  {
    label: 'Plastic bucket → has capacity_litres, has material (Plastic), NO gender/is_veg',
    file: '209-bucket.jpg',
    expect: {
      name: ['bucket', 'pail'],
      material: ['plastic', 'steel'],
      capacity_litres: null,
    },
    forbidden: ['gender', 'is_veg'],
  },

  // ── STATIONERY ────────────────────────────────────────────────
  {
    label: 'Pencil → has grade (HB/2B) or pencil_type (Graphite), NO gender/color',
    file: '91-pencil.jpg',
    expect: {
      name: ['pencil'],
    },
    forbidden: ['gender', 'is_veg', 'composition'],
  },
  {
    label: 'Gel pen → has ink_color, has pen_type (Gel), NO gender/is_veg',
    file: '290-gel-pen.jpg',
    expect: {
      name: ['pen', 'gel pen'],
      pen_type: ['gel', 'ballpoint', 'rollerball'],
    },
    forbidden: ['gender', 'is_veg', 'composition'],
  },
  {
    label: 'Office stapler → has compatible_with (staple size), NO gender/is_veg',
    file: '102-stapler.jpg',
    expect: {
      name: ['stapler'],
    },
    forbidden: ['gender', 'is_veg', 'composition', 'color'],
  },
  {
    label: 'Scissors → has blade_length_cm or material, NO gender/is_veg',
    file: '131-scissors.jpg',
    expect: {
      name: ['scissors'],
    },
    forbidden: ['gender', 'is_veg', 'composition'],
  },
  {
    label: 'Plastic ruler → has length_cm, has material (Plastic), NO gender/is_veg',
    file: '169-ruler.jpg',
    expect: {
      name: ['ruler'],
      material: ['plastic', 'steel', 'wood'],
      length_cm: null,
    },
    forbidden: ['gender', 'is_veg', 'composition'],
  },
  {
    label: 'School exercise notebook → has page_count, has ruling, NO gender/is_veg',
    file: '291-notebook.jpg',
    expect: {
      name: ['notebook', 'exercise book', 'book'],
      ruling: ['single line', 'ruled', 'lined', 'double line', 'blank', 'graph'],
    },
    forbidden: ['gender', 'is_veg', 'author', 'publisher'],
  },
  {
    label: 'Super glue/Fevicol → has glue_type, NO gender/is_veg',
    file: '163-fevicol.jpg',
    expect: {
      name: ['glue', 'adhesive', 'fevicol'],
      glue_type: null,
    },
    forbidden: ['gender', 'is_veg', 'color'],
  },

  // ── CLOTHING & FOOTWEAR ───────────────────────────────────────
  {
    label: 'White T-shirt → has gender, has fabric, has color (White), category Clothing',
    file: '85-tshirt.jpg',
    expect: {
      category: ['Clothing'],
      gender: null,
      fabric: null,
      color: ['white', 'ivory', 'cream'],
    },
    forbidden: ['is_veg', 'author', 'model_number', 'composition'],
  },
  {
    label: 'Leather shoe → has gender, color, sizes, material=Leather, category Footwear',
    file: '79-leather-shoe.jpg',
    expect: {
      category: ['Footwear'],
      material: ['leather', 'synthetic', 'faux leather'],
      gender: null,
    },
    forbidden: ['is_veg', 'author', 'composition'],
  },
  {
    label: 'Flip-flops/sandals → has gender, color, sizes, category Footwear',
    file: '88-sandals.jpg',
    expect: {
      category: ['Footwear'],
      gender: null,
    },
    forbidden: ['is_veg', 'author', 'composition'],
  },

  // ── PUJA / HOUSEHOLD ──────────────────────────────────────────
  {
    label: 'Incense sticks (agarbatti) → has fragrance, category Household, NO color/gender',
    file: '176-agarbatti.jpg',
    expect: {
      name: ['incense', 'agarbatti', 'stick'],
      category: ['Household'],
      fragrance: null,
    },
    forbidden: ['gender', 'is_veg', 'model_number'],
  },
  {
    label: 'Camphor cubes → category Household or Puja, NO color/gender/is_veg',
    file: '177-camphor.jpg',
    expect: {
      name: ['camphor', 'kapur', 'kapoor'],
      category: ['Household'],
    },
    forbidden: ['gender', 'is_veg', 'color', 'model_number'],
  },
  {
    label: 'Bindi stickers → category Household or Cosmetics, NO composition/is_veg',
    file: '196-bindis.jpg',
    expect: {
      name: ['bindi', 'bindis', 'sticker', 'dot'],
    },
    forbidden: ['is_veg', 'model_number', 'composition'],
  },
  {
    label: 'Mosquito coil → category Household, NO gender/is_veg/composition',
    file: '220-mosquito-coil.jpg',
    expect: {
      name: ['mosquito', 'coil', 'repellent'],
      category: ['Household'],
    },
    forbidden: ['gender', 'is_veg', 'composition', 'model_number'],
  },
  {
    label: 'Talcum powder tin → has fragrance or net_weight_g, NO gender/color/composition',
    file: '181-talc.jpg',
    expect: {
      name: ['talc', 'talcum', 'powder'],
      category: ['Personal Care'],
    },
    forbidden: ['color', 'gender', 'composition'],
  },
  {
    label: 'Safety pins pack → category Household or Stationery, NO color/gender/is_veg',
    file: '171-safety-pin.jpg',
    expect: {
      name: ['safety pin', 'pin'],
    },
    forbidden: ['gender', 'is_veg', 'composition', 'model_number'],
  },
  {
    label: 'Rubber bands pack → category Household or Stationery, NO color/gender/is_veg',
    file: '173-rubber-band.jpg',
    expect: {
      name: ['rubber band', 'elastic band', 'band'],
    },
    forbidden: ['gender', 'is_veg', 'composition', 'model_number'],
  },
  {
    label: 'Alarm clock → category Electronics or Household, NO gender/is_veg',
    file: '203-alarm-clock.jpg',
    expect: {
      name: ['alarm', 'clock'],
    },
    forbidden: ['gender', 'is_veg', 'composition'],
  },

  // ── TOYS ──────────────────────────────────────────────────────
  {
    label: 'LEGO/building blocks → has piece_count or age_group, category Toys',
    file: '301-lego.jpg',
    expect: {
      name: ['lego', 'blocks', 'building', 'bricks'],
      category: ['Toys', 'Stationery'],
    },
    forbidden: ['gender', 'is_veg', 'composition'],
  },
  {
    label: 'Jigsaw puzzle → has piece_count, has age_group, category Toys',
    file: '302-jigsaw.jpg',
    expect: {
      name: ['puzzle', 'jigsaw'],
      category: ['Toys'],
    },
    forbidden: ['gender', 'is_veg', 'composition'],
  },
];

// ═══════════════════════════════════════════════════════════════════
// RUN TESTS
// ═══════════════════════════════════════════════════════════════════
console.log('\n╔══════════════════════════════════════════════════════════════╗');
console.log('║  ACCURACY TEST — checks correct details, not just detection  ║');
console.log(`╚══════════════════════════════════════════════════════════════╝\n`);

if (!KEYS.length) {
  console.error('ERROR: Set GEMINI_DIRECT_KEY=key1,key2,key3 before running');
  process.exit(1);
}

let pass = 0, fail = 0, skip = 0;
const failures = [];

for (let i = 0; i < TESTS.length; i++) {
  const t = TESTS[i];
  const filePath = `test image/${t.file}`;
  console.log(`[${i + 1}/${TESTS.length}] ${t.label}`);

  if (!fs.existsSync(filePath)) {
    console.log(`  SKIP — file not found: ${filePath}\n`);
    skip++;
    continue;
  }

  const kb = Math.round(fs.statSync(filePath).size / 1024);
  console.log(`  file: ${t.file} (${kb}KB)`);

  const res = await scanFile(filePath);
  if (res.error) {
    console.log(`  ERROR: ${res.error}\n`);
    fail++;
    continue;
  }

  const gotProduct = res.is_product !== false;
  console.log(`  → is_product:${res.is_product} | name:"${res.name ?? ''}" | category:"${res.category ?? ''}"`);

  const fieldIssues = [];

  // 1. Reject check
  if (t.mustReject) {
    if (gotProduct) {
      fieldIssues.push(`should be REJECTED (is_product:false) but AI returned is_product:${res.is_product}`);
    }
  } else {
    // 2. Must be detected as a product
    if (!gotProduct) {
      fieldIssues.push(`should be a PRODUCT but AI returned is_product:false`);
    }

    // 3. Check expected fields
    if (t.expect) {
      for (const [field, expected] of Object.entries(t.expect)) {
        const aiVal = res[field];
        if (!fieldMatches(aiVal, expected)) {
          const expStr = Array.isArray(expected) ? expected.join(' or ') : (expected === null ? '(any non-empty)' : expected);
          fieldIssues.push(`"${field}" → AI returned: ${JSON.stringify(aiVal)} | expected: ${expStr}`);
        }
      }
    }

    // 4. Check forbidden fields
    if (t.forbidden) {
      for (const field of t.forbidden) {
        if (res[field] !== undefined && res[field] !== null && res[field] !== '') {
          fieldIssues.push(`FORBIDDEN field "${field}" should not be present, but AI returned: ${JSON.stringify(res[field])}`);
        }
      }
    }
  }

  if (fieldIssues.length === 0) {
    console.log(`  ✓ PASS\n`);
    pass++;
  } else {
    console.log(`  ✗ FAIL:`);
    fieldIssues.forEach(issue => console.log(`      • ${issue}`));
    console.log();
    fail++;
    failures.push({ label: t.label, file: t.file, issues: fieldIssues, res });
  }

  if (i < TESTS.length - 1) await new Promise(r => setTimeout(r, 5000));
}

console.log('='.repeat(65));
console.log(`ACCURACY: ${pass} PASS | ${fail} FAIL | ${skip} SKIP  (of ${TESTS.length} tests)`);
const pct = TESTS.length > 0 ? Math.round(100 * pass / (TESTS.length - skip)) : 0;
console.log(`Score: ${pct}% accuracy`);

if (failures.length) {
  console.log('\n═══ FAILURES — prompt needs fixing ═══');
  failures.forEach(f => {
    console.log(`\n  ✗ ${f.label}`);
    f.issues.forEach(issue => console.log(`      • ${issue}`));
  });
  fs.writeFileSync('test image/accuracy-failures.json', JSON.stringify(failures, null, 2));
  console.log('\nFailures saved → test image/accuracy-failures.json');
}
