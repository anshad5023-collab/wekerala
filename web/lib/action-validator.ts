import { THEMES, GOOGLE_FONTS } from './theme-engine';
import type { WebsiteConfig } from './theme-engine';
import { resolveColorName } from './color-dictionary';
import type { UpdateConfigAction, AiAction } from './ai-action-types';

// ── Constants ────────────────────────────────────────────────────────────────

const VALID_THEME_IDS = new Set(THEMES.map((t) => t.id));
const VALID_FONT_FAMILIES = new Set(GOOGLE_FONTS);
const VALID_SECTIONS = new Set(['hero', 'products', 'about', 'contact']);
const HEX_COLOR_RE = /^#[0-9a-fA-F]{6}$/;
const URL_RE = /^https?:\/\/.+/;
const MAX_STRING = 5000;

/**
 * Fields the AI is NOT allowed to touch.
 * Any key in this set is silently stripped from AI changes.
 */
const BLOCKED_FIELDS = new Set<string>(['isPublished', 'publishedAt', 'customHtml']);

/**
 * The complete set of fields the AI *may* touch.
 * Derived from WebsiteConfig minus blocked fields.
 * Used as an allow-list — anything outside this set is ignored.
 */
const ALLOWED_FIELDS = new Set<string>([
  'themeId',
  'siteName',
  'tagline',
  'aboutText',
  'primaryColor',
  'secondaryColor',
  'fontFamily',
  'sections',
  'whatsappEnabled',
  'whatsappNumber',
  'banners',
  'storeHoursText',
  'storeHoursEnabled',
  'customAbout',
  'customContact',
  'customPrivacy',
  'customShipping',
  'customReturn',
  'showAboutPage',
  'showContactPage',
  'showPrivacyPage',
  'showShippingPage',
  'showReturnPage',
  'socialLinks',
  'announcementBar',
  'announcementBarEnabled',
  'announcementBarColor',
  'seoTitle',
  'seoDescription',
  'couponCodes',
  'primaryButtonText',
  'deliveryCharge',
  'freeDeliveryAbove',
  'minOrderAmount',
  'logoUrl',
  'faviconUrl',
  'googleAnalyticsId',
  'facebookPixelId',
  'tawkPropertyId',
  'reviewsEnabled',
]);

// ── Result type ───────────────────────────────────────────────────────────────

export interface ValidationResult {
  ok: boolean;
  cleanedChanges: Record<string, unknown>;
  warnings: string[]; // server-side only, never sent to user
  errors: string[];   // fatal — action must not proceed
}

// ── Helpers ───────────────────────────────────────────────────────────────────

function coerceBool(v: unknown): boolean | null {
  if (typeof v === 'boolean') return v;
  if (v === 'true') return true;
  if (v === 'false') return false;
  return null;
}

function isValidUrl(v: unknown): boolean {
  return typeof v === 'string' && URL_RE.test(v);
}

function truncate(v: unknown): string {
  const s = String(v);
  return s.length > MAX_STRING ? s.slice(0, MAX_STRING) : s;
}

/**
 * Validate and clean a color value.
 * Accepts #RRGGBB or a human color name (resolved via color-dictionary).
 * Returns the canonical hex string, or null if the value is invalid.
 */
function resolveColor(raw: unknown): string | null {
  if (typeof raw !== 'string') return null;
  const trimmed = raw.trim();
  if (HEX_COLOR_RE.test(trimmed)) return trimmed.toLowerCase();
  // Try color-dictionary lookup
  const hex = resolveColorName(trimmed);
  return hex ?? null;
}

// ── Main validator ────────────────────────────────────────────────────────────

