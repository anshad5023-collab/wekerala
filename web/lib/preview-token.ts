import { createHmac, timingSafeEqual } from 'crypto';

const PREVIEW_SECRET = process.env.PREVIEW_SECRET ?? 'wekerala-preview-secret-change-me';

/**
 * Generate a time-limited HMAC-SHA256 preview token.
 * Token format: `<base64url-hmac>_<expiresAtMs>`
 */
export function generatePreviewToken(shopId: string): { token: string; expiresAt: number } {
  const expiresAt = Date.now() + 24 * 60 * 60 * 1000; // 24 hours
  const payload = `${shopId}:${expiresAt}`;
  const hmac = createHmac('sha256', PREVIEW_SECRET)
    .update(payload)
    .digest('base64url');
  return { token: `${hmac}_${expiresAt}`, expiresAt };
}

/**
 * Validate a preview token for a given shopId.
 * Returns true if the token is valid and not expired.
 */
export function validatePreviewToken(token: string, shopId: string): boolean {
  try {
    const underscoreIdx = token.lastIndexOf('_');
    if (underscoreIdx === -1) return false;

    const hmacPart = token.slice(0, underscoreIdx);
    const expiresAtStr = token.slice(underscoreIdx + 1);
    const expiresAt = parseInt(expiresAtStr, 10);

    if (isNaN(expiresAt) || Date.now() > expiresAt) return false;

    const payload = `${shopId}:${expiresAt}`;
    const expected = createHmac('sha256', PREVIEW_SECRET)
      .update(payload)
      .digest('base64url');

    // Constant-time comparison to prevent timing attacks
    const a = Buffer.from(hmacPart);
    const b = Buffer.from(expected);
    if (a.length !== b.length) return false;
    return timingSafeEqual(a, b);
  } catch {
    return false;
  }
}
