import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GeminiService {
  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  /// Sends product stock + sales data to Gemini and returns reorder suggestions.
  /// [products] is a list of maps with keys: name, stock, threshold, soldThisWeek, unit, price
  static Future<String> getReorderSuggestions(
      List<Map<String, dynamic>> products) async {
    if (_apiKey.isEmpty) {
      return 'Please add your GEMINI_API_KEY to the .env file to use AI suggestions.';
    }

    final productLines = products.map((p) {
      final stock = p['stock'] ?? 0;
      final sold = p['soldThisWeek'] ?? 0;
      final threshold = p['threshold'] ?? 5;
      final status = stock <= threshold ? '⚠️ LOW' : '✅ OK';
      return '- ${p['name']} | Stock: $stock ${p['unit']} $status | Sold this week: $sold | Price: ₹${p['price']}';
    }).join('\n');

    final prompt = '''
You are a smart inventory assistant for a Kerala shop. Analyze this product data and give practical reorder suggestions in simple English.

PRODUCT INVENTORY:
$productLines

Give a brief, actionable response:
1. List the top 3-5 products that need reordering urgently (low stock + high sales)
2. Suggest approximate reorder quantities based on weekly sales velocity
3. One short tip for managing inventory better

Keep the response under 200 words. Use simple language. Format with bullet points.
''';

    try {
      final res = await http
          .post(
            Uri.parse('$_endpoint?key=$_apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt}
                  ]
                }
              ],
              'generationConfig': {
                'maxOutputTokens': 300,
                'temperature': 0.4,
              },
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return (data['candidates'] as List?)
                ?.firstOrNull?['content']?['parts']
                ?.firstOrNull?['text'] as String? ??
            'No suggestions returned.';
      } else {
        return 'Gemini error (${res.statusCode}). Check your API key.';
      }
    } catch (e) {
      return 'Could not connect to Gemini. Check your internet connection.';
    }
  }
}
