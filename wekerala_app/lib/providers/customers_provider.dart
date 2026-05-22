import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/customer_model.dart';

// ── Stream: all customers ordered by most-recent order ────────────────────

final customersStreamProvider =
    StreamProvider.family<List<CustomerModel>, String>((ref, shopId) {
  return FirebaseFirestore.instance
      .collection('shops')
      .doc(shopId)
      .collection('customers')
      .orderBy('lastOrderDate', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(CustomerModel.fromFirestore).toList());
});

// ── Derived: customers who haven't ordered in 21+ days ───────────────────

final atRiskCustomersProvider =
    Provider.family<List<CustomerModel>, String>((ref, shopId) {
  final customersAsync = ref.watch(customersStreamProvider(shopId));
  return customersAsync
          .whenData((list) => list.where((c) => c.isAtRisk).toList())
          .value ??
      [];
});
