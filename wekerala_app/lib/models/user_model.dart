import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String userId;
  final String phone;
  final String name;
  final String language;
  final DateTime createdAt;
  final List<String> shopIds;
  final String activeShopId;
  // Phase 11 fields
  final String googleUid;
  final String email;
  final String role; // 'owner' | 'customer'
  final List<String> businessTypes;
  final bool tcAccepted;
  final bool trialUsed;

  const UserModel({
    required this.userId,
    required this.phone,
    required this.name,
    required this.language,
    required this.createdAt,
    required this.shopIds,
    required this.activeShopId,
    this.googleUid = '',
    this.email = '',
    this.role = 'owner',
    this.businessTypes = const [],
    this.tcAccepted = false,
    this.trialUsed = false,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      userId: data['userId'] as String? ?? doc.id,
      phone: data['phone'] as String? ?? '',
      name: data['name'] as String? ?? '',
      language: data['language'] as String? ?? 'en',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      shopIds: List<String>.from(data['shopIds'] as List? ?? []),
      activeShopId: data['activeShopId'] as String? ?? '',
      googleUid: data['googleUid'] as String? ?? '',
      email: data['email'] as String? ?? '',
      role: data['role'] as String? ?? 'owner',
      businessTypes: List<String>.from(data['businessTypes'] as List? ?? []),
      tcAccepted: data['tcAccepted'] as bool? ?? false,
      trialUsed: data['trialUsed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'phone': phone,
      'name': name,
      'language': language,
      'createdAt': Timestamp.fromDate(createdAt),
      'shopIds': shopIds,
      'activeShopId': activeShopId,
      'googleUid': googleUid,
      'email': email,
      'role': role,
      'businessTypes': businessTypes,
      'tcAccepted': tcAccepted,
      'trialUsed': trialUsed,
    };
  }

  UserModel copyWith({
    String? userId,
    String? phone,
    String? name,
    String? language,
    DateTime? createdAt,
    List<String>? shopIds,
    String? activeShopId,
    String? googleUid,
    String? email,
    String? role,
    List<String>? businessTypes,
    bool? tcAccepted,
    bool? trialUsed,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      language: language ?? this.language,
      createdAt: createdAt ?? this.createdAt,
      shopIds: shopIds ?? this.shopIds,
      activeShopId: activeShopId ?? this.activeShopId,
      googleUid: googleUid ?? this.googleUid,
      email: email ?? this.email,
      role: role ?? this.role,
      businessTypes: businessTypes ?? this.businessTypes,
      tcAccepted: tcAccepted ?? this.tcAccepted,
      trialUsed: trialUsed ?? this.trialUsed,
    );
  }
}
