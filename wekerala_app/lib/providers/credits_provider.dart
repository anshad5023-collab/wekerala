import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/credit_model.dart';

// ── Stream providers ──────────────────────────────────────────────────────────

/// Live stream of OPEN/PARTIAL credits only (status != 'paid').
/// Client-side filtering avoids the need for a composite Firestore index.
final creditsStreamProvider =
    StreamProvider.family<List<CreditModel>, String>((ref, shopId) {
  return FirebaseFirestore.instance
      .collection('shops')
      .doc(shopId)
      .collection('credits')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) {
    final all = s.docs.map(CreditModel.fromFirestore).toList();
    return all.where((c) => c.status != 'paid').toList();
  });
});

/// Live stream of ALL credits including paid ones.
final allCreditsStreamProvider =
    StreamProvider.family<List<CreditModel>, String>((ref, shopId) {
  return FirebaseFirestore.instance
      .collection('shops')
      .doc(shopId)
      .collection('credits')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(CreditModel.fromFirestore).toList());
});

// ── Repository ────────────────────────────────────────────────────────────────

class CreditsRepository {
  CreditsRepository._();

  static CollectionReference<Map<String, dynamic>> _col(String shopId) =>
      FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('credits');

  /// Add a new credit entry.
  static Future<void> add(String shopId, CreditModel credit) async {
    await _col(shopId).doc(credit.creditId).set(credit.toFirestore());
  }

  /// Mark a credit as fully paid.
  static Future<void> markPaid(String shopId, String creditId) async {
    final ref = _col(shopId).doc(creditId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final current = CreditModel.fromFirestore(snap);
    await ref.update({
      'status': 'paid',
      'paidAmount': current.amount,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Record a partial payment. Automatically promotes to 'paid' if fully settled.
  static Future<void> recordPartialPayment(
    String shopId,
    String creditId,
    double paymentAmount,
  ) async {
    final ref = _col(shopId).doc(creditId);
    final snap = await ref.get();
    if (!snap.exists) return;

    final current = CreditModel.fromFirestore(snap);
    final newPaid = (current.paidAmount + paymentAmount).clamp(0, current.amount);
    final fullyPaid = newPaid >= current.amount;

    await ref.update({
      'paidAmount': newPaid,
      'status': fullyPaid ? 'paid' : 'partial',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Permanently delete a credit entry.
  static Future<void> delete(String shopId, String creditId) async {
    await _col(shopId).doc(creditId).delete();
  }
}
