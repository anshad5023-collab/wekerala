import 'package:cloud_firestore/cloud_firestore.dart';

class VariantModel {
  final String variantId;
  final String name;
  final double price;
  final double offerPrice;
  final int? stockQty; // null = not tracking stock for this variant

  const VariantModel({
    required this.variantId,
    required this.name,
    required this.price,
    this.offerPrice = 0,
    this.stockQty,
  });

  bool get isOutOfStock => stockQty != null && stockQty! <= 0;
  bool get isLowStock => stockQty != null && stockQty! > 0 && stockQty! <= 3;

  factory VariantModel.fromMap(Map<String, dynamic> m) {
    return VariantModel(
      variantId: m['variantId'] as String? ?? '',
      name: m['name'] as String? ?? '',
      price: (m['price'] as num?)?.toDouble() ?? 0,
      offerPrice: (m['offerPrice'] as num?)?.toDouble() ?? 0,
      stockQty: (m['stockQty'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{
      'variantId': variantId,
      'name': name,
      'price': price,
      'offerPrice': offerPrice,
    };
    if (stockQty != null) m['stockQty'] = stockQty;
    return m;
  }

  VariantModel copyWith({
    String? name,
    double? price,
    double? offerPrice,
    Object? stockQty = _sentinel,
  }) {
    return VariantModel(
      variantId: variantId,
      name: name ?? this.name,
      price: price ?? this.price,
      offerPrice: offerPrice ?? this.offerPrice,
      stockQty: stockQty == _sentinel ? this.stockQty : stockQty as int?,
    );
  }

  static const Object _sentinel = Object();

  static String newId() =>
      FirebaseFirestore.instance.collection('_').doc().id;
}
