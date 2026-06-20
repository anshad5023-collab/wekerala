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
  final DateTime? scheduledFor; // pre-order delivery date/time
  /// How a delivery order is fulfilled: '' (unset) | 'self' | 'partner'.
  final String fulfillmentType;
  /// Delivery partner name/number when fulfillmentType == 'partner'.
  final String deliveryPartner;

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
    this.scheduledFor,
    this.fulfillmentType = '',
    this.deliveryPartner = '',
  });

  bool get isDelivery => deliveryType == 'delivery';

  static Color statusColor(String status) {
    switch (status) {
      case 'new':        return const Color(0xFFF57C00); // amber
      case 'confirmed':  return const Color(0xFF1976D2); // blue
      case 'processing': return const Color(0xFFFFA000); // dark amber
      case 'preparing':  return const Color(0xFFFFA000); // same as processing
      case 'ready':      return const Color(0xFF43A047); // green
      case 'out_for_delivery': return const Color(0xFF3949AB); // indigo
      case 'delivered':  return const Color(0xFF757575); // grey
      case 'cancelled':  return const Color(0xFFD32F2F); // red
      default:           return const Color(0xFF757575);
    }
  }

  /// Next status in the flow. Delivery orders get an extra "out for delivery"
  /// stage between ready and delivered.
  static String? nextStatus(String status, {bool isDelivery = false}) {
    switch (status) {
      case 'new':        return 'confirmed';
      case 'confirmed':  return 'processing';
      case 'processing': return 'ready';
      case 'ready':      return isDelivery ? 'out_for_delivery' : 'delivered';
      case 'out_for_delivery': return 'delivered';
      default:           return null;
    }
  }

  static String nextStatusLabel(String status, {bool isDelivery = false}) {
    switch (status) {
      case 'new':        return 'Confirm';
      case 'confirmed':  return 'Processing';
      case 'processing': return 'Mark Ready';
      case 'ready':      return isDelivery ? 'Out for Delivery' : 'Deliver';
      case 'out_for_delivery': return 'Mark Delivered';
      default:           return '';
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
      scheduledFor: m['scheduledFor'] != null
          ? _parseDate(m['scheduledFor'], DateTime.now())
          : null,
      fulfillmentType: m['fulfillmentType'] as String? ?? '',
      deliveryPartner: m['deliveryPartner'] as String? ?? '',
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
        if (scheduledFor != null) 'scheduledFor': Timestamp.fromDate(scheduledFor!),
        if (fulfillmentType.isNotEmpty) 'fulfillmentType': fulfillmentType,
        if (deliveryPartner.isNotEmpty) 'deliveryPartner': deliveryPartner,
      };

  OrderModel copyWith({
    String? status,
    String? paymentStatus,
    String? cancelReason,
    String? fulfillmentType,
    String? deliveryPartner,
  }) => OrderModel(
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
        scheduledFor: scheduledFor,
        fulfillmentType: fulfillmentType ?? this.fulfillmentType,
        deliveryPartner: deliveryPartner ?? this.deliveryPartner,
      );
}
