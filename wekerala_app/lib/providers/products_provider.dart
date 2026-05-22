import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product_model.dart';

final productsStreamProvider =
    StreamProvider.family<List<ProductModel>, String>((ref, shopId) {
  return FirebaseFirestore.instance
      .collection('shops')
      .doc(shopId)
      .collection('products')
      .orderBy('createdAt', descending: true)
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

  static Future<void> add(String shopId, ProductModel p) =>
      _col(shopId).doc(p.productId).set(p.toFirestore());

  static Future<void> update(String shopId, ProductModel p) =>
      _col(shopId).doc(p.productId).set(p.toFirestore());

  static Future<void> delete(String shopId, String productId) =>
      _col(shopId).doc(productId).delete();

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
  }
}
