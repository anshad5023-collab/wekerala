import 'package:cloud_firestore/cloud_firestore.dart';

class BillItemModel {
  final String productId;
  final String productName;
  final String category; // product category — used for category-level flash sale
  final double qty;
  final String unit;
  final double price;
  final double subtotal;
  final int gstRate;
  final String? hsnCode;
  final bool priceIncludesGst;

  const BillItemModel({
    required this.productId,
    required this.productName,
    this.category = '',
    required this.qty,
    required this.unit,
    required this.price,
    required this.subtotal,
    this.gstRate = 0,
    this.hsnCode,
    this.priceIncludesGst = true,
  });

  BillItemModel copyWith({
    String? productId,
    String? productName,
    String? category,
    double? qty,
    String? unit,
    double? price,
    double? subtotal,
    int? gstRate,
    Object? hsnCode = _billSentinel,
    bool? priceIncludesGst,
  }) {
    return BillItemModel(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      category: category ?? this.category,
      qty: qty ?? this.qty,
      unit: unit ?? this.unit,
      price: price ?? this.price,
      subtotal: subtotal ?? this.subtotal,
      gstRate: gstRate ?? this.gstRate,
      hsnCode: hsnCode == _billSentinel ? this.hsnCode : hsnCode as String?,
      priceIncludesGst: priceIncludesGst ?? this.priceIncludesGst,
    );
  }

  factory BillItemModel.fromMap(Map<String, dynamic> map) {
    return BillItemModel(
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      category: map['category'] as String? ?? '',
      qty: (map['qty'] as num?)?.toDouble() ?? 0,
      unit: map['unit'] as String? ?? 'piece',
      price: (map['price'] as num?)?.toDouble() ?? 0,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0,
      gstRate: (map['gstRate'] as num?)?.toInt() ?? 0,
      hsnCode: map['hsnCode'] as String?,
      priceIncludesGst: (map['priceIncludesGst'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{
      'productId': productId,
      'productName': productName,
      'category': category,
      'qty': qty,
      'unit': unit,
      'price': price,
      'subtotal': subtotal,
      'gstRate': gstRate,
      'priceIncludesGst': priceIncludesGst,
    };
    if (hsnCode != null) m['hsnCode'] = hsnCode;
    return m;
  }
}

class BillModel {
  final String billId;
  final String shopId;
  final List<BillItemModel> items;
  final double totalAmount;
  final double discountAmount;
  final double finalAmount;
  final String paymentMethod; // 'cash' | 'upi' | 'udhar'
  final String customerName;
  final String customerPhone;
  final bool isUdhar;
  final DateTime createdAt;
  final Map<String, Map<String, double>> gstBreakdown;
  final double totalTax;
  final String? gstinSnapshot;
  final bool isVoided;
  final DateTime? voidedAt;
  final String? invoiceNumber;
  final double? cashAmount;   // only for paymentMethod == 'split'
  final double? upiAmount;    // only for paymentMethod == 'split'
  final String? billedByName; // staff name who created this bill
  final String? billNote;     // free-text note (e.g. prescription number)

  const BillModel({
    required this.billId,
    required this.shopId,
    required this.items,
    required this.totalAmount,
    this.discountAmount = 0,
    required this.finalAmount,
    required this.paymentMethod,
    this.customerName = '',
    this.customerPhone = '',
    required this.isUdhar,
    required this.createdAt,
    this.gstBreakdown = const {},
    this.totalTax = 0.0,
    this.gstinSnapshot,
    this.isVoided = false,
    this.voidedAt,
    this.invoiceNumber,
    this.cashAmount,
    this.upiAmount,
    this.billedByName,
    this.billNote,
  });

  factory BillModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return BillModel(
      billId: d['billId'] as String? ?? doc.id,
      shopId: d['shopId'] as String? ?? '',
      items: (d['items'] as List<dynamic>?)
              ?.map((e) => BillItemModel.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalAmount: (d['totalAmount'] as num?)?.toDouble() ?? 0,
      discountAmount: (d['discountAmount'] as num?)?.toDouble() ?? 0,
      finalAmount: (d['finalAmount'] as num?)?.toDouble() ?? 0,
      paymentMethod: d['paymentMethod'] as String? ?? 'cash',
      customerName: d['customerName'] as String? ?? '',
      customerPhone: d['customerPhone'] as String? ?? '',
      isUdhar: d['isUdhar'] as bool? ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      gstBreakdown: (d['gstBreakdown'] as Map<String, dynamic>? ?? {}).map(
        (k, v) => MapEntry(k, (v as Map).map(
          (kk, vv) => MapEntry(kk.toString(), (vv as num?)?.toDouble() ?? 0.0),
        )),
      ),
      totalTax: (d['totalTax'] as num?)?.toDouble() ?? 0.0,
      gstinSnapshot: d['gstinSnapshot'] as String?,
      isVoided: d['isVoided'] as bool? ?? false,
      voidedAt: d['voidedAt'] != null
          ? (d['voidedAt'] as Timestamp).toDate()
          : null,
      invoiceNumber: d['invoiceNumber'] as String?,
      cashAmount: (d['cashAmount'] as num?)?.toDouble(),
      upiAmount: (d['upiAmount'] as num?)?.toDouble(),
      billedByName: d['billedByName'] as String?,
      billNote: d['billNote'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    final m = <String, dynamic>{
      'billId': billId,
      'shopId': shopId,
      'items': items.map((i) => i.toMap()).toList(),
      'totalAmount': totalAmount,
      'discountAmount': discountAmount,
      'finalAmount': finalAmount,
      'paymentMethod': paymentMethod,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'isUdhar': isUdhar,
      'createdAt': Timestamp.fromDate(createdAt),
      'gstBreakdown': gstBreakdown,
      'totalTax': totalTax,
      'isVoided': isVoided,
    };
    if (gstinSnapshot != null) m['gstinSnapshot'] = gstinSnapshot;
    if (voidedAt != null) m['voidedAt'] = Timestamp.fromDate(voidedAt!);
    if (invoiceNumber != null) m['invoiceNumber'] = invoiceNumber;
    if (cashAmount != null) m['cashAmount'] = cashAmount;
    if (upiAmount != null) m['upiAmount'] = upiAmount;
    if (billedByName != null && billedByName!.isNotEmpty) m['billedByName'] = billedByName;
    if (billNote != null && billNote!.isNotEmpty) m['billNote'] = billNote;
    return m;
  }
}

const Object _billSentinel = Object();
