import 'package:cloud_firestore/cloud_firestore.dart';

class CreditModel {
  final String creditId;
  final String customerName;
  final String customerPhone;
  final double amount;
  final double paidAmount;
  final String note;
  final String status; // 'open' | 'partial' | 'paid'
  final DateTime createdAt;
  final DateTime? dueDate;

  const CreditModel({
    required this.creditId,
    required this.customerName,
    required this.customerPhone,
    required this.amount,
    this.paidAmount = 0,
    this.note = '',
    required this.status,
    required this.createdAt,
    this.dueDate,
  });

  // ── Computed getters ──────────────────────────────────────────────────────

  double get outstanding => amount - paidAmount;

  bool get isOverdue =>
      dueDate != null &&
      dueDate!.isBefore(DateTime.now()) &&
      status != 'paid';

  // ── Firestore helpers ─────────────────────────────────────────────────────

  static DateTime _parseDate(dynamic v, DateTime fallback) {
    if (v is Timestamp) return v.toDate();
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v) ?? fallback;
    return fallback;
  }

  factory CreditModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final now = DateTime.now();

    dynamic rawDue = d['dueDate'];
    DateTime? dueDate;
    if (rawDue is Timestamp) {
      dueDate = rawDue.toDate();
    } else if (rawDue is String && rawDue.isNotEmpty) {
      dueDate = DateTime.tryParse(rawDue);
    }

    return CreditModel(
      creditId: d['creditId'] as String? ?? doc.id,
      customerName: d['customerName'] as String? ?? '',
      customerPhone: d['customerPhone'] as String? ?? '',
      amount: (d['amount'] as num?)?.toDouble() ?? 0,
      paidAmount: (d['paidAmount'] as num?)?.toDouble() ?? 0,
      note: d['note'] as String? ?? '',
      status: d['status'] as String? ?? 'open',
      createdAt: _parseDate(d['createdAt'], now),
      dueDate: dueDate,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'creditId': creditId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'amount': amount,
      'paidAmount': paidAmount,
      'note': note,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
    };
  }

  CreditModel copyWith({
    String? creditId,
    String? customerName,
    String? customerPhone,
    double? amount,
    double? paidAmount,
    String? note,
    String? status,
    DateTime? createdAt,
    DateTime? dueDate,
    bool clearDueDate = false,
  }) {
    return CreditModel(
      creditId: creditId ?? this.creditId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      amount: amount ?? this.amount,
      paidAmount: paidAmount ?? this.paidAmount,
      note: note ?? this.note,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
    );
  }
}
