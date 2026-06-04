import { NextRequest, NextResponse } from 'next/server';
import { GoogleGenerativeAI } from '@google/generative-ai';

export const runtime = 'nodejs';

export async function POST(req: NextRequest) {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    return NextResponse.json(
      { error: 'Gemini not configured — add GEMINI_API_KEY to Vercel environment variables' },
      { status: 503 }
    );
  }

  let body: { image?: string };
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON body' }, { status: 400 });
  }

  const { image } = body;
  if (!image) {
    return NextResponse.json({ error: 'No image provided' }, { status: 400 });
  }

  // Strip base64 data URL prefix if present (e.g. "data:image/jpeg;base64,...")
  const base64 = image.includes(',') ? image.split(',')[1] : image;

  try {
    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });

    const prompt = `You are analyzing a product packaging photo from an Indian grocery or retail store in Kerala.
Identify the product and return ONLY valid JSON — no markdown, no code fences, no explanation.
Use exactly this structure:
{
  "name": "product name in English (without brand)",
  "brand": "brand name only",
  "category": "exactly one of: Grocery Staples | Beverages | Snacks | Dairy & Eggs | Vegetables | Fruits | Cleaning | Medicines | Chicken | Fish | Breads | Biscuits & Cookies | Mutton | Beef | Prawns & Seafood | Personal Care | Baby Care | General",
  "unit": "exactly one of: piece | kg | gram | ml | litre",
  "confidence": "high | medium | low"
}
If the image is unclear or not a product, set confidence to low and use your best guess.`;

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

    return NextResponse.json(parsed);
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
