import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.7.1/firebase-app.js';
import { getFirestore } from 'https://www.gstatic.com/firebasejs/10.7.1/firebase-firestore.js';
import { getAuth } from 'https://www.gstatic.com/firebasejs/10.7.1/firebase-auth.js';

const firebaseConfig = {
  apiKey: 'AIzaSyCFB9YZL3_bXjvRMoWaYFv8nTs_ote52GQ',
  authDomain: 'shoplink-prod.firebaseapp.com',
  projectId: 'shoplink-prod',
  storageBucket: 'shoplink-prod.firebasestorage.app',
  messagingSenderId: '482080959600',
  appId: '1:482080959600:web:32c50b63e69435d88398b5',
};

const app = initializeApp(firebaseConfig);
export const db = getFirestore(app);
export const auth = getAuth(app);
