import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bill_model.dart';
import '../models/customer_model.dart';
import '../models/product_model.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class BillingState {
  final List<BillItemModel> cartItems;
  final double discountAmount;
  final bool isLoading;

  const BillingState({
    this.cartItems = const [],
    this.discountAmount = 0,
    this.isLoading = false,
  });

  double get subtotal =>
      cartItems.fold(0.0, (acc, item) => acc + item.subtotal);

  double get total => subtotal - discountAmount;

  /// GST breakdown grouped by rate.
  /// Each key is the GST rate (e.g. 5, 12, 18) and the value contains
  /// taxableAmount, cgst, and sgst for that rate slab.
  Map<int, Map<String, double>> get gstBreakdown {
    final result = <int, Map<String, double>>{};
    // Apply discount proportionally across items so GST is on net amount
    final discountRatio =
        subtotal > 0 ? (discountAmount / subtotal).clamp(0.0, 1.0) : 0.0;
    for (final item in cartItems) {
      if (item.gstRate <= 0) continue;
      final rate = item.gstRate;
      final effectiveSubtotal = item.subtotal * (1 - discountRatio);
      final taxable = item.priceIncludesGst
          ? effectiveSubtotal / (1 + rate / 100)
          : effectiveSubtotal;
      final cgst = taxable * (rate / 200);
      final sgst = taxable * (rate / 200);
      if (result.containsKey(rate)) {
        result[rate]!['taxableAmount'] =
            result[rate]!['taxableAmount']! + taxable;
        result[rate]!['cgst'] = result[rate]!['cgst']! + cgst;
        result[rate]!['sgst'] = result[rate]!['sgst']! + sgst;
      } else {
        result[rate] = {
          'taxableAmount': taxable,
          'cgst': cgst,
          'sgst': sgst,
        };
      }
    }
    return result;
  }

  double get totalTax {
    final bd = gstBreakdown;
    if (bd.isEmpty) return 0.0;
    return bd.values.fold(
        0.0, (acc, e) => acc + e['cgst']! + e['sgst']!);
  }

  BillingState copyWith({
    List<BillItemModel>? cartItems,
    double? discountAmount,
    bool? isLoading,
  }) {
    return BillingState(
      cartItems: cartItems ?? this.cartItems,
      discountAmount: discountAmount ?? this.discountAmount,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class BillingNotifier extends Notifier<BillingState> {
  @override
  BillingState build() => const BillingState();

  /// Add one unit of [product] to the cart. If already present, increment qty.
  void addItem(ProductModel product) {
    final items = List<BillItemModel>.from(state.cartItems);
    final idx = items.indexWhere((i) => i.productId == product.productId);

    final effectivePrice =
        product.offerPrice > 0 ? product.offerPrice : product.price;

    if (idx >= 0) {
      final existing = items[idx];
      final newQty = existing.qty + 1;
      items[idx] = existing.copyWith(
        qty: newQty,
        subtotal: newQty * existing.price,
      );
    } else {
      items.add(BillItemModel(
        productId: product.productId,
        productName: product.nameEn,
        qty: 1,
        unit: product.unit,
        price: effectivePrice,
        subtotal: effectivePrice,
        gstRate: product.gstRate,
        hsnCode: product.hsnCode,
        priceIncludesGst: product.priceIncludesGst,
      ));
    }

    state = state.copyWith(cartItems: items);
  }

  /// Remove an item from the cart by [productId].
  void removeItem(String productId) {
    state = state.copyWith(
      cartItems: state.cartItems
          .where((i) => i.productId != productId)
          .toList(),
    );
  }

  /// Update the quantity of a cart item. Removes it if [qty] <= 0.
  void updateQty(String productId, double qty) {
    if (qty <= 0) {
      removeItem(productId);
      return;
    }

    final items = List<BillItemModel>.from(state.cartItems);
    final idx = items.indexWhere((i) => i.productId == productId);
    if (idx < 0) return;

    final item = items[idx];
    items[idx] = item.copyWith(
      qty: qty,
      subtotal: qty * item.price,
    );

    state = state.copyWith(cartItems: items);
  }

  /// Set a flat discount amount on the current cart.
  void setDiscount(double amount) {
    state = state.copyWith(discountAmount: amount < 0 ? 0 : amount);
  }

  /// Reset the cart to empty.
  void clearCart() {
    state = const BillingState();
  }

  /// Persist the bill to Firestore and return the saved [BillModel].
  Future<BillModel> saveBill({
    required String shopId,
    required String paymentMethod,
    String customerName = '',
    String customerPhone = '',
    String? gstinSnapshot,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final db = FirebaseFirestore.instance;
      final ref = db.collection('shops').doc(shopId).collection('bills').doc();

      // Compute GST breakdown from cart state
      final breakdown = state.gstBreakdown;
      final tax = state.totalTax;
      // Convert int keys to string for Firestore storage
      final firestoreBreakdown = breakdown.map(
        (k, v) => MapEntry(k.toString(), v),
      );

      final now = DateTime.now();
      final bill = BillModel(
        billId: ref.id,
        shopId: shopId,
        items: List.unmodifiable(state.cartItems),
        totalAmount: state.subtotal,
        discountAmount: state.discountAmount,
        finalAmount: state.total,
        paymentMethod: paymentMethod,
        customerName: customerName,
        customerPhone: customerPhone,
        isUdhar: paymentMethod == 'udhar',
        createdAt: now,
        gstBreakdown: firestoreBreakdown,
        totalTax: tax,
        gstinSnapshot: (gstinSnapshot != null && gstinSnapshot.isNotEmpty)
            ? gstinSnapshot
            : null,
      );

      await ref.set(bill.toFirestore());

      // Decrement stock for each item
      final batch = FirebaseFirestore.instance.batch();
      for (final item in state.cartItems) {
        if (item.productId.isNotEmpty) {
          final productRef = FirebaseFirestore.instance
              .collection('shops')
              .doc(shopId)
              .collection('products')
              .doc(item.productId);
          batch.update(productRef, {
            'stockQty': FieldValue.increment(-item.qty),
          });
        }
      }
      await batch.commit();

      // Upsert customer record for any bill that has a phone number
      if (bill.customerPhone.isNotEmpty && bill.customerName.isNotEmpty) {
        unawaited(CustomerModel.upsertFromOrder(
          shopId: shopId,
          customerPhone: bill.customerPhone,
          customerName: bill.customerName,
          orderAmount: bill.finalAmount,
        ));

        // For udhar sales, also track the outstanding balance on the customer record
        if (bill.isUdhar) {
          unawaited(FirebaseFirestore.instance
              .collection('shops')
              .doc(shopId)
              .collection('customers')
              .doc(bill.customerPhone)
              .set({
            'udharBalance': FieldValue.increment(bill.finalAmount),
            'lastUdharDate': Timestamp.fromDate(bill.createdAt),
          }, SetOptions(merge: true)));
        }
      }

      state = state.copyWith(isLoading: false);
      return bill;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final billingProvider =
    NotifierProvider<BillingNotifier, BillingState>(BillingNotifier.new);

/// Stream of all bills created today for [shopId].
final dailyBillsStreamProvider =
    StreamProvider.family<List<BillModel>, String>((ref, shopId) {
  final startOfDay = DateTime.now().copyWith(
    hour: 0,
    minute: 0,
    second: 0,
    millisecond: 0,
    microsecond: 0,
  );

  return FirebaseFirestore.instance
      .collection('shops')
      .doc(shopId)
      .collection('bills')
      .where('createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(BillModel.fromFirestore).toList());
});

// ---------------------------------------------------------------------------
// Daily Sales Summary Provider
// ---------------------------------------------------------------------------

/// Provides a summary map for today: totalSales, billCount, cashTotal,
/// upiTotal, udharTotal — all as [double].
final dailySalesSummaryProvider =
    Provider.family<Map<String, double>, String>((ref, shopId) {
  final bills = ref.watch(dailyBillsStreamProvider(shopId));
  return bills.when(
    data: (list) {
      double total = 0, cash = 0, upi = 0, udhar = 0;
      for (final b in list) {
        total += b.finalAmount;
        if (b.paymentMethod == 'cash') {
          cash += b.finalAmount;
        } else if (b.paymentMethod == 'upi') {
          upi += b.finalAmount;
        } else if (b.isUdhar) {
          udhar += b.finalAmount;
        }
      }
      return {
        'totalSales': total,
        'billCount': list.length.toDouble(),
        'cashTotal': cash,
        'upiTotal': upi,
        'udharTotal': udhar,
      };
    },
    loading: () => {
      'totalSales': 0,
      'billCount': 0,
      'cashTotal': 0,
      'upiTotal': 0,
      'udharTotal': 0,
    },
    error: (_, __) => {
      'totalSales': 0,
      'billCount': 0,
      'cashTotal': 0,
      'upiTotal': 0,
      'udharTotal': 0,
    },
  );
});

// ---------------------------------------------------------------------------
// Bill History Provider (date-range filtered)
// ---------------------------------------------------------------------------

class BillDateRange {
  final DateTime start;
  final DateTime end;
  const BillDateRange(this.start, this.end);

  @override
  bool operator ==(Object other) =>
      other is BillDateRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// Stream of bills within [args.range] for [args.shopId], newest first.
final billHistoryProvider = StreamProvider.family<List<BillModel>,
    ({String shopId, BillDateRange range})>((ref, args) {
  return FirebaseFirestore.instance
      .collection('shops')
      .doc(args.shopId)
      .collection('bills')
      .where('createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(args.range.start))
      .where('createdAt',
          isLessThanOrEqualTo: Timestamp.fromDate(args.range.end))
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(BillModel.fromFirestore).toList());
});
