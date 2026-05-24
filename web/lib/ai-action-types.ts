import type { WebsiteConfig } from './theme-engine';

export type ActionType =
  | 'UPDATE_CONFIG'
  | 'ANALYTICS_QUERY'
  | 'CLARIFY_NEEDED'
  | 'ERROR'
  | 'NAVIGATE';

// ── Base ────────────────────────────────────────────────────────────────────
interface BaseAction {
  type: ActionType;
  confidence: number; // 0.0 – 1.0
  originalIntent: string;
}

// ── Fields the AI is allowed to mutate ─────────────────────────────────────
// Excludes: isPublished, publishedAt, customHtml
export type WebsiteConfigChangeable = Omit<
  WebsiteConfig,
  'isPublished' | 'publishedAt' | 'customHtml'
>;

// ── UPDATE_CONFIG ───────────────────────────────────────────────────────────
export interface UpdateConfigAction extends BaseAction {
  type: 'UPDATE_CONFIG';
  changes: Partial<WebsiteConfigChangeable>;
  /** Reply to the shop owner (must match the language they used) */
  humanMessage: string;
}

// ── ANALYTICS_QUERY ─────────────────────────────────────────────────────────
export type AnalyticsMetric =
  | 'orders_today'
  | 'orders_week'
  | 'orders_month'
  | 'revenue_today'
  | 'revenue_week'
  | 'revenue_month'
  | 'top_products'
  | 'avg_order_value'
  | 'pending_orders';

export type AnalyticsPeriod = 'day' | 'week' | 'month';

export interface AnalyticsQueryAction extends BaseAction {
  type: 'ANALYTICS_QUERY';
  metric: AnalyticsMetric;
  period: AnalyticsPeriod;
}

// ── CLARIFY_NEEDED ──────────────────────────────────────────────────────────
export interface ClarifyNeededAction extends BaseAction {
  type: 'CLARIFY_NEEDED';
  question: string;
  options: string[]; // 2–4 choices
  context: string;
}

// ── ERROR ────────────────────────────────────────────────────────────────────
export type ErrorReason = 'out_of_scope' | 'ambiguous' | 'impossible' | 'unsafe';

export interface ErrorAction extends BaseAction {
  type: 'ERROR';
  reason: ErrorReason;
  /** Message shown to the shop owner (match their language) */
  userMessage: string;
}

// ── NAVIGATE ─────────────────────────────────────────────────────────────────
export type NavigateTab = 'theme' | 'design' | 'pages' | 'offers' | 'plugins';

export interface NavigateAction extends BaseAction {
  type: 'NAVIGATE';
  tab: NavigateTab;
  humanMessage: string;
}

// ── Union ─────────────────────────────────────────────────────────────────────
export type AiAction =
  | UpdateConfigAction
  | AnalyticsQueryAction
  | ClarifyNeededAction
  | ErrorAction
  | NavigateAction;
