import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// Top-level helper — accepts both num and string-encoded numbers from Firestore
num? _toNum(dynamic v) {
  if (v is num) return v;
  if (v is String) return num.tryParse(v);
  return null;
}

class OrderItemModel {
  final String productId;
  final String productName;
  final String variantName;
  final double qty;
  final String unit;
  final double price;
  final String itemNote;
  final double subtotal;

  const OrderItemModel({
    required this.productId,
    required this.productName,
    this.variantName = '',
    required this.qty,
    required this.unit,
    required this.price,
    this.itemNote = '',
    required this.subtotal,
  });

  factory OrderItemModel.fromMap(Map<String, dynamic> m) => OrderItemModel(
        productId: m['productId'] as String? ?? '',
        productName: m['productName'] as String? ?? '',
        variantName: m['variantName'] as String? ?? '',
        qty: _toNum(m['qty'])?.toDouble() ?? 1,
        unit: m['unit'] as String? ?? 'piece',
        price: _toNum(m['price'])?.toDouble() ?? 0,
        itemNote: m['itemNote'] as String? ?? '',
        subtotal: _toNum(m['subtotal'])?.toDouble() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'variantName': variantName,
        'qty': qty,
        'unit': unit,
        'price': price,
        'itemNote': itemNote,
        'subtotal': subtotal,
      };
}

class OrderModel {
  final String orderId;
  final String shopId;
  final int orderNumber;
  final String status;
  final String customerName;
  final String customerPhone;
  final String customerLocation;
  final String deliveryType;
  final String orderNote;
  final List<OrderItemModel> items;
  final double totalAmount;
  final String paymentMethod;
  final String paymentStatus;
  final String cancelReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OrderModel({
    required this.orderId,
    required this.shopId,
    required this.orderNumber,
    required this.status,
    required this.customerName,
    required this.customerPhone,
    this.customerLocation = '',
    required this.deliveryType,
    this.orderNote = '',
    required this.items,
    required this.totalAmount,
    required this.paymentMethod,
    this.paymentStatus = 'pending',
    this.cancelReason = '',
    required this.createdAt,
    required this.updatedAt,
  });

  static Color statusColor(String status) {
    switch (status) {
      case 'new': return Colors.red;
      case 'confirmed': return Colors.blue;
      case 'processing': return Colors.orange;
      case 'ready': return Colors.green;
      case 'delivered': return Colors.grey;
      case 'cancelled': return Colors.red.shade900;
      default: return Colors.grey;
    }
  }

  static DateTime _parseDate(dynamic v, DateTime fallback) {
    if (v is Timestamp) return v.toDate();
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v) ?? fallback;
    return fallback;
  }

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    return OrderModel(
      orderId: doc.id,
      shopId: m['shopId'] as String? ?? '',
      orderNumber: _toNum(m['orderNumber'])?.toInt() ?? 0,
      status: m['status'] as String? ?? 'new',
      customerName: m['customerName'] as String? ?? '',
      customerPhone: m['customerPhone'] as String? ?? '',
      customerLocation: m['customerLocation'] as String? ?? '',
      deliveryType: m['deliveryType'] as String? ?? 'pickup',
      orderNote: m['orderNote'] as String? ?? '',
      items: (m['items'] as List<dynamic>? ?? [])
          .map((e) => OrderItemModel.fromMap(e as Map<String, dynamic>))
          .toList(),
      totalAmount: _toNum(m['totalAmount'])?.toDouble() ?? 0,
      paymentMethod: m['paymentMethod'] as String? ?? 'cash',
      paymentStatus: m['paymentStatus'] as String? ?? 'pending',
      cancelReason: m['cancelReason'] as String? ?? '',
      createdAt: _parseDate(m['createdAt'], DateTime.now()),
      updatedAt: _parseDate(m['updatedAt'], DateTime.now()),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'shopId': shopId,
        'orderNumber': orderNumber,
        'status': status,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'customerLocation': customerLocation,
        'deliveryType': deliveryType,
        'orderNote': orderNote,
        'items': items.map((e) => e.toMap()).toList(),
        'totalAmount': totalAmount,
        'paymentMethod': paymentMethod,
        'paymentStatus': paymentStatus,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  OrderModel copyWith({String? status, String? paymentStatus, String? cancelReason}) => OrderModel(
        orderId: orderId,
        shopId: shopId,
        orderNumber: orderNumber,
        status: status ?? this.status,
        customerName: customerName,
        customerPhone: customerPhone,
        customerLocation: customerLocation,
        deliveryType: deliveryType,
        orderNote: orderNote,
        items: items,
        totalAmount: totalAmount,
        paymentMethod: paymentMethod,
        paymentStatus: paymentStatus ?? this.paymentStatus,
        cancelReason: cancelReason ?? this.cancelReason,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
