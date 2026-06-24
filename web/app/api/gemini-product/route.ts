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

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  KERALA COMPREHENSIVE PRODUCT GUIDE — 200+ TYPES & VARIANTS
  For each product: look at image → pick MOST SPECIFIC name
  Works for PACKED (labelled), LOOSE/BULK, and HAND-HELD items
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

════════════════════════════════════════════════
🍌 BANANAS — 9 VARIETIES (identify by shape+size+colour)
════════════════════════════════════════════════
Look at: length, thickness, shape (angular vs round), skin colour when sold.
• NENDRAN (നേന്ത്രം) — 20-30cm long, thick, 4-5 sides (angular), green-yellow, starchy. Sold raw for chips.
  Packed: look for "Nendran" on label. Loose: longest, most angular banana in the bunch.
  → name: "Nendran Banana (Raw)" | unit: piece or kg
• ETHAPAZHAM (ഏത്തപ്പഴം) — Same Nendran banana but RIPENED (yellow-black skin). Sweet, eaten raw.
  → name: "Ethapazham (Ripe Nendran Banana)"
• POOVAN (പൂവൻ) — 10-12cm, thin, slightly curved, bright yellow, pointed tip. Sweet-tangy.
  → name: "Poovan Banana"
• PALAYAN KODAN (പാളയൻകോടൻ) — Similar to Poovan but chubbier, very sweet, premium price.
  → name: "Palayan Kodan Banana"
• MONTHAN (മൊന്തൻ) — 12-15cm, very thick, angular like Nendran but shorter. ONLY for cooking.
  → name: "Monthan Banana (Cooking)"
• ROBUSTA — 15-18cm, smooth rounded skin, supermarket-style, mild flavour. Sold everywhere.
  → name: "Robusta Banana"
• NJALIPOOVAN / MYSORE BANANA — Small (8-10cm), very sweet, pink blush on skin.
  → name: "Njalipoovan Banana"
• PALAYANKODAN CHENGALIKODAN — Rare, very sweet, fat short variety.
  → name: "Chengalikodan Banana"
• RAW GREEN BANANA (any) — Unripe, fully green, any variety, used for cooking.
  → name: "Kaya (Raw Green Banana)" | unit: piece or kg
• BANANA FLOWER (കദളിപ്പൂ / Vazha Poo) — Purple-red elongated flower cluster hanging from tree.
  → name: "Vazha Poo (Banana Flower)" | is_veg: Veg
• BANANA STEM (Vazha Thandu) — White cylindrical stem cross-section.
  → name: "Vazha Thandu (Banana Stem)" | is_veg: Veg

════════════════════════════════════════════════
🌾 RICE — 10 VARIETIES
════════════════════════════════════════════════
Look at: grain colour (red/white/yellow), grain shape (long/short/round), label brand.
• MATTA RICE / ROSEMATTA (Kerala Red Rice) — Distinctly RED-BROWN, thick grains, parboiled. Health rice.
  Packed: "Matta", "Rosematta", "Red Rice" on label. Loose: red-brown colour unmistakable.
  → name: "Kerala Matta Rice (Rosematta)" | brand if visible
• JAYA RICE — White, medium-long grain. Most common plain white rice in Kerala.
  → name: "Jaya Rice"
• PONNI RICE — White, slightly short-medium grain. South India rice for meals/idli.
  → name: "Ponni Rice"
• BASMATI RICE — Very long, thin, white grains. Aromatic. Premium brands (India Gate, Daawat, Kohinoor).
  → name: "[Brand] Basmati Rice" | brand: India Gate / Daawat / Kohinoor
• PALAKKADAN MATTA — Same as Matta but specifically from Palakkad region. Label will say "Palakkadan".
  → name: "Palakkadan Matta Rice"
• SONA MASOORI — White, lightweight medium grain. From Andhra/Telangana, sold widely in Kerala.
  → name: "Sona Masoori Rice"
• IDLI RICE / PARBOILED RICE — White, short round grain specifically for idli/dosa batter.
  → name: "Idli Rice (Parboiled)" or brand if visible
• BROKEN RICE (Thavidu) — Small white broken grains, budget rice.
  → name: "Thavidu (Broken Rice)"
• RICE FLOUR (Ari Podi) — Fine white powder in bag, different from wheat flour.
  → name: "Ari Podi (Rice Flour)" | is_veg: Veg
• PUTTU PODI — Coarsely ground rice flour specifically for making puttu. Usually has "Puttu" on label.
  → name: "[Brand] Puttu Podi (Rice Flour for Puttu)" | brands: Double Horse, Nirapara, Eastern

════════════════════════════════════════════════
🥭 MANGOES — 7 VARIETIES
════════════════════════════════════════════════
Look at: size, shape, skin colour (green/yellow/orange/red), texture, label if packed.
• MALGOVA — VERY LARGE (500g-1kg each), oval-round, green-yellow, thin skin, thick flesh.
  → name: "Malgova Mango"
• ALPHONSO / HAPUS — Medium, deep golden-orange skin, rich aroma, premium price. Usually labelled.
  → name: "Alphonso Mango (Hapus)"
• NEELAM — Medium-small, yellow-orange, slightly fibrous, season May-June. Common Kerala variety.
  → name: "Neelam Mango"
• PRIYA / PRIYAN — Common Kerala commercial mango, medium, green-yellow.
  → name: "Priya Mango"
• KILICHUNDAN (കിളിച്ചുണ്ടൻ) — Small, beak-shaped (kilichundan = parrot beak), very sweet. Prized Kerala variety.
  → name: "Kilichundan Mango (Parrot Mango)"
• SINDOORAM (സിന്ദൂരം) — Medium, red-orange skin, sweet. Distinctly reddish.
  → name: "Sindooram Mango"
• RAW MANGO (Manga / Pacha Manga) — Green, sour, used for pickles and curries.
  → name: "Pacha Manga (Raw/Green Mango)" | is_veg: Veg

════════════════════════════════════════════════
🥬 KERALA VEGETABLES — 30+ VARIETIES
════════════════════════════════════════════════
For ALL vegetables: is_veg: "Veg". Look at shape, colour, surface texture.

LEAFY GREENS:
• CHEERA (ചീര) — Amaranth leaves. RED CHEERA = red-purple leaves and stems. GREEN CHEERA = green.
  → "Red Cheera (Red Amaranth)" | "Green Cheera (Green Amaranth)"
• MURINGAYILA (മുരിങ്ങയില) — Moringa/Drumstick leaves, tiny oval leaflets on feathery branches.
  → name: "Muringayila (Drumstick Leaves)"
• CURRY LEAVES (കറിവേപ്പ് / Kariveppu) — Shiny dark green aromatic leaves on a stalk.
  → name: "Kariveppu (Curry Leaves)"
• ULUVA LEAF / FENUGREEK GREENS (വെന്തയകീര) — Pale green, 3-leaflet clusters, bitter taste.
  → name: "Uluva Keerai (Fenugreek Leaves)"
• THULASI (തുളസി / Holy Basil) — Small oval green leaves, aromatic, often potted.
  → name: "Thulasi (Holy Basil)"

GOURDS & CREEPERS:
• KUMBALANGA (കുമ്പളങ്ങ) — LARGE oval pale green, waxy smooth skin. Ash gourd/winter melon. Can be huge (5-10kg).
  → name: "Kumbalanga (Ash Gourd / Winter Melon)" | unit: kg
• PAVAKKA (പാവക്ക) — Green, WARTY surface (the bumps are the key ID feature). Bitter gourd.
  → name: "Pavakka (Bitter Gourd / Karela)"
• VELLARIKKA (വെള്ളരിക്ക) — Kerala cucumber. LONGER and PALER than regular cucumber. Pale green-white.
  → name: "Vellarikka (Kerala Cucumber)"
• KOVAKKA (കോവക്ക) — Oval, small (4-5cm), bright green, smooth. Ivy gourd/Tindora.
  → name: "Kovakka (Ivy Gourd / Tindora)"
• PEECHINGA (പീചിങ്ങ) — Ridge gourd. Long, with ridges/ribs running lengthwise, dark green.
  → name: "Peechinga (Ridge Gourd)"
