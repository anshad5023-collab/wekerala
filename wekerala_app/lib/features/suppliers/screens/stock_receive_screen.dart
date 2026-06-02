import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/product_model.dart';
import '../../../providers/products_provider.dart';
import '../../../providers/shop_provider.dart';

class StockReceiveScreen extends ConsumerStatefulWidget {
  const StockReceiveScreen({super.key});

  @override
  ConsumerState<StockReceiveScreen> createState() => _StockReceiveScreenState();
}

class _StockReceiveScreenState extends ConsumerState<StockReceiveScreen> {
  final Map<String, TextEditingController> _qtyControllers = {};
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _qtyControllers.values) { c.dispose(); }
    _searchCtrl.dispose();
    super.dispose();
  }

  TextEditingController _ctrl(String productId) {
    return _qtyControllers.putIfAbsent(productId, TextEditingController.new);
  }

  int _totalItems() {
    int count = 0;
    for (final c in _qtyControllers.values) {
      count += int.tryParse(c.text) ?? 0;
    }
    return count;
  }

  Future<void> _save(String shopId, List<ProductModel> products) async {
    final updates = <String, int>{};
    for (final c in _qtyControllers.entries) {
      final qty = int.tryParse(c.value.text) ?? 0;
      if (qty > 0) updates[c.key] = qty;
    }
    if (updates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter received qty for at least one product.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      final now = DateTime.now();

      for (final entry in updates.entries) {
        final productRef = db
            .collection('shops').doc(shopId)
            .collection('products').doc(entry.key);
        batch.update(productRef, {
          'stockQty': FieldValue.increment(entry.value),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Save a stock receive record for audit trail
      final receiveRef = db
          .collection('shops').doc(shopId)
          .collection('stockReceives').doc();
      batch.set(receiveRef, {
        'receiveId': receiveRef.id,
        'shopId': shopId,
        'items': updates.entries.map((e) {
          final matches = products.where((p) => p.productId == e.key);
          final productName =
              matches.isNotEmpty ? matches.first.nameEn : e.key;
          return {
            'productId': e.key,
            'productName': productName,
            'qtyReceived': e.value,
          };
        }).toList(),
        'createdAt': Timestamp.fromDate(now),
        'totalItems': updates.values.fold(0, (a, b) => a + b),
      });

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stock updated! ${updates.length} products, '
              '${updates.values.fold(0, (a, b) => a + b)} units added.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Clear all entries after save
      for (final c in _qtyControllers.values) { c.clear(); }
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopAsync = ref.watch(activeShopIdProvider);

    return shopAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (shopId) {
        if (shopId == null) {
          return const Scaffold(body: Center(child: Text('No active shop.')));
        }
        return _Body(
          shopId: shopId,
          searchCtrl: _searchCtrl,
          searchQuery: _searchQuery,
          onSearchChanged: (q) => setState(() => _searchQuery = q),
          ctrl: _ctrl,
          totalItems: _totalItems,
          saving: _saving,
          onSave: (products) => _save(shopId, products),
        );
      },
    );
  }
}

class _Body extends ConsumerWidget {
  final String shopId;
  final TextEditingController searchCtrl;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final TextEditingController Function(String) ctrl;
  final int Function() totalItems;
  final bool saving;
  final void Function(List<ProductModel>) onSave;

  const _Body({
    required this.shopId,
    required this.searchCtrl,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.ctrl,
    required this.totalItems,
    required this.saving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsStreamProvider(shopId));

    return productsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (allProducts) {
        final filtered = searchQuery.isEmpty
            ? allProducts
            : allProducts
                .where((p) =>
                    p.nameEn.toLowerCase().contains(searchQuery.toLowerCase()))
                .toList();

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Receive Stock'),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          body: Column(
            children: [
              // Search
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  controller: searchCtrl,
                  onChanged: onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              // Tip
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      'Enter qty received from supplier. Tap Save to update stock.',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              // Product list
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final p = filtered[i];
                    return _ProductReceiveRow(
                      product: p,
                      controller: ctrl(p.productId),
                    );
                  },
                ),
              ),
            ],
          ),
          bottomNavigationBar: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: ElevatedButton.icon(
              onPressed: saving ? null : () => onSave(allProducts),
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline, size: 20),
              label: Text(
                saving ? 'Saving...' : 'Save & Update Stock',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProductReceiveRow extends StatelessWidget {
  final ProductModel product;
  final TextEditingController controller;

  const _ProductReceiveRow({required this.product, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.nameEn,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  'Stock: ${product.stockQty?.toInt() ?? 0} ${product.unit}',
                  style: TextStyle(
                      fontSize: 12,
                      color: (product.stockQty ?? 0) <= 0
                          ? AppColors.error
                          : AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '0',
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                filled: true,
                fillColor: AppColors.surface,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Text('units',
              style:
                  TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
