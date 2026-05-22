import { NextRequest, NextResponse } from 'next/server';

const GEMINI_API_KEY = process.env.GEMINI_API_KEY ?? '';
const GEMINI_URL = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${GEMINI_API_KEY}`;

const PROJECT_ID = (process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID ?? 'shoplink-prod').replace(/^﻿/, '');
const FIREBASE_API_KEY = process.env.NEXT_PUBLIC_FIREBASE_API_KEY ?? '';
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function parseValue(v: any): unknown {
  if (!v) return null;
  if ('stringValue' in v) return v.stringValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return v.doubleValue;
  if ('booleanValue' in v) return v.booleanValue;
  if ('nullValue' in v) return null;
  if ('arrayValue' in v) return (v.arrayValue.values ?? []).map(parseValue);
  if ('mapValue' in v)
    return Object.fromEntries(
      Object.entries(v.mapValue.fields ?? {}).map(([k, fv]) => [k, parseValue(fv)])
    );
  return null;
}

// Keyword shortcuts — instant replies without calling Gemini
const PRICE_KEYWORDS = ['price', 'rate', 'cost', 'how much', 'എത്ര', 'വില', 'നിരക്ക്'];
const HOURS_KEYWORDS = ['open', 'time', 'hours', 'close', 'when', 'സമയം', 'തുറക്കുന്ന', 'അടയ്ക്കുന്ന'];
const DELIVERY_KEYWORDS = ['delivery', 'deliver', 'charge', 'free delivery', 'ഡെലിവറി', 'കൊണ്ടുവരും'];
const LOCATION_KEYWORDS = ['location', 'address', 'where', 'map', 'വിലാസം', 'എവിടെ'];
const ORDER_KEYWORDS = ['order', 'buy', 'purchase', 'cart', 'ഓർഡർ', 'വാങ്ങ'];

function matchKeyword(msg: string, keywords: string[]): boolean {
  const lower = msg.toLowerCase();
  return keywords.some((k) => lower.includes(k));
}

export async function POST(req: NextRequest) {
  try {
    const { shopId, message, history = [], language = 'en' } = await req.json() as {
      shopId: string;
      message: string;
      history: { role: string; text: string }[];
      language: string;
    };

    if (!shopId || !message) {
      return NextResponse.json({ error: 'Missing shopId or message' }, { status: 400 });
    }

    // Fetch shop data
    const shopRes = await fetch(`${BASE}/shops/${shopId}?key=${FIREBASE_API_KEY}`);
    if (!shopRes.ok) return NextResponse.json({ reply: "I couldn't find this shop. Please try again." });
    const shopDoc = await shopRes.json();
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const shop = Object.fromEntries(Object.entries((shopDoc.fields ?? {}) as Record<string, any>).map(([k, v]) => [k, parseValue(v)])) as Record<string, unknown>;

    const shopName = (shop.shopName as string) ?? 'this shop';
    const address = (shop.address as string) ?? '';
    const workingHours = (shop.workingHours as string) ?? 'Please contact the shop for hours';
    const deliveryType = (shop.deliveryType as string) ?? 'both';
    const minOrder = (shop.minOrderValue as number) ?? 0;
    const deliveryCharge = (shop.deliveryCharge as number) ?? 0;
    const aiSettings = (shop.aiSettings as Record<string, unknown>) ?? {};
    const slug = (shop.shopSlug as string) ?? shopId;
    const storefrontUrl = `https://wekerala.vercel.app/${slug}`;

    // Check if AI is enabled
    if (aiSettings.enabled === false) {
      return NextResponse.json({ reply: language === 'ml'
        ? `ഞങ്ങളുടെ കടയിൽ സ്വാഗതം! ഇവിടെ ഓർഡർ ചെയ്യൂ: ${storefrontUrl}`
        : `Welcome to ${shopName}! Browse and order here: ${storefrontUrl}` });
    }

    const shareProductPrices = aiSettings.shareProductPrices !== false;

    // ── Keyword shortcuts (no Gemini needed) ──────────────────────────────────

    if (matchKeyword(message, HOURS_KEYWORDS)) {
      return NextResponse.json({ reply: language === 'ml'
        ? `${shopName} സമയം: ${workingHours}`
        : `${shopName} hours: ${workingHours}` });
    }

    if (matchKeyword(message, LOCATION_KEYWORDS)) {
      return NextResponse.json({ reply: language === 'ml'
        ? `${shopName} വിലാസം: ${address}`
        : `${shopName} is located at: ${address}` });
    }

    if (matchKeyword(message, DELIVERY_KEYWORDS)) {
      const deliveryInfo = deliveryType === 'pickup'
        ? 'Pickup only (no delivery)'
        : `Delivery available. Min order: ₹${minOrder}. ${deliveryCharge === 0 ? 'Free delivery!' : `Delivery charge: ₹${deliveryCharge}`}`;
      return NextResponse.json({ reply: language === 'ml'
        ? `ഡെലിവറി: ${deliveryCharge === 0 ? 'സൗജന്യം!' : `₹${deliveryCharge}`}. മിനിമം ഓർഡർ: ₹${minOrder}`
        : deliveryInfo });
    }

    if (matchKeyword(message, ORDER_KEYWORDS)) {
      return NextResponse.json({ reply: language === 'ml'
        ? `ഓർഡർ ചെയ്യാൻ ഇവിടെ ക്ലിക്ക് ചെയ്യൂ: ${storefrontUrl}`
        : `To place an order, tap any product above to add to cart, then checkout! Or visit: ${storefrontUrl}` });
    }

    // ── Fetch products for context ─────────────────────────────────────────────
    let productList = '';
    if (shareProductPrices) {
      const productsRes = await fetch(
        `${BASE}/shops/${shopId}/products?key=${FIREBASE_API_KEY}&pageSize=20`
      );
      if (productsRes.ok) {
        const productsData = await productsRes.json();
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        const products = (productsData.documents ?? []).map((doc: any) => {
          // eslint-disable-next-line @typescript-eslint/no-explicit-any
          const f = Object.fromEntries(Object.entries(doc.fields ?? {}).map(([k, v]: [string, any]) => [k, parseValue(v)]));
          return f;
        });
        productList = products
          .filter((p: Record<string, unknown>) => !p.isHidden)
          .map((p: Record<string, unknown>) =>
            `- ${p.nameEn ?? p.name} ₹${p.price}${p.isOutOfStock ? ' [Out of stock]' : ' [In stock]'}`
          )
          .join('\n');
      }
    }

    // ── Gemini call ───────────────────────────────────────────────────────────
    const customNote = (aiSettings.customNote as string) ?? '';
    const replyLanguage = (aiSettings.replyLanguage as string) ?? 'auto';

    const langInstruction = replyLanguage === 'auto'
      ? 'Detect the customer language from their message and reply in the same language (Malayalam or English).'
      : replyLanguage === 'malayalam'
      ? 'Always reply in Malayalam.'
      : 'Always reply in English.';

    const systemPrompt = `You are a friendly shop assistant for "${shopName}" in Kerala, India.

Shop info:
- Address: ${address}
- Working hours: ${workingHours}
- Delivery: ${deliveryType === 'pickup' ? 'Pickup only' : `Available, min order ₹${minOrder}, charge ₹${deliveryCharge}`}
${productList ? `\nProducts available:\n${productList}` : ''}

Rules you MUST follow:
1. Keep replies SHORT — 1 to 3 sentences maximum.
2. ${langInstruction}
3. NEVER share the owner's personal phone number or home address.
4. If you cannot answer, say: "I'm not sure about that. You can browse our shop here: ${storefrontUrl}"
5. For ordering, say: "Tap any product above to add it to cart!"
6. Be warm and helpful.${customNote ? `\n7. ${customNote}` : ''}`;

    // Build conversation contents (last 5 messages + current)
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const contents: any[] = [
      { role: 'user', parts: [{ text: systemPrompt + '\n\nCustomer: ' + (history[0]?.text ?? message) }] },
    ];

    // Add history pairs (skip first since merged above)
    const recentHistory = history.slice(1);
    for (let i = 0; i < recentHistory.length; i++) {
      const h = recentHistory[i];
      contents.push({ role: h.role === 'user' ? 'user' : 'model', parts: [{ text: h.text }] });
    }

    // Add current message (if history existed)
    if (history.length > 0) {
      contents.push({ role: 'user', parts: [{ text: message }] });
    }

    const geminiRes = await fetch(GEMINI_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents,
        generationConfig: { maxOutputTokens: 150, temperature: 0.5 },
      }),
    });

    if (!geminiRes.ok) {
      return NextResponse.json({ reply: `I'm not sure about that. You can browse our shop here: ${storefrontUrl}` });
    }

    const geminiData = await geminiRes.json();
    const reply = geminiData?.candidates?.[0]?.content?.parts?.[0]?.text
      ?? `I'm not sure about that. Browse our shop here: ${storefrontUrl}`;

    return NextResponse.json({ reply: reply.trim() });
  } catch (e) {
    console.error('[chat]', e);
    return NextResponse.json({ reply: "Something went wrong. Please try again." }, { status: 500 });
  }
}
