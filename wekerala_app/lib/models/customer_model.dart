import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerModel {
  final String customerId;
  final String name;
  final String phone;
  final int totalOrders;
  final double totalSpent;
  final DateTime lastOrderDate;
  final DateTime firstOrderDate;
  final int loyaltyPoints;

  const CustomerModel({
    required this.customerId,
    required this.name,
    required this.phone,
    required this.totalOrders,
    required this.totalSpent,
    required this.lastOrderDate,
    required this.firstOrderDate,
    this.loyaltyPoints = 0,
  });

  // ── Computed getters ──────────────────────────────────────────────────────

  bool get isAtRisk =>
      DateTime.now().difference(lastOrderDate).inDays > 21;

  String get tag {
    if (isAtRisk) return 'At Risk';
    if (totalOrders >= 10) return 'Regular';
    return 'New';
  }

  // ── Firestore helpers ─────────────────────────────────────────────────────

  static DateTime _parseDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  factory CustomerModel.fromFirestore(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    return CustomerModel(
      customerId: doc.id,
      name: m['name'] as String? ?? '',
      phone: m['phone'] as String? ?? doc.id,
      totalOrders: (m['totalOrders'] as num?)?.toInt() ?? 0,
      totalSpent: (m['totalSpent'] as num?)?.toDouble() ?? 0.0,
      lastOrderDate: _parseDate(m['lastOrderDate']),
      firstOrderDate: _parseDate(m['firstOrderDate']),
      loyaltyPoints: (m['loyaltyPoints'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'customerId': customerId,
        'name': name,
        'phone': phone,
        'totalOrders': totalOrders,
        'totalSpent': totalSpent,
        'lastOrderDate': Timestamp.fromDate(lastOrderDate),
        'firstOrderDate': Timestamp.fromDate(firstOrderDate),
      };

  CustomerModel copyWith({
    String? customerId,
    String? name,
    String? phone,
    int? totalOrders,
    double? totalSpent,
    DateTime? lastOrderDate,
    DateTime? firstOrderDate,
  }) =>
      CustomerModel(
        customerId: customerId ?? this.customerId,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        totalOrders: totalOrders ?? this.totalOrders,
        totalSpent: totalSpent ?? this.totalSpent,
        lastOrderDate: lastOrderDate ?? this.lastOrderDate,
        firstOrderDate: firstOrderDate ?? this.firstOrderDate,
      );

  // ── Upsert ────────────────────────────────────────────────────────────────

  /// Ensures a customer record exists when a credit (Udhar) is recorded for them.
  /// Does NOT increment totalOrders or totalSpent — only guarantees the customer
  /// appears in the customer list so they can be messaged and tracked.
  static Future<void> upsertFromCredit({
    required String shopId,
    required String customerPhone,
    required String customerName,
  }) async {
    if (customerPhone.isEmpty) return;
    final ref = FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .collection('customers')
        .doc(customerPhone);

    final doc = await ref.get();
    final now = Timestamp.now();

    if (!doc.exists) {
      await ref.set({
        'customerId': customerPhone,
        'name': customerName,
        'phone': customerPhone,
        'totalOrders': 0,
        'totalSpent': 0.0,
        'lastOrderDate': now,
        'firstOrderDate': now,
      });
    } else if (customerName.isNotEmpty) {
      await ref.update({'name': customerName});
    }
  }

  /// Creates or updates the customer record whenever an order is placed.
  /// Called from the order placement flow.
  static Future<void> upsertFromOrder({
    required String shopId,
    required String customerPhone,
    required String customerName,
    required double orderAmount,
  }) async {
    final ref = FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .collection('customers')
        .doc(customerPhone);

    final doc = await ref.get();
    final now = Timestamp.now();

    if (!doc.exists) {
      await ref.set({
        'customerId': customerPhone,
        'name': customerName,
        'phone': customerPhone,
        'totalOrders': 1,
        'totalSpent': orderAmount,
        'lastOrderDate': now,
        'firstOrderDate': now,
      });
    } else {
      await ref.update({
        'totalOrders': FieldValue.increment(1),
        'totalSpent': FieldValue.increment(orderAmount),
        'lastOrderDate': now,
        if (customerName.isNotEmpty) 'name': customerName,
      });
    }
  }
}
