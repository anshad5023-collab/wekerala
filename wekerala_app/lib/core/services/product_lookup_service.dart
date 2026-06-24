import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

class ProductData {
  final String nameEn;
  final String brand;
  final String imageUrl;
  final String category;
  final String unit;
  final String description;
  final String source;
  final String barcodeType;
  /// Price/MRP read from the photo (0 = not visible). Never guessed.
  final double price;
  /// Discounted/offer price read from the photo (0 = none).
  final double offerPrice;
  /// Field names the AI was NOT confident about — the UI flags these for review.
  final List<String> uncertainFields;
  /// Shop-type-specific fields extracted by Gemini (composition, strength, fabric, etc.)
  final Map<String, dynamic> attributes;
  /// Main colour of the product/packaging read by the AI (e.g. 'Blue'). Used to
  /// verify any catalogue image matches the real product colour.
  final String dominantColor;
  /// Exact size/weight/volume printed on the pack (e.g. '80ml'). Sharpens the
  /// web image search to the correct variant.
  final String sizeText;
  /// True when the saved image is the owner's own photo (exact product) because
  /// no internet image matched. The UI can show "your photo" instead of a guess.
  final bool imageIsOwnerPhoto;

  const ProductData({
    this.nameEn = '',
    this.brand = '',
    this.imageUrl = '',
    this.category = '',
    this.unit = 'piece',
    this.description = '',
    this.source = '',
    this.barcodeType = 'CUSTOM',
    this.price = 0,
    this.offerPrice = 0,
    this.uncertainFields = const [],
    this.attributes = const {},
    this.dominantColor = '',
    this.sizeText = '',
    this.imageIsOwnerPhoto = false,
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
      // Retry on rate-limit / transient errors. Live Walk-Past Scan fires many
      // requests in a burst; the free Gemini tier (15 req/min) returns 429 when
      // exceeded, so we back off and retry instead of dropping the product.
      http.Response? resp;
      for (var attempt = 0; attempt < 3; attempt++) {
        resp = await http
            .post(
              Uri.parse('$_vercelBase/api/gemini-product'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'image': base64Image,
                'shopType': shopType,
                // Let Gemini pick the category from the shop's real list.
                'categories': shopCategories,
              }),
            )
            .timeout(const Duration(seconds: 25));
        if (resp.statusCode != 429 && resp.statusCode != 503) break;
        await Future.delayed(Duration(milliseconds: 900 * (attempt + 1)));
      }

      if (resp != null && resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        // Not a real product (e.g. an animal, a person, a random scene) — don't
        // create a junk product; the UI shows "could not identify".
        if (data['is_product'] == false) return null;
        final name = (data['name'] as String? ?? '').trim();
        final brand = (data['brand'] as String? ?? '').trim();
        final rawCat = (data['category'] as String? ?? '').trim();
        final color = (data['color'] as String? ?? '').trim();
        // dominant_color is the AI's read of the actual product colour from the
        // photo — more reliable than the free-form `color` attribute. We use it
        // both to sharpen the image search and to verify the result matches.
        final dominantColor =
            (data['dominant_color'] as String? ?? '').trim();
        final sizeText = (data['size_text'] as String? ?? '').trim();
        final unit = _normaliseUnit(data['unit'] as String? ?? 'piece');
        var imageUrl = (data['imageUrl'] as String? ?? '').trim();
        final description = (data['description'] as String? ?? '').trim();
        // Prices read from the photo only (never guessed by the model).
        final price = _parsePrice(data['price']);
        final offerPrice = _parsePrice(data['offerPrice']);
        final uncertain = ((data['uncertain_fields'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList();

        // The colour the catalogue image MUST match — prefer the AI's dominant
        // colour read, fall back to the colour attribute.
        final expectColor = dominantColor.isNotEmpty ? dominantColor : color;

        // Server (Vercel) couldn't get a DuckDuckGo image — DDG blocks data-center
        // IPs regardless of headers. Try again from the phone itself: a normal
        // mobile/WiFi IP isn't blocked, so this works where the server attempt can't.
        // Build the richest possible query — brand + name + exact colour + exact
        // size — so the result is the SAME variant, not just the same product type.
        if (imageUrl.isEmpty && (name.isNotEmpty || brand.isNotEmpty)) {
          imageUrl = await _fetchImageFromWeb(
              [brand, name, expectColor, sizeText]
                  .where((s) => s.isNotEmpty)
                  .join(' '));
        }

        // ── Colour verification gate ──────────────────────────────────────
        // Whatever image we ended up with (server OFF/OL match OR web search),
        // confirm its real colour matches the product the owner photographed.
        // If a clear chromatic colour was read and the candidate image's colour
        // is clearly different, DISCARD it — the Add-Product screen then keeps
        // the owner's own photo, which is always the exact product & colour.
        var imageVerified = imageUrl.isEmpty; // empty => owner photo, no check
        if (imageUrl.isNotEmpty && _isChromaticColor(expectColor)) {
          final ok = await _imageColourMatches(imageUrl, expectColor);
          if (!ok) {
            imageUrl = ''; // reject wrong-colour catalogue image
          } else {
            imageVerified = true;
          }
        } else if (imageUrl.isNotEmpty) {
          imageVerified = true; // neutral/unmappable colour — accept as-is
        }

        // Resolve the category against the shop's real list. Gemini was already
        // told to pick from this list, so prefer an exact match, then a clear
        // substring match. We deliberately do NOT fall back to fuzzy word-overlap
        // — that mapped "footwear" onto "Hair Accessories". A blank category the
        // owner can fill is always better than a confidently wrong one.
        String category = shopCategories.firstWhere(
          (c) => c.toLowerCase() == rawCat.toLowerCase(),
          orElse: () => '',
        );
        if (category.isEmpty && rawCat.isNotEmpty) {
          category = shopCategories.firstWhere(
            (c) =>
                c.toLowerCase().contains(rawCat.toLowerCase()) ||
                rawCat.toLowerCase().contains(c.toLowerCase()),
            orElse: () => '',
          );
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
          price: price,
          offerPrice: offerPrice,
          uncertainFields: uncertain,
          attributes: attributes,
          dominantColor: dominantColor,
          sizeText: sizeText,
          // No verified internet image => the screen should keep the owner's
          // photo (the exact product). True only when a match was confirmed.
          imageIsOwnerPhoto: !imageVerified,
        );
      }
    } catch (e) {
      debugPrint('Gemini photo lookup error: $e');
    }
    return null;
  }

  // ─── Private: web image search (run on-device) ───────────────────────────
  //
  // Search engines block data-center IPs (Vercel/AWS/etc.) as anti-bot
  // protection — no header trick fixes that. A shop owner's phone is on an
  // ordinary mobile/WiFi IP, so calling them directly from here works.
  // Free, no API key. We try Bing first (most scrape-friendly, no token
  // needed) and fall back to DuckDuckGo, so a single source going down or
  // changing its markup no longer means "no image".

  static const _imgUa =
      'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36';

  static Future<String> _fetchImageFromWeb(String query) async {
    final q = query.trim();
    if (q.isEmpty) return '';
    // Append "product" to bias results toward clean catalogue-style shots.
    final bing = await _bingImageSearch('$q product');
    if (bing.isNotEmpty) return bing;
    return _ddgImageSearch(q);
  }

  // Bing image search via HTML scrape. Each result carries a JSON `m`
  // attribute containing the full-size media URL as `murl`. No token, no key.
  static Future<String> _bingImageSearch(String query) async {
    try {
      // Prefetch the Bing homepage to get a session cookie. Without cookies,
      // Bing shows a consent/redirect page in many regions (India included) that
      // has no murl attribute — the regex silently finds nothing. A prior request
      // seeds the necessary cookies so the search page loads correctly.
      String cookie = '';
      try {
        final prefetch = await http.get(
          Uri.parse('https://www.bing.com/'),
          headers: {
            'User-Agent': _imgUa,
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.9',
            'Accept-Encoding': 'gzip, deflate',
          },
        ).timeout(const Duration(seconds: 5));
        cookie = prefetch.headers['set-cookie'] ?? '';
      } catch (_) {}

      final resp = await http.get(
        Uri.parse(
            'https://www.bing.com/images/search?q=${Uri.encodeQueryComponent(query)}'
            '&form=HDRSC2&first=1&safesearch=strict'),
        headers: {
          'User-Agent': _imgUa,
          'Accept-Language': 'en-US,en;q=0.9',
          'Accept-Encoding': 'gzip, deflate',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          if (cookie.isNotEmpty) 'Cookie': cookie,
        },
      ).timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) return '';
      final body = resp.body;
      // Markup is HTML-entity-encoded: murl&quot;:&quot;https://...&quot;
      for (final re in [
        RegExp(r'murl&quot;:&quot;(.*?)&quot;'),
        RegExp(r'"murl":"(.*?)"'),
      ]) {
        for (final m in re.allMatches(body)) {
          var url = m.group(1) ?? '';
          url = url.replaceAll('&amp;', '&');
          if (_isUsableImage(url)) return url;
        }
      }
    } catch (_) {/* best-effort */}
    return '';
  }

  // DuckDuckGo fallback — unofficial vqd-token flow. Hardened token regex
  // handles quoted, unquoted and JS-object (vqd:"…") variants DDG rotates between.
  static Future<String> _ddgImageSearch(String query) async {
    try {
      final tokenResp = await http.get(
        Uri.parse(
            'https://duckduckgo.com/?q=${Uri.encodeQueryComponent('$query product')}&iax=images&ia=images'),
        headers: {'User-Agent': _imgUa},
      ).timeout(const Duration(seconds: 6));

      final cookie = tokenResp.headers['set-cookie'] ?? '';
      final vqdMatch =
          RegExp(r'''vqd[=:]['"]?([\w-]+)''').firstMatch(tokenResp.body);
      if (vqdMatch == null) return '';

      final imgResp = await http.get(
        Uri.parse(
            'https://duckduckgo.com/i.js?q=${Uri.encodeQueryComponent(query)}&vqd=${vqdMatch.group(1)}&o=json&p=1&s=0&u=bing&f=,,,'),
        headers: {
          'User-Agent': _imgUa,
          'Referer': 'https://duckduckgo.com/',
          if (cookie.isNotEmpty) 'Cookie': cookie,
        },
      ).timeout(const Duration(seconds: 6));

      if (imgResp.statusCode != 200) return '';
      final data = jsonDecode(imgResp.body) as Map<String, dynamic>;
      final results = (data['results'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      for (final r in results) {
        final img = r['image'] as String?;
        if (img != null && _isUsableImage(img)) return img;
      }
    } catch (_) {/* best-effort */}
    return '';
  }

  // Reject non-http and obviously bad URLs (data URIs, tiny icons, gifs).
  static bool _isUsableImage(String url) {
    if (!url.startsWith('http')) return false;
    final low = url.toLowerCase();
    if (low.endsWith('.svg') || low.endsWith('.gif')) return false;
    return true;
  }

  // ─── Private: colour verification ─────────────────────────────────────────
  //
  // A catalogue image is only trustworthy if its colour matches the product the
  // owner actually photographed. We map the AI's colour word to a hue, measure
  // the candidate image's dominant hue on-device (free, no API), and compare.

  // Representative HSV hue (degrees) for each chromatic colour word. Neutral
  // colours (white/black/grey/silver/transparent/multicolour) are intentionally
  // absent — they can't be verified by hue, so we never reject on them.
  static const Map<String, double> _colourHue = {
    'red': 0, 'maroon': 0, 'crimson': 0, 'scarlet': 0,
    'orange': 30, 'amber': 35,
    'yellow': 55, 'gold': 50, 'golden': 50,
    'green': 120, 'olive': 80, 'lime': 90,
    'cyan': 185, 'teal': 180,
    'blue': 220, 'navy': 225, 'skyblue': 200,
    'purple': 280, 'violet': 280, 'indigo': 260, 'lavender': 280,
    'pink': 330, 'magenta': 320, 'maroon2': 350,
    'brown': 25,
  };

  // True when the colour word maps to a hue we can verify against pixels.
  static bool _isChromaticColor(String colorWord) {
    final w = colorWord.toLowerCase().trim();
    if (w.isEmpty) return false;
    for (final key in _colourHue.keys) {
      if (w.contains(key)) return true;
    }
    return false;
  }

  static double? _expectedHue(String colorWord) {
    final w = colorWord.toLowerCase().trim();
    for (final entry in _colourHue.entries) {
      if (w.contains(entry.key)) return entry.value;
    }
    return null;
  }

  // Download the candidate image and check its dominant chromatic hue is close
  // to the expected colour. Conservative: only returns false when the image has
  // enough coloured pixels AND their hue is clearly different — a neutral or
  // unreadable image passes (we don't want to reject good catalogue shots).
  static Future<bool> _imageColourMatches(String url, String colorWord) async {
    final expected = _expectedHue(colorWord);
    if (expected == null) return true; // can't verify => accept
    try {
      final resp = await http
          .get(Uri.parse(url), headers: {'User-Agent': _imgUa})
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return true; // can't fetch => don't reject
      final decoded = img.decodeImage(resp.bodyBytes);
      if (decoded == null) return true;

      // Downsample for speed — colour survives, work shrinks ~100x.
      final small = img.copyResize(decoded, width: 48);
      // Hue histogram (12 buckets of 30°), weighted by saturation*value, built
      // only from clearly chromatic pixels (skip white/black/grey background).
      final buckets = List<double>.filled(12, 0);
      var chromaticPixels = 0;
      for (var y = 0; y < small.height; y++) {
        for (var x = 0; x < small.width; x++) {
          final p = small.getPixel(x, y);
          final hsv = _rgbToHsv(p.r.toDouble(), p.g.toDouble(), p.b.toDouble());
          final h = hsv[0], s = hsv[1], v = hsv[2];
          // Skip near-white, near-black and washed-out (background) pixels.
          if (s < 0.25 || v < 0.18 || v > 0.97) continue;
          chromaticPixels++;
          buckets[(h ~/ 30) % 12] += s * v;
        }
      }
      final totalPixels = small.width * small.height;
      // Mostly neutral image (white pack, transparent bottle) — can't judge.
      if (chromaticPixels < totalPixels * 0.05) return true;

      // Dominant hue = centre of the heaviest bucket.
      var bestBucket = 0;
      for (var i = 1; i < 12; i++) {
        if (buckets[i] > buckets[bestBucket]) bestBucket = i;
      }
      final dominantHue = bestBucket * 30.0 + 15.0;

      // Circular hue distance; accept within ±45° (one bucket of slack each way).
      var diff = (dominantHue - expected).abs();
      if (diff > 180) diff = 360 - diff;
      return diff <= 45;
    } catch (_) {
      return true; // any failure => don't block a usable image
    }
  }

  // RGB (0-255) -> HSV with H in degrees [0,360), S and V in [0,1].
  static List<double> _rgbToHsv(double r, double g, double b) {
    r /= 255; g /= 255; b /= 255;
    final maxC = math.max(r, math.max(g, b));
    final minC = math.min(r, math.min(g, b));
    final d = maxC - minC;
    double h = 0;
    if (d != 0) {
      if (maxC == r) {
        h = 60 * (((g - b) / d) % 6);
      } else if (maxC == g) {
        h = 60 * (((b - r) / d) + 2);
      } else {
        h = 60 * (((r - g) / d) + 4);
      }
    }
    if (h < 0) h += 360;
    final s = maxC == 0 ? 0.0 : d / maxC;
    return [h, s, maxC];
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

  /// Parse a price value that may be a number, "45", "₹45", "45.00" or "" → 0.
  /// Returns 0 for anything non-numeric (so we never autofill a guessed price).
  static double _parsePrice(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    final s = v.toString().replaceAll(RegExp(r'[^0-9.]'), '');
    if (s.isEmpty) return 0;
    return double.tryParse(s) ?? 0;
  }

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
