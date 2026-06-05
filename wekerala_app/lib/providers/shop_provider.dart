import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/shop_model.dart';
import '../core/services/storage_service.dart';
import '../core/utils/slug_generator.dart';

const Map<String, List<String>> kShopCategories = {
  'Grocery': ['Vegetables', 'Fruits', 'Dairy & Eggs', 'Grocery Staples', 'Beverages', 'Snacks', 'Cleaning'],
  'Vegetable & Fruit': ['Vegetables', 'Fruits', 'Herbs & Leaves', 'Seasonal Items'],
  'Bakery': ['Breads', 'Cakes & Pastries', 'Biscuits & Cookies', 'Savoury Items', 'Drinks'],
  'Pharmacy': ['Medicines', 'Personal Care', 'Baby Care', 'Health Devices', 'Vitamins'],
  'Meat & Fish': ['Chicken', 'Beef', 'Mutton', 'Fish', 'Prawns & Seafood', 'Eggs'],
  'Stationery': ['Pens & Pencils', 'Notebooks', 'Art Supplies', 'Office Items', 'School Items'],
  'Textile': ["Men's Wear", "Women's Wear", "Kids' Wear", 'Accessories', 'Fabrics'],
  'Electronics': ['Mobile Accessories', 'Cables & Chargers', 'Headphones', 'Smart Devices'],
  'Hotel / Restaurant': ['Meals', 'Snacks', 'Beverages', 'Desserts', 'Special Items'],
  'General Store': ['Grocery', 'Stationery', 'Household', 'Personal Care', 'Miscellaneous'],
  'Fancy Store': ['Cosmetics', 'Hair Accessories', 'Artificial Jewelry', 'Toys & Games', 'Gift Items', 'Party Supplies', 'Personal Care'],
};

class OnboardingState {
  final String shopId;
  final String shopType;
  final List<String> categories;
  final String shopName;
  final String shopNameMl;
  final String ownerWhatsApp;
  final String address;
  final String district;
  final String bannerLocalPath;
  final String bannerUrl;
  final String deliveryType;
  final double minOrderValue;
  final List<String> paymentMethods;
  final String upiId;
  final bool isLoading;
  final String? error;
  final String? createdShopId;
  final String? shopSlug;

  const OnboardingState({
    required this.shopId,
    this.shopType = '',
    this.categories = const [],
    this.shopName = '',
    this.shopNameMl = '',
    this.ownerWhatsApp = '',
    this.address = '',
    this.district = '',
    this.bannerLocalPath = '',
    this.bannerUrl = '',
    this.deliveryType = 'both',
    this.minOrderValue = 0,
    this.paymentMethods = const ['cash'],
    this.upiId = '',
    this.isLoading = false,
    this.error,
    this.createdShopId,
    this.shopSlug,
  });

  OnboardingState copyWith({
    String? shopType,
    List<String>? categories,
    String? shopName,
    String? shopNameMl,
    String? ownerWhatsApp,
    String? address,
    String? district,
    String? bannerLocalPath,
    String? bannerUrl,
    String? deliveryType,
    double? minOrderValue,
    List<String>? paymentMethods,
    String? upiId,
    bool? isLoading,
    String? error,
    bool clearError = false,
    String? createdShopId,
    String? shopSlug,
  }) {
    return OnboardingState(
      shopId: shopId,
      shopType: shopType ?? this.shopType,
      categories: categories ?? this.categories,
      shopName: shopName ?? this.shopName,
      shopNameMl: shopNameMl ?? this.shopNameMl,
      ownerWhatsApp: ownerWhatsApp ?? this.ownerWhatsApp,
      address: address ?? this.address,
      district: district ?? this.district,
      bannerLocalPath: bannerLocalPath ?? this.bannerLocalPath,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      deliveryType: deliveryType ?? this.deliveryType,
      minOrderValue: minOrderValue ?? this.minOrderValue,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      upiId: upiId ?? this.upiId,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      createdShopId: createdShopId ?? this.createdShopId,
      shopSlug: shopSlug ?? this.shopSlug,
    );
  }
}

class OnboardingNotifier extends Notifier<OnboardingState> {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  @override
  OnboardingState build() {
    final shopId = _db.collection('shops').doc().id;
    return OnboardingState(shopId: shopId);
  }

  void setShopType(String type) {
    state = state.copyWith(
      shopType: type,
      categories: kShopCategories[type] ?? [],
    );
  }

  void setDetails({
    required String shopName,
    required String shopNameMl,
    required String ownerWhatsApp,
    required String address,
    required String district,
  }) {
    state = state.copyWith(
      shopName: shopName,
      shopNameMl: shopNameMl,
      ownerWhatsApp: ownerWhatsApp,
      address: address,
      district: district,
    );
  }

  Future<bool> uploadBanner(File file) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final url = await StorageService.uploadBanner(state.shopId, file);
      state = state.copyWith(
        isLoading: false,
        bannerLocalPath: file.path,
        bannerUrl: url,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  void clearBanner() {
    state = state.copyWith(bannerLocalPath: '', bannerUrl: '');
  }

  void setDelivery({required String deliveryType, required double minOrderValue}) {
    state = state.copyWith(
      deliveryType: deliveryType,
      minOrderValue: minOrderValue,
    );
  }

  void setPayment({required List<String> paymentMethods, required String upiId}) {
    state = state.copyWith(paymentMethods: paymentMethods, upiId: upiId);
  }

  Future<bool> createShop() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final slug = await SlugGenerator.findUnique(state.shopName);
      final now = DateTime.now();

      final shop = ShopModel(
        shopId: state.shopId,
        ownerId: user.uid,
        shopName: state.shopName,
        shopNameMl: state.shopNameMl,
        shopSlug: slug,
        shopType: state.shopType,
        ownerPhone: user.phoneNumber?.replaceFirst('+91', '') ?? '',
        ownerWhatsApp: state.ownerWhatsApp,
        address: state.address,
        district: state.district,
        bannerImageUrl: state.bannerUrl,
        logoUrl: '',
        isOpen: true,
        isActive: true,
        linkActive: true,
        deliveryType: state.deliveryType,
        minOrderValue: state.minOrderValue,
        paymentMethods: state.paymentMethods,
        upiId: state.upiId,
        categories: state.categories,
        trialStartDate: now,
        trialEndDate: now.add(const Duration(days: 30)),
        subscriptionStatus: 'trial',
        createdAt: now,
        totalOrders: 0,
        fcmToken: '',
      );

      await _db.collection('shops').doc(state.shopId).set(shop.toFirestore());
      await _db.collection('users').doc(user.uid).set({
        'shopIds': FieldValue.arrayUnion([state.shopId]),
        'activeShopId': state.shopId,
      }, SetOptions(merge: true));

      state = state.copyWith(
        isLoading: false,
        createdShopId: state.shopId,
        shopSlug: slug,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingNotifier, OnboardingState>(OnboardingNotifier.new);

final shopStreamProvider = StreamProvider.family<ShopModel, String>((ref, shopId) {
  return FirebaseFirestore.instance
      .collection('shops')
      .doc(shopId)
      .snapshots()
      .map(ShopModel.fromFirestore);
});

final activeShopIdProvider = StreamProvider<String?>((ref) async* {
  final authStream = FirebaseAuth.instance.authStateChanges();
  await for (final user in authStream) {
    if (user == null) {
      yield null;
      continue;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final shopId = doc.data()?['activeShopId'] as String?;
      yield (shopId != null && shopId.isNotEmpty) ? shopId : null;
    } catch (_) {
      yield null;
    }
  }
});
