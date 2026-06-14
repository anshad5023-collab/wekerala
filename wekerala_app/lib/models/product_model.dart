import 'package:cloud_firestore/cloud_firestore.dart';
import 'variant_model.dart';

const kProductUnits = [
  'piece', 'kg', 'g', 'litre', 'ml', 'dozen', 'box', 'packet', 'bundle', 'set'
];

class ProductModel {
  final String productId;
  final String nameEn;
  final String nameMl;
  final String category;
  final double price;
  final double offerPrice;
  final String unit;
  final double minQty;
  final String imageUrl;
  final String imageSource; // 'auto'|'owner'|'placeholder'
  final bool isHidden;
  final bool isOutOfStock;
  final bool hasVariants;
  final List<VariantModel> variants;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int orderCount;
  final int? stockQty;           // null = not tracking stock
  final int lowStockThreshold;   // default 5
  final DateTime? expiryDate;    // null = no expiry tracking
  final int gstRate;
  final String? hsnCode;
  final bool priceIncludesGst;
  final String? barcode;
  final String? batchNumber;
  final String? searchAlias; // generic/alternate name (e.g. "Metformin" for "Glycomet Tab")
  final String? description; // shown on storefront product detail
  /// Shop-type-specific attributes (fabric, dosage, spice level, etc.)
  /// Keys are defined in kShopTypeProductSchema; values are always String.
  final Map<String, dynamic> attributes;

  const ProductModel({
    required this.productId,
    required this.nameEn,
    this.nameMl = '',
    required this.category,
    required this.price,
    this.offerPrice = 0,
    this.unit = 'piece',
    this.minQty = 0,
    this.imageUrl = '',
    this.imageSource = 'placeholder',
    this.isHidden = false,
    this.isOutOfStock = false,
    this.hasVariants = false,
    this.variants = const [],
    required this.createdAt,
    required this.updatedAt,
    this.orderCount = 0,
    this.stockQty,
    this.lowStockThreshold = 5,
    this.expiryDate,
    this.gstRate = 0,
    this.hsnCode,
    this.priceIncludesGst = true,
    this.barcode,
    this.batchNumber,
    this.searchAlias,
    this.description,
    this.attributes = const {},
  });

  bool get isLowStock => stockQty != null && stockQty! <= lowStockThreshold;

  bool get isExpiringSoon {
    if (expiryDate == null) return false;
    return expiryDate!.isBefore(DateTime.now().add(const Duration(days: 2)));
  }

  bool get isExpired {
    if (expiryDate == null) return false;
    return expiryDate!.isBefore(DateTime.now());
  }

