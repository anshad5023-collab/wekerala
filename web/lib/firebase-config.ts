export function getFirebaseApiKey(): string {
  const key = process.env.NEXT_PUBLIC_FIREBASE_API_KEY;
  if (!key) {
    // In development, fall back to allow local testing
    if (process.env.NODE_ENV === 'development') {
      return 'AIzaSyCFB9YZL3_bXjvRMoWaYFv8nTs_ote52GQ';
    }
    throw new Error('NEXT_PUBLIC_FIREBASE_API_KEY is not configured');
  }
  return key;
}
