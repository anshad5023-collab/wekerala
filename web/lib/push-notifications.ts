'use client';

import { getToken } from 'firebase/messaging';
import { doc, updateDoc } from 'firebase/firestore';
import { db, getFirebaseMessaging } from './firebase';

// Set this in your .env.local:  NEXT_PUBLIC_FIREBASE_VAPID_KEY=<your key>
// Get it from: Firebase Console → Project Settings → Cloud Messaging → Web Push certificates
const VAPID_KEY = process.env.NEXT_PUBLIC_FIREBASE_VAPID_KEY ?? '';

/**
 * Requests browser push permission, gets the FCM token, and saves it to the
 * order document so Cloud Functions can push status updates to this browser.
 *
 * Returns true if permission was granted and token was saved, false otherwise.
 */
export async function subscribeOrderToPush(shopId: string, orderId: string): Promise<boolean> {
  try {
    if (typeof window === 'undefined') return false;

    // Register the service worker first
    const registration = await navigator.serviceWorker.register('/firebase-messaging-sw.js');

    const messaging = getFirebaseMessaging();
    if (!messaging) return false;

    // Request notification permission
    const permission = await Notification.requestPermission();
    if (permission !== 'granted') return false;

    // Get the FCM web push token
    const token = await getToken(messaging, {
      vapidKey: VAPID_KEY,
      serviceWorkerRegistration: registration,
    });

    if (!token) return false;

    // Save the token to the order document so Cloud Functions can send pushes
    await updateDoc(doc(db, 'shops', shopId, 'orders', orderId), {
      webPushToken: token,
    });

    return true;
  } catch (err) {
    console.error('[Push] Failed to subscribe:', err);
    return false;
  }
}