  factory ProductModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ProductModel(
      productId: d['productId'] as String? ?? doc.id,
      nameEn: d['nameEn'] as String? ?? '',
      nameMl: d['nameMl'] as String? ?? '',
      category: d['category'] as String? ?? '',
      price: (d['price'] as num?)?.toDouble() ?? 0,
      offerPrice: (d['offerPrice'] as num?)?.toDouble() ?? 0,
      unit: d['unit'] as String? ?? 'piece',
      minQty: (d['minQty'] as num?)?.toDouble() ?? 0,
      imageUrl: d['imageUrl'] as String? ?? '',
      imageSource: d['imageSource'] as String? ?? 'placeholder',
      isHidden: d['isHidden'] as bool? ?? false,
      isOutOfStock: d['isOutOfStock'] as bool? ?? false,
      hasVariants: d['hasVariants'] as bool? ?? false,
      variants: (d['variants'] as List?)
              ?.map((v) => VariantModel.fromMap(v as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      orderCount: (d['orderCount'] as num?)?.toInt() ?? 0,
      stockQty: (d['stockQty'] as num?)?.toInt(),
      lowStockThreshold: (d['lowStockThreshold'] as num?)?.toInt() ?? 5,
      expiryDate: (d['expiryDate'] as Timestamp?)?.toDate(),
      gstRate: (d['gstRate'] as num?)?.toInt() ?? 0,
      hsnCode: d['hsnCode'] as String?,
      priceIncludesGst: (d['priceIncludesGst'] as bool?) ?? true,
      barcode: d['barcode'] as String?,
      batchNumber: d['batchNumber'] as String?,
      searchAlias: d['searchAlias'] as String?,
      description: d['description'] as String?,
      attributes: (d['attributes'] as Map<String, dynamic>?) ?? {},
    );
  }

  Map<String, dynamic> toFirestore() {
    final m = <String, dynamic>{
      'productId': productId,
      'nameEn': nameEn,
      'nameMl': nameMl,
      'category': category,
      'price': price,
      'offerPrice': offerPrice,
      'unit': unit,
      'minQty': minQty,
      'imageUrl': imageUrl,
      'imageSource': imageSource,
      'isHidden': isHidden,
      'isOutOfStock': isOutOfStock,
      'hasVariants': hasVariants,
      'variants': variants.map((v) => v.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'orderCount': orderCount,
      'lowStockThreshold': lowStockThreshold,
      'gstRate': gstRate,
      'priceIncludesGst': priceIncludesGst,
    };
    if (stockQty != null) m['stockQty'] = stockQty;
    if (expiryDate != null) m['expiryDate'] = Timestamp.fromDate(expiryDate!);
    if (hsnCode != null) m['hsnCode'] = hsnCode;
    if (barcode != null) m['barcode'] = barcode;
    if (batchNumber != null) m['batchNumber'] = batchNumber;
    if (searchAlias != null && searchAlias!.isNotEmpty) m['searchAlias'] = searchAlias;
    if (description != null && description!.isNotEmpty) m['description'] = description;
    if (attributes.isNotEmpty) m['attributes'] = attributes;
    return m;
  }

  ProductModel copyWith({
    String? productId,
    String? nameEn,
    String? nameMl,
    String? category,
    double? price,
    double? offerPrice,
    String? unit,
    double? minQty,
    String? imageUrl,
    String? imageSource,
    bool? isHidden,
    bool? isOutOfStock,
    bool? hasVariants,
    List<VariantModel>? variants,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? orderCount,
    Object? stockQty = _sentinel,
    int? lowStockThreshold,
    Object? expiryDate = _sentinel,
    int? gstRate,
    Object? hsnCode = _sentinel,
    bool? priceIncludesGst,
    Object? barcode = _sentinel,
    Object? batchNumber = _sentinel,
    Object? searchAlias = _sentinel,
    Object? description = _sentinel,
    Map<String, dynamic>? attributes,
  }) {
    return ProductModel(
      productId: productId ?? this.productId,
      nameEn: nameEn ?? this.nameEn,
      nameMl: nameMl ?? this.nameMl,
      category: category ?? this.category,
      price: price ?? this.price,
      offerPrice: offerPrice ?? this.offerPrice,
      unit: unit ?? this.unit,
      minQty: minQty ?? this.minQty,
      imageUrl: imageUrl ?? this.imageUrl,
      imageSource: imageSource ?? this.imageSource,
      isHidden: isHidden ?? this.isHidden,
      isOutOfStock: isOutOfStock ?? this.isOutOfStock,
      hasVariants: hasVariants ?? this.hasVariants,
      variants: variants ?? this.variants,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      orderCount: orderCount ?? this.orderCount,
      stockQty: stockQty == _sentinel ? this.stockQty : stockQty as int?,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      expiryDate: expiryDate == _sentinel ? this.expiryDate : expiryDate as DateTime?,
      gstRate: gstRate ?? this.gstRate,
      hsnCode: hsnCode == _sentinel ? this.hsnCode : hsnCode as String?,
      priceIncludesGst: priceIncludesGst ?? this.priceIncludesGst,
      barcode: barcode == _sentinel ? this.barcode : barcode as String?,
      batchNumber: batchNumber == _sentinel ? this.batchNumber : batchNumber as String?,
      searchAlias: searchAlias == _sentinel ? this.searchAlias : searchAlias as String?,
      description: description == _sentinel ? this.description : description as String?,
      attributes: attributes ?? this.attributes,
    );
  }
}

// Sentinel for nullable copyWith fields
const Object _sentinel = Object();