• PADAVALANGA (പടവലങ്ങ) — Snake gourd. Very long (30-60cm), pale green, white stripes, twisted.
  → name: "Padavalanga (Snake Gourd)"
• CHAKKAKURU (ചക്കക്കുരു) — Jackfruit seeds. Light brown oval seeds sold separately.
  → name: "Chakkakuru (Jackfruit Seeds)" | is_veg: Veg
• MURINGAKKA (മുരിങ്ങക്ക) — Drumstick pods. Long (30-45cm), thin, dark green, rough surface.
  → name: "Muringakka (Drumstick / Moringa Pod)"

TUBERS & ROOTS:
• CHENA (ചേന) — Elephant foot yam. VERY LARGE rough brown tuber (2-10kg), cut into chunks in shop.
  → name: "Chena (Elephant Foot Yam)" | unit: kg
• CHEMBU (ചേമ്പ്) — Taro/Colocasia. Medium rough brown tuber (200-400g each), may have root fibres.
  → name: "Chembu (Taro / Colocasia)"
• KOORKA (കൂർക്ക) — Chinese potato. SMALL round-oval tubers (2-4cm), light brown, sold in bunches.
  → name: "Koorka (Chinese Potato)"
• KACHIL (കാച്ചിൽ) — Purple/violet yam. Purple-tinted skin and flesh when cut.
  → name: "Kachil (Purple Yam)"
• KATTU KACHIL / WILD YAM — Brown rough exterior, sold in chunks.
  → name: "Kachil (Wild Yam)"
• GINGER (ഇഞ്ചി / Inji) — Knobby tan-beige rhizome. Fresh = moist and firm. Dried = wrinkled.
  → name: "Inji (Fresh Ginger)" or "Dried Ginger"
• TURMERIC ROOT (ഇഞ്ചി മഞ്ഞൾ / Fresh Turmeric) — Like ginger but BRIGHT ORANGE inside, smaller.
  → name: "Fresh Turmeric Root (Inji Manjal)"

OTHERS:
• ETHAKKA / KAYA (ഏത്ത/കായ) — Raw plantain. Same as Nendran but unripe, green, for cooking.
  → name: "Ethakka / Raw Plantain (Kaya)"
• JACKFRUIT — UNRIPE (raw): large, green spiky skin, white inside. RIPE: yellow inside, sweet smell.
  → "Chakka (Raw Jackfruit)" or "Ripe Jackfruit (Pakam Chakka)" | unit: kg
• BREADFRUIT (ഈര) — Large round green fruit, bumpy surface. Common Kerala home garden tree.
  → name: "Eera (Breadfruit)"
• GREEN PAPAYA / RAW PAPAYA (Omakka) — Large, oblong, completely green. Used for curry.
  → name: "Omakka (Raw Green Papaya)"
• COCONUT — TENDER (green): for drinking. DRY (brown): for cooking/oil.
  → "Ilaneer (Tender Coconut)" | "Thenga (Dry Coconut)"
• DRUMSTICK FLOWER — White small flowers of Moringa tree, sold in small bunches.
  → name: "Muringapoo (Drumstick Flower)"

════════════════════════════════════════════════
🐟 FISH & SEAFOOD — 20+ VARIETIES
════════════════════════════════════════════════
ALL fish: is_veg: "Non-Veg". Identify by body shape, colour, size, scale pattern.
• NEYMEEN / KING FISH — Long (40-80cm), silver with dark spots, firm crosscut slices sold in shops.
  → name: "Neymeen (King Fish / Seer Fish)"
• MATHI / CHAALA (Sardine) — Very SMALL (8-12cm), silver, sold in LARGE piles. Most common Kerala fish.
  → name: "Mathi / Chaala (Indian Sardine)"
• AYALA (Indian Mackerel) — Medium (20-25cm), BLUE-GREEN STRIPES along body, torpedo shape.
  → name: "Ayala (Indian Mackerel)"
• AVOLI (Pomfret) — FLAT, disc-shaped, silver-white. Black Pomfret = dark colour.
  → "Avoli (Silver Pomfret)" | "Karuppu Avoli (Black Pomfret)"
• KARIMEEN (Pearl Spot) — Small (15-20cm), dark grey-green with gold spots, ROUND body, spiny fins.
  → name: "Karimeen (Pearl Spot)" — famous Kerala backwater fish
• CHEMMEEN / KONJU (Prawns/Shrimp) — Small/medium pink-grey shrimp = Chemmeen. Large = Konju.
  → "Chemmeen (Small Prawns)" | "Konju (Tiger Prawns / Large Prawns)"
• ROHU — Large (50-80cm sold in slices), silver with faint pink tinge, carp family.
  → name: "Rohu Fish (River Carp)"
• TILAPIA / JALEBI — Farm fish, disc-shaped like pomfret but more elongated, grey, available year-round.
  → name: "Tilapia (Jalebi Fish)"
• VATTA (Indian Scad) — Small (15-20cm), round body, silver with yellow/golden stripe.
  → name: "Vatta (Indian Scad)"
• KORA (Croaker) — Medium (25-40cm), yellowish with silver belly, large scales.
  → name: "Kora (Croaker / Jewfish)"
• KALAVA (Grouper) — LARGE, thick body, dark brown-green with spots, reef fish.
  → name: "Kalava (Grouper)"
• SEER FISH STEAKS — Cross-cut slices of King Fish showing white flesh.
  → name: "Neymeen Meen Kottam (King Fish Steaks)"
• SQUID / KOONTHAL (കൂന്തൽ) — White soft body with tentacles, torpedo shape.
  → name: "Koonthal (Squid)"
• CUTTLEFISH (Kanava) — Like squid but SHORTER and WIDER, rough texture.
  → name: "Kanava (Cuttlefish)"
• MUD CRAB / NJANDU (ഞണ്ട്) — Dark green-brown shell, large claws.
  → name: "Njandu (Mud Crab)"
• SPIDER CRAB / SMALL CRAB — Orange-red when cooked, sold live or cooked.
  → "Fresh Crab (Njandu)" if raw | "Cooked Crab" = is_product:false if clearly cooked dish
• KADUKKA / KALLUMAKKAYA (Mussels) — Dark oval shells, sold in bunches on rope or loose.
  → name: "Kallumakkaya (Mussels)"
• CLAMS / KAKKA (കക്ക) — Small dark shells, sold in bags.
  → name: "Kakka (Clams)"
• LOBSTER (Cheraman) — Large, sold live or fresh, reddish-orange shell.
  → name: "Cheraman (Lobster)"
• DRIED FISH (ഉണക്കമീൻ / Unakka Meen) — Any fish that is DRIED (dark, shrivelled, strong smell visible context).
  → name: "[Species] Unakka Meen (Dried Fish)" e.g. "Mathi Unakka Meen (Dried Sardine)"

════════════════════════════════════════════════
🌶️ SPICES — 20+ TYPES (packed and loose)
════════════════════════════════════════════════
PACKED: read brand + product name from label.
LOOSE: identify by visual appearance (colour, shape, texture).
Kerala brands: Eastern, Nirapara, Malabar Gold, Double Horse, Brahmins, MTR.
• BLACK PEPPER (Kurumulaku) — Round dark brown/black berries, or ground black powder.
  → "Kurumulaku (Black Pepper Whole)" | "Black Pepper Powder" | brand if visible
• CARDAMOM (Elakka) — Small green oval pods with visible seam, or black ground powder.
  → "Elakka (Green Cardamom Pods)" | "Cardamom Powder" | "Black Cardamom (Perumjeerakam)"
• TURMERIC (Manjal) — Bright ORANGE-YELLOW powder, or small finger-like yellowish root.
  → "Manjal Podi (Turmeric Powder)" | "Fresh Turmeric Root"
• RED CHILLI (Mulaku) — Whole dried red chillies (bright red, crinkled), or powder (deep red).
  → "Mulaku (Whole Red Chilli)" | "Mulaku Podi (Red Chilli Powder)"
• CORIANDER (Malli) — Small round tan seeds, or green powder.
  → "Malli Vithu (Coriander Seeds)" | "Malli Podi (Coriander Powder)"
• CUMIN (Jeerakam) — Thin elongated grey-green seeds.
  → "Jeerakam (Cumin Seeds)" | "Cumin Powder"
