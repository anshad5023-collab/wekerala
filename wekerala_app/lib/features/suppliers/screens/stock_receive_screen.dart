import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/product_model.dart';
import '../../../providers/products_provider.dart';
import '../../../providers/shop_provider.dart';

// Controller key format:
//   Non-variant product: productId
//   Variant product:     productId__variantId

class StockReceiveScreen extends ConsumerStatefulWidget {
  final String? supplierId;
  final String? supplierName;

  const StockReceiveScreen({super.key, this.supplierId, this.supplierName});

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
    for (final c in _qtyControllers.values) {
      c.dispose();
    }
    _searchCtrl.dispose();
    super.dispose();
  }

  TextEditingController _ctrl(String key) {
    return _qtyControllers.putIfAbsent(key, TextEditingController.new);
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
    for (final entry in _qtyControllers.entries) {
      final qty = int.tryParse(entry.value.text) ?? 0;
      if (qty > 0) updates[entry.key] = qty;
    }
    if (updates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Enter received qty for at least one product.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final db = FirebaseFirestore.instance;
      final now = DateTime.now();

      // Separate variant vs non-variant updates
      final nonVariantUpdates = <String, int>{};
      final variantUpdates = <String, Map<String, int>>{}; // productId -> {variantId -> qty}

      for (final entry in updates.entries) {
        if (entry.key.contains('__')) {
          final parts = entry.key.split('__');
          final productId = parts[0];
          final variantId = parts[1];
          variantUpdates.putIfAbsent(productId, () => {})[variantId] = entry.value;
        } else {
          nonVariantUpdates[entry.key] = entry.value;
        }
      }

      // Non-variant products: batch update
      if (nonVariantUpdates.isNotEmpty) {
        final batch = db.batch();
        for (final entry in nonVariantUpdates.entries) {
          final ref = db
              .collection('shops')
              .doc(shopId)
              .collection('products')
              .doc(entry.key);
          batch.update(ref, {
            'stockQty': FieldValue.increment(entry.value),
            'isOutOfStock': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }

      // Variant products: read-modify-write per product
      for (final entry in variantUpdates.entries) {
        final productId = entry.key;
        final variantQtyMap = entry.value;
        final ref = db
            .collection('shops')
            .doc(shopId)
            .collection('products')
            .doc(productId);
        final doc = await ref.get();
        if (!doc.exists) continue;
        final rawVariants =
            (doc.data()?['variants'] as List? ?? []).cast<Map>();
        final updatedVariants = rawVariants.map((v) {
          final vid = v['variantId'] as String? ?? '';
          if (variantQtyMap.containsKey(vid)) {
            final current = (v['stockQty'] as int?) ?? 0;
            return Map<String, dynamic>.from(v)
              ..['stockQty'] = current + variantQtyMap[vid]!;
          }
          return Map<String, dynamic>.from(v);
        }).toList();

        // Check if any variant still has stock (if all are 0 → keep isOutOfStock true)
        final anyInStock =
            updatedVariants.any((v) => ((v['stockQty'] as int?) ?? 0) > 0);
        await ref.update({
          'variants': updatedVariants,
          'isOutOfStock': !anyInStock,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Save audit record
      final allItemsSummary = <Map<String, dynamic>>[];
      for (final entry in nonVariantUpdates.entries) {
        final p = products.firstWhere((p) => p.productId == entry.key,
            orElse: () => products.first);
        allItemsSummary.add({
          'productId': entry.key,
          'productName': p.nameEn,
          'qtyReceived': entry.value,
        });
      }
      for (final pEntry in variantUpdates.entries) {
        final p = products.firstWhere((p) => p.productId == pEntry.key,
            orElse: () => products.first);
        for (final vEntry in pEntry.value.entries) {
          final variant = p.variants.firstWhere((v) => v.variantId == vEntry.key,
              orElse: () => p.variants.first);
          allItemsSummary.add({
            'productId': pEntry.key,
            'variantId': vEntry.key,
            'productName': '${p.nameEn} (${variant.name})',
            'qtyReceived': vEntry.value,
          });
        }
      }

      await db
          .collection('shops')
          .doc(shopId)
          .collection('stockReceives')
          .add({
        'shopId': shopId,
        if (widget.supplierId != null) 'supplierId': widget.supplierId,
        if (widget.supplierName != null) 'supplierName': widget.supplierName,
        'items': allItemsSummary,
        'createdAt': Timestamp.fromDate(now),
        'totalItems': updates.values.fold(0, (a, b) => a + b),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Stock updated! ${updates.length} items, '
              '${updates.values.fold(0, (a, b) => a + b)} units added.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      for (final c in _qtyControllers.values) {
        c.clear();
      }
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
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (shopId) {
        if (shopId == null) {
          return const Scaffold(
              body: Center(child: Text('No active shop.')));
        }
        return _Body(
          shopId: shopId,
          supplierName: widget.supplierName,
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
  final String? supplierName;
  final TextEditingController searchCtrl;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final TextEditingController Function(String) ctrl;
  final int Function() totalItems;
  final bool saving;
  final void Function(List<ProductModel>) onSave;

  const _Body({
    required this.shopId,
    this.supplierName,
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
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
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
            title: Text(supplierName != null
                ? 'Receive: $supplierName'
                : 'Receive Stock'),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          body: Column(
            children: [
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
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Enter received qty. For variants, expand the product row.',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final p = filtered[i];
                    if (p.hasVariants && p.variants.isNotEmpty) {
                      return _VariantProductRow(product: p, ctrl: ctrl);
                    }
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

// Row for products WITH variants — shows an expandable list of variants
class _VariantProductRow extends StatefulWidget {
  final ProductModel product;
  final TextEditingController Function(String) ctrl;

  const _VariantProductRow({required this.product, required this.ctrl});

  @override
  State<_VariantProductRow> createState() => _VariantProductRowState();
}

class _VariantProductRowState extends State<_VariantProductRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.nameEn,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        Text(
                          '${p.variants.length} variants',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            ...p.variants.map((v) {
              final key = '${p.productId}__${v.variantId}';
              return Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(v.name,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                          Text(
                            'Stock: ${v.stockQty ?? '—'} ${p.unit}',
                            style: TextStyle(
                                fontSize: 11,
                                color: (v.stockQty ?? 1) <= 0
                                    ? AppColors.error
                                    : AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: widget.ctrl(key),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: '0',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                                color: AppColors.primary.withValues(alpha: 0.4)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: AppColors.primary, width: 1.5),
                          ),
                          filled: true,
                          fillColor: AppColors.surface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('units',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

// Row for products WITHOUT variants
class _ProductReceiveRow extends StatelessWidget {
  final ProductModel product;
  final TextEditingController controller;

  const _ProductReceiveRow(
      {required this.product, required this.controller});

  @override
  Widget build(BuildContext context) {
    final p = product;
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
                Text(p.nameEn,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      'Stock: ${p.stockQty?.toInt() ?? 0} ${p.unit}',
                      style: TextStyle(
                          fontSize: 12,
                          color: (p.stockQty ?? 0) <= 0
                              ? AppColors.error
                              : AppColors.textSecondary),
                    ),
                    if (p.lowStockThreshold > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '(min: ${p.lowStockThreshold})',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary),
                      ),
                    ],
                    // Show expiry for pharmacy products
                    if (p.expiryDate != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        'Exp: ${p.expiryDate!.day}/${p.expiryDate!.month}/${p.expiryDate!.year}',
                        style: TextStyle(
                          fontSize: 11,
                          color: p.expiryDate!.isBefore(DateTime.now()
                                  .add(const Duration(days: 30)))
                              ? AppColors.error
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
                // Show HSN / batch info if present
                if ((p.hsnCode ?? '').isNotEmpty)
                  Text('HSN: ${p.hsnCode}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary)),
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
                  borderSide: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.4)),
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
          Text(p.unit,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
