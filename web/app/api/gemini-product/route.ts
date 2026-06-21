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

// Universal, PRODUCT-AWARE prompt. The old version branched on shop type and
// forced one rigid schema on every product (a phone in a Fancy Store got a
// "gender" field + a clothing category, the box was described instead of the
// product, and a non-product like an animal was still treated as a product).
// This single prompt detects what the product actually is and returns only the
// relevant fields, reads printed prices, and can reject non-products.
// Updated: handles Kerala shop realities — plain bags, no labels, handwritten prices,
// unlabeled bulk items (rice, spices, produce), dark/blurry single-product photos.
function buildPrompt(shopType: string): string {
  const hint = shopType
    ? `\n\nShop type (context hint only — the product may still be anything): ${shopType}.`
    : '';
  return `You are identifying ONE retail product from a close-up photo taken at an Indian shop, to auto-fill a product catalogue. The photo will be focused on ONE specific item — not a whole room or shelf. The item may be:
• A branded product with a clear label (e.g. POCO M6 5G, Pond's Dreamflower Talc)
• A product inside a box or packaging (identify the product INSIDE, not the box)
• A product in a plain transparent plastic bag or cover with no printed label — identify what is INSIDE the bag (e.g. rice, green chillies, coconut oil)
• A loose/bulk item with no label at all (e.g. a pile of rice, a bunch of bananas, a container of spices) — still identify it by visual type
• A product in dim/dark lighting or slightly blurry — still identify if possible; set confidence accordingly

Read ALL visible text: brand, model, variant, flavour, size/weight, and ANY price — whether printed (MRP ₹899), handwritten on a sticker/paper tag, or on a price board next to the product.

STEP 1 — Is this a real, sellable retail product (or sellable item like loose produce, grain, or spice)?
• YES (is_product: true): any physical item sold in a shop — labelled or unlabelled, branded or generic, packaged or loose.
• NO (is_product: false): a person, body part, animal, pet, furniture, empty shelf, empty room, outdoor scene, or anything that is clearly NOT a product being sold.
  → Important: an empty shop with no identifiable product visible = is_product: false.
  → An item in focus in the frame, even without a label, is almost always a product.

STEP 2 — Identify as specifically as possible:
• Branded/labelled: use the exact retail name (POCO M6 5G Smartphone, Walkaroo WY3492 Footwear, Parle-G Biscuits)
• In a plain bag: name what's inside ("Basmati Rice", "Green Chillies", "Coconut Oil")
• Loose/bulk item: name the item type ("Red Chilli", "Moong Dal", "Banana", "Coconut")
• Unknown brand but recognisable item: name the item type ("AA Battery", "USB Cable", "Notebook")
• Truly unidentifiable: set confidence "low" and give a best-guess generic name

Return ONLY valid JSON (no markdown, no code fences):
{
  "is_product": true or false,
  "name": "specific retail name — brand + model/variant/size if readable, else item type e.g. 'Green Chillies' or 'Basmati Rice'",
  "brand": "brand or maker — empty string if no brand visible",
  "category": "choose EXACTLY ONE value from this shop's category list (given below) that fits the ACTUAL product; use empty string if none truly fit — never force a wrong category",
  "unit": "one of: piece | kg | g | ml | litre | pack — use kg/g for loose produce/grain, piece for individual items",
  "description": "1-2 plain sentences about the actual product (what it is / does)",
  "price": "any visible price (printed MRP, handwritten tag, or price board), digits only e.g. 899 — empty string if NO price visible anywhere. NEVER guess a price",
  "offerPrice": "printed or written discounted / offer price, digits only — empty string if none. NEVER guess",
  "confidence": "high | medium | low",
  "uncertain_fields": ["names of any fields above you are NOT confident are accurate"]
}

ALSO add ONLY the attribute keys that are RELEVANT to THIS product type, and omit all the others (for example do NOT put "gender" or "fabric" on a phone, headphones, book or talc):
- Clothing / footwear: "gender" (Men|Women|Kids|Unisex), "fabric", "color", "sizes"
- Medicine / health: "composition", "strength", "form", "schedule", "manufacturer"
- Electronics: "model_number", "warranty_months", "compatible_with"
- Packaged food / loose produce: "is_veg" (Veg|Non-Veg|Egg|Vegan), "allergens", "weight_g"
Only add an attribute when you can actually read it or confidently identify it. Never invent values.${hint}`;
}

export async function POST(req: NextRequest) {
  const ip = req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ?? 'unknown';
  if (!checkRateLimit(ip, 10)) {
    return NextResponse.json({ error: 'Too many requests. Please wait a minute.' }, { status: 429 });
  }

  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
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

  try {
    const res = await fetch(
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
    if (!res.ok) {
      const errBody = await res.text();
      return NextResponse.json({ error: `Gemini error: ${res.status} ${errBody.slice(0, 300)}` }, { status: 500 });
    }
    const json = await res.json() as {
      candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
    };
    text = json.candidates?.[0]?.content?.parts?.[0]?.text?.trim() ?? '';
  } catch (e) {
    return NextResponse.json({ error: e instanceof Error ? e.message : String(e) }, { status: 500 });
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