• MUSTARD (Kaduku) — Tiny round seeds, brown or black.
  → "Kaduku (Mustard Seeds)"
• FENUGREEK (Uluva) — Small square yellow seeds.
  → "Uluva (Fenugreek Seeds)"
• CLOVES (Lavangam) — Dark brown nail-shaped, strong aroma.
  → "Lavangam (Cloves)"
• CINNAMON (Patta) — Rolled bark sticks, light brown.
  → "Patta (Cinnamon Sticks)" | "Cinnamon Powder"
• NUTMEG (Jathikka) — Round brown nut with seed, or brown powder.
  → "Jathikka (Nutmeg)" | "Jathipathri (Mace)" — orange-red lacy covering around nutmeg
• STAR ANISE (Thakkolam) — Star-shaped brown spice, 8 points.
  → "Thakkolam (Star Anise)"
• BAY LEAF (Vayanayila) — Dry oval leaf, grey-green.
  → "Vayanayila (Bay Leaf)"
• GARAM MASALA — Mixed spice powder in pack. Orange-brown powder.
  → "[Brand] Garam Masala" e.g. "Eastern Garam Masala"
• CURRY POWDER (Curry Masala) — Yellow-orange mixed powder, most common branded spice in Kerala.
  → "[Brand] Curry Powder" e.g. "Eastern Curry Powder", "Nirapara Curry Masala"
• FISH MASALA / FISH CURRY POWDER — Dark red-orange powder, labelled "Fish Masala" or "Meen Masala".
  → "[Brand] Meen Masala (Fish Curry Powder)"
• CHICKEN MASALA — Pack labelled "Chicken Masala" or "Kozhi Masala".
  → "[Brand] Kozhi Masala (Chicken Masala)"
• PEPPER CHICKEN / BIRYANI MASALA — Named on pack.
  → "[Brand] Biryani Masala"
• ASAFOETIDA (Kaayam / Hing) — Small block or tin/bottle of pungent brown paste/powder.
  → "Kaayam (Asafoetida / Hing)"
• TAMARIND (Puli / Imli) — Dark brown block of dried tamarind pulp, or concentrate in jar.
  → "Puli (Tamarind Block)" | "Tamarind Paste/Concentrate"
• KOKUM (Kudampuli / Malabar Tamarind) — Dark brown dried pieces of Garcinia fruit. Kerala-specific.
  → "Kudampuli (Kokum / Malabar Tamarind)"

════════════════════════════════════════════════
🧴 PERSONAL CARE — 30+ TYPES & BRANDS
════════════════════════════════════════════════
SHAMPOOS — identify by HAIR TYPE label or visual:
• Anti-dandruff shampoo: look for "Dandruff", "Scalp" on label. → hair_type: "Dandruff-prone"
• Head & Shoulders — blue bottle, anti-dandruff. → brand: "Head & Shoulders", hair_type: "Dandruff-prone"
• Dove Shampoo — white bottle, "Intense Repair" or "Daily Shine". → brand: "Dove"
• Clinic Plus — green bottle (family shampoo). → brand: "Clinic Plus"
• Sunsilk — yellow/pink/black variants by hair type. → brand: "Sunsilk"
• Pantene — gold bottle. → brand: "Pantene"
• Meera — herbal shampoo (brown pack), popular Kerala brand. → brand: "Meera", hair_type: "All Hair Types"
• Kesh King — ayurvedic, brown/gold bottle. → brand: "Kesh King"

HAIR OILS:
• Parachute coconut oil — blue round tin or bottle. → brand: "Parachute", name: "Parachute Coconut Hair Oil"
• Nihar Naturals — green bottle. → brand: "Nihar Naturals"
• Dabur Amla — green bottle with amla (gooseberry). → brand: "Dabur Amla Hair Oil"
• Bajaj Almond Drops — yellow bottle, almond icon. → brand: "Bajaj Almond Drops"
• Navratna Cool Oil — green bottle, "Cool Oil" text. → brand: "Navratna"
• VVD Virgin Coconut Oil — local Kerala brand, glass bottle. → brand: "VVD"
LOOSE/UNLABELLED COCONUT OIL — white/clear oil in plastic bag or open container.
  → name: "Vennennai (Coconut Oil)" | is_veg: Veg

SOAPS — identify by bar shape (rectangular = bath soap), colour, brand label:
• Lux — pink/white bar, floral design. → brand: "Lux"
• Hamam — brown-orange bar. → brand: "Hamam"
• Dettol Soap — green bar, distinctive shape. → brand: "Dettol"
• Lifebuoy — red bar, health soap. → brand: "Lifebuoy"
• Pears — amber transparent bar. → brand: "Pears"
• Santoor — white bar with sandal icon. → brand: "Santoor"
• Medimix — green/dark green Ayurvedic soap. → brand: "Medimix", type: "Ayurvedic"
• Kerala Naturals / Coconut soap — handmade brown soap blocks. → name: "Coconut Soap (Handmade)"

TOOTHPASTE — tube shape, identify brand:
• Colgate (red/white tube) → brand: "Colgate" | Variants: Total, Active Salt, Sensitive, Charcoal
• Pepsodent (blue tube) → brand: "Pepsodent"
• Close-Up (red tube) → brand: "Close-Up"
• Sensodyne (white/blue tube) → brand: "Sensodyne", variant: "Sensitive"
• Himalaya (green tube) → brand: "Himalaya", type: "Herbal"
• Dabur Red (red tube with Dabur) → brand: "Dabur Red"

COSMETICS — identify precisely:
• Kajal / Kohl (Kanmashi) — Black pencil or small container. → name: "Kajal (Kohl Eyeliner)"
• Kumkum (for bindi/forehead) — Small red powder in box. → name: "Kumkum Powder"
• Mehendi / Henna — Green powder pack or cone tube. → name: "Mehendi (Henna)"
• Nail cutter/clipper — Small metal tool. → name: "Nail Cutter / Nail Clipper"
• Hair comb — Plastic comb. → name: "Hair Comb (Plastic)" or "Wide-tooth Comb"
• Hair clip / Hair band — Small accessories. → name: "Hair Clip" or "Hair Band / Scrunchie"
• Compact powder / Face powder — Flat circular compact. → name: "Face Compact Powder" + brand
• Foundation — Liquid in pump bottle or tube. → name: "[Brand] Foundation" + shade if visible
• Sindoor (Vermilion) — Red powder in small box. → name: "Sindoor (Vermilion)"

════════════════════════════════════════════════
💊 MEDICINES — 15+ FORMS
════════════════════════════════════════════════
• BLISTER PACK / STRIP — Foil pack with pills visible in bubbles.
  → Read medicine name, composition from foil text. form: "tablet" | "capsule"
• BOTTLE OF TABLETS — Plastic bottle with screw cap.
  → Read label: name, composition, strength. form: "tablet" | "capsule"
• SYRUP BOTTLE — Amber or white bottle with liquid.
  → name from label, form: "syrup", read "Shake well before use" if visible
• EYE DROPS — Small plastic dropper bottle, 5-10ml.
  → form: "eye drops", read composition from label
• NASAL SPRAY — Pump bottle, small nozzle.
  → form: "nasal spray"
• OINTMENT TUBE — Metallic/plastic tube.
  → form: "ointment" | "cream" | "gel"
• INJECTION VIAL — Small glass vial with rubber top.
  → form: "injection", read label if visible
• THERMOMETER — Glass or digital. → name: "Clinical Thermometer" (Glass | Digital)
• BLOOD PRESSURE MONITOR — Electronic cuff device. → name: "BP Monitor / Blood Pressure Monitor"
• GLUCOMETER — Small electronic device with test strip slot. → name: "Glucometer (Blood Sugar Meter)"
• BANDAGE / COTTON ROLL — White rolled cotton or elastic bandage.
  → name: "Bandage Roll" | "Cotton Bandage" | "Crepe Bandage"
• ADHESIVE PLASTER — Small strip plasters in box. → name: "Adhesive Plaster / Band-Aid" + brand
• SURGICAL MASK — White or blue 3-layer mask. → name: "Surgical Face Mask (3-ply)"
• ORS SACHETS — Flat sachets, usually labelled "ORS", "Electral". → form: "powder"

