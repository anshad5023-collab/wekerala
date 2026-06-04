import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ProductData {
  final String nameEn;
  final String brand;
  final String imageUrl;
  final String category;
  final String unit;
  final String source;

  const ProductData({
    this.nameEn = '',
    this.brand = '',
    this.imageUrl = '',
    this.category = '',
    this.unit = 'piece',
    this.source = '',
  });

  bool get hasData => nameEn.isNotEmpty || imageUrl.isNotEmpty;
}

class ProductLookupService {
  static final _db = FirebaseFirestore.instance;
  static const _vercelBase = 'https://wekerala.vercel.app';

  // ─── Main barcode entry point ─────────────────────────────────────────────

  static Future<ProductData?> lookupBarcode(
      String barcode, List<String> shopCategories) async {
    // 1. Community database — fastest, zero cost, Kerala-specific
    final community = await _fromCommunity(barcode);
    if (community != null) return community;

    // 2. Open Food Facts — India DB first, then world
    final off = await _fromOpenFoodFacts(barcode, shopCategories);
    if (off != null) {
      _saveToCommunity(barcode, off);
      return off;
    }

    // 3. UPC Item DB — good packaged goods coverage
    final upc = await _fromUpcItemDb(barcode, shopCategories);
    if (upc != null) {
      _saveToCommunity(barcode, upc);
      return upc;
    }

    return null;
  }

  // ─── Photo-based identification via Gemini Vision ─────────────────────────

