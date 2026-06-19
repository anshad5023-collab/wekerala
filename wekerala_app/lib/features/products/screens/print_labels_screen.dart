import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/constants/app_colors.dart';
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

      // Auto-assign a barcode (the productId) to any chosen product without one,
      // so the printed label scans back to this product.
      final batch = FirebaseFirestore.instance.batch();
      final col = FirebaseFirestore.instance
          .collection('shops').doc(shopId).collection('products');
      final withCodes = <(ProductModel, String)>[];
      for (final p in chosen) {
        final code = (p.barcode != null && p.barcode!.isNotEmpty)
            ? p.barcode!
            : p.productId;
        if (p.barcode == null || p.barcode!.isEmpty) {
          batch.update(col.doc(p.productId), {'barcode': code});
        }
        withCodes.add((p, code));
      }
      await batch.commit();

      final doc = await _buildLabelsPdf(withCodes);
      await Printing.layoutPdf(onLayout: (_) async => doc.save());
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

  Future<pw.Document> _buildLabelsPdf(
      List<(ProductModel, String)> items) async {
    final doc = pw.Document();
    const perRow = 3;

    // Chunk into rows of [perRow] so MultiPage paginates cleanly.
    final rows = <List<(ProductModel, String)>>[];
    for (var i = 0; i < items.length; i += perRow) {
      rows.add(items.sublist(
          i, i + perRow > items.length ? items.length : i + perRow));
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(18),
        build: (ctx) => rows
            .map((row) => pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: List.generate(perRow, (c) {
                    if (c >= row.length) {
                      return pw.Expanded(child: pw.SizedBox());
                    }
                    final (p, code) = row[c];
                    return pw.Expanded(child: _label(p, code));
                  }),
                ))
            .toList(),
      ),
    );
    return doc;
  }

  pw.Widget _label(ProductModel p, String code) {
    return pw.Container(
      margin: const pw.EdgeInsets.all(4),
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            p.nameEn,
            maxLines: 2,
            overflow: pw.TextOverflow.clip,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 3),
          pw.Text('₹${p.price.toStringAsFixed(0)}',
              style:
                  pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 3),
          pw.BarcodeWidget(
            barcode: pw.Barcode.code128(),
            data: code,
            drawText: false,
            height: 26,
            width: 120,
          ),
        ],
      ),
    );
  }
}
