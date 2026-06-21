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
Never add an attribute unless you can actually read or confidently identify it.${hint}`;
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
