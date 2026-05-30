import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/order_model.dart';
import '../models/customer_model.dart';
import '../core/services/whatsapp_service.dart';

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

  // Read order + shop for post-update actions
  final results = await Future.wait([
    FirebaseFirestore.instance
        .collection('shops').doc(shopId)
        .collection('orders').doc(orderId)
        .get(),
    FirebaseFirestore.instance.collection('shops').doc(shopId).get(),
  ]);

  final orderDoc = results[0];
  final shopDoc = results[1];

  if (!orderDoc.exists) return;

  final data = orderDoc.data()!;
  final customerPhone = data['customerPhone'] as String? ?? '';
  final customerName = data['customerName'] as String? ?? '';
  final rawAmount = data['totalAmount'];
  final totalAmount = (rawAmount is num ? rawAmount : num.tryParse(rawAmount?.toString() ?? ''))?.toDouble() ?? 0;
  final shopName = shopDoc.data()?['shopName'] as String? ?? 'the shop';

  // Send WhatsApp status update to customer (no-op if Gupshup not configured)
  if (customerPhone.isNotEmpty) {
    WhatsAppService.sendOrderStatusToCustomer(
      customerPhone: customerPhone,
      orderNumber: data['orderNumber']?.toString() ?? orderId,
      status: newStatus,
      shopName: shopName,
    );
  }

  // Upsert customer record on delivery
  if (newStatus == 'delivered' && customerPhone.isNotEmpty) {
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
