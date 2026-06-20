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

// Shared instructions appended to every shop-type prompt: price OCR rules,
// accurate identification using the model's product knowledge, and per-field
// uncertainty so the app can flag shaky values instead of trusting them blindly.
const PRICE_AND_CONFIDENCE = `
PRICE RULES (read the photo only — never invent a price):
- "price": the MRP or selling price PRINTED on the label / shelf tag, digits only (e.g. "45"). If no price is visible in the image, use "". Do NOT estimate or guess.
- "offerPrice": a discounted / offer price PRINTED in the image, digits only. "" if none. Do NOT guess.
IDENTIFICATION: If you clearly recognise the EXACT product from its brand + name (e.g. a specific medicine, sunscreen, calculator, notebook), use its correct full standard name and you may fill standard attributes you are confident about. If you are not sure, leave a field "" rather than guessing.
"uncertain_fields": a JSON array listing the names of any fields above whose values you are NOT confident are accurate (e.g. ["price","brand"]). Empty array [] if you are confident about everything you filled.`;

function buildPrompt(shopType: string): string {
  const base = 'You are analyzing a product photo from an Indian retail store in Kerala. Be as SPECIFIC as possible — read ALL visible text on the label including brand, model name, variant, size/weight, and any printed price/MRP. Return ONLY valid JSON — no markdown, no code fences, no explanation.';

  if (shopType === 'Pharmacy') {
    return `${base}
Extract medicine/pharmaceutical product details. Use exactly this JSON structure:
{
  "name": "medicine name in English (brand name only, not generic)",
  "brand": "manufacturer/company name",
  "description": "1-2 sentence description: what it treats, key active ingredients, dosage form e.g. Paracetamol 500mg tablet for fever and mild pain relief",
  "category": "exactly one of: Medicines | Personal Care | Baby Care | Health Devices | Vitamins",
  "unit": "piece",
  "composition": "active ingredient(s) with strength e.g. Paracetamol 500mg",
  "strength": "dosage strength e.g. 500mg or 10mg/5ml",
  "manufacturer": "manufacturing company name",
  "form": "exactly one of: Tablet | Capsule | Syrup | Drops | Ointment / Cream | Injection | Inhaler | Powder | Gel | Spray",
  "schedule": "exactly one of: OTC (Over the Counter) | Prescription Required | H Schedule | X Schedule",
  "price": "MRP printed on the strip/box, digits only — empty string if not visible",
  "offerPrice": "discounted price printed in the photo, digits only — empty string if none",
  "confidence": "high | medium | low",
  "uncertain_fields": []
}
If any field is not visible/identifiable, use empty string "".${PRICE_AND_CONFIDENCE}`;
  }

  if (shopType === 'Textile' || shopType === 'Fancy Store') {
    return `${base}
Extract clothing/textile/fashion product details. Use exactly this JSON structure:
{
  "name": "specific product name e.g. Men's Cotton Formal Shirt, Ladies Kancheepuram Silk Saree, Kids Cartoon Print T-Shirt",
  "brand": "brand name if visible",
  "description": "1-2 sentence description: material, style, occasion, key features visible in the photo",
  "category": "exactly one of: Men's Wear | Women's Wear | Kids' Wear | Accessories | Fabrics | Cosmetics | Hair Accessories | Artificial Jewelry | Toys & Games | Gift Items",
  "unit": "piece",
  "fabric": "material type e.g. Cotton, Silk, Polyester, Khadi",
  "color": "primary colour(s) e.g. Navy Blue, Red & White Stripes",
  "sizes": "available sizes if visible e.g. S M L XL or 28-36",
  "gender": "exactly one of: Men | Women | Kids | Unisex",
  "price": "price/MRP printed on the tag, digits only — empty string if not visible",
  "offerPrice": "discounted price printed on the tag, digits only — empty string if none",
  "confidence": "high | medium | low",
  "uncertain_fields": []
}
If any field is not visible, use empty string "".${PRICE_AND_CONFIDENCE}`;
  }

  if (shopType === 'Hotel / Restaurant' || shopType === 'Bakery') {
    return `${base}
Extract food/dish details. Use exactly this JSON structure:
{
  "name": "specific dish or food item name",
  "brand": "",
  "description": "1-2 sentence description: key ingredients, taste profile, serving style",
  "category": "exactly one of: Meals | Snacks | Beverages | Desserts | Special Items | Breads | Cakes & Pastries | Biscuits & Cookies | Savoury Items | Drinks",
  "unit": "piece",
  "is_veg": "exactly one of: Veg | Non-Veg | Egg | Vegan",
  "allergens": "allergens if visible e.g. Gluten, Dairy, Nuts — or empty string",
  "price": "price printed in the photo, digits only — empty string if not visible",
  "offerPrice": "discounted price printed in the photo, digits only — empty string if none",
  "confidence": "high | medium | low",
  "uncertain_fields": []
}
If any field is not visible, use empty string "".${PRICE_AND_CONFIDENCE}`;
  }

  if (shopType === 'Electronics') {
    return `${base}
Extract electronics product details. Use exactly this JSON structure:
{
  "name": "specific product name including model e.g. boAt Rockerz 255 Pro+ Wireless Earphones",
  "brand": "brand name",
  "description": "1-2 sentence description: key specs, features, what it does",
  "category": "exactly one of: Mobile Accessories | Cables & Chargers | Headphones | Smart Devices",
  "unit": "piece",
  "model_number": "model number or SKU if visible",
  "warranty_months": "warranty period in months as number string e.g. 12 — or empty string",
  "compatible_with": "compatible devices if visible e.g. All Android, iPhone 13/14",
  "price": "MRP/price printed on the box, digits only — empty string if not visible",
  "offerPrice": "discounted price printed in the photo, digits only — empty string if none",
  "confidence": "high | medium | low",
  "uncertain_fields": []
}
If any field is not visible, use empty string "".${PRICE_AND_CONFIDENCE}`;
  }

  // Default — generic Indian grocery/retail
  return `${base}
Identify the SPECIFIC product — read the label carefully for brand, variant, weight/size. Return ONLY valid JSON:
{
  "name": "specific product name including variant and size e.g. Parle-G Original Glucose Biscuits 100g or Amul Taaza Homogenised Toned Milk 500ml",
  "brand": "brand name only",
  "description": "1-2 sentence description of the product: what it is, key features, variant details, weight/size, intended use",
  "category": "exactly one of: Grocery Staples | Beverages | Snacks | Dairy & Eggs | Vegetables | Fruits | Cleaning | Medicines | Chicken | Fish | Breads | Biscuits & Cookies | Mutton | Beef | Prawns & Seafood | Personal Care | Baby Care | General",
  "unit": "exactly one of: piece | kg | g | ml | litre",
  "price": "MRP printed on the pack, digits only — empty string if not visible",
  "offerPrice": "discounted price printed in the photo, digits only — empty string if none",
  "confidence": "high | medium | low",
  "uncertain_fields": []
}
If the image is unclear or not a product, set confidence to low and leave uncertain fields empty.${PRICE_AND_CONFIDENCE}`;
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

  // If the app sent the shop's actual category list, make Gemini choose from it
  // exactly — otherwise it invents a category (e.g. "Footwear") that doesn't
  // exist in this shop and the app mis-maps it (shoes ending up as "Hair
  // Accessories"). Empty string is allowed when nothing fits, which the app
  // shows as a blank the owner can fill — far better than a wrong guess.
  if (Array.isArray(categories) && categories.length > 0) {
    const list = categories.filter((c) => typeof c === 'string' && c.trim()).slice(0, 40);
    if (list.length > 0) {
      prompt +=
        `\n\nFor the "category" field you MUST choose exactly one value from this ` +
        `shop's own category list (copy it verbatim), or use "" if none genuinely ` +
        `fit. Do not invent a category outside this list:\n${list.join(' | ')}`;
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
    let parsed: Record<string, string>;
    try {
      parsed = JSON.parse(text);
    } catch {
      const match = text.match(/\{[\s\S]*?\}/);
      if (!match) {
        return NextResponse.json(
          { error: 'Could not parse Gemini response', raw: text },
          { status: 500 }
        );
      }
      parsed = JSON.parse(match[0]);
    }

    // After Gemini identifies name+brand, try multiple free image sources server-side.
    // General web image search (DuckDuckGo/Bing scraping) is done on-device instead —
    // data-center IPs like Vercel's get blocked, but a phone's mobile/WiFi IP isn't.
    if (parsed.name || parsed.brand) {
      const query = [parsed.brand, parsed.name].filter(Boolean).join(' ');

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

      // 2. Open Library — books, textbooks, notebooks (official API, no key needed)
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

      // NOTE: Wikipedia "generator search" was removed — it matched unrelated
      // articles (e.g. a cityscape for "ASICS GEL-PULSE 16") and produced
      // badly wrong images. Open Food Facts + Open Library are exact-match
      // databases; everything else (shoes, clothing, electronics) is searched
      // on-device via Bing in the app, and the owner can always switch to their
      // own photo in the review screen.
    }

    return NextResponse.json(parsed);
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
