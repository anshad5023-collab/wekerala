import { NextRequest, NextResponse } from 'next/server';
import { GoogleGenerativeAI } from '@google/generative-ai';

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
  const base = 'You are analyzing a product photo from an Indian retail store in Kerala. Return ONLY valid JSON — no markdown, no code fences, no explanation.';

  if (shopType === 'Pharmacy') {
    return `${base}
Extract medicine/pharmaceutical product details. Use exactly this JSON structure:
{
  "name": "medicine name in English (brand name only, not generic)",
  "brand": "manufacturer/company name",
  "category": "exactly one of: Medicines | Personal Care | Baby Care | Health Devices | Vitamins",
  "unit": "piece",
  "composition": "active ingredient(s) with strength e.g. Paracetamol 500mg or Amoxicillin 250mg + Clavulanic acid 125mg",
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
  "name": "product type in English (e.g. Men's Cotton Shirt, Ladies Saree, Kids T-Shirt)",
  "brand": "brand name if visible",
  "category": "exactly one of: Men's Wear | Women's Wear | Kids' Wear | Accessories | Fabrics | Cosmetics | Hair Accessories | Artificial Jewelry | Toys & Games | Gift Items",
  "unit": "piece",
  "fabric": "material type e.g. Cotton, Silk, Polyester, Khadi, Linen, Rayon",
  "color": "primary colour(s) e.g. Navy Blue, Red & White Stripes",
  "sizes": "available sizes if visible e.g. S M L XL or 28-36",
  "care_instructions": "care instructions if visible e.g. Hand wash, Dry clean",
  "gender": "exactly one of: Men | Women | Kids | Unisex",
  "confidence": "high | medium | low"
}
If any field is not visible, use empty string "".`;
  }

  if (shopType === 'Hotel / Restaurant' || shopType === 'Bakery') {
    return `${base}
Extract food/dish details. Use exactly this JSON structure:
{
  "name": "dish or food item name in English",
  "brand": "",
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
  "name": "product name in English (without brand)",
  "brand": "brand name",
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
Identify the product and return ONLY valid JSON with exactly this structure:
{
  "name": "product name in English (without brand)",
  "brand": "brand name only",
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

  try {
    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({ model: 'gemini-2.0-flash' });

    const prompt = buildPrompt(shopType);

    const result = await model.generateContent([
      prompt,
      { inlineData: { data: base64, mimeType: 'image/jpeg' } },
    ]);

    const text = result.response.text().trim();

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

    // After Gemini identifies name+brand, try to fetch an actual product image
    // from Open Food Facts by searching the product name — completely free
    if (parsed.name || parsed.brand) {
      const query = [parsed.brand, parsed.name].filter(Boolean).join(' ');
      try {
        const offRes = await fetch(
          `https://world.openfoodfacts.org/cgi/search.pl?search_terms=${encodeURIComponent(query)}&search_simple=1&action=process&json=1&page_size=1&lc=en`,
          { headers: { 'User-Agent': 'Oratas/1.0 (oratas4ai@gmail.com)' } }
        );
        if (offRes.ok) {
          const offData = await offRes.json() as { products?: Array<{ image_front_url?: string }> };
          const imgUrl = offData.products?.[0]?.image_front_url;
          if (imgUrl) parsed.imageUrl = imgUrl;
        }
      } catch { /* image fetch is best-effort */ }
    }

    return NextResponse.json(parsed);
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
