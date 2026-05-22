import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.7.1/firebase-app.js';
import { getFirestore } from 'https://www.gstatic.com/firebasejs/10.7.1/firebase-firestore.js';

// ⚠️  BEFORE DEPLOYING: Go to Firebase Console > Project Settings > Your apps
// Click "Add app" > Web > register, then copy the config here.
// The apiKey, projectId, etc. below must match your web app registration.
// The apiKey shown is from the Android app and may also work for web in the same project.
const firebaseConfig = {
  apiKey: 'AIzaSyCFB9YZL3_bXjvRMoWaYFv8nTs_ote52GQ',
  authDomain: 'shoplink-prod.firebaseapp.com',
  projectId: 'shoplink-prod',
  storageBucket: 'shoplink-prod.firebasestorage.app',
  messagingSenderId: '482080959600',
  // Replace with your web app's appId from Firebase Console
  appId: '1:482080959600:web:32c50b63e69435d88398b5',
};

const app = initializeApp(firebaseConfig);
export const db = getFirestore(app);
