// ⚠️  THIS IS A PLACEHOLDER — REPLACE BY RUNNING:
//     flutterfire configure
//
// That command will overwrite this file with your real Firebase credentials.
// DO NOT use the app with this stub — it will throw a runtime error.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        return desktop;
      default:
        return windows;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCFB9YZL3_bXjvRMoWaYFv8nTs_ote52GQ',
    appId: '1:482080959600:android:25b5b83610dea37d8398b5',
    messagingSenderId: '482080959600',
    projectId: 'shoplink-prod',
    storageBucket: 'shoplink-prod.firebasestorage.app',
  );

  // Desktop (Windows/Linux/macOS) — same project as Android, desktop Firebase SDK
  static const FirebaseOptions desktop = FirebaseOptions(
    apiKey: 'AIzaSyCFB9YZL3_bXjvRMoWaYFv8nTs_ote52GQ',
    appId: '1:482080959600:android:25b5b83610dea37d8398b5',
    messagingSenderId: '482080959600',
    projectId: 'shoplink-prod',
    storageBucket: 'shoplink-prod.firebasestorage.app',
  );

  // Replace these with real values from: flutterfire configure

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'PLACEHOLDER_RUN_FLUTTERFIRE_CONFIGURE',
    appId: '1:000000000000:ios:0000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'shoplink-prod',
    storageBucket: 'shoplink-prod.appspot.com',
    iosClientId: 'PLACEHOLDER',
    iosBundleId: 'com.shoplink.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'PLACEHOLDER_RUN_FLUTTERFIRE_CONFIGURE',
    appId: '1:000000000000:web:0000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'shoplink-prod',
    storageBucket: 'shoplink-prod.appspot.com',
    authDomain: 'shoplink-prod.firebaseapp.com',
    measurementId: 'G-XXXXXXXXXX',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyC-9jIznz_fTBjPxvz2-FS8dXwUkX5he5E',
    appId: '1:482080959600:web:ae2b9c91b39645318398b5',
    messagingSenderId: '482080959600',
    projectId: 'shoplink-prod',
    authDomain: 'shoplink-prod.firebaseapp.com',
    storageBucket: 'shoplink-prod.firebasestorage.app',
  );

}