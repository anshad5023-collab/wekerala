import { NextResponse } from 'next/server';

// Update this URL after uploading a new release APK to Firebase Storage
const APK_URL =
  'https://firebasestorage.googleapis.com/v0/b/shoplink-prod.firebasestorage.app/o/apk%2Fshoplink-latest.apk?alt=media';

export function GET() {
  return NextResponse.redirect(APK_URL, { status: 302 });
}
