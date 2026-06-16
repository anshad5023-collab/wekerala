// Lightweight tactile feedback using the browser's free Vibration API.
// No cost, no dependency, no network — supported on most Android devices
// (silently no-ops on iOS Safari and desktop, which is fine).

type HapticPattern = 'light' | 'medium' | 'success' | 'warning';

const PATTERNS: Record<HapticPattern, number | number[]> = {
  light: 8,            // a single soft tick — add to cart, quantity change
  medium: 16,          // a firmer tap — primary actions
  success: [12, 40, 24], // double-buzz — order placed
  warning: [30, 30, 30], // triple — errors / blocked actions
};

export function haptic(pattern: HapticPattern = 'light') {
  if (typeof navigator === 'undefined' || !('vibrate' in navigator)) return;
  try {
    navigator.vibrate(PATTERNS[pattern]);
  } catch {
    /* some browsers throw if called outside a user gesture — ignore */
  }
}
