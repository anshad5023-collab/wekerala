import { NextRequest, NextResponse } from 'next/server';
import { THEMES, GOOGLE_FONTS } from '@/lib/theme-engine';
import type { WebsiteConfig } from '@/lib/theme-engine';
import { validateUpdateConfig, validateAIAction } from '@/lib/action-validator';
import type { UpdateConfigAction, AiAction } from '@/lib/ai-action-types';

// ── Firestore REST helpers ────────────────────────────────────────────────────

const PROJECT_ID = (process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID ?? 'shoplink-prod').replace(/^﻿/, '');
const API_KEY = process.env.NEXT_PUBLIC_FIREBASE_API_KEY ?? 'AIzaSyCFB9YZL3_bXjvRMoWaYFv8nTs_ote52GQ';
const GEMINI_API_KEY = process.env.GEMINI_API_KEY ?? '';
const BASE_REST = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

type FVal =
  | { stringValue: string }
  | { integerValue: string }
  | { doubleValue: number }
  | { booleanValue: boolean }
  | { nullValue: null }
  | { arrayValue: { values?: FVal[] } }
  | { mapValue: { fields?: Record<string, FVal> } };

function parseValue(v: FVal): unknown {
  if ('stringValue' in v) return v.stringValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return v.doubleValue;
  if ('booleanValue' in v) return v.booleanValue;
  if ('nullValue' in v) return null;
  if ('arrayValue' in v) return (v.arrayValue.values ?? []).map(parseValue);
  if ('mapValue' in v) return parseFields(v.mapValue.fields ?? {});
  return null;
}

function parseFields(fields: Record<string, FVal>): Record<string, unknown> {
  return Object.fromEntries(Object.entries(fields).map(([k, v]) => [k, parseValue(v)]));
}

function toFirestoreValue(v: unknown): FVal {
  if (v === null || v === undefined) return { nullValue: null };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (typeof v === 'number') return { stringValue: String(v) };
  if (typeof v === 'string') return { stringValue: v };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(toFirestoreValue) } };
  if (typeof v === 'object') {
    return {
      mapValue: {
        fields: Object.fromEntries(
          Object.entries(v as Record<string, unknown>).map(([k, val]) => [k, toFirestoreValue(val)]),
        ),
      },
    };
  }
  return { nullValue: null };
}

// ── Firestore helpers ─────────────────────────────────────────────────────────

async function firestoreGet(path: string): Promise<Record<string, unknown> | null> {
  const res = await fetch(`${BASE_REST}/${path}?key=${API_KEY}`, { cache: 'no-store' });
  if (!res.ok) return null;
  const json = await res.json();
  if (!json.fields) return null;
  return parseFields(json.fields as Record<string, FVal>);
}

