import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _langKey = 'language';

// Holds the language value loaded before runApp — passed in via ProviderScope override
final initialLanguageProvider = Provider<String>((ref) => 'en');

// Loaded translation maps
final _translationsProvider = FutureProvider<Map<String, Map<String, String>>>((ref) async {
  final enJson = await rootBundle.loadString('assets/translations/en.json');
  final mlJson = await rootBundle.loadString('assets/translations/ml.json');
  final en = Map<String, String>.from(json.decode(enJson) as Map);
  final ml = Map<String, String>.from(json.decode(mlJson) as Map);
  return {'en': en, 'ml': ml};
});

// Current language — 'en' or 'ml'
class LanguageNotifier extends Notifier<String> {
  @override
  String build() => ref.read(initialLanguageProvider);

  Future<void> setLanguage(String lang) async {
    state = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_langKey, lang);
  }
}

final languageProvider = NotifierProvider<LanguageNotifier, String>(LanguageNotifier.new);

// Resolved translations map for the current language
final translationsProvider = Provider<Map<String, String>>((ref) {
  final lang = ref.watch(languageProvider);
  final translations = ref.watch(_translationsProvider);
  return translations.when(
    data: (maps) => maps[lang] ?? maps['en'] ?? {},
    loading: () => {},
    error: (_, __) => {},
  );
});

// Helper extension for easy access in screens
extension WidgetRefTranslation on WidgetRef {
  String tr(String key) {
    final map = watch(translationsProvider);
    return map[key] ?? key;
  }
}

extension RefTranslation on Ref {
  String tr(String key) {
    final map = read(translationsProvider);
    return map[key] ?? key;
  }
}

// Load saved language from SharedPreferences — call in main.dart before runApp
Future<String> loadSavedLanguage() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_langKey) ?? '';
}
