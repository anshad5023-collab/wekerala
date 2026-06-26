import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/bill_model.dart';
import '../models/variant_model.dart';
import '../models/customer_model.dart';
import '../models/product_model.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// A bill the owner set aside ("parked") to serve another customer, then
/// resumes later — e.g. the customer forgot their wallet.
class ParkedBill {
  final String id;
  final String label;
  final List<BillItemModel> items;
  final double discount;
  final DateTime createdAt;

  const ParkedBill({
    required this.id,
    required this.label,
    required this.items,
    required this.discount,
    required this.createdAt,
  });

  double get total => items.fold(0.0, (a, i) => a + i.subtotal) - discount;

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'items': items.map((i) => i.toMap()).toList(),
        'discount': discount,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ParkedBill.fromMap(Map<String, dynamic> m) => ParkedBill(
        id: m['id'] as String,
        label: (m['label'] as String?) ?? '',
        items: ((m['items'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(BillItemModel.fromMap)
            .toList(),
        discount: (m['discount'] as num?)?.toDouble() ?? 0,
        createdAt:
            DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
      );
}

class BillingState {
  final List<BillItemModel> cartItems;
  final double discountAmount;
  final double flashSalePercent; // 0 = no flash sale
  final String flashSaleName;
  final String flashSaleCategory; // '' = applies to all products
  final bool isLoading;
  final String preNote; // pre-filled note (e.g. 'Table: 4' from KOT)
  final bool roundOffEnabled; // round the final total to the nearest rupee
  final List<ParkedBill> parkedBills; // bills set aside to resume later

  const BillingState({
    this.cartItems = const [],
    this.discountAmount = 0,
    this.flashSalePercent = 0,
    this.flashSaleName = '',
    this.flashSaleCategory = '',
    this.isLoading = false,
    this.preNote = '',
    this.roundOffEnabled = false,
    this.parkedBills = const [],
  });

  double get subtotal =>
      cartItems.fold(0.0, (acc, item) => acc + item.subtotal);

  // If category is set, discount applies only to items in that category
  double get flashSaleDiscount {
    if (flashSalePercent == 0) return 0;
    if (flashSaleCategory.isEmpty) return subtotal * (flashSalePercent / 100);
    final categorySubtotal = cartItems
        .where((item) => item.category == flashSaleCategory)
        .fold(0.0, (acc, item) => acc + item.subtotal);
    return categorySubtotal * (flashSalePercent / 100);
  }

  // GST that must be ADDED on top for tax-EXCLUSIVE items (tax-inclusive items
  // already carry GST inside their price, so they add nothing here). Discount is
  // spread proportionally, mirroring [gstBreakdown]. For an all-inclusive cart
  // — the default — this is always 0, so it changes nothing.
  double get addedGst {
    final effectiveDiscount = discountAmount + flashSaleDiscount;
    final ratio =
        subtotal > 0 ? (effectiveDiscount / subtotal).clamp(0.0, 1.0) : 0.0;
    double tax = 0;
    for (final item in cartItems) {
      if (item.gstRate <= 0 || item.priceIncludesGst) continue;
      final net = item.subtotal * (1 - ratio);
      tax += net * (item.gstRate / 100);
    }
    return tax;
  }

  // Never allow a negative bill. A manual discount (or flash sale) larger than
  // the cart must floor at ₹0 — otherwise finalAmount goes negative, which would
  // corrupt day revenue and, for udhar sales, REDUCE the customer's debt.
  double get rawTotal {
    final t = subtotal - flashSaleDiscount - discountAmount + addedGst;
    return t < 0 ? 0.0 : t;
  }

  // Final payable. When round-off is on, snap to the nearest whole rupee so the
  // owner can collect a clean cash amount (no coins).
  double get total {
    if (!roundOffEnabled) return rawTotal;
    return rawTotal.roundToDouble();
  }

  // Signed round-off adjustment (+ owner collects a little more, − a little
  // less). Shown as a line on the cart + receipt so the bill always reconciles.
  double get roundOffAmount => roundOffEnabled ? total - rawTotal : 0.0;

  // Effective discount can't exceed the subtotal (mirrors the clamped total).
  double get totalDiscountAmount {
    final d = flashSaleDiscount + discountAmount;
    return d > subtotal ? subtotal : d;
  }

  /// GST breakdown grouped by rate.
  /// Each key is the GST rate (e.g. 5, 12, 18) and the value contains
  /// taxableAmount, cgst, and sgst for that rate slab.
  Map<int, Map<String, double>> get gstBreakdown {
    final result = <int, Map<String, double>>{};
    // Apply discount proportionally across items so GST is on the NET amount the
    // customer actually pays. Both the manual discount AND the flash sale reduce
    // the taxable base (both are known at the time of sale).
    final effectiveDiscount = discountAmount + flashSaleDiscount;
    final discountRatio =
        subtotal > 0 ? (effectiveDiscount / subtotal).clamp(0.0, 1.0) : 0.0;
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
    double? flashSalePercent,
    String? flashSaleName,
    String? flashSaleCategory,
    bool? isLoading,
    String? preNote,
    bool? roundOffEnabled,
    List<ParkedBill>? parkedBills,
  }) {
    return BillingState(
      cartItems: cartItems ?? this.cartItems,
      discountAmount: discountAmount ?? this.discountAmount,
      flashSalePercent: flashSalePercent ?? this.flashSalePercent,
      flashSaleName: flashSaleName ?? this.flashSaleName,
      flashSaleCategory: flashSaleCategory ?? this.flashSaleCategory,
      isLoading: isLoading ?? this.isLoading,
      preNote: preNote ?? this.preNote,
      roundOffEnabled: roundOffEnabled ?? this.roundOffEnabled,
      parkedBills: parkedBills ?? this.parkedBills,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class BillingNotifier extends Notifier<BillingState> {
  static const _cartKey = 'billing_cart_draft';
  static const _parkedKey = 'billing_parked_bills';

  @override
  BillingState build() {
    // Restore cart + parked bills from SharedPreferences on first build
    _restoreCart();
    _restoreParked();
    return const BillingState();
  }

  Future<void> _restoreParked() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_parkedKey);
      if (json == null) return;
      final list = (jsonDecode(json) as List).cast<Map<String, dynamic>>();
      final parked = list.map(ParkedBill.fromMap).toList();
      if (parked.isNotEmpty) {
        state = state.copyWith(parkedBills: parked);
      }
    } catch (e, st) {
      debugPrint('BillingProvider: parked restore failed: $e\n$st');
    }
  }

  void _persistParked(List<ParkedBill> parked) {
    SharedPreferences.getInstance().then((prefs) {
      if (parked.isEmpty) {
        prefs.remove(_parkedKey);
      } else {
        prefs.setString(
            _parkedKey, jsonEncode(parked.map((p) => p.toMap()).toList()));
      }
    });
  }

  /// Set the current cart aside under [label] and start a fresh cart. Keeps the
  /// round-off preference and the list of parked bills.
  void parkCurrentBill(String label) {
    if (state.cartItems.isEmpty) return;
    final parked = ParkedBill(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      label: label.trim(),
      items: List.unmodifiable(state.cartItems),
      discount: state.discountAmount,
      createdAt: DateTime.now(),
    );
    final newParked = [parked, ...state.parkedBills];
    _persistParked(newParked);
    _persistCart([]);
    state = BillingState(
      roundOffEnabled: state.roundOffEnabled,
      parkedBills: newParked,
    );
  }

  /// Resume a parked bill into the current cart. Any items already in the cart
  /// are merged (qty added) so nothing is lost.
  void resumeParkedBill(String id) {
    final idx = state.parkedBills.indexWhere((p) => p.id == id);
    if (idx < 0) return;
    final parked = state.parkedBills[idx];
    final cart = List<BillItemModel>.from(state.cartItems);
    for (final it in parked.items) {
      final i = cart.indexWhere((c) => c.productId == it.productId);
      if (i >= 0) {
        final newQty = cart[i].qty + it.qty;
        cart[i] = cart[i].copyWith(qty: newQty, subtotal: newQty * cart[i].price);
      } else {
        cart.add(it.copyWith());
      }
    }
    final newParked = List<ParkedBill>.from(state.parkedBills)..removeAt(idx);
    _persistParked(newParked);
    _persistCart(cart);
    state = state.copyWith(
      cartItems: cart,
      discountAmount: parked.discount,
      parkedBills: newParked,
    );
  }

  /// Discard a parked bill without resuming it.
  void deleteParkedBill(String id) {
    final newParked =
        state.parkedBills.where((p) => p.id != id).toList();
    _persistParked(newParked);
    state = state.copyWith(parkedBills: newParked);
  }

  Future<void> _restoreCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_cartKey);
      if (json == null) return;
      final list = (jsonDecode(json) as List).cast<Map<String, dynamic>>();
      final items = list.map(BillItemModel.fromMap).toList();
      if (items.isNotEmpty) {
        state = state.copyWith(cartItems: items);
      }
    } catch (e, st) {
      // Non-fatal — fresh cart on error
      debugPrint('BillingProvider: cart restore failed: $e\n$st');
    }
  }

  void _persistCart(List<BillItemModel> items) {
    SharedPreferences.getInstance().then((prefs) {
      if (items.isEmpty) {
        prefs.remove(_cartKey);
      } else {
        prefs.setString(_cartKey, jsonEncode(items.map((i) => i.toMap()).toList()));
      }
    });
  }

  /// Add one unit of [product] to the cart. If already present, increment qty.
  /// Decrement qty by the item's natural step (0.25 for weight-based, 1 otherwise).
  void decrementItem(String productId) {
    final items = List<BillItemModel>.from(state.cartItems);
    final idx = items.indexWhere((i) => i.productId == productId);
    if (idx < 0) return;
    final item = items[idx];
    final newQty = (item.qty - item.qtyStep).clamp(0.0, double.infinity);
    if (newQty <= 0) {
      items.removeAt(idx);
    } else {
      items[idx] = item.copyWith(qty: newQty, subtotal: newQty * item.price);
    }
    state = state.copyWith(cartItems: items);
    _persistCart(items);
  }

  void addItem(ProductModel product, {VariantModel? variant}) {
    final items = List<BillItemModel>.from(state.cartItems);
    // Use variant-specific ID so each variant is a separate cart line
    final cartId = variant != null
        ? '${product.productId}_${variant.variantId}'
        : product.productId;
    final idx = items.indexWhere((i) => i.productId == cartId);

    final effectivePrice = variant != null
        ? (variant.offerPrice > 0 ? variant.offerPrice : variant.price)
        : (product.offerPrice > 0 ? product.offerPrice : product.price);

    final displayName = variant != null
        ? '${product.nameEn} (${variant.name})'
        : product.nameEn;

    if (idx >= 0) {
      final existing = items[idx];
      final newQty = existing.qty + existing.qtyStep;
      items[idx] = existing.copyWith(
        qty: newQty,
        subtotal: newQty * existing.price,
      );
    } else {
      items.add(BillItemModel(
        productId: cartId,
        productName: displayName,
        category: product.category,
        qty: 1,
        unit: product.unit,
        price: effectivePrice,
        subtotal: effectivePrice,
        gstRate: product.gstRate,
        hsnCode: product.hsnCode,
        priceIncludesGst: product.priceIncludesGst,
        batchNumber: product.batchNumber,
        tracksStock: product.stockQty != null, // false for services
      ));
    }

    state = state.copyWith(cartItems: items);
    _persistCart(items);
  }

  /// Add an ad-hoc priced line that isn't in the catalog — for "no-catalog"
  /// billing (tea shops, vendors) or a one-off loose item. No stock tracking
  /// and no GST; each call is its own line so repeated quick-adds don't merge.
  void addCustomItem({required String name, required double price, double qty = 1}) {
    if (price <= 0 || qty <= 0) return;
    final items = List<BillItemModel>.from(state.cartItems);
    items.add(BillItemModel(
      productId: 'quick_${DateTime.now().microsecondsSinceEpoch}',
      productName: name.trim().isEmpty ? 'Item' : name.trim(),
      qty: qty,
      unit: 'piece',
      price: price,
      subtotal: price * qty,
      tracksStock: false,
    ));
    state = state.copyWith(cartItems: items);
    _persistCart(items);
  }

  /// Add [qty] of [product] in one go (used by voice billing). Merges with an
  /// existing line if the product is already in the cart.
  void addProductQuantity(ProductModel product, double qty) {
    if (qty <= 0) return;
    final items = List<BillItemModel>.from(state.cartItems);
    final idx = items.indexWhere((i) => i.productId == product.productId);
    final price = product.offerPrice > 0 ? product.offerPrice : product.price;
    if (idx >= 0) {
      final newQty = items[idx].qty + qty;
      items[idx] =
          items[idx].copyWith(qty: newQty, subtotal: newQty * items[idx].price);
    } else {
      items.add(BillItemModel(
        productId: product.productId,
        productName: product.nameEn,
        category: product.category,
        qty: qty,
        unit: product.unit,
        price: price,
        subtotal: price * qty,
        gstRate: product.gstRate,
        hsnCode: product.hsnCode,
        priceIncludesGst: product.priceIncludesGst,
        batchNumber: product.batchNumber,
        tracksStock: product.stockQty != null,
      ));
    }
    state = state.copyWith(cartItems: items);
    _persistCart(items);
  }

  /// Apply active flash sale discount to billing state.
  void applyFlashSale(double percent, String name, String category) {
    state = state.copyWith(
      flashSalePercent: percent,
      flashSaleName: name,
      flashSaleCategory: category,
    );
  }

  /// Remove an item from the cart by [productId].
  void removeItem(String productId) {
    final items = state.cartItems.where((i) => i.productId != productId).toList();
    state = state.copyWith(cartItems: items);
    _persistCart(items);
  }

  /// Re-insert a previously removed [item] at [index] (used by "Undo" after a
  /// swipe-to-delete). Restores the exact line — qty, price, modifiers and all.
  void restoreCartItem(BillItemModel item, int index) {
    final items = List<BillItemModel>.from(state.cartItems);
    // Don't duplicate if it somehow got re-added already.
    if (items.any((i) => i.productId == item.productId)) return;
    // Guard against a stale index if the cart changed in the meantime.
    final int safeIndex = index < 0
        ? 0
        : (index > items.length ? items.length : index);
    items.insert(safeIndex, item);
    state = state.copyWith(cartItems: items);
    _persistCart(items);
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
    _persistCart(items);
  }

  /// Load items from a previous bill into the cart ("reorder from last time").
  /// Merges with any current cart: existing lines get more qty, new lines added.
  /// Uses the previous bill's stored prices (owner can adjust before saving).
  void reorder(List<BillItemModel> previousItems) {
    final cart = List<BillItemModel>.from(state.cartItems);
    for (final it in previousItems) {
      final idx = cart.indexWhere((c) => c.productId == it.productId);
      if (idx >= 0) {
        final newQty = cart[idx].qty + it.qty;
        cart[idx] =
            cart[idx].copyWith(qty: newQty, subtotal: newQty * cart[idx].price);
      } else {
        cart.add(it.copyWith());
      }
    }
    state = state.copyWith(cartItems: cart);
    _persistCart(cart);
  }

  /// Set a flat discount amount on the current cart.
  void setDiscount(double amount) {
    state = state.copyWith(discountAmount: amount < 0 ? 0 : amount);
  }

  /// Toggle rounding the final total to the nearest rupee.
  void setRoundOff(bool enabled) {
    state = state.copyWith(roundOffEnabled: enabled);
  }

  /// Apply an active flash sale percentage discount.
  void setFlashSale(double percent, String name, {String category = ''}) {
    state = state.copyWith(
        flashSalePercent: percent,
        flashSaleName: name,
        flashSaleCategory: category);
  }

  /// Remove any active flash sale discount.
  void clearFlashSale() {
    state = state.copyWith(
        flashSalePercent: 0, flashSaleName: '', flashSaleCategory: '');
  }

  /// Override the unit price of a cart line (counter bargaining / negotiated
  /// price). Recomputes the line subtotal from the new price × current qty.
  void setItemPrice(String productId, double price) {
    if (price < 0) return;
    final items = List<BillItemModel>.from(state.cartItems);
    final idx = items.indexWhere((i) => i.productId == productId);
    if (idx < 0) return;
    final item = items[idx];
    items[idx] = item.copyWith(price: price, subtotal: price * item.qty);
    state = state.copyWith(cartItems: items);
    _persistCart(items);
  }

  /// Set modifier add-ons for a cart item (Bakery / Hotel).
  void setItemModifiers(String productId, List<String> modifiers) {
    final items = List<BillItemModel>.from(state.cartItems);
    final idx = items.indexWhere((i) => i.productId == productId);
    if (idx < 0) return;
    items[idx] = items[idx].copyWith(modifiers: modifiers);
    state = state.copyWith(cartItems: items);
    _persistCart(items);
  }

  /// Set a per-item free-text note (e.g. Rx# for pharmacy, special instructions).
  void setItemNote(String productId, String note) {
    final items = List<BillItemModel>.from(state.cartItems);
    final idx = items.indexWhere((i) => i.productId == productId);
    if (idx < 0) return;
    items[idx] = items[idx].copyWith(itemNote: note.isEmpty ? null : note);
    state = state.copyWith(cartItems: items);
    _persistCart(items);
  }

  /// Reset the cart to empty. Keeps the round-off preference and any parked
  /// bills so they survive completing/clearing the current sale.
  void clearCart() {
    state = BillingState(
      roundOffEnabled: state.roundOffEnabled,
      parkedBills: state.parkedBills,
    );
    _persistCart([]);
  }

  /// Set a pre-filled note (e.g. 'Table: 4' from KOT conversion).
  void setPreNote(String note) {
    state = state.copyWith(preNote: note);
  }

  /// Persist the bill to Firestore and return the saved [BillModel].
  Future<BillModel> saveBill({
    required String shopId,
    required String paymentMethod,
    String customerName = '',
    String customerPhone = '',
    String? gstinSnapshot,
    double? cashAmount,
    double? upiAmount,
    String? billNote,
  }) async {
    // Auto-capture who is billing (staff name from Firebase Auth)
    final billedByName =
        FirebaseAuth.instance.currentUser?.displayName ?? '';
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
        discountAmount: state.totalDiscountAmount,
        finalAmount: state.total,
        roundOff: state.total - state.rawTotal,
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
        cashAmount: cashAmount,
        upiAmount: upiAmount,
        billedByName: billedByName.isNotEmpty ? billedByName : null,
        billNote: (billNote != null && billNote.isNotEmpty) ? billNote : null,
      );

      // Generate sequential invoice number using a Firestore transaction counter
      String? invoiceNum;
      final counterRef = db.collection('shops').doc(shopId).collection('meta').doc('invoiceCounter');
      invoiceNum = await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(counterRef);
        final current = (snap.data()?['count'] as int?) ?? 0;
        final next = current + 1;
        tx.set(counterRef, {'count': next}, SetOptions(merge: true));
        return next.toString().padLeft(4, '0');
      });

      final billWithInvoice = BillModel(
        billId: bill.billId,
        shopId: bill.shopId,
        items: bill.items,
        totalAmount: bill.totalAmount,
        discountAmount: bill.discountAmount,
        finalAmount: bill.finalAmount,
        roundOff: bill.roundOff,
        paymentMethod: bill.paymentMethod,
        customerName: bill.customerName,
        customerPhone: bill.customerPhone,
        isUdhar: bill.isUdhar,
        createdAt: bill.createdAt,
        gstBreakdown: bill.gstBreakdown,
        totalTax: bill.totalTax,
        gstinSnapshot: bill.gstinSnapshot,
        invoiceNumber: invoiceNum,
        cashAmount: bill.cashAmount,
        upiAmount: bill.upiAmount,
        billedByName: bill.billedByName,
        billNote: bill.billNote,
      );
      // Write the bill AND all stock decrements in ONE atomic batch. Previously
      // the bill was set first and stock moved in a separate commit — if the
      // second commit failed you got a saved bill with un-decremented stock.
      // Batching them is atomic (all-or-nothing) AND a single network round-trip
      // instead of two, so it's faster and cheaper on every sale.
      // Variant items have productId = 'realId_variantId' — handle separately.
      final batch = FirebaseFirestore.instance.batch();
      batch.set(ref, billWithInvoice.toFirestore());
      for (final item in state.cartItems) {
        if (item.productId.isEmpty || !item.tracksStock) continue;
        final parts = item.productId.split('_');
        final realProductId = parts.first;
        final isVariant = parts.length > 1;
        final productRef = FirebaseFirestore.instance
            .collection('shops')
            .doc(shopId)
            .collection('products')
            .doc(realProductId);
        // orderCount is a popularity counter for bestsellers — round weight sales
        // (e.g. 0.5 kg) up to at least 1 so they still rank. Stock, however, must
        // decrement by the EXACT quantity sold (fractional included).
        final countInc = item.qty < 1 ? 1 : item.qty.round();
        if (isVariant) {
          final variantId = parts.sublist(1).join('_');
          batch.update(productRef, {
            // was -item.qty.toInt() — that truncated fractional weight to 0,
            // so selling 0.5 kg of a variant decremented no stock at all.
            'variantStock.$variantId': FieldValue.increment(-item.qty),
            'orderCount': FieldValue.increment(countInc),
          });
        } else {
          batch.update(productRef, {
            'stockQty': FieldValue.increment(-item.qty),
            'orderCount': FieldValue.increment(countInc),
          });
        }
      }
      await batch.commit();

      // Auto-update isOutOfStock for products whose stock just hit 0
      unawaited(_updateOutOfStockFlags(shopId, state.cartItems));

      // Upsert customer record for any bill that has a phone number
      if (bill.customerPhone.isNotEmpty && bill.customerName.isNotEmpty) {
        unawaited(CustomerModel.upsertFromOrder(
          shopId: shopId,
          customerPhone: bill.customerPhone,
          customerName: bill.customerName,
          orderAmount: bill.finalAmount,
        ));

        // For udhar sales, track balance on customer AND create a credit document
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
          // Create credit record so it appears in Credits screen and home Outstanding
          unawaited(FirebaseFirestore.instance
              .collection('shops')
              .doc(shopId)
              .collection('credits')
              .add({
            'shopId': shopId,
            'customerName': bill.customerName,
            'customerPhone': bill.customerPhone,
            'amount': bill.finalAmount,
            'paidAmount': 0.0,
            'status': 'open',
            'billId': bill.billId,
            'invoiceNumber': bill.invoiceNumber,
            'notes': bill.billNote ?? '',
            'createdAt': Timestamp.fromDate(bill.createdAt),
            'updatedAt': Timestamp.fromDate(bill.createdAt),
          }));
        }

        // Award loyalty points (fire-and-forget, non-fatal)
        unawaited(_awardLoyaltyPoints(shopId: shopId, bill: billWithInvoice));
      }

      state = state.copyWith(isLoading: false);
      return billWithInvoice;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  /// Award loyalty points after a bill is saved (non-fatal).
  static Future<void> _awardLoyaltyPoints({
    required String shopId,
    required BillModel bill,
  }) async {
    try {
      final shopDoc = await FirebaseFirestore.instance
          .collection('shops').doc(shopId).get();
      final settings =
          (shopDoc.data()?['loyaltySettings'] as Map<String, dynamic>?) ?? {};
      if (settings['enabled'] != true) return;
      final pointsPer100 =
          (settings['pointsPerHundred'] as num?)?.toInt() ?? 10;
      final points = ((bill.finalAmount / 100) * pointsPer100).floor();
      if (points <= 0) return;
      await FirebaseFirestore.instance
          .collection('shops').doc(shopId)
          .collection('customers').doc(bill.customerPhone)
          .set({'loyaltyPoints': FieldValue.increment(points)},
              SetOptions(merge: true));
    } catch (e, st) {
      // Non-fatal — loyalty failure must not block billing
      debugPrint('BillingProvider: loyalty points award failed: $e\n$st');
    }
  }

  /// After billing, auto-set isOutOfStock=true for products that hit zero stock.
  static Future<void> _updateOutOfStockFlags(
      String shopId, List<BillItemModel> cartItems) async {
    try {
      final db = FirebaseFirestore.instance;
      final productIds = cartItems
          .where((i) => i.tracksStock && !i.productId.contains('_'))
          .map((i) => i.productId)
          .toSet();
      for (final id in productIds) {
        final snap = await db.collection('shops').doc(shopId)
            .collection('products').doc(id).get();
        if (!snap.exists) continue;
        final qty = (snap.data()?['stockQty'] as num?)?.toDouble() ?? 1;
        if (qty <= 0) {
          unawaited(snap.reference.update({
            'isOutOfStock': true,
            // Heal oversold stock: if it went negative (sold more than on hand),
            // floor it back to 0. Reuses the read we already did here — no extra cost.
            if (qty < 0) 'stockQty': 0,
          }));
        } else {
          // Restore if restocked via stock-receive (just in case)
          if (snap.data()?['isOutOfStock'] == true) {
            unawaited(snap.reference.update({'isOutOfStock': false}));
          }
        }
      }
    } catch (e, st) {
      // Non-fatal
      debugPrint('BillingProvider: out-of-stock flag update failed: $e\n$st');
    }
  }

  /// Void a bill: mark as voided in Firestore and reverse stock decrements.
  Future<void> voidBill(BillModel bill) async {
    final db = FirebaseFirestore.instance;
    final billRef = db
        .collection('shops')
        .doc(bill.shopId)
        .collection('bills')
        .doc(bill.billId);

    final batch = db.batch();
    batch.update(billRef, {
      'isVoided': true,
      'voidedAt': Timestamp.fromDate(DateTime.now()),
    });

    // Reverse stock decrements — same variant-aware logic as saveBill
    for (final item in bill.items) {
      if (item.productId.isEmpty) continue;
      final parts = item.productId.split('_');
      final realProductId = parts.first;
      final isVariant = parts.length > 1;
      final productRef = db
          .collection('shops')
          .doc(bill.shopId)
          .collection('products')
          .doc(realProductId);
      if (isVariant) {
        final variantId = parts.sublist(1).join('_');
        batch.update(productRef, {
          // Restore the EXACT qty sold (was .toInt() — dropped fractional weight,
          // so voiding a 0.5 kg variant sale gave back 0 stock). Mirrors saveBill.
          'variantStock.$variantId': FieldValue.increment(item.qty),
        });
      } else {
        batch.update(productRef, {
          'stockQty': FieldValue.increment(item.qty),
        });
      }
    }
    await batch.commit();

    // If this was an udhar bill, reverse the customer balance and cancel the credit
    if (bill.isUdhar && bill.customerPhone.isNotEmpty) {
      final db2 = FirebaseFirestore.instance;
      // Decrement udharBalance on customer
      unawaited(db2.collection('shops').doc(bill.shopId)
          .collection('customers').doc(bill.customerPhone)
          .set({'udharBalance': FieldValue.increment(-bill.finalAmount)},
              SetOptions(merge: true)));
      // Mark the linked credit as cancelled
      final creditsSnap = await db2.collection('shops').doc(bill.shopId)
          .collection('credits')
          .where('billId', isEqualTo: bill.billId)
          .limit(1).get();
      for (final doc in creditsSnap.docs) {
        unawaited(doc.reference.update({'status': 'paid', 'paidAmount': bill.finalAmount}));
      }
    }
  }

  /// Record a return/refund of [returnedItems] (each carrying the qty being
  /// returned) against [original]. Restocks the items, writes a negative
  /// "return" bill so revenue drops, and — for a credit refund — reduces the
  /// customer's outstanding udhar. The refund is prorated by the original
  /// bill's discount so it equals what the customer actually paid.
  Future<BillModel> createReturn({
    required BillModel original,
    required List<BillItemModel> returnedItems,
    required String refundMethod, // 'cash' | 'upi' | 'udhar'
  }) async {
    final db = FirebaseFirestore.instance;
    final returnRef =
        db.collection('shops').doc(original.shopId).collection('bills').doc();

    final gross = returnedItems.fold<double>(0, (a, i) => a + i.subtotal);
    // Prorate by what the customer actually paid (discount/round-off aware).
    final ratio = original.totalAmount > 0
        ? original.finalAmount / original.totalAmount
        : 1.0;
    final refundTotal =
        double.parse((gross * ratio).toStringAsFixed(2));
    final now = DateTime.now();
    final isUdharRefund = refundMethod == 'udhar';

    final returnBill = BillModel(
      billId: returnRef.id,
      shopId: original.shopId,
      items: List.unmodifiable(returnedItems),
      totalAmount: -refundTotal,
      discountAmount: 0,
      finalAmount: -refundTotal,
      paymentMethod: refundMethod,
      customerName: original.customerName,
      customerPhone: original.customerPhone,
      isUdhar: isUdharRefund,
      createdAt: now,
      isReturn: true,
      returnOfBillId: original.billId,
      gstinSnapshot: original.gstinSnapshot,
      billedByName: FirebaseAuth.instance.currentUser?.displayName,
    );

    // Atomic: write the return bill AND restock every returned item.
    final batch = db.batch();
    batch.set(returnRef, returnBill.toFirestore());
    for (final item in returnedItems) {
      if (item.productId.isEmpty || !item.tracksStock) continue;
      final parts = item.productId.split('_');
      final realProductId = parts.first;
      final isVariant = parts.length > 1;
      final productRef = db
          .collection('shops')
          .doc(original.shopId)
          .collection('products')
          .doc(realProductId);
      if (isVariant) {
        final variantId = parts.sublist(1).join('_');
        batch.update(productRef, {
          'variantStock.$variantId': FieldValue.increment(item.qty),
          'isOutOfStock': false,
        });
      } else {
        batch.update(productRef, {
          'stockQty': FieldValue.increment(item.qty),
          'isOutOfStock': false,
        });
      }
    }
    await batch.commit();

    // Credit refund: reduce the customer's outstanding udhar by the refund.
    if (isUdharRefund && original.customerPhone.isNotEmpty) {
      unawaited(db
          .collection('shops')
          .doc(original.shopId)
          .collection('customers')
          .doc(original.customerPhone)
          .set({'udharBalance': FieldValue.increment(-refundTotal)},
              SetOptions(merge: true)));
    }

    return returnBill;
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
      for (final b in list.where((b) => !b.isVoided)) {
        total += b.finalAmount;
        if (b.paymentMethod == 'split') {
          cash += b.cashAmount ?? 0;
          upi += b.upiAmount ?? 0;
        } else if (b.paymentMethod == 'cash') {
          cash += b.finalAmount;
        } else if (b.paymentMethod == 'upi') {
          upi += b.finalAmount;
        } else if (b.isUdhar) {
          udhar += b.finalAmount;
        }
      }
      final nonVoidedCount =
          list.where((b) => !b.isVoided && !b.isReturn).length;
      return {
        'totalSales': total,
        'billCount': nonVoidedCount.toDouble(),
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

// ---------------------------------------------------------------------------
// Flash Sale Provider — active flash sale for a shop
// ---------------------------------------------------------------------------

/// Streams the first active (non-expired, not past endTime) flash sale
/// for [shopId]. Returns null when no flash sale is live.
final activeFlashSaleProvider =
    StreamProvider.family<Map<String, dynamic>?, String>((ref, shopId) {
  return FirebaseFirestore.instance
      .collection('shops')
      .doc(shopId)
      .collection('flashSales')
      .where('expired', isEqualTo: false)
      .snapshots()
      .map((snap) {
    final now = DateTime.now();
    Map<String, dynamic>? best;
    double bestPct = 0;
    for (final doc in snap.docs) {
      final d = doc.data();
      final end = (d['endTime'] as Timestamp?)?.toDate();
      if (end == null || !end.isAfter(now)) continue;
      final pct = ((d['discountPercent'] ?? 0) as num).toDouble();
      if (pct > bestPct) { bestPct = pct; best = d; }
    }
    return best;
  });
});

// ---------------------------------------------------------------------------
// Weekly/Monthly POS Bills Providers — for analytics
// ---------------------------------------------------------------------------

final weeklyBillsProvider =
    StreamProvider.family<List<BillModel>, String>((ref, shopId) {
  final start = DateTime.now().subtract(const Duration(days: 7));
  return FirebaseFirestore.instance
      .collection('shops')
      .doc(shopId)
      .collection('bills')
      .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
      .orderBy('createdAt', descending: true)
      .limit(500)
      .snapshots()
      .map((s) => s.docs.map(BillModel.fromFirestore).toList());
});

// 30-day bills for analytics "This Month" view
final monthlyBillsProvider =
    StreamProvider.family<List<BillModel>, String>((ref, shopId) {
  final start = DateTime.now().subtract(const Duration(days: 30));
  return FirebaseFirestore.instance
      .collection('shops')
      .doc(shopId)
      .collection('bills')
      .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
      .orderBy('createdAt', descending: true)
      .limit(2000)
      .snapshots()
      .map((s) => s.docs.map(BillModel.fromFirestore).toList());
});
