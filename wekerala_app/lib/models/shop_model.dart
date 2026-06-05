import 'package:cloud_firestore/cloud_firestore.dart';

class ShopModel {
  final String shopId;
  final String ownerId;
  final String shopName;
  final String shopNameMl;
  final String shopSlug;
  final String shopType;
  final String ownerPhone;
  final String ownerWhatsApp;
  final String address;
  final String district;
  final String bannerImageUrl;
  final String logoUrl;
  final bool isOpen;
  final bool isActive;
  final bool linkActive;
  final String deliveryType;
  final double minOrderValue;
  final List<String> paymentMethods;
  final String upiId;
  final List<String> categories;
  final DateTime trialStartDate;
  final DateTime trialEndDate;
  final String subscriptionStatus;
  final DateTime? lastPaymentDate;
  final DateTime createdAt;
  final int totalOrders;
  final String fcmToken;
  // Phase 9.3 / 9.7 — website appearance fields
  final String? themeColor;
  final String? deliveryTimeEstimate;
  final String? promotionalBanner;
  final String? announcementText;
  final String? productLayout;
  // Phase 11 — external website
  final String? externalUrl;
  // Phase 15.2 — business directory fields
  final List<String> serviceTypes;
  final List<String> photos;
  final String? workingHours;
  final String? priceRange;
  final String? about;
  final double avgRating;
  final int ratingCount;
  final bool isVerified;
  final bool isFeatured;
  final String? gstin;
  final String? gstBusinessName;
  final bool autoSendWhatsappReceipt;
  // ONDC integration — seller / provider ID registered on eSamudaay or Mystore
  final String? ondcSellerId;
  // AI chat widget settings
  final Map<String, dynamic> aiSettings;
  // Meta WhatsApp Cloud API — phone number ID for this shop's WhatsApp number
  final String whatsappPhoneNumberId;
  // Per-shop WhatsApp notification preferences (toggles + udharReminderDays)
  final Map<String, dynamic> whatsappSettings;
  // Loyalty program configuration
  final Map<String, dynamic> loyaltySettings;
  // Google Maps link for pickup customers
  final String? googleMapsLink;
  // Subscription plan: 'trial' | 'lite' | 'standard' | 'pro' | 'chain'
  final String plan;

  /// Returns true if this shop has WhatsApp AI access (Standard and above, or on trial).
  bool get hasWhatsAppAccess =>
      plan == 'trial' || plan == 'standard' || plan == 'pro' || plan == 'chain';

  /// Monthly WhatsApp utility conversation limit (0 = none included).
  int get waUtilityLimit => switch (plan) {
        'standard' => 200,
        'pro' => 600,
        'chain' => 2000,
        _ => 0,
      };

  /// Monthly WhatsApp marketing/broadcast limit (0 = none included).
  int get waMarketingLimit => switch (plan) {
        'standard' => 30,
        'pro' => 100,
        'chain' => 300,
        _ => 0,
      };

  const ShopModel({
    required this.shopId,
    required this.ownerId,
    required this.shopName,
    required this.shopNameMl,
    required this.shopSlug,
    required this.shopType,
    required this.ownerPhone,
    required this.ownerWhatsApp,
    required this.address,
    required this.district,
    required this.bannerImageUrl,
    required this.logoUrl,
    required this.isOpen,
    required this.isActive,
    required this.linkActive,
    required this.deliveryType,
    required this.minOrderValue,
    required this.paymentMethods,
    required this.upiId,
    required this.categories,
    required this.trialStartDate,
    required this.trialEndDate,
    required this.subscriptionStatus,
    this.lastPaymentDate,
    required this.createdAt,
    required this.totalOrders,
    required this.fcmToken,
    this.themeColor,
    this.deliveryTimeEstimate,
    this.promotionalBanner,
    this.announcementText,
    this.productLayout,
    this.externalUrl,
    this.serviceTypes = const [],
    this.photos = const [],
    this.workingHours,
    this.priceRange,
    this.about,
    this.avgRating = 0.0,
    this.ratingCount = 0,
    this.isVerified = false,
    this.isFeatured = false,
    this.gstin,
    this.gstBusinessName,
    this.autoSendWhatsappReceipt = false,
    this.ondcSellerId,
    this.aiSettings = const {},
    this.whatsappPhoneNumberId = '',
    this.whatsappSettings = const {},
    this.loyaltySettings = const {},
    this.googleMapsLink,
    this.plan = 'trial',
  });

