import 'package:cloud_firestore/cloud_firestore.dart';

class SlugGenerator {
  SlugGenerator._();

  static String fromName(String name) {
    return name
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-{2,}'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  static Future<String> findUnique(String shopName) async {
    final base = fromName(shopName);
    final root = base.isEmpty ? 'shop-${DateTime.now().millisecondsSinceEpoch}' : base;
    return _findAvailable(root, root, 2);
  }

  static Future<String> _findAvailable(
      String slug, String base, int counter) async {
    final query = await FirebaseFirestore.instance
        .collection('shops')
        .where('shopSlug', isEqualTo: slug)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return slug;
    return _findAvailable('$base-$counter', base, counter + 1);
  }
}