  static Future<ProductData?> lookupByPhoto(
      String base64Image, List<String> shopCategories) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$_vercelBase/api/gemini-product'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'image': base64Image}),
          )
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final name = (data['name'] as String? ?? '').trim();
        final brand = (data['brand'] as String? ?? '').trim();
        final rawCat = (data['category'] as String? ?? '').trim();
        final unit = _normaliseUnit(data['unit'] as String? ?? 'piece');

        final category = shopCategories.firstWhere(
          (c) =>
              c.toLowerCase().contains(rawCat.toLowerCase()) ||
              rawCat.toLowerCase().contains(c.toLowerCase()),
          orElse: () => '',
        );

        final fullName = (brand.isNotEmpty &&
                name.isNotEmpty &&
                !name.toLowerCase().contains(brand.toLowerCase()))
            ? '$brand $name'
            : name;

        return ProductData(
          nameEn: fullName,
          brand: brand,
          category: category,
          unit: unit,
          source: 'gemini',
        );
      }
    } catch (e) {
      debugPrint('Gemini photo lookup error: $e');
    }
    return null;
  }

  // ─── Private: Community DB ───────────────────────────────────────────────

  static Future<ProductData?> _fromCommunity(String barcode) async {
    try {
      final doc =
          await _db.collection('product_catalog').doc(barcode).get();
      if (!doc.exists) return null;
      final d = doc.data()!;
      return ProductData(
        nameEn: d['nameEn'] as String? ?? '',
        brand: d['brand'] as String? ?? '',
        imageUrl: d['imageUrl'] as String? ?? '',
        category: d['category'] as String? ?? '',
        unit: d['unit'] as String? ?? 'piece',
        source: 'community',
      );
    } catch (_) {
      return null;
    }
  }

  // Fire-and-forget — don't await, never blocks the UI
  static void _saveToCommunity(String barcode, ProductData data) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _db.collection('product_catalog').doc(barcode).set({
      'barcode': barcode,
      'nameEn': data.nameEn,
      'brand': data.brand,
      'imageUrl': data.imageUrl,
      'category': data.category,
      'unit': data.unit,
      'source': data.source,
      'addedAt': FieldValue.serverTimestamp(),
      'verifiedCount': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  // ─── Private: Open Food Facts ────────────────────────────────────────────

  static Future<ProductData?> _fromOpenFoodFacts(
      String barcode, List<String> categories) async {
    for (final host in [
      'in.openfoodfacts.org',
      'world.openfoodfacts.org'
    ]) {
      try {
        final resp = await http.get(
          Uri.parse('https://$host/api/v2/product/$barcode.json'),
          headers: {'User-Agent': 'Oratas/1.0 (oratas4ai@gmail.com)'},
        ).timeout(const Duration(seconds: 8));
        if (resp.statusCode != 200) continue;
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        if (data['status'] != 1) continue;
        final p = data['product'] as Map<String, dynamic>;
        final name = ((p['product_name_en'] ??
                    p['product_name_in'] ??
                    p['product_name']) as String? ??
                '')
            .trim();
        final brand =
            (p['brands'] as String? ?? '').split(',').first.trim();
        final imageUrl =
            ((p['image_front_url'] ?? p['image_url']) as String? ?? '')
                .trim();
        if (name.isEmpty && imageUrl.isEmpty) continue;
        return ProductData(
          nameEn: (brand.isNotEmpty &&
                  name.isNotEmpty &&
                  !name.toLowerCase().contains(brand.toLowerCase()))
              ? '$brand $name'
              : name,
          brand: brand,
          imageUrl: imageUrl,
          category: _offCategory(p, categories),
          unit: _offUnit(p),
          source: 'openfoodfacts',
        );
      } catch (_) {}
    }
    return null;
  }

  // ─── Private: UPC Item DB ────────────────────────────────────────────────

  static Future<ProductData?> _fromUpcItemDb(
      String barcode, List<String> categories) async {
    try {
      final resp = await http.get(
        Uri.parse(
            'https://api.upcitemdb.com/prod/trial/lookup?upc=$barcode'),
        headers: {'User-Agent': 'Oratas/1.0'},
      ).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final items =
          (data['items'] as List?)?.cast<Map<String, dynamic>>();
      if (items == null || items.isEmpty) return null;
      final item = items.first;
      final name = (item['title'] as String? ?? '').trim();
      final brand = (item['brand'] as String? ?? '').trim();
      final images =
          (item['images'] as List?)?.cast<String>() ?? [];
      final imageUrl = images.isNotEmpty ? images.first : '';
      if (name.isEmpty) return null;
      final rawCat =
          (item['category'] as String? ?? '').toLowerCase();
      return ProductData(
        nameEn: name,
        brand: brand,
        imageUrl: imageUrl,
        category: _matchCategory([rawCat], categories),
        unit: 'piece',
        source: 'upcitemdb',
      );
    } catch (_) {
      return null;
    }
  }

  // ─── Category helpers ────────────────────────────────────────────────────

  static const _categoryMap = {
    'beverages': ['Beverages', 'Drinks'],
    'drinks': ['Beverages', 'Drinks'],
    'dairy': ['Dairy & Eggs'],
    'milk': ['Dairy & Eggs'],
    'eggs': ['Dairy & Eggs'],
    'snacks': ['Snacks'],
    'chips': ['Snacks'],
    'biscuits': ['Biscuits & Cookies', 'Snacks'],
    'cookies': ['Biscuits & Cookies', 'Snacks'],
    'chocolates': ['Snacks'],
    'confectionery': ['Snacks'],
    'vegetables': ['Vegetables'],
    'fruits': ['Fruits'],
    'cereals': ['Grocery Staples'],
    'rice': ['Grocery Staples'],
    'flour': ['Grocery Staples'],
    'oils': ['Grocery Staples'],
    'spices': ['Grocery Staples'],
    'condiments': ['Grocery Staples'],
    'cleaning': ['Cleaning'],
    'detergent': ['Cleaning'],
    'breads': ['Breads'],
    'bread': ['Breads'],
    'cakes': ['Cakes & Pastries'],
    'medicines': ['Medicines'],
    'pharmacy': ['Medicines'],
    'chicken': ['Chicken'],
    'beef': ['Beef'],
    'mutton': ['Mutton'],
    'fish': ['Fish'],
    'seafood': ['Prawns & Seafood'],
    'personal care': ['Personal Care'],
    'baby': ['Baby Care'],
  };

  static String _offCategory(
      Map<String, dynamic> p, List<String> available) {
    final tags =
        ((p['categories_tags'] as List?)?.cast<String>() ?? [])
            .map((t) => t.split(':').last.toLowerCase())
            .toList();
    return _matchCategory(tags, available);
  }

  static String _matchCategory(
      List<String> tags, List<String> available) {
    for (final tag in tags) {
      for (final entry in _categoryMap.entries) {
        if (tag.contains(entry.key)) {
          for (final cat in entry.value) {
            if (available.contains(cat)) return cat;
          }
        }
      }
    }
    return '';
  }

  // ─── Unit helpers ────────────────────────────────────────────────────────

  static String _offUnit(Map<String, dynamic> p) =>
      _normaliseUnit(p['quantity'] as String? ?? '');

  static String _normaliseUnit(String raw) {
    final s = raw.toLowerCase();
    if (s.contains('kg') || s.contains('kilogram')) return 'kg';
    if (s.contains(' g') || s.contains('gram')) return 'gram';
    if (s.contains('ml') || s.contains('millilitre')) return 'ml';
    if (s.contains('litre') || s.contains('liter') || s.contains(' l')) {
      return 'litre';
    }
    return 'piece';
  }
}