async function firestorePost(path: string, data: Record<string, unknown>): Promise<void> {
  await fetch(`${BASE_REST}/${path}?key=${API_KEY}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      fields: Object.fromEntries(
        Object.entries(data).map(([k, v]) => [k, toFirestoreValue(v)]),
      ),
    }),
  });
}

async function firestorePatch(path: string, data: Record<string, unknown>, fieldMask?: string[]): Promise<void> {
  let url = `${BASE_REST}/${path}?key=${API_KEY}`;
  if (fieldMask && fieldMask.length > 0) {
    url += fieldMask.map((f) => `&updateMask.fieldPaths=${encodeURIComponent(f)}`).join('');
  }
  await fetch(url, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      fields: Object.fromEntries(
        Object.entries(data).map(([k, v]) => [k, toFirestoreValue(v)]),
      ),
    }),
  });
}

/** Publish AI changes directly to Firestore — no manual Publish button needed. */
async function publishAiChanges(
  shopId: string,
  currentConfig: Partial<Record<string, unknown>>,
  changes: Record<string, unknown>,
): Promise<void> {
  const now = new Date().toISOString();
  const merged = { ...currentConfig, ...changes, isPublished: true, publishedAt: now };

  // Read current version number
  let nextVersion = 1;
  try {
    const existingPublished = await firestoreGet(`shops/${shopId}/versions/published`);
    const ver = existingPublished?.['version'];
    if (typeof ver === 'number') nextVersion = ver + 1;
    else if (typeof ver === 'string') nextVersion = (parseInt(ver, 10) || 0) + 1;
  } catch { /* start at 1 */ }

  // Write published version
  await firestorePatch(`shops/${shopId}/versions/published`, {
    config: merged,
    publishedAt: now,
    publishedBy: 'ai',
    version: nextVersion,
  });

  // Write draft (keep in sync with published)
  await firestorePatch(`shops/${shopId}/versions/draft`, {
    config: merged,
    savedAt: now,
    savedBy: 'ai',
    hasPendingDraft: false,
  });

  // Write legacy shops/{shopId}.website field for backward compat
  await firestorePatch(`shops/${shopId}`, { website: merged }, ['website']);
}

// ── Local rules fast-path ─────────────────────────────────────────────────────

interface LocalRuleResult {
  matched: boolean;
  changes?: Partial<WebsiteConfig>;
  humanMessage?: string;
}

function checkLocalRules(message: string): LocalRuleResult {
  const m = message.toLowerCase().trim();

  const pairs: Array<[RegExp, Partial<WebsiteConfig>, string]> = [
    [/\b(enable|turn on|activate|add)\b.*whatsapp/i, { whatsappEnabled: true }, 'WhatsApp ordering has been enabled.'],
    [/\b(disable|turn off|deactivate)\b.*whatsapp/i, { whatsappEnabled: false }, 'WhatsApp ordering will be turned off.'],
    [/\b(enable|turn on|activate|add)\b.*review/i, { reviewsEnabled: true }, 'Customer reviews section has been enabled.'],
    [/\b(disable|turn off|deactivate|remove)\b.*review/i, { reviewsEnabled: false }, 'Customer reviews have been disabled.'],
    [/\bhide\b.*about( page)?/i, { showAboutPage: false }, 'The About page has been hidden.'],
    [/\bshow\b.*about( page)?/i, { showAboutPage: true }, 'The About page is now visible.'],
    [/\b(enable|turn on|activate|add)\b.*announcement/i, { announcementBarEnabled: true }, 'Announcement bar has been enabled! Now go to the Pages tab to set the announcement text.'],
    [/\b(disable|turn off|deactivate|hide|remove)\b.*announcement/i, { announcementBarEnabled: false }, 'Announcement bar has been disabled.'],
  ];

  for (const [pattern, changes, humanMessage] of pairs) {
    if (pattern.test(m)) {
      return { matched: true, changes, humanMessage };
    }
  }

  return { matched: false };
}

// ── System prompt ─────────────────────────────────────────────────────────────

function buildSystemPrompt(config: Partial<WebsiteConfig>): string {
  const themeIds = THEMES.map((t) => t.id).join(', ');
  const fonts = GOOGLE_FONTS.join(', ');
  const currentSections = Array.isArray(config.sections) ? config.sections.join(',') : 'hero,products,about,contact';

  return `You are the Website Builder AI for weKerala, helping shop owners in Kerala, India customize their online store.
Return ONLY valid JSON. No markdown. No text outside the JSON.

VALID THEMES: ${themeIds}
VALID FONTS: ${fonts}
VALID SECTIONS (only these 4 are implemented): hero, products, about, contact

INDIAN COLOR KNOWLEDGE:
- mango/kesari/saffron = warm orange (#ff9f1c or #ff671f)
- haldi/turmeric = yellow (#e9b824)
- kasavu = traditional Kerala gold (#d4a843)
- peacock blue = #0078a8, peacock green = #00827f
- laterite = Kerala red soil (#c45c3d)
- traditional Kerala theme = dark red or forest green
- neela/blue shades: #1565c0 (dark), #1e88e5 (medium), #42a5f5 (light)
- pacha/green shades: #2e7d32 (dark), #43a047 (medium), #66bb6a (light)
- chuvappu/red shades: #b71c1c (dark), #e53935 (medium), #ef5350 (light)

Current config: themeId=${config.themeId ?? 'modern'}, primaryColor=${config.primaryColor ?? '#283618'}, sections=${currentSections}

CONVERSATION CONTEXT: You may receive prior messages (conversation history) before the current message. Use them to understand follow-up requests like "make it darker", "change that font", "undo that color". The current config above reflects the LATEST state.

RESPONSE FORMAT — choose exactly one:
{"type":"UPDATE_CONFIG","confidence":0.95,"originalIntent":"...","changes":{...},"humanMessage":"..."}
{"type":"ANALYTICS_QUERY","confidence":0.99,"originalIntent":"...","metric":"orders_today","period":"day"}
{"type":"CLARIFY_NEEDED","confidence":0.80,"originalIntent":"...","question":"...","options":["...","..."],"context":"..."}
{"type":"NAVIGATE","confidence":0.90,"originalIntent":"...","tab":"orders","humanMessage":"..."}
{"type":"ERROR","confidence":0.75,"originalIntent":"...","reason":"out_of_scope","userMessage":"..."}

RULES:
1. Colors MUST be #RRGGBB hex — convert color names yourself
2. Only include fields you are changing in "changes"
3. NEVER change isPublished or publishedAt
4. humanMessage/userMessage MUST be in the EXACT same language the owner used (Malayalam if they wrote in Malayalam, English if English)
5. For vague requests ("make it nicer", "improve it"), use CLARIFY_NEEDED with 3 specific options
6. For "show me orders", "go to products", "view analytics" → use NAVIGATE to the right tab
7. For unimplemented features (plugins, coupons, bulk SMS) → use ERROR with reason "out_of_scope" and suggest what IS available
8. metric values for ANALYTICS_QUERY: orders_today, orders_week, orders_month, revenue_today, revenue_week, revenue_month, top_products, avg_order_value, pending_orders
9. tab values for NAVIGATE (ONLY these 4 work): preview (show website preview), orders (view orders), products (manage products), analytics (view sales analytics)
10. For "darker/lighter color" follow-up: darken/lighten the CURRENT primaryColor by ~20%, compute hex yourself`;
}

// ── Gemini Flash call ─────────────────────────────────────────────────────────

interface HistoryItem {
  role: 'user' | 'assistant';
  text: string;
}

async function callGemini(
  systemPrompt: string,
  userMessage: string,
  history: HistoryItem[] = [],
): Promise<AiAction> {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${GEMINI_API_KEY}`;

  // Build multi-turn contents from history then append current message
  const contents: Array<{ role: string; parts: Array<{ text: string }> }> = [];
  for (const item of history.slice(-8)) {
    contents.push({
      role: item.role === 'assistant' ? 'model' : 'user',
      parts: [{ text: item.text }],
    });
  }
  contents.push({ role: 'user', parts: [{ text: userMessage }] });

  const body = {
    system_instruction: { parts: [{ text: systemPrompt }] },
    contents,
    generationConfig: {
      temperature: 0.2,
      maxOutputTokens: 512,
      responseMimeType: 'application/json',
      thinkingConfig: { thinkingBudget: 0 },
    },
  };

  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const errText = await res.text().catch(() => 'unknown error');
    console.error('[chat-builder] Gemini error:', res.status, errText);
    return {
      type: 'ERROR',
      confidence: 0,
      originalIntent: userMessage,
      reason: 'impossible',
      userMessage: 'AI service is temporarily unavailable. Please try again in a moment.',
    };
  }

  const json = await res.json();
  const rawText: string =
    json?.candidates?.[0]?.content?.parts?.[0]?.text ?? '';

  // Strip any accidental markdown fences
  const cleaned = rawText
    .replace(/^```[a-z]*\n?/i, '')
    .replace(/\n?```$/i, '')
    .trim();

  try {
    const parsed = JSON.parse(cleaned);
    return validateAIAction(parsed);
  } catch {
    console.error('[chat-builder] Failed to parse Gemini response:', cleaned);
    return {
      type: 'ERROR',
      confidence: 0,
      originalIntent: userMessage,
      reason: 'ambiguous',
      userMessage: 'Sorry, I couldn\'t understand that request. Please try rephrasing.',
    };
  }
}

// ── Analytics formatting ──────────────────────────────────────────────────────

interface AnalyticsSummary {
  totalRevenue?: number;
  orderCount?: number;
  avgOrderValue?: number;
  topProducts?: Array<{ name: string; qty: number; revenue: number }>;
  pendingOrders?: number;
}

function formatINR(amount: number): string {
  return `₹${amount.toLocaleString('en-IN')}`;
}

function formatAnalyticsResponse(
  metric: string,
  period: string,
  summary: AnalyticsSummary | null,
): string {
  if (!summary) {
    const periodLabel = period === 'day' ? 'today' : period === 'week' ? 'this week' : 'this month';
    return `No data available ${periodLabel}. Share your shop link to get customers!`;
  }

  const { totalRevenue = 0, orderCount = 0, avgOrderValue = 0, topProducts = [], pendingOrders = 0 } = summary;
  const periodLabel = period === 'day' ? 'today' : period === 'week' ? 'this week' : 'this month';

  switch (metric) {
    case 'orders_today':
    case 'orders_week':
    case 'orders_month':
      if (orderCount === 0) {
        return `No orders ${periodLabel}. Share your shop link to get customers!`;
      }
      return `You got ${orderCount.toLocaleString('en-IN')} order${orderCount !== 1 ? 's' : ''} ${periodLabel}, earning ${formatINR(totalRevenue)} total.`;

    case 'revenue_today':
    case 'revenue_week':
    case 'revenue_month':
      if (totalRevenue === 0) {
        return `No revenue ${periodLabel} yet. Keep sharing your shop!`;
      }
      return `Your revenue ${periodLabel}: ${formatINR(totalRevenue)} from ${orderCount.toLocaleString('en-IN')} order${orderCount !== 1 ? 's' : ''}.`;

    case 'top_products':
      if (topProducts.length === 0) {
        return `No product sales data ${periodLabel} yet.`;
      }
      {
        const top = topProducts[0];
        const lines = topProducts
          .slice(0, 5)
          .map((p, i) => `${i + 1}. ${p.name} — ${p.qty.toLocaleString('en-IN')} sold (${formatINR(p.revenue)})`)
          .join('\n');
        return `Your top product ${periodLabel}: ${top.name} (${top.qty.toLocaleString('en-IN')} sold)\n\nTop ${Math.min(5, topProducts.length)} products:\n${lines}`;
      }

    case 'avg_order_value':
      if (orderCount === 0) {
        return `No orders ${periodLabel} yet to calculate average order value.`;
      }
      return `Your average order value ${periodLabel}: ${formatINR(avgOrderValue)} (from ${orderCount.toLocaleString('en-IN')} order${orderCount !== 1 ? 's' : ''}).`;

    case 'pending_orders':
      if (pendingOrders === 0) {
        return `No pending orders right now. All caught up!`;
      }
      return `You have ${pendingOrders.toLocaleString('en-IN')} pending order${pendingOrders !== 1 ? 's' : ''} waiting for your attention.`;

    default:
      return `Analytics data ${periodLabel}: ${orderCount} orders, ${formatINR(totalRevenue)} revenue.`;
  }
}

// ── Firestore analytics fetch ─────────────────────────────────────────────────

async function fetchAnalyticsSummary(shopId: string, period: string): Promise<AnalyticsSummary | null> {
  // Try the pre-computed summary document first
  const summary = await firestoreGet(`shops/${shopId}/analytics/summary`);
  if (summary) return summary as unknown as AnalyticsSummary;

  // Fallback: compute from orders sub-collection via REST query
  const cutoffMs =
    period === 'day'
      ? Date.now() - 86400000
      : period === 'week'
      ? Date.now() - 7 * 86400000
      : Date.now() - 30 * 86400000;
  const cutoffISO = new Date(cutoffMs).toISOString();

  const queryUrl = `${BASE_REST}:runQuery?key=${API_KEY}`;
  const queryBody = {
    structuredQuery: {
      from: [{ collectionId: 'orders', allDescendants: false }],
      where: {
        compositeFilter: {
          op: 'AND',
          filters: [
            {
              fieldFilter: {
                field: { fieldPath: 'shopId' },
                op: 'EQUAL',
                value: { stringValue: shopId },
              },
            },
            {
              fieldFilter: {
                field: { fieldPath: 'createdAt' },
                op: 'GREATER_THAN_OR_EQUAL',
                value: { stringValue: cutoffISO },
              },
            },
          ],
        },
      },
      limit: 500,
    },
  };

  try {
    const res = await fetch(queryUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(queryBody),
    });
    if (!res.ok) return null;

    const docs = (await res.json()) as Array<{ document?: { fields?: Record<string, FVal> } }>;
    const orders = docs
      .filter((d) => d.document?.fields)
      .map((d) => parseFields(d.document!.fields!))
      .filter((o) => o['status'] !== 'cancelled');

    if (orders.length === 0) return { orderCount: 0, totalRevenue: 0, avgOrderValue: 0, topProducts: [] };

    const totalRevenue = orders.reduce((s, o) => s + (Number(o['totalAmount']) || 0), 0);
    const orderCount = orders.length;
    const avgOrderValue = orderCount > 0 ? Math.round(totalRevenue / orderCount) : 0;
    const pendingOrders = orders.filter((o) => o['status'] === 'pending').length;

    const productMap = new Map<string, { qty: number; revenue: number }>();
    for (const order of orders) {
      const items = order['items'] as Array<Record<string, unknown>> | undefined;
      if (!Array.isArray(items)) continue;
      for (const item of items) {
        const name = String(item['productName'] ?? 'Unknown');
        const qty = Number(item['qty']) || 0;
        const price = Number(item['price']) || 0;
        const cur = productMap.get(name) ?? { qty: 0, revenue: 0 };
        productMap.set(name, { qty: cur.qty + qty, revenue: cur.revenue + qty * price });
      }
    }
    const topProducts = Array.from(productMap.entries())
      .map(([name, v]) => ({ name, qty: v.qty, revenue: Math.round(v.revenue) }))
      .sort((a, b) => b.qty - a.qty)
      .slice(0, 5);

    return { totalRevenue: Math.round(totalRevenue), orderCount, avgOrderValue, topProducts, pendingOrders };
  } catch (e) {
    console.error('[chat-builder] analytics fallback error:', e);
    return null;
  }
}

// ── POST /api/chat-builder ────────────────────────────────────────────────────

export async function POST(req: NextRequest) {
  // 1. Parse body
  let body: { shopId?: string; uid?: string; message?: string; history?: HistoryItem[] };
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON body' }, { status: 400 });
  }

  const { shopId, uid, message, history } = body;

  if (!shopId || !uid || !message) {
    return NextResponse.json({ error: 'Missing shopId, uid, or message' }, { status: 400 });
  }

  // 2. Verify ownership
  const shopFields = await firestoreGet(`shops/${shopId}`);
  if (!shopFields) {
    return NextResponse.json({ error: 'Shop not found' }, { status: 404 });
  }
  if (shopFields['ownerId'] !== uid) {
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
  }

  // 3. Fetch current website config
  let currentConfig: Partial<WebsiteConfig> = {};

  // Try shops/{shopId}/versions/draft first
  const draftConfig = await firestoreGet(`shops/${shopId}/versions/draft`);
  if (draftConfig) {
    currentConfig = draftConfig as Partial<WebsiteConfig>;
  } else {
    // Fallback: shops/{shopId}.website field (old format)
    const websiteField = shopFields['website'];
    if (websiteField && typeof websiteField === 'object') {
      currentConfig = websiteField as Partial<WebsiteConfig>;
    }
  }

  // 4. Build system prompt
  const systemPrompt = buildSystemPrompt(currentConfig);

  // 5. Check local rules fast-path
  const localResult = checkLocalRules(message);
  let action: AiAction;

  if (localResult.matched && localResult.changes) {
    const fakeAction: UpdateConfigAction = {
      type: 'UPDATE_CONFIG',
      confidence: 1.0,
      originalIntent: message,
      changes: localResult.changes,
      humanMessage: localResult.humanMessage ?? 'Done!',
    };

    const validation = validateUpdateConfig(fakeAction, currentConfig);
    if (!validation.ok) {
      action = {
        type: 'ERROR',
        confidence: 0.9,
        originalIntent: message,
        reason: 'impossible',
        userMessage: validation.errors.join(' '),
      };
    } else {
      action = { ...fakeAction, changes: validation.cleanedChanges as typeof fakeAction.changes };
    }
  } else {
    // 6. Call Gemini Flash with conversation history
    const safeHistory = Array.isArray(history) ? history : [];
    action = await callGemini(systemPrompt, message, safeHistory);
  }

  // 7. Validate UPDATE_CONFIG actions
  if (action.type === 'UPDATE_CONFIG') {
    const validation = validateUpdateConfig(action as UpdateConfigAction, currentConfig);

    if (validation.warnings.length > 0) {
      console.warn('[chat-builder] validation warnings:', validation.warnings);
    }

    if (!validation.ok) {
      action = {
        type: 'ERROR',
        confidence: 0.8,
        originalIntent: action.originalIntent,
        reason: 'impossible',
        userMessage: validation.errors.join(' '),
      };
    } else {
      action = {
        ...(action as UpdateConfigAction),
        changes: validation.cleanedChanges as UpdateConfigAction['changes'],
      };
    }
  }

  // 8. Destructive guards for UPDATE_CONFIG
  let requiresConfirmation = false;
  let confirmPrompt: string | undefined;

  if (action.type === 'UPDATE_CONFIG') {
    const changes = (action as UpdateConfigAction).changes as Record<string, unknown>;

    if (changes['whatsappEnabled'] === false) {
      requiresConfirmation = true;
      confirmPrompt =
        "Turning off WhatsApp means customers can't contact you for orders. Are you sure?";
    } else if (
      Array.isArray(changes['sections']) &&
      !(changes['sections'] as string[]).includes('products')
    ) {
      requiresConfirmation = true;
      confirmPrompt =
        "This will remove the Products section from your store. Customers won't see your items. Are you sure?";
    }
  }

  // 9. Auto-publish UPDATE_CONFIG changes directly to live website (non-blocking)
  if (action.type === 'UPDATE_CONFIG') {
    const aiChanges = (action as UpdateConfigAction).changes as Record<string, unknown>;
    void publishAiChanges(shopId, currentConfig, aiChanges).catch((e: unknown) => {
      console.error('[chat-builder] Auto-publish failed (non-fatal):', e);
    });
  }

  // 10. Log action to Firestore (non-blocking)
  void firestorePost(`shops/${shopId}/ai_actions`, {
    type: action.type,
    originalIntent: action.originalIntent,
    confidence: action.confidence,
    message,
    uid,
    createdAt: new Date().toISOString(),
    requiresConfirmation,
  }).catch((e: unknown) => {
    console.error('[chat-builder] Failed to log ai_action:', e);
  });

  // 10. Handle ANALYTICS_QUERY — embed formatted data into humanMessage so Flutter reads it
  if (action.type === 'ANALYTICS_QUERY') {
    const { metric, period } = action;
    const summary = await fetchAnalyticsSummary(shopId, period);
    const formattedMessage = formatAnalyticsResponse(metric, period, summary);

    return NextResponse.json({
      action: { ...action, humanMessage: formattedMessage },
    });
  }

  // 12. Return
  const response: {
    action: AiAction;
    requiresConfirmation?: boolean;
    confirmPrompt?: string;
  } = { action };

  if (requiresConfirmation) {
    response.requiresConfirmation = true;
    response.confirmPrompt = confirmPrompt;
  }

  return NextResponse.json(response);
}