════════════════════════════════════════════════
🎵 MUSICAL INSTRUMENTS — 20+ TYPES
════════════════════════════════════════════════
• MIDI KEYBOARD / DIGITAL KEYBOARD — Flat keyboard with 25/49/61/88 keys. May have "MIDI" or brand.
  Look for: number of keys visible, brand (Casio, Yamaha, Roland, Korg, Akai).
  → name: "[Brand] [Key Count]-Key MIDI Keyboard" e.g. "Casio CT-X700 61-Key Digital Keyboard"
  → Add: "key_count" (25|49|61|76|88), "brand", "model_number" if visible
• SYNTHESIZER — Similar to keyboard but more complex, with knobs/sliders/pads. Often labelled "SYNTH".
  → name: "[Brand] Synthesizer" | brand: Korg, Roland, Moog, Arturia
• ELECTRIC GUITAR — Solid body, pickups visible, electric guitar shape.
  → name: "[Brand] Electric Guitar" | Add: "color", "body_type" (Stratocaster|Les Paul|Semi-hollow)
• ACOUSTIC GUITAR — Hollow wooden body with sound hole. Round hole = standard acoustic.
  → name: "[Brand] Acoustic Guitar" | Add: "strings" (6-string|12-string), "size" (Full|3/4|1/2)
• CLASSICAL GUITAR (Nylon string) — Like acoustic but with wider neck, nylon strings look different.
  → name: "Classical Guitar (Nylon String)"
• BASS GUITAR — Like electric guitar but longer neck (scale), 4 strings.
  → name: "[Brand] Bass Guitar (4-string)"
• UKULELE — Small 4-string, guitar-like but much smaller (50cm body).
  → name: "Ukulele" | Add: "size" (Soprano|Concert|Tenor|Baritone)
• VIOLIN — Hourglass wooden body, 4 strings, bow instrument. Dark wood.
  → name: "Violin" | Add: "size" (1/4|1/2|3/4|4/4 Full)
• TABLA — Pair of Indian drums: small treble drum (dayan) + larger bass drum (bayan). Dark skin head.
  → name: "Tabla (Indian Classical Drums)" | unit: set
• HARMONIUM — Box with bellows (pump handle on side), keyboard on top. Portable Indian keyboard.
  → name: "Harmonium" | Add: "reeds" if visible, "brand" (Bina, Paloma, Paul & Co.)
• FLUTE — Long tube: BANSURI = bamboo (dark yellow-brown), WESTERN = silver metal.
  → "Bansuri (Indian Bamboo Flute)" | "Western Flute (Silver)" | Add: "material"
• MRIDANGAM — Large barrel-shaped South Indian drum, two skin heads.
  → name: "Mridangam (South Indian Classical Drum)"
• VEENA / VINA — Large plucked Indian string instrument, long neck with dragon head carving.
  → name: "Veena (Indian Classical Instrument)"
• MANDOLIN — Small pear-shaped body, 8 strings (4 pairs), similar to ukulele but different headstock.
  → name: "Mandolin" | Add: "strings" (8-string)
• CAJON — Box-shaped percussion, player sits on it and hits the front face.
  → name: "Cajon (Box Drum)"
• DJEMBE — Goblet-shaped African drum with skin head, rope-tuned.
  → name: "Djembe Drum"
• XYLOPHONE / MARIMBA — Row of wooden bars hit with mallets, often colourful children's version.
  → "Xylophone (Children's)" if small/colourful | "Marimba" if large professional
• DRUM KIT / DRUM SET — Multiple drums + cymbals on stands.
  → name: "Drum Kit" | Add: "pieces" (5-piece|7-piece) if countable, "brand"
• SNARE DRUM — Single metal drum on stand or portable.
  → name: "Snare Drum"
• CYMBALS — Metal discs on stand. → name: "Cymbal" | Add: "size_inch" if visible
• GUITAR AMPLIFIER — Box with speaker + control knobs, guitar amp logo.
  → name: "[Brand] Guitar Amplifier" | Add: "wattage" if visible
• MICROPHONE — Handheld mic (dynamic), condenser (on desk stand), wireless.
  → "Wired Microphone" | "Condenser Microphone" | "Wireless Microphone" + brand
• HEADPHONES (Studio/DJ) — Large over-ear, often labelled "Studio", "Monitor", "DJ".
  → name: "[Brand] Studio Headphones" | "DJ Headphones" | Add: "model_number"
• GUITAR STRINGS PACK — Small flat packet. Read gauge/type printed on pack.
  → name: "[Brand] Guitar Strings [Gauge]" e.g. "Ernie Ball Regular Slinky 10-46"
• GUITAR PICK / PLECTRUM — Small triangular plastic piece, usually in packet or loose.
  → name: "Guitar Pick / Plectrum" | Add: "thickness" (Thin|Medium|Heavy) if stated

════════════════════════════════════════════════
📱 ELECTRONICS — 40+ TYPES & BRANDS
════════════════════════════════════════════════
MOBILE PHONES — always read the MODEL from box or phone itself:
• Samsung: Galaxy A-series (budget), S-series (premium), M-series (midrange)
  → name: "Samsung Galaxy [Model]" e.g. "Samsung Galaxy A54 5G"
• Realme: numbers (Realme 11, C65, Narzo) → name: "Realme [Model]"
• Redmi / Poco / Xiaomi: → name: "Redmi Note [number]" or "POCO M6 5G"
• Vivo / iQOO: → name: "Vivo [Model]"
• Oppo: → name: "Oppo [Model]"
• OnePlus: → name: "OnePlus [Model]"
• Apple iPhone: → name: "iPhone [Model]" e.g. "iPhone 15"
• Nokia: → name: "Nokia [Model]"

LAPTOPS — read brand + model from lid or box:
• HP, Dell, Lenovo, Asus, Acer, Apple MacBook, Microsoft Surface
  → name: "[Brand] [Series] Laptop" e.g. "HP 15s Laptop", "Dell Inspiron 15"

TABLETS:
• Samsung Galaxy Tab, Lenovo Tab, Apple iPad, Realme Pad
  → name: "[Brand] [Model] Tablet" e.g. "Samsung Galaxy Tab A8"

EARPHONES / EARBUDS — identify pack shape or device:
• Wired earphones (3.5mm): small earbuds with wire
  → name: "[Brand] Wired Earphones" | compatible_with: "3.5mm Jack"
• TWS (True Wireless): small case box, two separate earbuds inside
  → name: "[Brand] TWS Earbuds" | compatible_with: "Bluetooth"
• AirPods: white case, Apple branding → name: "Apple AirPods" + model if visible
• Boat Airdopes: very common in Kerala → brand: "Boat"
• JBL/Sony/Realme/OnePlus Buds → name with brand

POWER BANKS:
• Rectangular battery pack, USB ports. Look for mAh printed.
  → name: "[Brand] Power Bank [mAh]" e.g. "Ambrane 20000mAh Power Bank"

SMART WATCH / FITNESS BAND:
• Watches with screen, silicone strap, charging cable.
  → "Smart Watch [Brand]" | "Fitness Band [Brand]"
• Boat Storm, Fire-Boltt, Noise, Apple Watch, Samsung Galaxy Watch
  → name: "[Brand] [Model] Smart Watch" or "Fitness Tracker"

CHARGER / ADAPTER:
• Mobile charger (box + cable) → name: "[Watt] Fast Charger" e.g. "33W Fast Charger"
• Laptop charger (brick + cable) → name: "Laptop Charger [Brand] [Watt]W"
• Power adapter / Travel adapter → name: "Universal Power Adapter"

ROUTERS / NETWORKING:
• WiFi router (antenna box) → name: "[Brand] WiFi Router" | brand: TP-Link, D-Link, Jio, ACT
• Mobile data dongle → name: "4G/5G WiFi Dongle"

HOME APPLIANCES:
• Electric kettle — jug shape, electric cord, heat water.
  → name: "[Brand] Electric Kettle [Litre]L" | Add: capacity_litres, wattage
• Rice cooker — Pot with lid and electric base, "Rice Cooker" usually printed.
  → name: "[Brand] Electric Rice Cooker" | Add: capacity_litres
• Induction cooktop — Flat glass surface, no flame, sleek.
  → name: "[Brand] Induction Cooktop" | Add: wattage
