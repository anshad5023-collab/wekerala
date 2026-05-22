import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_config.dart';

typedef ProductRow = Map<String, dynamic>;

class SheetsParser {
  SheetsParser._();

  static List<ProductRow> parsePasted(String text) {
    final lines = text
        .trim()
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return [];

    // Skip first row if it looks like a header
    final first = lines[0].toLowerCase();
    final start =
        (first.contains('name') || first.contains('price')) ? 1 : 0;

    return lines
        .skip(start)
        .map((line) => _parseRow(line.split('\t')))
        .where((p) =>
            (p['nameEn'] as String).isNotEmpty &&
            (p['price'] as double) > 0)
        .toList();
  }

  static Future<List<ProductRow>> fetchFromUrl(String url) async {
    final id = _extractId(url);
    if (id == null) throw Exception('Invalid Google Sheets URL');
    final key = AppConfig.googleSheetsApiKey;
    if (key.isEmpty) throw Exception('Google Sheets API key not configured');

    final uri = Uri.parse(
      'https://sheets.googleapis.com/v4/spreadsheets/$id/values/Sheet1?key=$key',
    );
    final res = await http.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw Exception('Could not fetch sheet (${res.statusCode})');
    }

    final data = json.decode(res.body) as Map<String, dynamic>;
    final rows = (data['values'] as List?)?.cast<List>() ?? [];
    if (rows.isEmpty) return [];

    final first = rows[0].map((e) => e.toString().toLowerCase()).toList();
    final hasHeader =
        first.any((c) => c.contains('name') || c.contains('price'));
    final dataRows = hasHeader ? rows.skip(1).toList() : rows;

    return dataRows
        .map((row) => _parseRow(row.map((e) => e.toString()).toList()))
        .where((p) =>
            (p['nameEn'] as String).isNotEmpty &&
            (p['price'] as double) > 0)
        .toList();
  }

  static ProductRow _parseRow(List<String> cols) {
    String c(int i) => cols.length > i ? cols[i].trim() : '';
    return {
      'nameEn': c(0),
      'price': double.tryParse(c(1)) ?? 0.0,
      'unit': c(2).isNotEmpty ? c(2) : 'piece',
      'offerPrice': double.tryParse(c(3)) ?? 0.0,
      'minQty': double.tryParse(c(4)) ?? 0.0,
      'category': c(5),
    };
  }

  static String? _extractId(String url) {
    final match =
        RegExp(r'/spreadsheets/d/([a-zA-Z0-9-_]+)').firstMatch(url);
    return match?.group(1);
  }
}
