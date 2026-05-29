importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyCFB9YZL3_bXjvRMoWaYFv8nTs_ote52GQ',
  authDomain: 'shoplink-prod.firebaseapp.com',
  projectId: 'shoplink-prod',
  storageBucket: 'shoplink-prod.firebasestorage.app',
  messagingSenderId: '482080959600',
  appId: '1:482080959600:web:32c50b63e69435d88398b5',
});

const messaging = firebase.messaging();

// Handle background push messages (app is closed or in background tab)
messaging.onBackgroundMessage((payload) => {
  const { title, body } = payload.notification ?? {};
  self.registration.showNotification(title ?? 'weKerala', {
    body: body ?? '',
    icon: '/icons/icon-192x192.png',
    badge: '/icons/icon-192x192.png',
    data: payload.data ?? {},
    vibrate: [200, 100, 200],
  });
});

// Clicking the notification opens/focuses the shop page
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const shopId = event.notification.data?.shopId;
  const orderId = event.notification.data?.orderId;
  const url = shopId && orderId
    ? `/shop?shopId=${shopId}&view=tracking&orderId=${orderId}`
    : '/';
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => {
      for (const client of list) {
        if (client.url.includes(shopId ?? '') && 'focus' in client) return client.focus();
      }
      return clients.openWindow(url);
    })
  );
});