• Water purifier / Filter — Mounted unit with tap. → name: "[Brand] Water Purifier" | brand: Kent, Aquaguard
• Geyser / Water heater — Cylindrical tank, electric. → name: "[Brand] Water Heater [Litre]L"
• Table/Ceiling Fan — Already covered (add: wattage, sweep_size for ceiling fans)
• Air cooler — Box with water tank, different from AC. → name: "[Brand] Air Cooler"
• Trimmer (beard/hair) — Electric trimmer device, rechargeable.
  → name: "[Brand] Beard Trimmer" or "Hair Trimmer" | Add: model_number

════════════════════════════════════════════════
🎮 TOYS & GAMES — 20+ TYPES
════════════════════════════════════════════════
• LEGO / BUILDING BLOCKS — Coloured plastic interlocking bricks.
  → name: "[Brand] Building Blocks [Piece count]pc" | Add: piece_count, age_group
• JIGSAW PUZZLE — Box showing completed image + loose pieces.
  → name: "Jigsaw Puzzle [Piece count]pc" | Add: piece_count, age_group
• BOARD GAME — Flat box with game board illustration (Monopoly, Ludo, Snakes & Ladders, Business).
  → name: "[Game Name] Board Game"
• LUDO BOARD — Colourful cross-shaped board, standard Indian game.
  → name: "Ludo Board Game"
• SNAKES & LADDERS — Grid board with snakes and ladders drawn.
  → name: "Snakes and Ladders Board Game"
• CARROM BOARD — Large square wooden board with pockets at corners.
  → name: "Carrom Board" | Add: size (Full Size|Medium|Mini), material
• CHESS SET — Board + 32 pieces. → name: "Chess Set" | Add: material (Plastic|Wood|Metal)
• CAROM / STRIKER DISC — Small circular disc for carrom.
  → name: "Carrom Striker" or "Carrom Coins Set"
• ACTION FIGURES — Plastic character figures.
  → name: "[Character] Action Figure" e.g. "Spider-Man Action Figure" | Add: character_name, age_group
• BARBIE / DOLL — Female doll with fashion clothes.
  → name: "Barbie Doll" or "Fashion Doll" | Add: age_group, character_name
• REMOTE CONTROL CAR — Toy car with RC controller.
  → name: "Remote Control Car / RC Car" | Add: age_group, compatible_with (battery type)
• REMOTE CONTROL HELICOPTER / DRONE — RC flying toy.
  → name: "RC Helicopter" or "Mini Drone Toy" | Add: age_group
• TOY GUN / NERF — Plastic foam dart gun.
  → name: "Foam Dart Gun (Toy)" | Add: age_group
• WATER GUN / PICHKARI — Plastic water squirt gun, colourful.
  → name: "Water Gun / Pichkari (Toy)" | Add: age_group
• RUBIK'S CUBE / MAGIC CUBE — Colourful 3×3 (or other) twisting cube puzzle.
  → name: "Rubik's Cube [Size]" e.g. "3×3 Magic Cube"
• YO-YO — Disc toy on string. → name: "Yo-Yo (Toy)"
• SPINNING TOP / LATTU — Traditional spinning top toy.
  → name: "Spinning Top (Lattu)"
• SOFT TOY / STUFFED ANIMAL — Plush toys: teddy bear, rabbit, cartoon character.
  → name: "[Animal/Character] Soft Toy / Stuffed Toy" e.g. "Teddy Bear Soft Toy"
• CLAY / PLAY-DOH — Soft coloured modelling clay in tub or pack.
  → name: "Modelling Clay / Play Doh" + brand | Add: age_group
• COLOURING BOOK — Book with outlines to colour. → name: "Colouring Book" | Add: theme (Animals|Mandala)
• CRAYONS / COLOUR PENCILS SET — Box of crayons or coloured pencils.
  → name: "[Brand] Crayons [Count]pc" or "Colour Pencils [Count]pc Set"

════════════════════════════════════════════════
📚 BOOKS & STATIONERY — 20+ TYPES
════════════════════════════════════════════════
BOOKS — always state if PACKED or individual, read cover if visible:
• MALAYALAM NOVEL — Cover usually has dramatic photo, Malayalam title text. Author name prominent.
  → name: "[Title] (Malayalam Novel)" | Add: author, publisher (Mathrubhumi|DC Books|Current Books)
• ENGLISH NOVEL — English title on cover, usually with artwork.
  → name: "[Title] by [Author] (Novel)"
• SCHOOL TEXTBOOK — "Class [X] [Subject]" text visible, NCERT / State Board logo.
  → name: "Class [X] [Subject] Textbook" | Add: publisher (NCERT|SCERT Kerala|CBSE)
• RELIGIOUS BOOK — Bible = cross on cover; Quran = Arabic script; Hindu texts = devanagari/temple motif.
  → "Holy Bible" | "Quran Sharif" | "Bhagavad Gita" etc.
• COMIC BOOK / MANGA — Sequential art panels, bright covers.
  → name: "[Title] Comic Book"
• MAGAZINE — Glossy cover, date/issue number visible.
  → name: "[Title] Magazine [Month Year]" | brand: Vanitha|Mathrubhumi|Grihalakshmi|Filmfare

NOTEBOOKS — identify by ruling and size:
• SINGLE LINE RULED (most common) — Horizontal lines only.
  → name: "[Brand] Single Line Notebook [Page count]pg" | ruling: "Single Line"
• DOUBLE LINE (for kids) — Two lines per row for handwriting practice.
  → name: "Double Line Notebook (Children's)" | ruling: "Double Line"
• GRAPH PAPER — Small grid squares printed. → name: "[Brand] Graph Notebook" | ruling: "Graph"
• BLANK / UNRULED — No lines. → name: "[Brand] Blank Sketch Book"
• SPIRAL NOTEBOOK — Metal spiral binding on left or top.
  → name: "Spiral Notebook [Pages]pg"
• HARDCOVER JOURNAL/DIARY — Thick cover with lock or elastic band.
  → name: "Hardbound Journal / Diary"
• COMPOSITION BOOK (Exam pad style) — Stiff covers, used in Kerala schools.
  → name: "Composition Notebook"
• A4 PAPER REAM — 500 sheets of A4 printing paper in sealed package.
  → name: "[Brand] A4 Printing Paper 500 Sheets" | e.g. "JK Copier A4 Paper"

PENS & WRITING:
• Reynolds 045 — Thin blue pen, very common in Kerala schools. → brand: "Reynolds 045"
• Cello Finegrip — Black/blue ballpoint. → brand: "Cello"
• Linc Glycer — Blue/black gel-ballpoint hybrid. → brand: "Linc"
• Faber-Castell — Premium brand, gold logo. → brand: "Faber-Castell"
• Parker Pen — Premium, arrow clip on cap. → brand: "Parker"
• Pilot G2 / Pilot V5 — Gel pens with "Pilot" on barrel. → brand: "Pilot"
• MARKER / WHITEBOARD MARKER — Thick nib, labelled "Marker" or "Whiteboard".
  → name: "[Brand] Whiteboard Marker" or "Permanent Marker"
• HIGHLIGHTER — Thick nib, bright fluorescent colour. → name: "Highlighter Pen [Colour]"
• SKETCH PEN / FELT PEN — Thin colourful pens in set. → name: "Sketch Pens [Count]pc Set"
• PENCIL TYPES:
  - HB (most common, light grey line) → "HB Pencil"
  - 2B (darker, for sketching) → "2B Pencil (Sketching)"
  - Mechanical pencil (metal/plastic body, 0.5mm lead) → "Mechanical Pencil 0.5mm"
  - Colour pencil → already covered

ART SUPPLIES:
• WATERCOLOUR SET — Small rectangular pans in case, or tubes. → name: "[Brand] Watercolour Set"
• ACRYLIC PAINT SET — Tubes or bottles of bright paint. → name: "[Brand] Acrylic Paint Set"
• OIL PAINT — Thick tubes, strong chemical smell (context). → name: "[Brand] Oil Paint Set"
• CANVAS / DRAWING SHEET — White rectangular sheet/pad. → name: "Drawing Sheets / Artist Canvas"
• PAINT BRUSH SET — Multiple brushes in packet. → name: "Paint Brush Set [Count]pc"
• GEOMETRY BOX — Plastic box containing compass, divider, set squares, scale, protractor.
  → name: "[Brand] Geometry Box Set"
