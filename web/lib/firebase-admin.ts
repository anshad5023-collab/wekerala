import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';

function ensureInit() {
  if (!getApps().length) {
    const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT;
    if (!serviceAccountJson) throw new Error('FIREBASE_SERVICE_ACCOUNT not configured');
    initializeApp({
      credential: cert(JSON.parse(serviceAccountJson.replace(/\\n/g, '\n'))),
    });
  }
}

export function getAdminDb() {
  ensureInit();
  return getFirestore();
}

export function getAdminMessaging() {
  ensureInit();
  return getMessaging();
}