export function validateUpdateConfig(
  action: UpdateConfigAction,
  _currentConfig: Partial<WebsiteConfig>,
): ValidationResult {
  const warnings: string[] = [];
  const errors: string[] = [];
  const cleaned: Record<string, unknown> = {};

  const raw = action.changes as Record<string, unknown>;

  for (const [key, value] of Object.entries(raw)) {
    // Blocked fields — hard reject
    if (BLOCKED_FIELDS.has(key)) {
      warnings.push(`Blocked field ignored: ${key}`);
      continue;
    }

    // Unknown fields — silently ignore
    if (!ALLOWED_FIELDS.has(key)) {
      warnings.push(`Unknown field ignored: ${key}`);
      continue;
    }

    switch (key) {
      // ── themeId ──────────────────────────────────────────────────────────
      case 'themeId': {
        if (typeof value !== 'string' || !VALID_THEME_IDS.has(value)) {
          errors.push(`Invalid themeId "${value}". Valid: ${[...VALID_THEME_IDS].join(', ')}`);
        } else {
          cleaned[key] = value;
        }
        break;
      }

      // ── fontFamily ───────────────────────────────────────────────────────
      case 'fontFamily': {
        if (typeof value !== 'string' || !VALID_FONT_FAMILIES.has(value)) {
          errors.push(`Invalid fontFamily "${value}". Valid: ${[...VALID_FONT_FAMILIES].join(', ')}`);
        } else {
          cleaned[key] = value;
        }
        break;
      }

      // ── Colors ───────────────────────────────────────────────────────────
      case 'primaryColor':
      case 'secondaryColor':
      case 'announcementBarColor': {
        const hex = resolveColor(value);
        if (!hex) {
          errors.push(`Invalid color for ${key}: "${value}". Provide #RRGGBB hex or a recognized color name.`);
        } else {
          if (typeof value === 'string' && !HEX_COLOR_RE.test(value.trim())) {
            warnings.push(`Color name "${value}" resolved to ${hex} for ${key}`);
          }
          cleaned[key] = hex;
        }
        break;
      }

      // ── sections ─────────────────────────────────────────────────────────
      case 'sections': {
        if (!Array.isArray(value)) {
          errors.push(`sections must be an array`);
          break;
        }
        const filtered = (value as unknown[]).filter(
          (s) => typeof s === 'string' && VALID_SECTIONS.has(s),
        );
        const rejected = (value as unknown[]).filter(
          (s) => !filtered.includes(s),
        );
        if (rejected.length > 0) {
          warnings.push(`Unknown section(s) removed: ${rejected.join(', ')}`);
        }
        if (filtered.length === 0) {
          errors.push(`sections must contain at least one of: ${[...VALID_SECTIONS].join(', ')}`);
          break;
        }
        cleaned[key] = filtered;
        break;
      }

      // ── whatsappNumber ───────────────────────────────────────────────────
      case 'whatsappNumber': {
        const digits = String(value).replace(/[\s\-+]/g, '');
        if (!/^\d{10,15}$/.test(digits)) {
          errors.push(`whatsappNumber must be 10–15 digits (got "${value}")`);
        } else {
          cleaned[key] = digits;
        }
        break;
      }

      // ── Delivery / order amounts ──────────────────────────────────────────
      case 'deliveryCharge': {
        const n = Number(value);
        if (!isFinite(n) || n < 0 || n > 9999) {
          errors.push(`deliveryCharge must be 0–9999`);
        } else {
          cleaned[key] = n;
        }
        break;
      }
      case 'freeDeliveryAbove':
      case 'minOrderAmount': {
        const n = Number(value);
        if (!isFinite(n) || n < 0 || n > 99999) {
          errors.push(`${key} must be 0–99999`);
        } else {
          cleaned[key] = n;
        }
        break;
      }

      // ── Boolean fields ────────────────────────────────────────────────────
      case 'whatsappEnabled':
      case 'storeHoursEnabled':
      case 'showAboutPage':
      case 'showContactPage':
      case 'showPrivacyPage':
      case 'showShippingPage':
      case 'showReturnPage':
      case 'announcementBarEnabled':
      case 'reviewsEnabled': {
        const b = coerceBool(value);
        if (b === null) {
          errors.push(`${key} must be a boolean (got "${value}")`);
        } else {
          cleaned[key] = b;
        }
        break;
      }

      // ── socialLinks ───────────────────────────────────────────────────────
      case 'socialLinks': {
        if (typeof value !== 'object' || value === null || Array.isArray(value)) {
          errors.push(`socialLinks must be an object`);
          break;
        }
        const links = value as Record<string, unknown>;
        const validKeys = new Set(['instagram', 'facebook', 'youtube', 'twitter']);
        const cleanedLinks: Record<string, string> = {};
        for (const [lk, lv] of Object.entries(links)) {
          if (!validKeys.has(lk)) {
            warnings.push(`Unknown socialLinks key ignored: ${lk}`);
            continue;
          }
          const s = String(lv ?? '').trim();
          if (s !== '' && !URL_RE.test(s)) {
            errors.push(`socialLinks.${lk} must be a valid http(s) URL or empty string`);
          } else {
            cleanedLinks[lk] = s;
          }
        }
        if (errors.length === 0) cleaned[key] = cleanedLinks;
        break;
      }

      // ── banners ───────────────────────────────────────────────────────────
      case 'banners': {
        if (!Array.isArray(value)) {
          errors.push(`banners must be an array`);
          break;
        }
        const validBanners = (value as unknown[]).filter((u) => isValidUrl(u));
        const invalidBanners = (value as unknown[]).filter((u) => !isValidUrl(u));
        if (invalidBanners.length > 0) {
          warnings.push(`${invalidBanners.length} invalid banner URL(s) removed`);
        }
        cleaned[key] = validBanners;
        break;
      }

      // ── URL fields ────────────────────────────────────────────────────────
      case 'logoUrl':
      case 'faviconUrl': {
        const s = String(value ?? '').trim();
        if (s !== '' && !URL_RE.test(s)) {
          errors.push(`${key} must be a valid http(s) URL or empty string`);
        } else {
          cleaned[key] = s;
        }
        break;
      }

      // ── SEO / length-limited strings ──────────────────────────────────────
      case 'siteName': {
        const s = truncate(value);
        if (s.length > 80) {
          errors.push(`siteName must be at most 80 characters`);
        } else {
          cleaned[key] = s;
        }
        break;
      }
      case 'seoTitle': {
        const s = truncate(value);
        if (s.length > 60) {
          warnings.push(`seoTitle truncated to 60 chars for SEO`);
          cleaned[key] = s.slice(0, 60);
        } else {
          cleaned[key] = s;
        }
        break;
      }
      case 'seoDescription': {
        const s = truncate(value);
        if (s.length > 160) {
          warnings.push(`seoDescription truncated to 160 chars for SEO`);
          cleaned[key] = s.slice(0, 160);
        } else {
          cleaned[key] = s;
        }
        break;
      }

      // ── All other allowed string fields ───────────────────────────────────
      default: {
        if (typeof value === 'string') {
          cleaned[key] = truncate(value);
        } else if (typeof value === 'number' || typeof value === 'boolean') {
          cleaned[key] = value;
        } else if (Array.isArray(value) || (typeof value === 'object' && value !== null)) {
          // Pass through complex types (e.g. couponCodes) as-is
          cleaned[key] = value;
        } else if (value === null || value === undefined) {
          // Skip nulls
          warnings.push(`Null/undefined value for ${key} ignored`);
        } else {
          cleaned[key] = String(value);
        }
        break;
      }
    }
  }

  if (Object.keys(cleaned).length === 0) {
    errors.push('No valid changes remain after validation');
  }

  return {
    ok: errors.length === 0 && Object.keys(cleaned).length > 0,
    cleanedChanges: cleaned,
    warnings,
    errors,
  };
}

