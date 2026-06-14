import 'package:cloud_firestore/cloud_firestore.dart';

class VariantModel {
  final String variantId;
  final String name;
  final double price;
  final double offerPrice;
  final int? stockQty; // null = not tracking stock for this variant
  final String? sku;
  final Map<String, dynamic> attributes;

  const VariantModel({
    required this.variantId,
    required this.name,
    required this.price,
    this.offerPrice = 0,
    this.stockQty,
    this.sku,
    this.attributes = const {},
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
      sku: m['sku'] as String?,
      attributes: (m['attributes'] as Map<String, dynamic>?) ?? {},
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
    if (sku != null && sku!.isNotEmpty) m['sku'] = sku;
    if (attributes.isNotEmpty) m['attributes'] = attributes;
    return m;
  }

  VariantModel copyWith({
    String? name,
    double? price,
    double? offerPrice,
    Object? stockQty = _sentinel,
    Object? sku = _sentinel,
    Map<String, dynamic>? attributes,
  }) {
    return VariantModel(
      variantId: variantId,
      name: name ?? this.name,
      price: price ?? this.price,
      offerPrice: offerPrice ?? this.offerPrice,
      stockQty: stockQty == _sentinel ? this.stockQty : stockQty as int?,
      sku: sku == _sentinel ? this.sku : sku as String?,
      attributes: attributes ?? this.attributes,
    );
  }

  static const Object _sentinel = Object();

  static String newId() =>
      FirebaseFirestore.instance.collection('_').doc().id;
}
