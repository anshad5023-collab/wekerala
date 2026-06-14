import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product_model.dart';

// Tracks how many products to load — starts at 300, user can expand
final productLimitProvider =
    StateProvider.family<int, String>((ref, shopId) => 300);

final productsStreamProvider =
    StreamProvider.family<List<ProductModel>, String>((ref, shopId) {
  final limit = ref.watch(productLimitProvider(shopId));
  return FirebaseFirestore.instance
      .collection('shops')
      .doc(shopId)
      .collection('products')
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(ProductModel.fromFirestore).toList());
});

// Returns the first product matching the given barcode, or null if not found
final productByBarcodeProvider =
    Provider.family<ProductModel?, ({String shopId, String barcode})>(
        (ref, args) {
  final products = ref.watch(productsStreamProvider(args.shopId));
  return products.whenData((list) {
    for (final p in list) {
      if (p.barcode == args.barcode) return p;
    }
    return null;
  }).value;
});

// Returns products where stock is being tracked and qty is at or below threshold
final lowStockProductsProvider =
    Provider.family<List<ProductModel>, String>((ref, shopId) {
  final products = ref.watch(productsStreamProvider(shopId));
  return products
          .whenData((list) => list
              .where((p) =>
                  p.lowStockThreshold > 0 &&
                  p.stockQty != null &&
                  p.stockQty! <= p.lowStockThreshold)
              .toList())
          .value ??
      [];
});

class ProductRepository {
  static CollectionReference _col(String shopId) =>
      FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('products');

  static Future<void> add(String shopId, ProductModel p) async {
    await _col(shopId).doc(p.productId).set(p.toFirestore());
    final shopUpdate = <String, dynamic>{'productCount': FieldValue.increment(1)};
    if (p.category.isNotEmpty) {
      shopUpdate['categories'] = FieldValue.arrayUnion([p.category]);
    }
    await FirebaseFirestore.instance.collection('shops').doc(shopId).update(shopUpdate);
  }

  static Future<void> update(String shopId, ProductModel p) async {
    await _col(shopId).doc(p.productId).set(p.toFirestore());
    if (p.category.isNotEmpty) {
      await FirebaseFirestore.instance.collection('shops').doc(shopId).update({
        'categories': FieldValue.arrayUnion([p.category]),
      });
    }
  }

  static Future<void> delete(String shopId, String productId) async {
    await _col(shopId).doc(productId).delete();
    await FirebaseFirestore.instance.collection('shops').doc(shopId).update({
      'productCount': FieldValue.increment(-1),
    });
  }

  static Future<void> setHidden(String shopId, String productId, bool v) =>
      _col(shopId).doc(productId).update({
        'isHidden': v,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  static Future<void> setOutOfStock(String shopId, String productId, bool v) =>
      _col(shopId).doc(productId).update({
        'isOutOfStock': v,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  static Future<ProductModel?> getById(String shopId, String productId) async {
    final doc = await _col(shopId).doc(productId).get();
    return doc.exists ? ProductModel.fromFirestore(doc) : null;
  }

  static Future<void> batchAdd(
      String shopId, List<ProductModel> products) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final p in products) {
      batch.set(_col(shopId).doc(p.productId), p.toFirestore());
    }
    await batch.commit();
    // Denormalize count + auto-register categories in a single write
    final newCategories = products.map((p) => p.category).where((c) => c.isNotEmpty).toSet().toList();
    final shopUpdate = <String, dynamic>{'productCount': FieldValue.increment(products.length)};
    if (newCategories.isNotEmpty) {
      shopUpdate['categories'] = FieldValue.arrayUnion(newCategories);
    }
    await FirebaseFirestore.instance.collection('shops').doc(shopId).update(shopUpdate);
  }
}

// Returns products with an expiry date within the next 7 days (including already expired)
final expiringProductsProvider =
    Provider.family<List<ProductModel>, String>((ref, shopId) {
  final products = ref.watch(productsStreamProvider(shopId));
  final now = DateTime.now();
  final cutoff = now.add(const Duration(days: 7));
  return products
          .whenData((list) {
            final expiring = list
                .where((p) =>
                    p.expiryDate != null && p.expiryDate!.isBefore(cutoff))
                .toList()
              ..sort((a, b) =>
                  (a.expiryDate ?? now).compareTo(b.expiryDate ?? now));
            return expiring;
          })
          .value ??
      [];
});
// Returns products where stock tracking is enabled and qty == 0
final zeroStockProductsProvider =
    Provider.family<List<ProductModel>, String>((ref, shopId) {
  final products = ref.watch(productsStreamProvider(shopId));
  return products
          .whenData((list) => list
              .where((p) =>
                  p.stockQty != null &&
                  p.stockQty == 0)
              .toList())
          .value ??
      [];
});