• COMPASS (drawing) — Metal hinged tool for drawing circles.
  → name: "Compass Set (Geometry)"

════════════════════════════════════════════════
🔧 TOOLS — 25+ TYPES (packed and loose)
════════════════════════════════════════════════
POWER TOOLS (with cable or battery):
• ELECTRIC DRILL — Pistol-grip tool with rotating chuck. → name: "[Brand] Electric Drill [Watt]W"
• ANGLE GRINDER — Disc grinder with guard. → name: "[Brand] Angle Grinder [mm]mm"
• JIGSAW (power) — Electric saw with blade moving up-down. → name: "[Brand] Jigsaw Power Tool"

HAND TOOLS — identify by shape:
• Hammer: metal head + wooden/rubber handle.
  → "Claw Hammer" (curved claw) | "Ball Peen Hammer" (round back) | "Rubber Mallet" (rubber head)
• Screwdriver types: + head = Phillips; − head = Flat/Slotted; star = Torx.
  → read size from shaft: 6"/8"/10". "Phillips Screwdriver 8 inch" etc.
• Pliers types: → "Combination Pliers" | "Long Nose Pliers" | "Wire Cutter Pliers"
• Wrench types: → "Adjustable Wrench [mm]mm" | "Ring Spanner [mm]mm" | "Allen Key Set"
• Saw types: → "Hand Saw" | "Hacksaw" | "PVC Pipe Cutter"
• Files: Metal files for smoothing metal. → "Metal File Set" | "Round File" | "Flat File"
• Chisel: Flat blade for woodworking. → "Wood Chisel [mm]mm" | "Cold Chisel"
• LEVEL / SPIRIT LEVEL — Long rectangular tool with bubble vials.
  → name: "Spirit Level / Bubble Level [cm]cm"
• DRILL BITS SET — Multiple small drill bits in case. → name: "Drill Bit Set [Count]pc [Material]"
• CABLE TESTER — Electronic device for checking electrical cables.
  → name: "Cable Tester / Wire Tester"
• SOLDERING IRON — Electric pen-like tool for joining wires/electronics.
  → name: "[Watt]W Soldering Iron"
• WIRE STRIPPER — Scissors-like tool for stripping wire insulation.
  → name: "Wire Stripper / Wire Cutter Tool"

CONSUMABLES:
• SANDPAPER SHEETS — Rough paper sheets in pack. → name: "Sandpaper / Abrasive Sheet [Grit]"
• SCREWS & NUTS PACK — Small metal fasteners in bag. → "Self-tapping Screws [Size]" | "Hex Nut Pack"
• WALL PLUG / RAWLPLUG — Small plastic anchors for wall drilling. → name: "Wall Plug / Rawlplug Set"
• WD-40 / LUBRICANT SPRAY — Red and yellow aerosol spray can. → brand: "WD-40"
• DUCT TAPE / MASKING TAPE — Wide sticky tape roll. → "Duct Tape [mm]mm" | "Masking Tape"
• THREAD SEAL TAPE (PTFE) — Thin white tape roll for plumbing. → name: "PTFE Thread Seal Tape"

════════════════════════════════════════════════
🍳 KITCHEN — 25+ TYPES
════════════════════════════════════════════════
COOKWARE — identify by shape and material:
• PRESSURE COOKER: tall pot, locking lid with weight on top, usually aluminium or steel.
  → "Aluminium Pressure Cooker [L]L" | "Stainless Steel Pressure Cooker [L]L"
  → Brands: Hawkins, Prestige, Butterfly, Futura
• KADAI / WOK: wide deep pan with two side handles, used for deep frying.
  → "Iron Kadai [diameter]cm" | "Non-stick Kadai" | "Stainless Steel Kadai"
• TAWA: flat round griddle, used for chapati/dosa. Iron or non-stick.
  → "Iron Tawa [diameter]cm" | "Non-stick Tawa"
• APPAM / APPE PAN: curved pan with small round moulds for appam or paniyaram.
  → name: "Appam / Appachetty Pan" | "Paniyaram Pan"
• PUTTU MAKER / PUTTU KUTTI: cylindrical steamer for making puttu (Kerala breakfast).
  → name: "Puttu Kutti (Puttu Maker)" | Add: material (Aluminium|Steel|Bamboo)
• IDLI MAKER: round pot with tray inserts with circular moulds.
  → name: "Idli Maker / Idli Cooker" | Add: idli_count (4|6|8 idlis)
• DOSA TAWA / DOSA GRIDDLE: large flat tawa specifically for dosa.
  → name: "Dosa Tawa (Iron)" | "Non-stick Dosa Pan"

STORAGE:
• CASSEROLE (hot pot): round insulated pot to keep food warm.
  → name: "[Brand] Casserole / Hot Pot [L]L" | Add: capacity_litres
• STAINLESS STEEL CONTAINER / DABBA: cylindrical or square airtight steel container.
  → name: "Steel Container / Dabba [ml]ml"
• PLASTIC CONTAINER SET: clear/coloured plastic airtight boxes.
  → name: "Plastic Airtight Container Set [Count]pc"
• WATER BOTTLE: wide-mouth or sports cap. → "[Brand] Water Bottle [ml]ml"
• FLASK / THERMOS: already covered in detail

UTENSILS:
• LADLE / SPATULA / TURNER: cooking spoons → identify material (steel/wood/silicone/plastic)
• GRATER: flat metal plate with holes. → "Stainless Steel Grater"
• STRAINER / COLANDER: bowl with holes. → "Kitchen Strainer / Colander"
• CHOPPING BOARD: flat board. → "Wooden Chopping Board" | "Plastic Chopping Board"
• PEELER: Y-shaped or straight vegetable peeler. → "Vegetable Peeler"
• COCONUT SCRAPER: Kerala-specific tool with a serrated disc on stand.
  → name: "Thenga Chirakal (Coconut Scraper / Grater)"
• MORTAR & PESTLE (Ammi Kallu / Ammikkallu): stone grinding set.
  → name: "Ammi Kallu (Stone Mortar and Pestle)" | Add: material (Stone|Marble|Wood)
• MEASURING CUPS SET: nested cups (1 cup, ½ cup, ¼ cup).
  → name: "Measuring Cups Set [material]"
• MEASURING SPOONS SET: small spoon set (1 tbsp, 1 tsp, ½ tsp).
  → name: "Measuring Spoons Set"

════════════════════════════════════════════════
👶 BABY PRODUCTS — 15+ TYPES
════════════════════════════════════════════════
• FEEDING BOTTLE: clear plastic or glass bottle with silicone teat/nipple.
  → name: "[Brand] Baby Feeding Bottle [ml]ml" | Add: material (Plastic|Glass)
• BABY FORMULA / INFANT MILK: tin or box with baby face, "0-6 months" or "Stage 1/2".
  → name: "[Brand] Infant Formula [Stage]" e.g. "Nestlé NAN Pro Stage 1"
• BABY FOOD (CERELAC / PORRIDGE): box/pouch with infant picture. → brand: Nestle Cerelac, HiPP
  → name: "[Brand] Baby Cereal / Baby Food [Flavour]"
• NAPPY RASH CREAM: small tube or tin. → name: "[Brand] Nappy Rash Cream"
• BABY SHAMPOO / BABY WASH: gentle formula, "No More Tears" or "Baby" on label.
  → name: "[Brand] Baby Shampoo" | e.g. "Johnson's Baby Shampoo"
• BABY LOTION / BABY OIL: small bottle. → name: "[Brand] Baby Lotion" | "[Brand] Baby Oil"
• BABY POWDER: tin/bottle with baby image. → name: "[Brand] Baby Powder"
• DIAPERS / NAPPIES: bag/packet of folded pads. Look for size (S/M/L/XL) and count.
  → name: "[Brand] Diapers Size [S/M/L/XL] [count]pc" | e.g. "Pampers Active Baby Diaper M 46pc"
