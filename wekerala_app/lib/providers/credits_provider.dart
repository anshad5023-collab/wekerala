import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/credit_model.dart';

// ── Stream providers ──────────────────────────────────────────────────────────

/// Live stream of OPEN/PARTIAL credits only (status != 'paid').
/// Firestore-level filter + limit(200) prevents unbounded reads.
/// Requires a composite index: status ASC, createdAt DESC.
final creditsStreamProvider =
    StreamProvider.family<List<CreditModel>, String>((ref, shopId) {
  return FirebaseFirestore.instance
      .collection('shops')
      .doc(shopId)
      .collection('credits')
      .where('status', isNotEqualTo: 'paid')
      .orderBy('status')
      .orderBy('createdAt', descending: true)
      .limit(200)
      .snapshots()
      .map((s) => s.docs.map(CreditModel.fromFirestore).toList());
});

/// Live stream of ALL credits including paid ones.
final allCreditsStreamProvider =
    StreamProvider.family<List<CreditModel>, String>((ref, shopId) {
  return FirebaseFirestore.instance
      .collection('shops')
      .doc(shopId)
      .collection('credits')
      .orderBy('createdAt', descending: true)
      .limit(300) // last 300 credit entries
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
    // Also update udharBalance on customer document for consistency
    if (credit.customerPhone.isNotEmpty) {
      FirebaseFirestore.instance
          .collection('shops').doc(shopId)
          .collection('customers').doc(credit.customerPhone)
          .set({'udharBalance': FieldValue.increment(credit.amount)},
              SetOptions(merge: true));
    }
  }

  /// Mark a credit as fully paid.
  static Future<void> markPaid(String shopId, String creditId) async {
    final ref = _col(shopId).doc(creditId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final current = CreditModel.fromFirestore(snap);
    final remaining = current.outstanding;
    await ref.update({
      'status': 'paid',
      'paidAmount': current.amount,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    // Also decrement udharBalance on customer document
    if (current.customerPhone.isNotEmpty && remaining > 0) {
      FirebaseFirestore.instance
          .collection('shops').doc(shopId)
          .collection('customers').doc(current.customerPhone)
          .set({'udharBalance': FieldValue.increment(-remaining)},
              SetOptions(merge: true));
    }
  }

  /// Record a partial payment. Automatically promotes to 'paid' if fully settled.
  /// Uses a Firestore transaction to atomically guard against concurrent payments
  /// pushing paidAmount above the credit amount (race condition).
  static Future<void> recordPartialPayment(
    String shopId,
    String creditId,
    double paymentAmount,
  ) async {
    final db = FirebaseFirestore.instance;
    final ref = _col(shopId).doc(creditId);

    String customerPhone = '';
    await db.runTransaction((transaction) async {
      final snap = await transaction.get(ref);
      if (!snap.exists) throw Exception('Credit not found');

      final data = snap.data()!;
      final currentPaid = (data['paidAmount'] as num?)?.toDouble() ?? 0;
      final amount = (data['amount'] as num?)?.toDouble() ?? 0;
      customerPhone = (data['customerPhone'] as String?) ?? '';

      final newPaid = currentPaid + paymentAmount;
      if (newPaid > amount + 0.001) {
        // 0.001 tolerance for floating-point rounding
        throw Exception('Payment exceeds outstanding balance');
      }
      final clampedPaid = newPaid.clamp(0.0, amount);
      final fullyPaid = clampedPaid >= amount;

      transaction.update(ref, {
        'paidAmount': clampedPaid,
        'status': fullyPaid ? 'paid' : 'partial',
        'lastPaymentAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    // Decrement udharBalance on customer document (outside transaction — best-effort)
    if (customerPhone.isNotEmpty && paymentAmount > 0) {
      db
          .collection('shops').doc(shopId)
          .collection('customers').doc(customerPhone)
          .set({'udharBalance': FieldValue.increment(-paymentAmount)},
              SetOptions(merge: true));
    }
  }

  /// Permanently delete a credit entry.
  static Future<void> delete(String shopId, String creditId) async {
    await _col(shopId).doc(creditId).delete();
  }
}
