import { NextRequest, NextResponse } from 'next/server';

export const runtime = 'nodejs';

// Simple in-memory rate limiter: 10 requests per IP per minute
const rateLimitMap = new Map<string, { count: number; resetAt: number }>();

function checkRateLimit(ip: string, maxPerMinute = 10): boolean {
  const now = Date.now();
  const entry = rateLimitMap.get(ip);
  if (!entry || now > entry.resetAt) {
    rateLimitMap.set(ip, { count: 1, resetAt: now + 60_000 });
    return true;
  }
  if (entry.count >= maxPerMinute) return false;
  entry.count++;
  return true;
}

// Universal product-aware prompt — handles 35+ real Kerala shop edge cases:
// plain bags, loose produce, handwritten prices, dark/blurry shots, regional
// language labels, multiple products in frame, crossed-out prices, generic items,
// combo packs, open boxes, product facing away, price boards, empty containers.
function buildPrompt(shopType: string): string {
  const hint = shopType
    ? `\n\nShop type hint (the product may still be anything): ${shopType}.`
    : '';
  return `You are an AI helping a Kerala (India) shop owner add products to their inventory by photographing them. Given a photo, identify the ONE product being sold and return structured JSON.

━━━ WHAT THE PHOTO MIGHT SHOW ━━━
The owner pointed their phone at ONE product. It may be:
1. LABELLED PRODUCT — brand + name visible (Parle-G, Lux Soap, POCO M6 5G, Casio calculator)
2. PRODUCT IN BOX — read the box label to name the product (the sealed box IS what the shop sells):
   e.g. POCO M6 5G box → name="POCO M6 5G", Colgate toothpaste box → name="Colgate Total Toothpaste"
3. PLAIN TRANSPARENT BAG — very common in Kerala; identify what is INSIDE the bag:
   e.g. rice, green chillies, coconut oil, sugar, spices, lemon
4. LOOSE/BULK ITEM — no packaging at all; identify by visual type:
   e.g. Red Chilli, Moong Dal, Coconut, Banana, Bitter Gourd, Ginger, Cardamom
5. DIM/BLURRY/ANGLED — shop lighting is often poor; try to identify anyway, set confidence low
6. MESSY MARKET STALL — many items in background; focus on the most prominent/centred item
7. PRODUCT FACING AWAY — only the back/side visible; read barcode text, ingredients brand, or describe generically
8. MEDICINE/BLISTER PACK — may show only blisters; identify medicine name if visible
9. STACKED PRODUCTS — multiple units of the same item; treat as one product type
10. COMBO / BUNDLE PACK — "2+1 free", "Family Pack", "Value Pack" → name it as sold:
    e.g. "Lux Soap 3-Pack" or "Parle-G Family Pack 800g"
11. HAND-HELD / LIFTED UP — owner holding product toward camera; identify the product, ignore the hand

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
Labels may be in Malayalam, Tamil, Kannada, Hindi, Arabic, Urdu, or English. Read them all:
• For brand names in regional scripts: transliterate to English (e.g. "നിരപ്പാറ" → "Nirapara")
• Arabic/Urdu labels are common on Gulf-imported products sold in Kerala — read and transliterate them
• Common Kerala brands to recognise: Nirapara, Eastern, Milma, Malabar Gold, Double Horse,
  KTC, Cavin's, Palazhi, Ente Keralam
• If you see both English and regional text for the same name, prefer the English version

━━━ KERALA FISH & SEAFOOD GUIDE ━━━
Use the local Malayalam name alongside the English name for Kerala fish:
• Neymeen / Ayakoora = King Fish / Seer Fish (silvery, firm, crosscut slices common)
• Mathi / Chaala = Sardine (small silvery, often sold in large fresh piles)
• Ayala = Indian Mackerel (blue-green stripes, medium size)
• Avoli = Pomfret (flat disc-shaped, white/silver)
• Karimeen = Pearl Spot (dark, round, bony — famous Kerala fish, symbol of backwaters)
• Chemmeen / Konju = Prawns / Shrimp (small-medium: Chemmeen; large: Konju/Tiger prawn)
• Meen (generic) = Fish (if species unclear, use "Fresh Fish (Meen)")
• Pearl spot/Karimeen in banana leaf = Karimeen Pollichathu (popular dish, is_product:false if cooked)
• When photographed in a Kerala fish market: identify species if visible, else "Fresh Fish"

━━━ KERALA-SPECIFIC PRODUCT IDENTIFICATION GUIDE ━━━
Kerala shops sell many products with specific local varieties. Use the EXACT local name when identifiable.

🍌 BANANAS — Kerala has 8+ distinct commercial varieties. Identify by visual appearance:
  • Nendran (നേന്ത്രം) — Long (20-30cm), thick, angular, green-yellow. Used for chips & cooking. Most common in Kerala shops.
    → name: "Nendran Banana (Ethapazham)" | Ripe Nendran → "Ethapazham (Ripe Nendran)"
  • Poovan (പൂവൻ) — Small (10-12cm), thin, slightly curved, bright yellow with a pointed tip. Sweet & tangy.
    → name: "Poovan Banana"
  • Palayan Kodan (പാളയൻകോടൻ) — Small-medium, chubby, very sweet, yellow. Premium eating banana.
    → name: "Palayan Kodan Banana"
  • Monthan (മൊന്തൻ) — Short, very thick, angular like Nendran but shorter. Cooking only, never eaten raw.
    → name: "Monthan Banana (Cooking)"
  • Robusta — Large (15-18cm), regular supermarket banana, smooth skin, mild taste.
    → name: "Robusta Banana"
  • Kadali / Raw banana (കദളി) — Any unripe green cooking banana.
    → name: "Raw Banana (Pachakkai Vazhakkai)"
  • If variety unclear: name="Banana" and add "variety" to uncertain_fields

🌾 RICE — Kerala shops sell specific varieties. Identify by pack label or grain colour if visible:
  • Matta Rice / Rosematta / Kerala Red Rice — Dark reddish-brown, parboiled, thick grains. Distinctly red/brown colour.
    → name: "Kerala Matta Rice (Rosematta)" | is_veg: "Veg"
  • Jaya Rice — White, medium-long grain, most common white rice in Kerala.
    → name: "Jaya Rice" | is_veg: "Veg"
  • Ponni Rice — White, slightly shorter grain, used for idli/dosa/rice.
    → name: "Ponni Rice" | is_veg: "Veg"
  • Basmati Rice — Long, thin, white, aromatic. Usually branded (India Gate, Dawaat, Kohinoor).
    → name: "Basmati Rice [Brand if visible]"
  • If variety not readable from label: name="Rice" (specify variety in uncertain_fields)

🥭 MANGOES — Kerala has local varieties:
  • Malgova — Very large, round-oval, green-yellow skin, thick flesh. Premium dessert mango.
    → name: "Malgova Mango"
  • Alphonso / Hapus — Medium, golden-orange skin, very sweet aroma. Usually labelled.
    → name: "Alphonso Mango (Hapus)"
  • Neelam — Small-medium, yellow, fibrous, season May-June.
    → name: "Neelam Mango"
  • Priya / Priyan — Common Kerala variety, green-yellow.
    → name: "Priya Mango"
  • If variety not identifiable: name="Mango" (add variety to uncertain_fields)

🥬 KERALA VEGETABLES — use local Malayalam names alongside English:
  • Cheera (ചീര) — Amaranth leaves, red or green bunches. → name: "Cheera (Amaranth Leaves)" | Red: "Red Cheera"
  • Muringakka (മുരിങ്ങക്ക) — Drumstick / Moringa pods, long thin green pods.
    → name: "Muringakka (Drumstick)"
  • Kumbalanga (കുമ്പളങ്ങ) — Ash gourd / Winter melon, large pale green oval.
    → name: "Kumbalanga (Ash Gourd)"
  • Pavakka (പാവക്ക) — Bitter gourd / Karela, warty green surface.
    → name: "Pavakka (Bitter Gourd)"
  • Chena (ചേന) — Elephant foot yam, large rough brown tuber.
    → name: "Chena (Elephant Foot Yam)"
  • Koorka (കൂർക്ക) — Chinese potato / Crosnes, small round tubers.
    → name: "Koorka (Chinese Potato)"
  • Chembu (ചേമ്പ്) — Taro / Colocasia, large rough tuber.
    → name: "Chembu (Taro)"
  • Unnakkai / Kaya (കായ) — Raw / unripe plantain, used for Kerala dishes.
    → name: "Kaya (Raw Plantain)"
  • Vellarikka (വെള്ളരിക്ക) — Cucumber (Kerala variety, longer and lighter than regular).
    → name: "Vellarikka (Kerala Cucumber)"
  • Kovakka (കോവക്ക) — Ivy gourd / Tindora, small oval green vegetable.
    → name: "Kovakka (Ivy Gourd)"
  • Ethakka (full Nendran) / Kaya — Large raw plantain for cooking.
    → name: "Ethakka / Raw Plantain"

🌶️ KERALA SPICES — be specific with variety:
  • Kurumulaku (കുരുമുളക്) — Black pepper, round dark berries. Kerala's most famous spice.
    → name: "Kurumulaku (Black Pepper)" or "Black Pepper Powder" if ground
  • Elakka (ഏലക്ക) — Cardamom pods, green oval pods with seeds.
    → name: "Elakka (Green Cardamom)"
  • Jathikka (ജാതിക്ക) — Nutmeg, round brown nut. Jathipathri = Mace (lacy red/orange covering).
    → name: "Jathikka (Nutmeg)" or "Jathipathri (Mace)"
  • Lavangam (ലവംഗം) — Cloves, small dark brown nail-shaped.
    → name: "Lavangam (Cloves)"
  • Patta (പട്ട) — Cinnamon / Cassia bark, rolled brown sticks.
    → name: "Patta (Cinnamon)"
  • Thalichapodi / Chilli powder — Red chilli powder, bright red colour.
    → name: "Red Chilli Powder" (or brand if visible e.g. "Eastern Red Chilli Powder")
  • Haldi / Manjal (മഞ്ഞൾ) — Turmeric, bright orange-yellow powder or root.
    → name: "Manjal (Turmeric Powder)" or "Fresh Turmeric Root"

🥥 COCONUT PRODUCTS:
  • Tender coconut / Ilaneer (ഇളനീർ) — Green, spherical, young coconut for drinking.
    → name: "Ilaneer (Tender Coconut)"
  • Dry coconut / Copra (കൊപ്ര) — Brown, hard, dried coconut half.
    → name: "Copra (Dried Coconut)"
  • Coconut oil — Identify brand if visible:
    → KLF Nirmal, Parachute, Ente Keralam, Nirapara — use brand name: "KLF Nirmal Coconut Oil"
    → If loose/unlabelled: name: "Coconut Oil (Vennennai)"

🐟 KERALA FISH (extended) — add to fish guide:
  • Tilapia (Jalebi / Aquaculture fish) — Farm-raised, disc-shaped, available year-round.
    → name: "Tilapia (Jalebi)"
  • Vatta ( വട്ട) — Indian Scad, small round silvery fish. Common in Kerala.
    → name: "Vatta Fish (Indian Scad)"
  • Kora (കൊര) — Croaker fish, yellowish, medium size.
    → name: "Kora (Croaker Fish)"
  • Kalava (കലവ) — Grouper, large reef fish.
    → name: "Kalava (Grouper)"
  • Crab (ഞണ്ട്) — Mud crab or mangrove crab, dark shell.
    → name: "Njandu (Mud Crab)"
  • Squid / Koonthal (കൂന്തൽ) — White tentacled body.
    → name: "Koonthal (Squid)"
  • Oyster / Mussels (Kadukka) — Dark shells, sold in bunches.
    → name: "Kadukka (Mussels / Oyster)"

🍚 KERALA BRANDED STAPLES — recognise these local brands:
  • Nirapara — Rice, flour, spice powders (red pack with Kerala motif)
  • Eastern — Masala powders, curry powder (yellow/orange packs)
  • Double Horse — Rice, atta, spices (blue/white pack)
  • Milma — Kerala cooperative dairy (white milk packets, butter, curd)
  • Brahmins — Chutneys, pickles (purple/maroon label)
  • KLF Nirmal — Coconut oil (yellow tin or bottle)
  • Ente Keralam — Coconut oil and Kerala food products
  • Malabar Gold — Spices (green and gold pack)

IMPORTANT: When you can identify the EXACT Kerala local variety, ALWAYS use the specific name.
"Nendran Banana" is far more useful to a Kerala shop owner than just "Banana".
"Matta Rice" is more useful than "Rice".
"Karimeen" is more useful than "Fresh Fish".
Add the local Malayalam name in brackets where possible.


━━━ WHEN THERE IS NO LABEL OR BRAND ━━━
• Loose item or plain bag → name it accurately by type: "Basmati Rice", "Green Chilli",
  "Coconut Oil", "Ginger", "Banana", "Bitter Gourd", "Cardamom", "Turmeric Powder"
• Generic device/item → name it accurately: "AA Battery", "USB-A to USB-C Cable",
  "A4 Notebook 200 Pages", "Steel Scissors", "Plastic Comb"
• Truly unidentifiable → set confidence "low", name it by best guess, add "name" to uncertain_fields

━━━ WHAT IS NOT A PRODUCT ━━━
Return is_product: false for:
• People, body parts, animals, pets, plants/trees, furniture IN THE SCENE
• Empty shelf or empty floor with no product visible
• Wide-angle shot of entire shop interior (no single product in focus)
• A promotional flyer, brochure, or advertisement leaflet that is NOT itself for sale
• Clearly damaged/used/empty container (no longer sellable)
• Currency notes or coins (rupees, dirhams, dollars etc.) — money is not a retail product
• A receipt, invoice, bill, or order chit

IMPORTANT EXCEPTIONS — these MUST return is_product: true:
• A BOOK, TEXTBOOK, NOTEBOOK, or MAGAZINE being held or displayed on a shelf — even if its cover
  shows photos of people (Gandhi, Kennedy, etc.) — the book is the product being sold
• The BACK COVER of a book listing other publications by the same publisher — it IS a book product
  (look for ISBN barcode, price printed on cover, or publisher name to confirm it's a book)
• FRESH PRODUCE ON ITS PLANT — if the photo CLEARLY shows harvested or ready-to-harvest produce
  as the subject (e.g. pepper clusters on vine, coconuts on a branch, bananas in a bunch close-up),
  identify the PRODUCE as the product, not the plant. Ask: "Is the produce the subject, or the tree?"
  e.g. Close-up of pepper clusters → name="Fresh Green Pepper (Black Pepper)", is_product=true
• Any item a shop would sell, even without a label = is_product: true
• NOVELTY / SHAPED STATIONERY — a fish-shaped eraser, animal-shaped pencil holder, etc.
  is still a stationery product. Identify by function: "Fish-shaped Rubber Eraser", not by shape.
• PUJA / RELIGIOUS ITEMS sold in shops — camphor tablets, incense sticks (agarbatti), dhoop,
  pooja oil lamps, vibhuti, kumkum, sindoor — are retail products. Return is_product: true.
• SPORTS & GAMES sold in shops — cricket bat, carrom board, playing cards, chess set, football,
  badminton racket — are retail products. Return is_product: true.
• VINTAGE-LOOKING or OLD-STYLE PRODUCTS — if a product (soap box, tin, bottle) looks old or
  vintage but is clearly a packaged retail item, it IS a product. Return is_product: true.
DO NOT return false just because there is no label or because people's faces appear on a product cover.

━━━ JSON OUTPUT ━━━
Return ONLY valid JSON (no markdown, no code fences):
{
  "is_product": true or false,
  "name": "specific retail name — brand + model/variant/size if readable; else item type like 'Green Chillies' or 'Basmati Rice 1kg'; never leave empty if product identified",
  "brand": "brand or maker — empty string if genuinely none visible",
  "category": "choose EXACTLY ONE from this shop's category list below; empty string if none truly fits — NEVER force a wrong category. CATEGORY RULES: a book/novel/textbook/magazine → pick the Books category (not Gift Items, not Stationery). A vegetable/fruit → Fresh Produce. A medicine/tablet/syrup → Medicines. A phone/laptop/gadget → Electronics.",
  "unit": "piece | kg | g | ml | litre | pack — use kg/g for produce and loose grain; piece for single items",
  "description": "1-2 plain sentences about what the product IS and what it does",
  "price": "MRP or selling price — digits only e.g. '899'; empty string if no price is visible anywhere. NEVER guess",
  "offerPrice": "discounted / offer price — digits only; empty string if none. NEVER guess",
  "confidence": "high | medium | low",
  "uncertain_fields": ["field names you are NOT confident about — e.g. ['name', 'price']"]
}

━━━ PRODUCT-TYPE ATTRIBUTES — EXACT PER-PRODUCT WHITELIST ━━━
First identify the EXACT product type. Then add ONLY the fields listed for that type.
NEVER add fields from a different product type's list.

════════════════════════════════════════════════
📚 BOOKS & READING
════════════════════════════════════════════════

NOVEL / STORY BOOK / FICTION (e.g. Thottiyude Makan, Harry Potter):
  Add: "author", "publisher", "language" (e.g. Malayalam, English, Hindi)
  ✗ NEVER: color, gender, fabric, model_number, composition, is_veg, sizes

TEXTBOOK / ACADEMIC BOOK (school/college subject book):
  Add: "author", "publisher", "language", "edition" (e.g. 2024 Edition), "isbn"
  ✗ NEVER: color, gender, fabric, model_number

MAGAZINE / PERIODICAL (Mathrubhumi, Vanitha, etc.):
  Add: "publisher", "language", "frequency" (Weekly|Monthly|Quarterly)
  ✗ NEVER: author, color, gender, model_number

════════════════════════════════════════════════
👕 CLOTHING
════════════════════════════════════════════════

SHIRT / T-SHIRT / POLO:
  Add: "gender" (Men|Women|Kids|Unisex), "fabric" (Cotton|Polyester|Blend), "color", "sizes" (e.g. S/M/L/XL/XXL)
  ✗ NEVER: author, model_number, composition, is_veg

SAREE / DUPATTA / CHURIDAR / KURTA / SALWAR:
  Add: "gender" (Women|Unisex), "fabric" (Silk|Cotton|Chiffon|Georgette|Polyester), "color"
  ✗ NEVER: author, model_number, is_veg

LUNGI / DHOTI / MUNDU (Kerala traditional):
  Add: "gender" (Men|Unisex), "fabric" (Cotton|Silk), "color"
  ✗ NEVER: author, model_number, composition

TROUSER / JEANS / SHORTS:
  Add: "gender" (Men|Women|Kids|Unisex), "fabric" (Denim|Cotton|Polyester), "color", "sizes"
  ✗ NEVER: author, model_number, composition

SCHOOL UNIFORM / KIDS WEAR:
  Add: "gender" (Boys|Girls|Unisex), "fabric", "color", "sizes" (age group e.g. 4-6 yrs)
  ✗ NEVER: author, model_number, composition

════════════════════════════════════════════════
👟 FOOTWEAR
════════════════════════════════════════════════

LEATHER SHOE / FORMAL SHOE:
  Add: "gender" (Men|Women|Kids|Unisex), "color", "sizes" (e.g. 6/7/8/9/10), "material": "Leather"
  ✗ NEVER: author, fabric, composition, is_veg

SPORTS SHOE / SNEAKER / RUNNING SHOE:
  Add: "gender" (Men|Women|Kids|Unisex), "color", "sizes", "material" (Synthetic|Mesh|Leather)
  ✗ NEVER: author, fabric, composition, is_veg

SANDAL / CHAPPAL / SLIPPER / HAWAI:
  Add: "gender" (Men|Women|Kids|Unisex), "color", "sizes", "material" (Rubber|EVA|Leather|Synthetic)
  ✗ NEVER: author, fabric, composition, is_veg

════════════════════════════════════════════════
📱 ELECTRONICS
════════════════════════════════════════════════

SMARTPHONE / MOBILE PHONE:
  Add: "model_number" (e.g. POCO M6 5G), "color", "warranty_months" (usually 12)
  ✗ NEVER: author, gender, composition, is_veg, fabric

LAPTOP / NOTEBOOK COMPUTER:
  Add: "model_number", "color", "warranty_months"
  ✗ NEVER: author, gender, composition, is_veg

TABLET / ANDROID TABLET:
  Add: "model_number", "color", "warranty_months"
  ✗ NEVER: author, gender, composition, is_veg

KEYBOARD (computer):
  Add: "model_number", "compatible_with" (USB|Wireless|Bluetooth), "color", "warranty_months"
  ✗ NEVER: author, gender, composition, is_veg

MOUSE (computer):
  Add: "model_number", "compatible_with" (USB|Wireless|Bluetooth), "color", "warranty_months"
  ✗ NEVER: author, gender, composition, is_veg

PEN DRIVE / USB FLASH DRIVE:
  Add: "model_number", "compatible_with" (USB 2.0|USB 3.0), "color", "warranty_months"
  ✗ NEVER: author, gender, composition, is_veg

EARPHONES / WIRED HEADPHONES:
  Add: "model_number", "compatible_with" (3.5mm Jack|USB-C|Lightning), "color", "warranty_months"
  ✗ NEVER: author, gender, composition, is_veg

BLUETOOTH EARBUDS / WIRELESS HEADPHONES:
  Add: "model_number", "compatible_with": "Bluetooth", "color", "warranty_months"
  ✗ NEVER: author, gender, composition, is_veg

BLUETOOTH SPEAKER / PORTABLE SPEAKER:
  Add: "model_number", "compatible_with" (Bluetooth|AUX), "color", "warranty_months"
  ✗ NEVER: author, gender, composition, is_veg

TELEVISION / TV:
  Add: "model_number", "warranty_months"
  ✗ NEVER: author, gender, composition

ELECTRIC FAN / TABLE FAN / CEILING FAN:
  Add: "model_number", "warranty_months", "wattage"
  ✗ NEVER: author, gender, composition, is_veg

ELECTRIC IRON / CLOTHES IRON:
  Add: "model_number", "warranty_months", "wattage"
  ✗ NEVER: author, gender, composition, is_veg

MIXER / GRINDER / BLENDER:
  Add: "model_number", "warranty_months", "wattage"
  ✗ NEVER: author, gender, composition, is_veg

BATTERY (AA/AAA/9V cell):
  Add: "compatible_with" (AA|AAA|C|D|9V), "warranty_months"
  ✗ NEVER: author, gender, composition, is_veg, color

USB CABLE / CHARGING CABLE:
  Add: "compatible_with" (e.g. USB-A to USB-C|Micro-USB|Lightning), "color"
  ✗ NEVER: author, gender, composition, is_veg

CALCULATOR:
  Add: "model_number", "compatible_with" (Solar|Battery), "warranty_months"
  ✗ NEVER: author, gender, composition, is_veg

TORCH / FLASHLIGHT:
  Add: "compatible_with" (battery type e.g. AA|D cell), "color"
  ✗ NEVER: author, gender, composition, is_veg

════════════════════════════════════════════════
💊 MEDICINES & HEALTH
════════════════════════════════════════════════

TABLET / CAPSULE / BLISTER PACK:
  Add: "composition" (e.g. Paracetamol 500mg), "strength", "form": "tablet", "manufacturer"
  ✗ NEVER: color, gender, author, is_veg, model_number

SYRUP / LIQUID MEDICINE:
  Add: "composition", "strength", "form": "syrup", "manufacturer"
  ✗ NEVER: color, gender, author, is_veg, model_number

EYE / EAR / NASAL DROPS:
  Add: "composition", "form": "drops", "manufacturer"
  ✗ NEVER: color, gender, author, is_veg, model_number

CREAM / OINTMENT / GEL (medicinal):
  Add: "composition", "form": "cream" or "ointment" or "gel", "manufacturer"
  ✗ NEVER: color, gender, author, is_veg, model_number

BANDAGE / FIRST AID ITEM:
  Add: "form": "bandage" or "dressing", "manufacturer"
  ✗ NEVER: color, gender, author, is_veg, model_number, composition

════════════════════════════════════════════════
🧴 PERSONAL CARE (cosmetic/hygiene — NOT medicine)
════════════════════════════════════════════════

SHAMPOO:
  Add: "hair_type" (Dry|Oily|Normal|Damaged|All Hair Types), "volume_ml"
  ✗ NEVER: gender, color, author, model_number, composition

HAIR CONDITIONER / HAIR MASK:
  Add: "hair_type" (Dry|Damaged|Normal|All Hair Types), "volume_ml"
  ✗ NEVER: gender, color, author, model_number

HAIR OIL (coconut / almond / amla):
  Add: "hair_type" (Dry|Normal|All), "volume_ml"
  ✗ NEVER: gender, color, author, model_number

FACE WASH / FACE CLEANSER:
  Add: "skin_type" (Oily|Dry|Normal|Combination|Sensitive|All Skin Types), "volume_ml"
  ✗ NEVER: gender, color, author, model_number

FACE CREAM / MOISTURIZER:
  Add: "skin_type" (Oily|Dry|Normal|All Skin Types), "volume_ml"
  ✗ NEVER: gender, color, author, model_number

SUNSCREEN / SUNBLOCK:
  Add: "skin_type", "spf" (e.g. SPF 30|SPF 50), "volume_ml"
  ✗ NEVER: gender, color, author, model_number

BODY LOTION / BODY CREAM:
  Add: "skin_type" (Dry|Normal|All), "volume_ml"
  ✗ NEVER: gender, color, author, model_number

SOAP BAR (bathing soap):
  Add: "skin_type" (if stated: Dry|Oily|Normal|Sensitive), "net_weight_g"
  ✗ NEVER: gender, color, author, model_number, composition

TOOTHPASTE:
  Add: "variant" (Whitening|Sensitive|Cavity Protection|Fresh Mint|Herbal|Kids), "weight_g"
  ✗ NEVER: gender, color, author, model_number, is_veg

TOOTHBRUSH:
  Add: "bristle_type" (Soft|Medium|Hard), "gender" (only if explicitly Kids stated)
  ✗ NEVER: color, author, model_number, composition, is_veg

RAZOR / SHAVING BLADE:
  Add: "blade_count" (e.g. 2-blade|3-blade|5-blade), "gender" (Men|Women)
  ✗ NEVER: author, composition, is_veg, model_number

DEODORANT / ANTIPERSPIRANT:
  Add: "gender" (Men|Women|Unisex), "volume_ml", "fragrance" (e.g. Fresh|Sport|Floral — if stated)
  ✗ NEVER: color, author, model_number, composition, is_veg

PERFUME / EAU DE TOILETTE:
  Add: "gender" (Men|Women|Unisex), "volume_ml"
  ✗ NEVER: color, author, model_number, composition, is_veg

LIPSTICK / LIP GLOSS / LIP BALM:
  Add: "shade_name" (if readable e.g. Scarlet Surge), "shade_number" (if visible), "finish" (Matte|Glossy|Satin|Sheer)
  ✗ NEVER: gender, color, author, model_number

NAIL POLISH / NAIL COLOR:
  Add: "shade_name" (if readable), "finish" (Matte|Glossy|Glitter)
  ✗ NEVER: gender, color, author, model_number, composition

KAJAL / KOHL / EYELINER:
  Add: "form" (Pencil|Liquid|Gel), "color" (Black|Brown|Blue)
  ✗ NEVER: gender, author, model_number, composition

TALCUM POWDER / BODY POWDER:
  Add: "fragrance" (if stated e.g. Rose|Jasmine|Lavender), "net_weight_g"
  ✗ NEVER: gender, color, author, model_number, composition

SANITARY PAD / MENSTRUAL PAD:
  Add: "pad_size" (Regular|Large|XL|Overnight|Panty Liner), "count" (if visible)
  ✗ NEVER: gender, color, author, model_number, composition

DIAPER / NAPPY (baby):
  Add: "size" (Newborn|S|M|L|XL|XXL), "count" (if visible)
  ✗ NEVER: color, author, model_number, composition

════════════════════════════════════════════════
🍎 FOOD — FRESH PRODUCE
════════════════════════════════════════════════

VEGETABLE / FRUIT (any loose or bagged):
  Add: "is_veg": "Veg", "weight_g" (if label or price board shows weight)
  ✗ NEVER: color, gender, author, model_number, composition

FISH / SEAFOOD (fresh / raw):
  Add: "is_veg": "Non-Veg", "weight_g" (if visible)
  ✗ NEVER: color, gender, author, model_number, composition

MEAT / CHICKEN / MUTTON / BEEF (raw):
  Add: "is_veg": "Non-Veg", "weight_g" (if visible)
  ✗ NEVER: color, gender, author, model_number

EGG (raw):
  Add: "is_veg": "Egg", "count" (if pack shows number of eggs)
  ✗ NEVER: color, gender, author, model_number

════════════════════════════════════════════════
🛍️ FOOD — PACKAGED & BRANDED
════════════════════════════════════════════════

RICE / WHEAT / ATTA / FLOUR:
  Add: "is_veg": "Veg", "weight_g", "allergens" (if visible)
  ✗ NEVER: color, gender, author, model_number

COOKING OIL (coconut / sunflower / palm):
  Add: "is_veg": "Veg", "volume_ml"
  ✗ NEVER: color, gender, author, model_number

SPICE / MASALA / CONDIMENT:
  Add: "is_veg": "Veg", "weight_g"
  ✗ NEVER: color, gender, author, model_number

SUGAR / SALT / JAGGERY:
  Add: "is_veg": "Veg", "weight_g"
  ✗ NEVER: color, gender, author, model_number

DAL / LENTILS / PULSES:
  Add: "is_veg": "Veg", "weight_g"
  ✗ NEVER: color, gender, author, model_number

TEA / COFFEE (leaf, powder, bags):
  Add: "is_veg": "Veg", "weight_g", "variant" (if visible e.g. Strong Brew|Green Tea|Filter Coffee)
  ✗ NEVER: color, gender, author, model_number

MILK / BUTTERMILK / LASSI:
  Add: "is_veg": "Veg", "volume_ml", "fat_type" (Full Cream|Toned|Double Toned|Skimmed — if stated)
  ✗ NEVER: color, gender, author, model_number

BUTTER / GHEE / PANEER / CHEESE:
  Add: "is_veg": "Veg", "weight_g"
  ✗ NEVER: color, gender, author, model_number

BISCUIT / COOKIE / CRACKER:
  Add: "is_veg" (Veg|Egg), "weight_g", "allergens" (if visible)
  ✗ NEVER: color, gender, author, model_number

CHIPS / SNACK / NAMKEEN / MURUKKU / BANANA CHIPS:
  Add: "is_veg" (Veg|Non-Veg), "weight_g"
  ✗ NEVER: color, gender, author, model_number

CHOCOLATE / CANDY / SWEETS:
  Add: "is_veg" (Veg|Egg|Non-Veg), "weight_g", "allergens" (contains milk/nuts — if visible)
  ✗ NEVER: color, gender, author, model_number

INSTANT NOODLES / PASTA:
  Add: "is_veg" (Veg|Non-Veg), "weight_g"
  ✗ NEVER: color, gender, author, model_number

SOFT DRINK / JUICE / WATER / ENERGY DRINK:
  Add: "is_veg": "Veg", "volume_ml"
  ✗ NEVER: color, gender, author, model_number

HEALTH DRINK POWDER (Horlicks, Complan, Bournvita):
  Add: "is_veg": "Veg", "weight_g", "variant" (if visible e.g. Chocolate|Vanilla|Classic)
  ✗ NEVER: color, gender, author, model_number

════════════════════════════════════════════════
🏏 SPORTS — CRICKET
════════════════════════════════════════════════

CRICKET BAT:
  Add: "wood_type" (Kashmir Willow|English Willow|Tape Ball), "size" (Junior|Senior|Short Handle|Long Handle), "weight_g" (if labeled)
  ✗ NEVER: author, gender, color, composition, is_veg, model_number

CRICKET BALL:
  Add: "ball_type" (Leather|Tennis|Rubber|Tape), "color" (Red|White|Pink|Yellow)
  ✗ NEVER: author, gender, composition, is_veg, model_number

CRICKET GLOVES / PADS / HELMET:
  Add: "size" (Junior|Senior|S|M|L)
  ✗ NEVER: author, color, composition, is_veg, model_number

════════════════════════════════════════════════
🏸 SPORTS — BADMINTON
════════════════════════════════════════════════

BADMINTON RACKET:
  Add: "material" (Aluminium|Carbon Fibre|Steel), "weight_g" (if labeled), "grip_size" (G4|G5 — if visible)
  ✗ NEVER: author, gender, color, composition, is_veg, model_number

BADMINTON SHUTTLECOCK:
  Add: "shuttle_type" (Feather|Nylon|Synthetic), "speed" (Slow|Medium|Fast — if labeled)
  ✗ NEVER: author, gender, color, composition, is_veg

════════════════════════════════════════════════
⚽ SPORTS — FOOTBALL / BASKETBALL / VOLLEYBALL
════════════════════════════════════════════════

FOOTBALL / SOCCER BALL:
  Add: "size" (3|4|5), "material" (PU Leather|PVC|Rubber|Foam)
  ✗ NEVER: author, gender, composition, is_veg, model_number

BASKETBALL:
  Add: "size" (5|6|7), "material" (PU Leather|Rubber|Composite)
  ✗ NEVER: author, gender, composition, is_veg, model_number

VOLLEYBALL:
  Add: "material" (PU Leather|PVC|Rubber), "size" (Official|Mini)
  ✗ NEVER: author, gender, composition, is_veg, model_number

════════════════════════════════════════════════
🏓 SPORTS — TABLE TENNIS / CARROM / CHESS / CARDS
════════════════════════════════════════════════

TABLE TENNIS BAT / PADDLE:
  Add: "rubber_type" (if visible: Smooth|Pimpled)
  ✗ NEVER: author, gender, color, composition, is_veg

TABLE TENNIS BALL:
  Add: "color" (White|Orange), "ball_type" (Training|Tournament)
  ✗ NEVER: author, gender, composition, is_veg

CARROM BOARD:
  Add: "size" (Full Size|Medium|Mini), "material" (Plywood|MDF|Hardboard)
  ✗ NEVER: author, gender, color, composition, is_veg, model_number

CHESS SET:
  Add: "material" (Plastic|Wood|Metal|Magnetic), "size" (Standard|Travel|Mini)
  ✗ NEVER: author, gender, color, composition, is_veg, model_number

PLAYING CARDS:
  Add: "card_type" (Standard 52-card|Jumbo Print|Waterproof)
  ✗ NEVER: author, gender, color, composition, is_veg, model_number

════════════════════════════════════════════════
🔧 TOOLS & HARDWARE
════════════════════════════════════════════════

HAMMER:
  Add: "head_material" (Steel|Rubber|Wood mallet), "weight_g" (if labeled)
  ✗ NEVER: author, gender, color, composition, is_veg, model_number

SCREWDRIVER:
  Add: "screw_type" (Phillips +|Flat -|Torx|Multi-bit), "size" (e.g. 6 inch|8 inch)
  ✗ NEVER: author, gender, color, composition, is_veg, model_number

PLIERS:
  Add: "plier_type" (Combination|Long Nose|Wire Cutter|Slip Joint), "size_mm" (if labeled)
  ✗ NEVER: author, gender, color, composition, is_veg, model_number

WRENCH / SPANNER:
  Add: "wrench_type" (Open-end|Ring|Adjustable|Allen Key), "size_mm" (if labeled)
  ✗ NEVER: author, gender, color, composition, is_veg, model_number

SAW:
  Add: "saw_type" (Hand Saw|Hacksaw|Pruning Saw), "blade_length_cm" (if visible)
  ✗ NEVER: author, gender, color, composition, is_veg, model_number

TAPE MEASURE:
  Add: "length_m" (e.g. 3|5|10)
  ✗ NEVER: author, gender, color, composition, is_veg, model_number

NAILS / SCREWS / BOLTS (pack):
  Add: "size" (e.g. 1 inch|2 inch), "material" (Galvanised Steel|Stainless Steel)
  ✗ NEVER: author, gender, color, composition, is_veg, model_number

PAINT BRUSH:
  Add: "brush_size" (e.g. 1 inch|2 inch|No.8), "bristle_type" (Natural|Synthetic)
  ✗ NEVER: author, gender, composition, is_veg, model_number

════════════════════════════════════════════════
🍳 KITCHEN UTENSILS & COOKWARE
════════════════════════════════════════════════

PRESSURE COOKER:
  Add: "capacity_litres" (e.g. 3|5|7), "material" (Aluminium|Stainless Steel)
  ✗ NEVER: author, gender, color, composition, is_veg, model_number

KADAI / WOK / COOKING PAN:
  Add: "material" (Iron|Stainless Steel|Non-stick Aluminium|Copper), "diameter_cm" (if labeled)
  ✗ NEVER: author, gender, color, composition, is_veg, model_number

TAWA / GRIDDLE / FLAT PAN:
  Add: "material" (Iron|Non-stick|Stainless Steel), "diameter_cm" (if labeled)
  ✗ NEVER: author, gender, color, composition, is_veg, model_number

SPATULA / LADLE / COOKING SPOON:
  Add: "material" (Stainless Steel|Plastic|Wood|Silicone)
  ✗ NEVER: author, gender, color, composition, is_veg, model_number

KNIFE / CHOPPER:
  Add: "blade_material" (Stainless Steel|Carbon Steel), "knife_type" (Chef|Vegetable|Bread|Cleaver)
  ✗ NEVER: author, gender, color, composition, is_veg, model_number

PLATE / THALI:
  Add: "material" (Stainless Steel|Melamine|Plastic|Ceramic), "diameter_cm" (if visible)
  ✗ NEVER: author, gender, color, composition, is_veg, model_number

CUP / GLASS / TUMBLER / MUG:
  Add: "material" (Stainless Steel|Glass|Plastic|Ceramic), "capacity_ml" (if labeled)
  ✗ NEVER: author, gender, color, composition, is_veg, model_number

LUNCH BOX / TIFFIN BOX:
  Add: "material" (Stainless Steel|Plastic), "compartments" (e.g. 3), "capacity_ml" (if labeled)
  ✗ NEVER: author, gender, color, composition, is_veg, model_number

THERMOS / INSULATED FLASK:
  Add: "capacity_ml" (e.g. 500|750|1000), "material" (Stainless Steel|Plastic)
  ✗ NEVER: author, gender, color, composition, is_veg, model_number

BUCKET / MUG (bathroom / household):
  Add: "capacity_litres" (e.g. 10|15|20), "material" (Plastic|Steel)
  ✗ NEVER: author, gender, color, composition, is_veg, model_number

════════════════════════════════════════════════
📎 STATIONERY
════════════════════════════════════════════════

PEN / BALLPOINT PEN:
  Add: "ink_color" (Blue|Black|Red|Green), "pen_type" (Ballpoint|Gel|Rollerball|Fountain)
  ✗ NEVER: author, gender, fabric, composition, is_veg, model_number

PENCIL:
  Add: "grade" (HB|2B|4B|6B — if labeled), "pencil_type" (Graphite|Colour|Mechanical)
  ✗ NEVER: author, gender, composition, is_veg, model_number

NOTEBOOK / EXERCISE BOOK:
  Add: "page_count" (if visible, e.g. 100|200|300), "ruling" (Single Line|Double Line|Blank|Graph)
  ✗ NEVER: author, publisher, gender, composition, is_veg

ERASER:
  Add: "eraser_type" (Vinyl|Gum|Kneaded), "color" (White|Pink)
  ✗ NEVER: author, gender, composition, is_veg, model_number

STAPLER:
  Add: "compatible_with" (staple size e.g. No.10|No.24/6)
  ✗ NEVER: author, gender, color, composition, is_veg

SCISSORS:
  Add: "blade_length_cm" (if labeled), "material" (Stainless Steel)
  ✗ NEVER: author, gender, composition, is_veg

RULER:
  Add: "length_cm" (e.g. 15|30|60), "material" (Plastic|Steel|Wood)
  ✗ NEVER: author, gender, color, composition, is_veg

TAPE / CELLO TAPE:
  Add: "width_mm" (if labeled e.g. 12mm|24mm), "length_m" (if labeled)
  ✗ NEVER: author, gender, color, composition, is_veg

GLUE / ADHESIVE / FEVICOL:
  Add: "glue_type" (White Glue|Super Glue|Stick Glue|Epoxy)
  ✗ NEVER: author, gender, color, composition, is_veg, model_number

════════════════════════════════════════════════
🪔 HOUSEHOLD / PUJA / CLEANING ITEMS
════════════════════════════════════════════════

INCENSE STICK / AGARBATTI:
  Add: "fragrance" (if readable e.g. Jasmine|Sandalwood|Rose|Lavender|Chandan)
  ✗ NEVER: color, gender, author, model_number

CANDLE:
  Add: "candle_type" (Wax|Taper|Tealight|Scented), "color" (if clearly visible)
  ✗ NEVER: author, gender, composition, is_veg, model_number

CAMPHOR / BINDI / KUMKUM / SAFETY PIN / RUBBER BAND / MOSQUITO COIL / FLOOR CLEANER / MATCHBOX:
  NO extra fields — base JSON only (name, brand, category, unit, description, price)

════════════════════════════════════════════════
🧸 TOYS
════════════════════════════════════════════════

ACTION FIGURE / DOLL:
  Add: "character_name" (if recognizable e.g. Spider-Man|Barbie), "age_group" (e.g. 3+|6+), "material" (Plastic|Fabric)
  ✗ NEVER: composition

BUILDING BLOCKS / CONSTRUCTION TOY:
  Add: "piece_count" (if labeled), "age_group", "material" (Plastic|Wood)
  ✗ NEVER: gender, author, composition

PUZZLE / JIGSAW:
  Add: "piece_count" (e.g. 100|500|1000), "age_group"
  ✗ NEVER: gender, author, composition

⚠️ MASTER RULE: Identify the product type first. Add ONLY what is listed for that type.
Any field not in the whitelist for this product = DO NOT add it.${hint}`;
}