• BABY WIPES: flat packet of moist wipes. → name: "[Brand] Baby Wipes [count]pc"
• PACIFIER / TEETHER: silicone teat device. → name: "Baby Pacifier / Soother" | "Baby Teether"
• BABY MONITOR: electronic device with camera/screen. → name: "Baby Monitor"
• BABY RATTLE / SOFT TOY: noisy toy for infants. → name: "Baby Rattle Toy"
• NURSING PILLOW: C-shaped or U-shaped pillow. → name: "Nursing / Breastfeeding Pillow"

════════════════════════════════════════════════
🐾 PET PRODUCTS — 10+ TYPES
════════════════════════════════════════════════
• DOG FOOD: bag/pouch with dog photo. → "[Brand] Dog Food [Type]" | brands: Pedigree, Royal Canin, Drools
  Add: pet_type: "Dog", size: "Puppy|Adult|Senior"
• CAT FOOD: bag/pouch with cat photo. → "[Brand] Cat Food" | brands: Whiskas, Felix, Royal Canin
  Add: pet_type: "Cat"
• FISH FOOD: small container with tropical fish photo. → "[Brand] Fish Food" | e.g. Taiyo, API
• PET COLLAR: rubber or leather neck collar. → "Dog Collar" | "Cat Collar" + brand
• DOG LEASH: rope or chain leash. → "Dog Leash / Collar Set"
• PET SHAMPOO: bottle with animal image. → "[Brand] Pet Shampoo [Pet type]"
• CAT LITTER: heavy bag of granules/clay. → "[Brand] Cat Litter [kg]kg"
• PET CAGE / CARRIER: wire cage or hard plastic carrier. → "Pet Carrier / Travel Cage"

════════════════════════════════════════════════
🏠 HOUSEHOLD CLEANING — 15+ TYPES
════════════════════════════════════════════════
• BROOM / VAALU (വാലു): long-handled or hand-held broom. → "Broom (Vaalu)" | "Floor Broom"
• MOP SET: mop head + bucket set. → "Floor Mop Set" | Add: mop_type (Flat|Spin|String)
• SCRUB BRUSH / BRUSH: stiff-bristled cleaning brush. → "Scrub Brush" | "Bottle Brush"
• DISHWASHING BAR (Maraichan Soap): rectangular bar for dishes. → "[Brand] Dishwash Bar"
  e.g. Vim Bar, Sunlight, Pril Bar
• DISHWASHING LIQUID: bottle of liquid soap. → "[Brand] Dishwash Liquid [ml]ml"
  e.g. Vim Liquid, Pril Liquid, Exo
• WASHING POWDER / LAUNDRY DETERGENT: box or bag. → "[Brand] Washing Powder [g/kg]"
  e.g. Ariel, Surf Excel, Tide, Rin, Wheel
• FABRIC SOFTENER / COMFORT: bottle. → "[Brand] Fabric Softener" | brand: Comfort, Downy
• BLEACH / CHLORINE: white/yellow bottle. → "[Brand] Bleach / Chlorine [ml]ml"
• TOILET CLEANER: curved bottle. → "[Brand] Toilet Cleaner [ml]ml" | e.g. Harpic, Domex
• FLOOR CLEANER / PHENYL: bottle, often labelled "Phenyl" or "Floor Cleaner".
  → "[Brand] Floor Cleaner" | e.g. Lizol, Colin, Magiclean
• GLASS CLEANER: spray bottle. → "[Brand] Glass Cleaner" | e.g. Colin Glass Cleaner
• GARBAGE BAGS / WASTE BAGS: roll/pack of dark plastic bags.
  → "Garbage Bags [size]L [count]pc"
• AIR FRESHENER: spray or gel. → "[Brand] Air Freshener [Fragrance]" | e.g. Air Wick, Ambi Pur
• MOSQUITO REPELLENT SPRAY: aerosol spray can. → "[Brand] Mosquito Repellent Spray"
  e.g. Good Knight Spray, Mortein, Baygon
• COCKROACH CHALK / GEL: small chalk sticks or syringe tube. → "Cockroach Killing Chalk" | "Cockroach Gel"
• MOTHBALLS / NAPHTHALENE: white balls in packet. → "Naphthalene Balls / Mothballs"

════════════════════════════════════════════════
🏗️ HARDWARE & ELECTRICAL — 20+ TYPES
════════════════════════════════════════════════
• LIGHT BULB / LED BULB: glass bulb shape or LED disc.
  → "[Brand] LED Bulb [Watt]W [Colour]" e.g. "Wipro 9W LED Bulb Warm White"
  | brands: Philips, Wipro, Syska, Crompton, Havells
• TUBE LIGHT / FLUORESCENT TUBE: long glass tube. → "[Brand] Tube Light [Watt]W [Length]"
• LED STRIP LIGHT: flexible strip with LEDs. → "LED Strip Light [meter]m [Colour]"
• SWITCH BOARD / SWITCHBOX: white plastic box with switches/sockets.
  → "Switchboard / Switch Plate [Count] Socket" | brands: Anchor, Legrand, Havells
• ELECTRIC SWITCH (individual): small white switch. → "Electric Switch [Amp]A" | brand: Anchor
• EXTENSION BOARD / POWER STRIP: multiple socket strip with cord.
  → "[Brand] Extension Board [Socket count] Socket" | Add: cable_length
• MCBS / CIRCUIT BREAKER: small white/grey modular device. → "MCB Circuit Breaker [Amp]A"
• COPPER WIRE / ELECTRICAL WIRE: coiled wire roll. → "[Brand] Copper Wire [sq.mm]sq.mm [metre]m"
• ELECTRICAL TAPE / INSULATION TAPE: black roll. → "Electrical Insulation Tape"
• PVC PIPE: white/grey cylindrical pipe. → "PVC Pipe [diameter]mm [length]m"
• PVC ELBOW / TEE / FITTING: pipe connector. → "PVC Elbow [diameter]mm" | "PVC Tee Fitting"
• WATER VALVE / COCK: brass/plastic tap. → "Water Tap / Cock [material]"
• PADLOCK: metal lock with shackle. → "[Brand] Padlock [mm]mm" | e.g. Godrej padlock
• DOOR HINGE: metal hinge pair. → "Door Hinge [size]inch"
• WALL PUTTY: white powder bag or white paste bucket. → "[Brand] Wall Putty"
• PAINT CAN / PAINT BUCKET: sealed metal or plastic can. → "[Brand] Interior Paint [L]L [Colour if visible]"
  | brands: Asian Paints, Berger, Dulux, Nerolac

════════════════════════════════════════════════
👕 CLOTHING & TRADITIONAL WEAR — 20+ TYPES
════════════════════════════════════════════════
KERALA TRADITIONAL:
• MUNDU (മുണ്ട്) — White cotton cloth, dhoti-style, men. Single = Mundu. Double = Dothi.
  → "Mundu (Kerala Traditional Dhoti)" | Add: fabric (Cotton|Silk)
• KASAVU MUNDU — White with gold border (kasavu = gold thread). Festival wear.
  → "Kasavu Mundu (Gold Border Traditional)" | Add: border_width if visible
• SETTU MUNDU / NERIYATHU — Two-piece women's set: white cloth + matching kasavu top cloth.
  → name: "Settu Mundu / Neriyathu (Women's Traditional Set)"
• LUNGI — Colourful checked cotton tube skirt for men. NOT white.
  → "Lungi [Colour/Pattern]" e.g. "Checked Lungi (Blue)" | Add: fabric, color
• SAREE — 5-6 metre draped garment. Identify fabric from texture/sheen.
  → "[Type] Saree" e.g. "Kerala Cotton Saree" | "Silk Saree" | "Kanjivaram Saree" | "Chiffon Saree"
• BLOUSE / BLOUSE PIECE — Small fabric piece sold with saree. → "Saree Blouse Piece [Color]"
• CHURIDAR / SALWAR KAMEEZ — Tunic top + narrow bottom trousers set.
  → "Churidar Set (Salwar Kameez)" | Add: fabric, color
• PATTU PAVADA (Kids) — Traditional long skirt for girls, silk or cotton.
  → "Pattu Pavada (Traditional Girls' Skirt)"
• MUNDUM NERIYATHUM (2-piece) — Traditional Kerala women's wear: lower cloth + upper cloth.
  → name: "Mundum Neriyathum (Kerala Women's Traditional)"

