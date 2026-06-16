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

function buildPrompt(shopType: string): string {
  const base = 'You are analyzing a product photo from an Indian retail store in Kerala. Be as SPECIFIC as possible — read all visible text on the label including model name, variant, size/weight. Return ONLY valid JSON — no markdown, no code fences, no explanation.';

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
  "confidence": "high | medium | low"
}
If any field is not visible/identifiable, use empty string "".`;
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
  "confidence": "high | medium | low"
}
If any field is not visible, use empty string "".`;
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
  "confidence": "high | medium | low"
}
If any field is not visible, use empty string "".`;
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
  "confidence": "high | medium | low"
}
If any field is not visible, use empty string "".`;
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
  "confidence": "high | medium | low"
}
If the image is unclear or not a product, set confidence to low and use your best guess.`;
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

  let body: { image?: string; shopType?: string };
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON body' }, { status: 400 });
  }

  const { image, shopType = '' } = body;
  if (!image || typeof image !== 'string') {
    return NextResponse.json({ error: 'image required' }, { status: 400 });
  }
  if (image.length > 2_000_000) {
    return NextResponse.json({ error: 'Image too large' }, { status: 400 });
  }

  // Strip base64 data URL prefix if present (e.g. "data:image/jpeg;base64,...")
  const base64 = image.includes(',') ? image.split(',')[1] : image;

  const prompt = buildPrompt(shopType);

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

    // After Gemini identifies name+brand, search for a product image.
    // Pipeline: 1) Open Food Facts (food), 2) DuckDuckGo image search (all products, free, no key)
    if (parsed.name || parsed.brand) {
      const query = [parsed.brand, parsed.name].filter(Boolean).join(' ');

      // 1 — Open Food Facts (best for packaged food with barcode data)
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

      // 2 — DuckDuckGo image search if Open Food Facts had no result
      // Uses DDG's unofficial vqd-token flow — free, no API key, searches entire web.
      // DDG blocks non-browser User-Agents (e.g. "Googlebot") with 403 — must look like
      // a real Chrome browser AND carry the session cookie from step A into step B.
      if (!parsed.imageUrl) {
        try {
          const browserUA =
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36';

          // Step A: get vqd token + session cookie
          const ddgHtml = await fetch(
            `https://duckduckgo.com/?q=${encodeURIComponent(query + ' product')}&iax=images&ia=images`,
            { headers: { 'User-Agent': browserUA }, signal: AbortSignal.timeout(5000) }
          );
          parsed._debug_step_a_status = String(ddgHtml.status);
          const cookie = ddgHtml.headers.get('set-cookie') ?? '';
          const html = await ddgHtml.text();
          const vqdMatch = html.match(/vqd=['"]([^'"]+)['"]/);
          parsed._debug_vqd_found = vqdMatch ? 'yes' : 'no';
          if (vqdMatch) {
            // Step B: fetch image results, carrying the cookie from step A
            const imgRes = await fetch(
              `https://duckduckgo.com/i.js?q=${encodeURIComponent(query)}&vqd=${vqdMatch[1]}&o=json&p=1&s=0&u=bing&f=,,,`,
              {
                headers: {
                  'User-Agent': browserUA,
                  'Referer': 'https://duckduckgo.com/',
                  ...(cookie ? { Cookie: cookie } : {}),
                },
                signal: AbortSignal.timeout(5000),
              }
            );
            parsed._debug_step_b_status = String(imgRes.status);
            if (imgRes.ok) {
              const imgData = await imgRes.json() as { results?: Array<{ image?: string; thumbnail?: string }> };
              parsed._debug_results_count = String(imgData.results?.length ?? 0);
              // Pick first result that looks like a real product image URL (not a tiny icon)
              const hit = imgData.results?.find(r => r.image && r.image.startsWith('http'));
              if (hit?.image) parsed.imageUrl = hit.image;
            }
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
