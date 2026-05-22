import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  AppConfig._();

  static String get unsplashAccessKey => dotenv.env['UNSPLASH_ACCESS_KEY'] ?? '';
  static String get googleSheetsApiKey => dotenv.env['GOOGLE_SHEETS_API_KEY'] ?? '';
  static String get shoplinkUpiId => dotenv.env['SHOPLINK_UPI_ID'] ?? '';
  static String get supportWhatsApp => dotenv.env['SUPPORT_WHATSAPP'] ?? '';
  static String get storefrontBaseUrl =>
      dotenv.env['STOREFRONT_BASE_URL'] ?? 'https://shoplink-prod.web.app';
  static String get adminUrl =>
      dotenv.env['ADMIN_URL'] ?? 'https://admin-shoplink-prod.web.app';
  static String get appVersion => dotenv.env['APP_VERSION'] ?? '1.0.0';
  static String get apkStoragePath =>
      dotenv.env['APK_STORAGE_PATH'] ?? 'apk/shoplink-latest.apk';
  static bool get useFirebaseEmulator =>
      dotenv.env['USE_FIREBASE_EMULATOR'] == 'true';
  static bool get debugMode => dotenv.env['DEBUG_MODE'] == 'true';
}