  static DateTime _parseDate(dynamic v, DateTime fallback) {
    if (v is Timestamp) return v.toDate();
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v) ?? fallback;
    return fallback;
  }

  factory ShopModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ShopModel(
      shopId: d['shopId'] as String? ?? doc.id,
      ownerId: d['ownerId'] as String? ?? '',
      shopName: d['shopName'] as String? ?? '',
      shopNameMl: d['shopNameMl'] as String? ?? '',
      shopSlug: d['shopSlug'] as String? ?? '',
      shopType: d['shopType'] as String? ?? '',
      ownerPhone: d['ownerPhone'] as String? ?? '',
      ownerWhatsApp: d['ownerWhatsApp'] as String? ?? '',
      address: d['address'] as String? ?? '',
      district: d['district'] as String? ?? '',
      bannerImageUrl: d['bannerImageUrl'] as String? ?? '',
      logoUrl: d['logoUrl'] as String? ?? '',
      isOpen: d['isOpen'] as bool? ?? true,
      isActive: d['isActive'] as bool? ?? true,
      linkActive: d['linkActive'] as bool? ?? true,
      deliveryType: d['deliveryType'] as String? ?? 'both',
      minOrderValue: (d['minOrderValue'] as num?)?.toDouble() ?? 0,
      paymentMethods: List<String>.from(d['paymentMethods'] as List? ?? ['cash']),
      upiId: d['upiId'] as String? ?? '',
      categories: List<String>.from(d['categories'] as List? ?? []),
      trialStartDate: _parseDate(d['trialStartDate'], DateTime.now()),
      trialEndDate: _parseDate(d['trialEndDate'], DateTime.now().add(const Duration(days: 30))),
      subscriptionStatus: d['subscriptionStatus'] as String? ?? 'trial',
      lastPaymentDate: d['lastPaymentDate'] != null ? _parseDate(d['lastPaymentDate'], DateTime.now()) : null,
      createdAt: _parseDate(d['createdAt'], DateTime.now()),
      totalOrders: d['totalOrders'] as int? ?? 0,
      fcmToken: d['fcmToken'] as String? ?? '',
      themeColor: d['themeColor'] as String?,
      deliveryTimeEstimate: d['deliveryTimeEstimate'] as String?,
      promotionalBanner: d['promotionalBanner'] as String?,
      announcementText: d['announcementText'] as String?,
      productLayout: d['productLayout'] as String?,
      externalUrl: d['externalUrl'] as String?,
      serviceTypes: List<String>.from(d['serviceTypes'] as List? ?? []),
      photos: List<String>.from(d['photos'] as List? ?? []),
      workingHours: d['workingHours'] as String?,
      priceRange: d['priceRange'] as String?,
      about: d['about'] as String?,
      avgRating: (d['avgRating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: d['ratingCount'] as int? ?? 0,
      isVerified: d['isVerified'] as bool? ?? false,
      isFeatured: d['isFeatured'] as bool? ?? false,
      gstin: d['gstin'] as String?,
      gstBusinessName: d['gstBusinessName'] as String?,
      autoSendWhatsappReceipt: (d['autoSendWhatsappReceipt'] as bool?) ?? false,
      ondcSellerId: d['ondcSellerId'] as String?,
      aiSettings: Map<String, dynamic>.from(d['aiSettings'] as Map? ?? {}),
      whatsappPhoneNumberId: d['whatsappPhoneNumberId'] as String? ?? '',
      whatsappSettings: Map<String, dynamic>.from(d['whatsappSettings'] as Map? ?? {}),
      loyaltySettings: Map<String, dynamic>.from(d['loyaltySettings'] as Map? ?? {}),
      googleMapsLink: d['googleMapsLink'] as String?,
      plan: d['plan'] as String? ?? 'trial',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'shopId': shopId,
      'ownerId': ownerId,
      'shopName': shopName,
      'shopNameMl': shopNameMl,
      'shopSlug': shopSlug,
      'shopType': shopType,
      'ownerPhone': ownerPhone,
      'ownerWhatsApp': ownerWhatsApp,
      'address': address,
      'district': district,
      'bannerImageUrl': bannerImageUrl,
      'logoUrl': logoUrl,
      'isOpen': isOpen,
      'isActive': isActive,
      'linkActive': linkActive,
      'deliveryType': deliveryType,
      'minOrderValue': minOrderValue,
      'paymentMethods': paymentMethods,
      'upiId': upiId,
      'categories': categories,
      'trialStartDate': Timestamp.fromDate(trialStartDate),
      'trialEndDate': Timestamp.fromDate(trialEndDate),
      'subscriptionStatus': subscriptionStatus,
      'lastPaymentDate':
          lastPaymentDate != null ? Timestamp.fromDate(lastPaymentDate!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'totalOrders': totalOrders,
      'fcmToken': fcmToken,
      if (themeColor != null) 'themeColor': themeColor,
      if (deliveryTimeEstimate != null) 'deliveryTimeEstimate': deliveryTimeEstimate,
      if (promotionalBanner != null) 'promotionalBanner': promotionalBanner,
      if (announcementText != null) 'announcementText': announcementText,
      if (productLayout != null) 'productLayout': productLayout,
      if (externalUrl != null) 'externalUrl': externalUrl,
      if (serviceTypes.isNotEmpty) 'serviceTypes': serviceTypes,
      if (photos.isNotEmpty) 'photos': photos,
      if (workingHours != null) 'workingHours': workingHours,
      if (priceRange != null) 'priceRange': priceRange,
      if (about != null) 'about': about,
      'avgRating': avgRating,
      'ratingCount': ratingCount,
      'isVerified': isVerified,
      'isFeatured': isFeatured,
      if (gstin != null) 'gstin': gstin,
      if (gstBusinessName != null) 'gstBusinessName': gstBusinessName,
      'autoSendWhatsappReceipt': autoSendWhatsappReceipt,
      if (ondcSellerId != null) 'ondcSellerId': ondcSellerId,
      'aiSettings': aiSettings,
      if (whatsappPhoneNumberId.isNotEmpty) 'whatsappPhoneNumberId': whatsappPhoneNumberId,
      if (whatsappSettings.isNotEmpty) 'whatsappSettings': whatsappSettings,
      'loyaltySettings': loyaltySettings,
      if (googleMapsLink != null && googleMapsLink!.isNotEmpty) 'googleMapsLink': googleMapsLink,
      'plan': plan,
    };
  }

  ShopModel copyWith({
    bool? isOpen,
    String? subscriptionStatus,
    String? fcmToken,
    int? totalOrders,
    String? themeColor,
    String? deliveryTimeEstimate,
    String? promotionalBanner,
    String? announcementText,
    String? productLayout,
    List<String>? serviceTypes,
    List<String>? photos,
    String? workingHours,
    String? priceRange,
    String? about,
    double? avgRating,
    int? ratingCount,
    bool? isVerified,
    bool? isFeatured,
    Object? gstin = _shopSentinel,
    Object? gstBusinessName = _shopSentinel,
    bool? autoSendWhatsappReceipt,
    Object? ondcSellerId = _shopSentinel,
    Map<String, dynamic>? aiSettings,
    String? whatsappPhoneNumberId,
    Map<String, dynamic>? whatsappSettings,
    Map<String, dynamic>? loyaltySettings,
    Object? googleMapsLink = _shopSentinel,
    String? plan,
  }) {
    return ShopModel(
      shopId: shopId,
      ownerId: ownerId,
      shopName: shopName,
      shopNameMl: shopNameMl,
      shopSlug: shopSlug,
      shopType: shopType,
      ownerPhone: ownerPhone,
      ownerWhatsApp: ownerWhatsApp,
      address: address,
      district: district,
      bannerImageUrl: bannerImageUrl,
      logoUrl: logoUrl,
      isOpen: isOpen ?? this.isOpen,
      isActive: isActive,
      linkActive: linkActive,
      deliveryType: deliveryType,
      minOrderValue: minOrderValue,
      paymentMethods: paymentMethods,
      upiId: upiId,
      categories: categories,
      trialStartDate: trialStartDate,
      trialEndDate: trialEndDate,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      lastPaymentDate: lastPaymentDate,
      createdAt: createdAt,
      totalOrders: totalOrders ?? this.totalOrders,
      fcmToken: fcmToken ?? this.fcmToken,
      themeColor: themeColor ?? this.themeColor,
      deliveryTimeEstimate: deliveryTimeEstimate ?? this.deliveryTimeEstimate,
      promotionalBanner: promotionalBanner ?? this.promotionalBanner,
      announcementText: announcementText ?? this.announcementText,
      productLayout: productLayout ?? this.productLayout,
      serviceTypes: serviceTypes ?? this.serviceTypes,
      photos: photos ?? this.photos,
      workingHours: workingHours ?? this.workingHours,
      priceRange: priceRange ?? this.priceRange,
      about: about ?? this.about,
      avgRating: avgRating ?? this.avgRating,
      ratingCount: ratingCount ?? this.ratingCount,
      isVerified: isVerified ?? this.isVerified,
      isFeatured: isFeatured ?? this.isFeatured,
      gstin: gstin == _shopSentinel ? this.gstin : gstin as String?,
      gstBusinessName: gstBusinessName == _shopSentinel ? this.gstBusinessName : gstBusinessName as String?,
      autoSendWhatsappReceipt: autoSendWhatsappReceipt ?? this.autoSendWhatsappReceipt,
      ondcSellerId: ondcSellerId == _shopSentinel ? this.ondcSellerId : ondcSellerId as String?,
      aiSettings: aiSettings ?? this.aiSettings,
      whatsappPhoneNumberId: whatsappPhoneNumberId ?? this.whatsappPhoneNumberId,
      whatsappSettings: whatsappSettings ?? this.whatsappSettings,
      loyaltySettings: loyaltySettings ?? this.loyaltySettings,
      googleMapsLink: googleMapsLink == _shopSentinel ? this.googleMapsLink : googleMapsLink as String?,
      plan: plan ?? this.plan,
    );
  }
}

const Object _shopSentinel = Object();