export async function POST(req: NextRequest) {
  const ip = req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ?? 'unknown';
  if (!checkRateLimit(ip, 10)) {
    return NextResponse.json({ error: 'Too many requests. Please wait a minute.' }, { status: 429 });
  }

  // Collect all configured API keys — will try them in order and rotate on quota exhaustion
  const apiKeys = [
    process.env.GEMINI_API_KEY,
    process.env.GEMINI_API_KEY_2,
    process.env.GEMINI_API_KEY_3,
  ].filter((k): k is string => !!k);
  if (apiKeys.length === 0) {
    return NextResponse.json(
      { error: 'Gemini not configured — add GEMINI_API_KEY to Vercel environment variables' },
      { status: 503 }
    );
  }

  let body: { image?: string; shopType?: string; categories?: string[] };
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON body' }, { status: 400 });
  }

  const { image, shopType = '', categories } = body;
  if (!image || typeof image !== 'string') {
    return NextResponse.json({ error: 'image required' }, { status: 400 });
  }
  if (image.length > 2_000_000) {
    return NextResponse.json({ error: 'Image too large' }, { status: 400 });
  }

  // Strip base64 data URL prefix if present (e.g. "data:image/jpeg;base64,...")
  const base64 = image.includes(',') ? image.split(',')[1] : image;

  let prompt = buildPrompt(shopType);

  // Give Gemini the shop's real category list so it picks the right one for the
  // ACTUAL product (a General/Fancy store sells phones, books, talc, shoes...).
  if (Array.isArray(categories) && categories.length > 0) {
    const list = categories.filter((c) => typeof c === 'string' && c.trim()).slice(0, 40);
    if (list.length > 0) {
      prompt += `\n\nThis shop's category list (pick the "category" value verbatim from here, or empty string if none fit):\n${list.join(' | ')}`;
    }
  }

  let text = '';

  // Try each API key in order; rotate to next key on quota exhaustion (429)
  let lastErr = '';
  let allKeysExhausted = true;
  for (const apiKey of apiKeys) {
    let geminiRes: Response;
    try {
      geminiRes = await fetch(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent',
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-goog-api-key': apiKey,
          },
          body: JSON.stringify({
            contents: [{
              parts: [
                { text: prompt },
                { inline_data: { mime_type: 'image/jpeg', data: base64 } },
              ],
            }],
          }),
        }
      );
    } catch (e) {
      lastErr = e instanceof Error ? e.message : String(e);
      continue;
    }
    if (geminiRes.status === 429) {
      // This key is rate-limited — try the next one
      lastErr = `quota_exceeded_key_${apiKeys.indexOf(apiKey) + 1}`;
      continue;
    }
    if (!geminiRes.ok) {
      const errBody = await geminiRes.text();
      return NextResponse.json({ error: `Gemini error: ${geminiRes.status} ${errBody.slice(0, 300)}` }, { status: 500 });
    }
    const json = await geminiRes.json() as {
      candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
    };
    text = json.candidates?.[0]?.content?.parts?.[0]?.text?.trim() ?? '';
    allKeysExhausted = false;
    break;
  }
  if (allKeysExhausted) {
    return NextResponse.json(
      { error: 'Daily scan quota reached. Please try again after midnight. ' + lastErr },
      { status: 429 }
    );
  }

  if (!text) {
    return NextResponse.json({ error: 'Empty response from Gemini' }, { status: 500 });
  }

  try {
    // Try direct parse first, then extract JSON from response
    let parsed: Record<string, unknown>;
    try {
      parsed = JSON.parse(text);
    } catch {
      const match = text.match(/\{[\s\S]*\}/);
      if (!match) {
        return NextResponse.json(
          { error: 'Could not parse Gemini response', raw: text },
          { status: 500 }
        );
      }
      parsed = JSON.parse(match[0]);
    }

    const name = typeof parsed.name === 'string' ? parsed.name : '';
    const brand = typeof parsed.brand === 'string' ? parsed.brand : '';
    const isProduct = parsed.is_product !== false; // default true unless explicitly false

    // After Gemini identifies the product, try free exact-match image databases
    // server-side (Open Food Facts for groceries, Open Library for books). Skip
    // for non-products. General web image search runs on-device in the app.
    if (isProduct && (name || brand)) {
      const query = [brand, name].filter(Boolean).join(' ');

      // 1. Open Food Facts — best for packaged grocery/food products
      if (!parsed.imageUrl) {
        try {
          const offRes = await fetch(
            `https://world.openfoodfacts.org/cgi/search.pl?search_terms=${encodeURIComponent(query)}&search_simple=1&action=process&json=1&page_size=1&lc=en`,
            { headers: { 'User-Agent': 'Oratas/1.0 (oratas4ai@gmail.com)' }, signal: AbortSignal.timeout(4000) }
          );
          if (offRes.ok) {
            const offData = await offRes.json() as { products?: Array<{ image_front_url?: string }> };
            const imgUrl = offData.products?.[0]?.image_front_url;
            if (imgUrl) parsed.imageUrl = imgUrl;
          }
        } catch { /* best-effort */ }
      }

      // 2. Open Library — books, textbooks (official API, no key needed)
      if (!parsed.imageUrl) {
        try {
          const olRes = await fetch(
            `https://openlibrary.org/search.json?q=${encodeURIComponent(query)}&limit=1&fields=cover_i`,
            { headers: { 'User-Agent': 'Oratas/1.0 (oratas4ai@gmail.com)' }, signal: AbortSignal.timeout(4000) }
          );
          if (olRes.ok) {
            const olData = await olRes.json() as { docs?: Array<{ cover_i?: number }> };
            const coverId = olData.docs?.[0]?.cover_i;
            if (coverId) parsed.imageUrl = `https://covers.openlibrary.org/b/id/${coverId}-L.jpg`;
          }
        } catch { /* best-effort */ }
      }
    }

    return NextResponse.json(parsed);
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