/**
 * Light structural check on any AI-produced action before downstream processing.
 * Returns the action unchanged if it passes, or an ErrorAction if it is malformed.
 */
export function validateAIAction(raw: unknown): AiAction {
  if (!raw || typeof raw !== 'object') {
    return {
      type: 'ERROR',
      confidence: 0,
      originalIntent: '',
      reason: 'ambiguous',
      userMessage: 'Sorry, I couldn\'t understand that. Please try rephrasing.',
    };
  }

  const obj = raw as Record<string, unknown>;
  const validTypes = new Set(['UPDATE_CONFIG', 'ANALYTICS_QUERY', 'CLARIFY_NEEDED', 'ERROR', 'NAVIGATE']);

  if (!validTypes.has(String(obj['type']))) {
    return {
      type: 'ERROR',
      confidence: 0,
      originalIntent: String(obj['originalIntent'] ?? ''),
      reason: 'ambiguous',
      userMessage: 'Sorry, I couldn\'t understand that. Please try rephrasing.',
    };
  }

  // Clamp confidence to 0–1
  if (typeof obj['confidence'] === 'number') {
    obj['confidence'] = Math.max(0, Math.min(1, obj['confidence']));
  } else {
    obj['confidence'] = 0.5;
  }

  return obj as unknown as AiAction;
}
