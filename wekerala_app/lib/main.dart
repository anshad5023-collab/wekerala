import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/services/fcm_service.dart';
import 'core/services/local_notification_service.dart';
import 'firebase_options.dart';
import 'providers/language_provider.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('FLUTTER ERROR: ${details.exception}');
      debugPrint('STACK: ${details.stack}');
    };

    final isAndroid = !kIsWeb && Platform.isAndroid;

    if (isAndroid) {
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      );
    }

    // Load env vars and Firebase in parallel — saves ~300ms
    await Future.wait([
      dotenv.load(fileName: '.env'),
      Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
    ]);

    if (!kIsWeb) {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    }

    if (isAndroid) {
      FirebaseMessaging.onBackgroundMessage(handleFcmBackground);
    }

    // Init notifications (Android only) and load language
    String savedLang;
    if (isAndroid) {
      // Run in parallel on Android — saves ~200ms
      final results = await Future.wait([
        LocalNotificationService.init().catchError((_) async {}),
        loadSavedLanguage(),
      ]);
      savedLang = results[1] as String;
    } else {
      savedLang = await loadSavedLanguage();
    }

    runApp(
      ProviderScope(
        overrides: [
          initialLanguageProvider.overrideWithValue(
            savedLang.isNotEmpty ? savedLang : 'en',
          ),
        ],
        child: const WeKeralaApp(),
      ),
    );
  }, (error, stack) {
    debugPrint('UNHANDLED ERROR: $error');
    debugPrint('STACK: $stack');
  });
}
