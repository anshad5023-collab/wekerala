/**
 * Server-side HMAC session tokens for control-panel API routes.
 *
 * Why: The web control panel has no Firebase Auth session (opened by Flutter
 * via URL). Routes that write data (upload, website publish) must not trust a
 * client-supplied uid. Instead, on page load the client POSTs to /api/auth/session
 * with the uid+shopId it received from Flutter; the server verifies ownership
 * via Admin SDK, then issues a short-lived signed token. Subsequent API calls
 * send this token as Bearer — the server verifies it without touching Firestore.
 *
 * Algorithm: HMAC-SHA256 over base64url(header).base64url(payload) — same
 * structure as JWT but using Node's built-in crypto (no external dep).
 */

import { createHmac, timingSafeEqual } from 'crypto';

const SECRET = process.env.SESSION_SECRET
  ?? process.env.FIREBASE_SERVICE_ACCOUNT?.slice(0, 64)  // fallback: first 64 chars of service account JSON
  ?? 'wekerala-session-secret-change-in-prod';

const TOKEN_TTL_MS = 24 * 60 * 60 * 1000; // 24 hours

interface SessionPayload {
  uid: string;
  shopId: string;
  iat: number;
  exp: number;
}

function b64url(str: string): string {
  return Buffer.from(str).toString('base64url');
}

function sign(payload: SessionPayload): string {
  const header = b64url(JSON.stringify({ alg: 'HS256', typ: 'WKS' }));
  const body = b64url(JSON.stringify(payload));
  const data = `${header}.${body}`;
  const sig = createHmac('sha256', SECRET).update(data).digest('base64url');
  return `${data}.${sig}`;
}

export function createSessionToken(uid: string, shopId: string): string {
  const now = Date.now();
  return sign({ uid, shopId, iat: now, exp: now + TOKEN_TTL_MS });
}

export function verifySessionToken(
  token: string
): { uid: string; shopId: string } | null {
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return null;
    const [header, body, sig] = parts;
    const data = `${header}.${body}`;
    const expected = createHmac('sha256', SECRET).update(data).digest('base64url');
    // Timing-safe comparison
    if (
      expected.length !== sig.length ||
      !timingSafeEqual(Buffer.from(expected), Buffer.from(sig))
    ) return null;
    const payload = JSON.parse(Buffer.from(body, 'base64url').toString()) as SessionPayload;
    if (Date.now() > payload.exp) return null;
    return { uid: payload.uid, shopId: payload.shopId };
  } catch {
    return null;
  }
}

/** Extract and verify a session token from an Authorization: Bearer header. */
export function authFromRequest(
  req: Request
): { uid: string; shopId: string } | null {
  const header = req.headers.get('authorization') ?? '';
  if (!header.startsWith('Bearer ')) return null;
  return verifySessionToken(header.slice(7));
}
