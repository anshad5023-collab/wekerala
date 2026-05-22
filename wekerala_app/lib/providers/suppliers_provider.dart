import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/supplier_model.dart';

final suppliersStreamProvider =
    StreamProvider.family<List<SupplierModel>, String>((ref, shopId) {
  return FirebaseFirestore.instance
      .collection('shops')
      .doc(shopId)
      .collection('suppliers')
      .orderBy('name')
      .snapshots()
      .map((snap) => snap.docs.map(SupplierModel.fromFirestore).toList());
});

class SuppliersRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String shopId) =>
      _db.collection('shops').doc(shopId).collection('suppliers');

  Future<void> addSupplier(String shopId, SupplierModel supplier) async {
    await _col(shopId).add(supplier.toFirestore());
  }

  Future<void> updateSupplier(String shopId, SupplierModel supplier) async {
    await _col(shopId).doc(supplier.supplierId).update(supplier.toFirestore());
  }

  Future<void> deleteSupplier(String shopId, String supplierId) async {
    await _col(shopId).doc(supplierId).delete();
  }
}

final suppliersRepositoryProvider = Provider<SuppliersRepository>(
  (_) => SuppliersRepository(),
);