MODERN CLOTHING:
• T-SHIRT — Round neck, short sleeve. → "[Brand] T-Shirt" | Add: gender, color, sizes, fabric
• POLO / COLLAR T-SHIRT — Has collar. → "Polo T-Shirt" | Add: gender, color, fabric
• FORMAL SHIRT — Full sleeve, buttons. → "Formal Shirt" | Add: gender (Men), color, fabric
• KURTI — Short tunic for women. → "Kurti [Fabric]" | Add: gender (Women), color, fabric
• JEANS — Denim trousers. → "[Brand] Jeans [Fit]" e.g. "Slim Fit Jeans" | Add: color, sizes
• SHORTS — Knee-length bottoms. → "Shorts [Type]" | Add: gender, color, fabric
• SCHOOL UNIFORM — White shirt + navy/grey trousers or skirt set.
  → "School Uniform Set" | Add: gender (Boys|Girls), sizes
• INNER WEAR / VEST — Sleeveless undershirt. → "[Brand] Vest / Banian" | brand: Rupa, Lux, VIP
• SOCKS — Pair of socks. → "Socks [Type]" (Ankle|Calf|Knee) | Add: gender, color, sizes
• SCHOOL SOCKS — White socks specifically for school uniform.
  → "White School Socks [Size]" | Add: sizes

════════════════════════════════════════════════
👟 FOOTWEAR — 15+ TYPES
════════════════════════════════════════════════
• SPORTS SHOE / SNEAKER: thick rubber sole, laces, mesh or synthetic upper.
  → "[Brand] Sports Shoe / Sneaker" | Add: gender, color, sizes, material
  | brands: Nike, Adidas, Puma, Reebok, Bata, Liberty, Campus
• SCHOOL SHOE: black leather-look shoe with laces. Formal and sturdy.
  → "Black School Shoe" | Add: gender (Boys|Girls|Unisex), sizes
• FORMAL LEATHER SHOE: shiny leather, no logos, office wear.
  → "[Brand] Formal Leather Shoe" | Add: gender, color, sizes
• KOLHAPURI / ETHNIC SANDAL: traditional handcrafted leather sandal.
  → "Kolhapuri Sandal" | Add: gender, color, sizes
• RUBBER SLIPPER / HAWAI CHAPPAL: basic flat rubber slipper. Very common Kerala footwear.
  → "[Brand] Rubber Chappal" | Add: gender, color, sizes
  | brands: Paragon (very popular in Kerala), VKC, Relaxo
• VKC SLIPPER / VKC PRIDE: Kerala-brand EVA/rubber footwear. Look for "VKC" on sole.
  → "VKC [Model] Slipper" | Add: gender, color, sizes
• PARAGON CHAPPAL: red or other colour flat rubber slipper. Paragon = most popular in Kerala.
  → "Paragon [Model] Chappal" | Add: gender, color, sizes
• SANDAL / STRAP SANDAL: has straps across foot, open toe.
  → "[Brand] Leather Sandal" | Add: gender, color, sizes, material
• HEEL / STILETTO: women's high heel shoe.
  → "Women's Heels / High Heels" | Add: color, heel_height_cm, sizes
• BOOTS: ankle or knee-high footwear. → "Ankle Boots" | "Rain Boots / Gumboots"
• CANVAS SHOE: fabric upper (canvas), rubber sole, flat.
  → "Canvas Shoe / Plimsoll" | Add: gender, color, sizes
  | brands: Keds, Converse (if visible)
• SAFETY SHOE / WORK BOOT: reinforced toe cap, usually brown/black. Steel toe visible.
  → "Safety Shoe (Steel Toe)"

════════════════════════════════════════════════
🏋️ SPORTS — ALL TYPES
════════════════════════════════════════════════
CRICKET (already detailed) + ADDITIONAL:
• BAT GRIP: rubber grip for wrapping cricket bat handle. → "Cricket Bat Grip"
• CRICKET STUMPS SET: 3 stumps + 2 bails. → "Cricket Stumps Set (3 Stumps)"
• ABDOMINAL GUARD / BOX: protective gear. → "Cricket Abdominal Guard"

FOOTBALL/SOCCER:
• SHIN GUARDS: plastic leg guards. → "Football Shin Guards [Size]"
• FOOTBALL BOOTS/CLEATS: shoes with studs. → "[Brand] Football Boots [Size]"
• GOAL KEEPER GLOVES: padded gloves. → "Goalkeeper Gloves [Size]"

BADMINTON:
• BADMINTON RACKET COVER/CASE: bag for storing racket. → "Badminton Racket Cover Bag"
• BADMINTON NET: net for play. → "Badminton Net [Size]"

FITNESS:
• YOGA MAT: flat rolled mat. → "[Brand] Yoga Mat [mm]mm [Color]"
  | brands: Boldfit, Strauss, Nike, Adidas
• SKIPPING ROPE: rope with handles. → "Skipping Rope / Jump Rope"
• DUMBBELL: single weight. → "[Weight]kg Dumbbell" or "Dumbbell Pair [Weight]kg"
• WEIGHT PLATE: disc-shaped weight. → "[Weight]kg Weight Plate"
• RESISTANCE BAND / EXERCISE BAND: flat elastic band. → "Resistance Band [Level]"
• PULL-UP BAR / DOOR BAR: rod that mounts in doorway. → "Pull-up Bar / Chin-up Bar"
• EXERCISE CYCLE: stationary bike. → "[Brand] Stationary Exercise Cycle"

SWIMMING:
• SWIMMING GOGGLES: oval silicone eye cover. → "[Brand] Swimming Goggles"
• SWIMMING CAP: rubber/silicone cap. → "Swimming Cap [Material]"
• SWIMMING COSTUME: already covered under clothing

════════════════════════════════════════════════
📦 PACKAGING SCENARIOS — HOW TO IDENTIFY
════════════════════════════════════════════════
IMPORTANT: Products come in MANY packaging forms. The packaging does NOT change what the product IS.
• LOOSE / UNPACKAGED: fish on ice, bananas in bunch, vegetables in crate, bulk rice in sack.
  → Identify by visual appearance. Use Kerala name. This is STILL is_product:true
• TRANSPARENT PLASTIC BAG (unlabelled): VERY common in Kerala shops — rice, chilli, spices in clear bags.
  → Look at WHAT IS INSIDE the bag. Ignore the bag itself.
• BRANDED PACK (with label): read brand + product name + size. This is the easiest case.
• GLASS JAR: pickles, honey, jam, coconut oil. → Read label if any. Identify contents by colour/texture if no label.
• REFILL POUCH: flat plastic pouch (for shampoo, oil, etc.). Smaller, flexible.
  → Same product as bottle version but "Refill Pouch" or "Sachet"
• SACHET (5g-30g): very small single-use packet (shampoo sachet, masala sachet, coffee sachet).
  → name: "[Product] Sachet [weight]" e.g. "Dove Shampoo Sachet 8ml"
• CAN / TIN: metal sealed container. Paint, food, oil.
  → Read label. "Tuna in Water" | "Sweetened Condensed Milk Tin"
• AEROSOL / SPRAY CAN: pressurised can with nozzle.
  → "Deodorant Spray" | "Paint Spray Can" | "Insecticide Spray"
• BOTTLE WITH PUMP: hand pump dispenser (soap dispenser, lotion).
  → "Liquid Handwash Pump [Brand] [ml]ml"
• BOX INSIDE BOX: phone/electronics in retail box. The BOX is what is being sold.
  → Identify the product INSIDE: "POCO M6 5G Box" = the phone being sold


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
• Wide-angle shot of entire shop/market interior with multiple aisles, shelves, or product sections visible — return is_product: false EVEN IF individual products are identifiable within the scene. A store interior photo is NOT a product scan.
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
  badminton racket, JIGSAW PUZZLE, board game — are retail products. Return is_product: true.
  A jigsaw puzzle shown partially assembled / in-progress is still a sellable product (it's a game box).
• COOKWARE & KITCHEN UTENSILS — a tawa, griddle, dosa pan, kadai (wok), pressure cooker, steel pot,
  spatula, ladle, or any kitchen cooking vessel IS a retail product even if shown in-use, on a stove,
  or without packaging. Return is_product: true.
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
