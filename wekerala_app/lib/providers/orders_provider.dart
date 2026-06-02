import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/order_model.dart';
import '../models/customer_model.dart';

final ordersStreamProvider =
    StreamProvider.family<List<OrderModel>, String>((ref, shopId) {
  return FirebaseFirestore.instance
      .collection('shops')
      .doc(shopId)
      .collection('orders')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(OrderModel.fromFirestore).toList());
});

final orderDetailProvider =
    StreamProvider.family<OrderModel?, ({String shopId, String orderId})>(
        (ref, args) {
  return FirebaseFirestore.instance
      .collection('shops')
      .doc(args.shopId)
      .collection('orders')
      .doc(args.orderId)
      .snapshots()
      .map((s) => s.exists ? OrderModel.fromFirestore(s) : null);
});

Future<void> updateOrderStatus(
    String shopId, String orderId, String newStatus,
    {String? cancelReason}) async {
  final fields = <String, dynamic>{
    'status': newStatus,
    'updatedAt': FieldValue.serverTimestamp(),
  };
  if (cancelReason != null && cancelReason.isNotEmpty) {
    fields['cancelReason'] = cancelReason;
  }
  await FirebaseFirestore.instance
      .collection('shops')
      .doc(shopId)
      .collection('orders')
      .doc(orderId)
      .update(fields);

  // Read order + shop for post-update side effects
  final orderDoc = await FirebaseFirestore.instance
      .collection('shops').doc(shopId)
      .collection('orders').doc(orderId)
      .get();

  if (!orderDoc.exists) return;

  final data = orderDoc.data()!;
  final customerPhone = data['customerPhone'] as String? ?? '';
  final customerName = data['customerName'] as String? ?? '';
  final rawAmount = data['totalAmount'];
  final totalAmount = (rawAmount is num ? rawAmount : num.tryParse(rawAmount?.toString() ?? ''))?.toDouble() ?? 0;

  // Restore stock when order is cancelled
  if (newStatus == 'cancelled') {
    final items = data['items'] as List<dynamic>? ?? [];
    if (items.isNotEmpty) {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      for (final item in items) {
        final itemMap = item as Map<String, dynamic>?;
        final productId = itemMap?['productId'] as String? ?? '';
        final qty = (itemMap?['qty'] as num?)?.toInt() ?? 0;
        if (productId.isNotEmpty && qty > 0) {
          final productRef = db.collection('shops').doc(shopId).collection('products').doc(productId);
          batch.update(productRef, {'stockQty': FieldValue.increment(qty)});
        }
      }
      await batch.commit();
    }
  }

  // Upsert customer on first meaningful status (confirmed = shop owner accepted the order)
  if ((newStatus == 'confirmed' || newStatus == 'delivered') && customerPhone.isNotEmpty) {
    await CustomerModel.upsertFromOrder(
      shopId: shopId,
      customerPhone: customerPhone,
      customerName: customerName,
      orderAmount: totalAmount,
    );
  }
}

// Today's orders computed from full stream
extension OrderListX on List<OrderModel> {
  List<OrderModel> get today {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return where((o) => o.createdAt.isAfter(start)).toList();
  }

  double get todayRevenue =>
      today.fold(0, (acc, o) => acc + o.totalAmount);
}

// Provider to get active shopId for order detail screen (needs shopId from user doc)
final activeShopIdForOrdersProvider = FutureProvider<String?>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;
  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get();
  final shopId = doc.data()?['activeShopId'] as String?;
  return (shopId != null && shopId.isNotEmpty) ? shopId : null;
});
