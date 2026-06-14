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
  final String description;
  final String source;
  final String barcodeType;
  /// Shop-type-specific fields extracted by Gemini (composition, strength, fabric, etc.)
  final Map<String, dynamic> attributes;

  const ProductData({
    this.nameEn = '',
    this.brand = '',
    this.imageUrl = '',
    this.category = '',
    this.unit = 'piece',
    this.description = '',
    this.source = '',
    this.barcodeType = 'CUSTOM',
    this.attributes = const {},
  });

  bool get hasData => nameEn.isNotEmpty || imageUrl.isNotEmpty;
}

class ProductLookupService {
  static final _db = FirebaseFirestore.instance;
  static const _vercelBase = 'https://wekerala.vercel.app';

  // ─── Barcode type detection ───────────────────────────────────────────────

  static String detectBarcodeType(String code) {
    final digits = code.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 13) return 'EAN13';
    if (digits.length == 12) return 'UPC';
    if (digits.length == 8) return 'EAN8';
    return 'CUSTOM';
  }

  // ─── Main barcode entry point ─────────────────────────────────────────────
  //
  // Database cascade order varies by shop type:
  //   Grocery / Bakery / Café / default  → community → Open Food Facts → UPC Item DB
  //   Pharmacy                            → community → UPC Item DB (medicines) → Open Food Facts (supplements)
  //   Electronics / Stationery            → community → UPC Item DB → Open Food Facts
  //   Textile / Fancy / Gift              → community → Open Food Facts (cosmetics) → UPC Item DB

  static Future<ProductData?> lookupBarcode(
      String barcode, List<String> shopCategories, {String shopType = ''}) async {
    final barcodeType = detectBarcodeType(barcode);
    final type = shopType.toLowerCase();

    // Step 1: Community database — always first, zero cost, shared across all Kerala shops
    final community = await _fromCommunity(barcode);
    if (community != null) {
      return ProductData(
        nameEn: community.nameEn,
        brand: community.brand,
        imageUrl: community.imageUrl,
        category: community.category,
        unit: community.unit,
        source: community.source,
        barcodeType: barcodeType,
        attributes: community.attributes,
      );
    }

    // Steps 2 & 3: Order depends on shop type
    final tryUpcFirst = type == 'pharmacy' ||
        type == 'electronics' ||
        type == 'stationery';

    Future<ProductData?> tryOff() async {
      final off = await _fromOpenFoodFacts(barcode, shopCategories);
      if (off == null) return null;
      return ProductData(
        nameEn: off.nameEn,
        brand: off.brand,
        imageUrl: off.imageUrl,
        category: off.category,
        unit: off.unit,
        source: off.source,
        barcodeType: barcodeType,
      );
    }

    Future<ProductData?> tryUpc() async {
      final upc = await _fromUpcItemDb(barcode, shopCategories);
      if (upc == null) return null;
      return ProductData(
        nameEn: upc.nameEn,
        brand: upc.brand,
        imageUrl: upc.imageUrl,
        category: upc.category,
        unit: upc.unit,
        source: upc.source,
        barcodeType: barcodeType,
      );
    }

    final first = tryUpcFirst ? await tryUpc() : await tryOff();
    if (first != null) {
      _saveToCommunity(barcode, first);
      return first;
    }

    final second = tryUpcFirst ? await tryOff() : await tryUpc();
    if (second != null) {
      _saveToCommunity(barcode, second);
      return second;
    }

    return null;
  }

  // ─── Photo-based identification via Gemini Vision ─────────────────────────

  static Future<ProductData?> lookupByPhoto(
    String base64Image,
    List<String> shopCategories, {
    String shopType = '',
  }) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$_vercelBase/api/gemini-product'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'image': base64Image,
              'shopType': shopType,
            }),
          )
          .timeout(const Duration(seconds: 25));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final name = (data['name'] as String? ?? '').trim();
        final brand = (data['brand'] as String? ?? '').trim();
        final rawCat = (data['category'] as String? ?? '').trim();
        final unit = _normaliseUnit(data['unit'] as String? ?? 'piece');
        final imageUrl = (data['imageUrl'] as String? ?? '').trim();
        final description = (data['description'] as String? ?? '').trim();

        // Match Gemini category against shop's category list.
        // Strategy: substring match first, then word-overlap fallback.
        String category = shopCategories.firstWhere(
          (c) =>
              c.toLowerCase().contains(rawCat.toLowerCase()) ||
              rawCat.toLowerCase().contains(c.toLowerCase()),
          orElse: () => '',
        );
        if (category.isEmpty && rawCat.isNotEmpty) {
          // Word-overlap: pick the shop category sharing the most words with Gemini's category
          final geminiWords = rawCat.toLowerCase().split(RegExp(r'[\s&/,]+'));
          String bestMatch = '';
          int bestScore = 0;
          for (final c in shopCategories) {
            final shopWords = c.toLowerCase().split(RegExp(r'[\s&/,]+'));
            final score = geminiWords.where((w) => w.length > 2 && shopWords.contains(w)).length;
            if (score > bestScore) { bestScore = score; bestMatch = c; }
          }
          if (bestScore > 0) category = bestMatch;
        }

        final fullName = (brand.isNotEmpty &&
                name.isNotEmpty &&
                !name.toLowerCase().contains(brand.toLowerCase()))
            ? '$brand $name'
            : name;

        // Extract shop-type-specific attributes from Gemini response
        final attributes = <String, dynamic>{};
        final attrKeys = [
          'composition', 'strength', 'manufacturer', 'form', 'schedule',
          'fabric', 'color', 'sizes', 'care_instructions', 'gender',
          'is_veg', 'allergens', 'spice_level', 'weight_g',
          'brand', 'model_number', 'warranty_months', 'cut_type',
        ];
        for (final key in attrKeys) {
          final val = data[key];
          if (val != null && val.toString().isNotEmpty) {
            attributes[key] = val.toString();
          }
        }

        return ProductData(
          nameEn: fullName,
          brand: brand,
          imageUrl: imageUrl,
          category: category,
          unit: unit,
          description: description,
          source: 'gemini',
          attributes: attributes,
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
        attributes: (d['attributes'] as Map<String, dynamic>?) ?? {},
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
      'barcodeType': data.barcodeType,
      if (data.attributes.isNotEmpty) 'attributes': data.attributes,
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
    // Grocery / food
    'beverages': ['Beverages', 'Drinks'],
    'drinks': ['Beverages', 'Drinks'],
    'juice': ['Beverages', 'Drinks'],
    'water': ['Beverages', 'Drinks'],
    'soda': ['Beverages', 'Drinks'],
    'dairy': ['Dairy & Eggs'],
    'milk': ['Dairy & Eggs'],
    'eggs': ['Dairy & Eggs'],
    'cheese': ['Dairy & Eggs'],
    'butter': ['Dairy & Eggs'],
    'curd': ['Dairy & Eggs'],
    'snacks': ['Snacks'],
    'chips': ['Snacks'],
    'biscuits': ['Biscuits & Cookies', 'Snacks'],
    'cookies': ['Biscuits & Cookies', 'Snacks'],
    'chocolates': ['Snacks'],
    'confectionery': ['Snacks'],
    'candy': ['Snacks'],
    'vegetables': ['Vegetables'],
    'fruits': ['Fruits'],
    'cereals': ['Grocery Staples'],
    'rice': ['Grocery Staples'],
    'wheat': ['Grocery Staples'],
    'flour': ['Grocery Staples'],
    'dal': ['Grocery Staples'],
    'pulses': ['Grocery Staples'],
    'oils': ['Grocery Staples'],
    'oil': ['Grocery Staples'],
    'ghee': ['Grocery Staples'],
    'spices': ['Grocery Staples'],
    'masala': ['Grocery Staples'],
    'salt': ['Grocery Staples'],
    'sugar': ['Grocery Staples'],
    'condiments': ['Grocery Staples'],
    'sauce': ['Grocery Staples'],
    'pickle': ['Grocery Staples'],
    'cleaning': ['Cleaning'],
    'detergent': ['Cleaning'],
    'soap': ['Cleaning', 'Personal Care'],
    'dishwash': ['Cleaning'],
    'floor cleaner': ['Cleaning'],
    'breads': ['Breads'],
    'bread': ['Breads'],
    'cakes': ['Cakes & Pastries'],
    'pastry': ['Cakes & Pastries'],
    // Pharmacy
    'medicines': ['Medicines'],
    'medicine': ['Medicines'],
    'tablet': ['Medicines'],
    'capsule': ['Medicines'],
    'syrup': ['Medicines'],
    'pharmacy': ['Medicines'],
    'vitamin': ['Vitamins'],
    'supplement': ['Vitamins'],
    'health device': ['Health Devices'],
    'thermometer': ['Health Devices'],
    'blood pressure': ['Health Devices'],
    // Meat & fish
    'chicken': ['Chicken'],
    'beef': ['Beef'],
    'mutton': ['Mutton'],
    'fish': ['Fish'],
    'seafood': ['Prawns & Seafood'],
    'prawn': ['Prawns & Seafood'],
    // Personal care
    'personal care': ['Personal Care'],
    'shampoo': ['Personal Care'],
    'conditioner': ['Personal Care'],
    'hair': ['Personal Care', 'Hair Accessories'],
    'toothpaste': ['Personal Care'],
    'toothbrush': ['Personal Care'],
    'deo': ['Personal Care'],
    'deodorant': ['Personal Care'],
    'perfume': ['Personal Care', 'Cosmetics'],
    'lotion': ['Personal Care', 'Cosmetics'],
    'cream': ['Personal Care', 'Cosmetics'],
    'face wash': ['Personal Care', 'Cosmetics'],
    'sunscreen': ['Personal Care', 'Cosmetics'],
    'baby': ['Baby Care'],
    'diaper': ['Baby Care'],
    // Fancy / gift stores
    'cosmetics': ['Cosmetics'],
    'makeup': ['Cosmetics'],
    'lipstick': ['Cosmetics'],
    'foundation': ['Cosmetics'],
    'kajal': ['Cosmetics'],
    'nail': ['Cosmetics'],
    'hair accessories': ['Hair Accessories'],
    'hair clip': ['Hair Accessories'],
    'hair band': ['Hair Accessories'],
    'jewelry': ['Artificial Jewelry'],
    'jewellery': ['Artificial Jewelry'],
    'earring': ['Artificial Jewelry'],
    'necklace': ['Artificial Jewelry'],
    'bangle': ['Artificial Jewelry'],
    'toys': ['Toys & Games'],
    'toy': ['Toys & Games'],
    'game': ['Toys & Games'],
    'gift': ['Gift Items'],
    'party': ['Party Supplies'],
    'balloon': ['Party Supplies'],
    // Textile / clothing
    'clothing': ["Men's Wear", "Women's Wear", "Kids' Wear"],
    'apparel': ["Men's Wear", "Women's Wear"],
    'shirt': ["Men's Wear"],
    'trouser': ["Men's Wear"],
    'pants': ["Men's Wear"],
    'saree': ["Women's Wear"],
    'churidar': ["Women's Wear"],
    'dress': ["Women's Wear"],
    'kids': ["Kids' Wear"],
    'children': ["Kids' Wear"],
    'accessories': ['Accessories'],
    'belt': ['Accessories'],
    'wallet': ['Accessories'],
    'bag': ['Accessories'],
    'handbag': ['Accessories'],
    'fabric': ['Fabrics'],
    'textile': ['Fabrics'],
    // Electronics
    'mobile': ['Mobile Accessories'],
    'phone': ['Mobile Accessories'],
    'charger': ['Cables & Chargers'],
    'cable': ['Cables & Chargers'],
    'earphone': ['Headphones'],
    'headphone': ['Headphones'],
    'bluetooth': ['Headphones', 'Smart Devices'],
    'smart': ['Smart Devices'],
    'electronics': ['Mobile Accessories', 'Smart Devices'],
    // Stationery
    'pen': ['Pens & Pencils'],
    'pencil': ['Pens & Pencils'],
    'notebook': ['Notebooks'],
    'book': ['Notebooks'],
    'art': ['Art Supplies'],
    'office': ['Office Items'],
    'school': ['School Items'],
    'stationery': ['Pens & Pencils', 'Notebooks'],
    // Hotel / restaurant
    'meals': ['Meals'],
    'food': ['Meals', 'Snacks'],
    'dessert': ['Desserts'],
    'beverage': ['Beverages', 'Drinks'],
    // Household / general
    'household': ['Household'],
    'kitchen': ['Household'],
    'utensil': ['Household'],
    'container': ['Household'],
    'miscellaneous': ['Miscellaneous'],
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
    if (s.contains(' g') || s.contains('gram')) return 'g';
    if (s.contains('ml') || s.contains('millilitre')) return 'ml';
    if (s.contains('litre') || s.contains('liter') || s.contains(' l')) {
      return 'litre';
    }
    return 'piece';
  }
}
