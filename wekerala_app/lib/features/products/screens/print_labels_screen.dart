import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/label_print_service.dart';
import '../../../models/product_model.dart';
import '../../../providers/products_provider.dart';
import '../../../providers/shop_provider.dart';

/// Print price labels for shelves: pick products, generate a PDF grid of
/// labels (name + price + barcode) and send to a printer / share as PDF.
/// Products without a barcode get one auto-assigned (their productId) so the
/// printed label scans back to the right product at billing.
class PrintLabelsScreen extends ConsumerStatefulWidget {
  const PrintLabelsScreen({super.key});

  @override
  ConsumerState<PrintLabelsScreen> createState() => _PrintLabelsScreenState();
}

class _PrintLabelsScreenState extends ConsumerState<PrintLabelsScreen> {
  final Set<String> _selected = {};
  String _query = '';
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final shopId = ref.watch(activeShopIdProvider).valueOrNull;
    if (shopId == null) {
      return const Scaffold(body: Center(child: Text('No shop found')));
    }
    final productsAsync = ref.watch(productsStreamProvider(shopId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Print Price Labels'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (all) {
          final products = _query.isEmpty
              ? all
              : all
                  .where((p) =>
                      p.nameEn.toLowerCase().contains(_query.toLowerCase()))
                  .toList();
          return Column(
            children: [
              // Search + select all
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search products',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Text('${_selected.length} selected',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() {
                        if (_selected.length == products.length) {
                          _selected.clear();
                        } else {
                          _selected
                            ..clear()
                            ..addAll(products.map((p) => p.productId));
                        }
                      }),
                      child: Text(_selected.length == products.length
                          ? 'Clear all'
                          : 'Select all'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (ctx, i) {
                    final p = products[i];
                    final sel = _selected.contains(p.productId);
                    return CheckboxListTile(
                      value: sel,
                      activeColor: AppColors.primary,
                      onChanged: (_) => setState(() {
                        if (sel) {
                          _selected.remove(p.productId);
                        } else {
                          _selected.add(p.productId);
                        }
                      }),
                      title: Text(p.nameEn,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('₹${p.price.toStringAsFixed(0)}'
                          '${p.barcode != null && p.barcode!.isNotEmpty ? ' · ${p.barcode}' : ''}'),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ElevatedButton.icon(
            onPressed: _selected.isEmpty || _busy
                ? null
                : () => _printLabels(shopId, productsAsync.valueOrNull ?? []),
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.print),
            label: Text('Print ${_selected.length} label'
                '${_selected.length == 1 ? '' : 's'}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _printLabels(String shopId, List<ProductModel> all) async {
    setState(() => _busy = true);
    try {
      final chosen =
          all.where((p) => _selected.contains(p.productId)).toList();

      // Auto-assign an internal barcode to any chosen product without one, so
      // the printed label scans back to this product at billing.
      final batch = FirebaseFirestore.instance.batch();
      final col = FirebaseFirestore.instance
          .collection('shops').doc(shopId).collection('products');
      final labels = <LabelData>[];
      var salt = 0;
      for (final p in chosen) {
        final code = (p.barcode != null && p.barcode!.isNotEmpty)
            ? p.barcode!
            : LabelPrintService.generateInternalEan13(salt++);
        if (p.barcode == null || p.barcode!.isEmpty) {
          batch.update(col.doc(p.productId), {'barcode': code});
        }
        labels.add(LabelData(name: p.nameEn, price: p.price, barcode: code));
      }
      await batch.commit();

      await LabelPrintService.printLabels(labels);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not print: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
