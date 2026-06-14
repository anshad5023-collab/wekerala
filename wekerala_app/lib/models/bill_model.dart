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
  final String? batchNumber;       // pharmacy dispensing record
  final bool tracksStock;          // false for services — skip stock decrement
  final List<String> modifiers;    // Bakery/Hotel add-ons: ["Extra cheese", "No spice"]
  final String? itemNote;          // per-item free-text note (Rx#, special instructions)

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
    this.batchNumber,
    this.tracksStock = true,
    this.modifiers = const [],
    this.itemNote,
  });

  /// True when this item is sold by weight (kg / g / gram).
  bool get isWeightBased {
    final u = unit.toLowerCase();
    return u == 'kg' || u == 'g' || u == 'gram' || u == 'grams' || u == 'gm';
  }

  /// Step size for qty increment: 0.25 kg for weight-based, 1 otherwise.
  double get qtyStep => isWeightBased ? 0.25 : 1.0;

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
    Object? batchNumber = _billSentinel,
    bool? tracksStock,
    List<String>? modifiers,
    Object? itemNote = _billSentinel,
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
      batchNumber: batchNumber == _billSentinel ? this.batchNumber : batchNumber as String?,
      tracksStock: tracksStock ?? this.tracksStock,
      modifiers: modifiers ?? this.modifiers,
      itemNote: itemNote == _billSentinel ? this.itemNote : itemNote as String?,
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
      batchNumber: map['batchNumber'] as String?,
      tracksStock: (map['tracksStock'] as bool?) ?? true,
      modifiers: (map['modifiers'] as List<dynamic>?)?.cast<String>() ?? const [],
      itemNote: map['itemNote'] as String?,
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
    if (batchNumber != null && batchNumber!.isNotEmpty) m['batchNumber'] = batchNumber;
    if (modifiers.isNotEmpty) m['modifiers'] = modifiers;
    if (itemNote != null && itemNote!.isNotEmpty) m['itemNote'] = itemNote;
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

  BillModel copyWith({
    String? billId,
    String? shopId,
    List<BillItemModel>? items,
    double? totalAmount,
    double? discountAmount,
    double? finalAmount,
    String? paymentMethod,
    String? customerName,
    String? customerPhone,
    bool? isUdhar,
    DateTime? createdAt,
    Map<String, Map<String, double>>? gstBreakdown,
    double? totalTax,
    Object? gstinSnapshot = _billSentinel,
    bool? isVoided,
    Object? voidedAt = _billSentinel,
    Object? invoiceNumber = _billSentinel,
    Object? cashAmount = _billSentinel,
    Object? upiAmount = _billSentinel,
    Object? billedByName = _billSentinel,
    Object? billNote = _billSentinel,
  }) {
    return BillModel(
      billId: billId ?? this.billId,
      shopId: shopId ?? this.shopId,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      finalAmount: finalAmount ?? this.finalAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      isUdhar: isUdhar ?? this.isUdhar,
      createdAt: createdAt ?? this.createdAt,
      gstBreakdown: gstBreakdown ?? this.gstBreakdown,
      totalTax: totalTax ?? this.totalTax,
      gstinSnapshot: gstinSnapshot == _billSentinel ? this.gstinSnapshot : gstinSnapshot as String?,
      isVoided: isVoided ?? this.isVoided,
      voidedAt: voidedAt == _billSentinel ? this.voidedAt : voidedAt as DateTime?,
      invoiceNumber: invoiceNumber == _billSentinel ? this.invoiceNumber : invoiceNumber as String?,
      cashAmount: cashAmount == _billSentinel ? this.cashAmount : cashAmount as double?,
      upiAmount: upiAmount == _billSentinel ? this.upiAmount : upiAmount as double?,
      billedByName: billedByName == _billSentinel ? this.billedByName : billedByName as String?,
      billNote: billNote == _billSentinel ? this.billNote : billNote as String?,
    );
  }
}

const Object _billSentinel = Object();
