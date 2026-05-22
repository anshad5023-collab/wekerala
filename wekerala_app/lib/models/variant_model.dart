import 'package:cloud_firestore/cloud_firestore.dart';

class VariantModel {
  final String variantId;
  final String name;
  final double price;
  final double offerPrice;

  const VariantModel({
    required this.variantId,
    required this.name,
    required this.price,
    this.offerPrice = 0,
  });

  factory VariantModel.fromMap(Map<String, dynamic> m) {
    return VariantModel(
      variantId: m['variantId'] as String? ?? '',
      name: m['name'] as String? ?? '',
      price: (m['price'] as num?)?.toDouble() ?? 0,
      offerPrice: (m['offerPrice'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'variantId': variantId,
        'name': name,
        'price': price,
        'offerPrice': offerPrice,
      };

  VariantModel copyWith({String? name, double? price, double? offerPrice}) {
    return VariantModel(
      variantId: variantId,
      name: name ?? this.name,
      price: price ?? this.price,
      offerPrice: offerPrice ?? this.offerPrice,
    );
  }

  static String newId() =>
      FirebaseFirestore.instance.collection('_').doc().id;
}
