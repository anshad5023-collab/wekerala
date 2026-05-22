import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_config.dart';

class ImageMatcher {
  ImageMatcher._();

  static Future<String?> findForProduct(String productName) async {
    final key = AppConfig.unsplashAccessKey;
    if (key.isEmpty) return null;
    try {
      final query = Uri.encodeComponent(productName.toLowerCase().trim());
      final uri = Uri.parse(
        'https://api.unsplash.com/search/photos?query=$query&per_page=1&orientation=squarish&client_id=$key',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final data = json.decode(res.body) as Map<String, dynamic>;
      final results = data['results'] as List?;
      if (results == null || results.isEmpty) return null;
      return (results[0] as Map)['urls']?['small'] as String?;
    } catch (_) {
      return null;
    }
  }
}
