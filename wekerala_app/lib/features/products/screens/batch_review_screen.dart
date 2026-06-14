import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/storage_service.dart';
import '../../../models/product_model.dart';
import '../../../providers/products_provider.dart';
import '../../../providers/shop_provider.dart';
import '../models/scan_job.dart';

/// One editable card per scanned product — owner fills price + stock, then saves all.
class BatchReviewScreen extends ConsumerStatefulWidget {
  final List<ScanJob> jobs;
  const BatchReviewScreen({super.key, required this.jobs});

  @override
  ConsumerState<BatchReviewScreen> createState() => _BatchReviewScreenState();
}

class _BatchReviewScreenState extends ConsumerState<BatchReviewScreen> {
  late final List<_EditState> _edits;
  bool _saving = false;
  int _savedCount = 0;

  @override
  void initState() {
    super.initState();
    _edits = widget.jobs.map((j) => _EditState(job: j)).toList();
  }

  Future<void> _saveAll() async {
    // Validate — every ready card needs a price
    for (final e in _edits) {
      if (e.job.status != ScanStatus.done) continue;
      if (e.skip) continue;
      final price = double.tryParse(e.priceCtrl.text.trim()) ?? 0;
      if (price <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Enter a price for "${e.job.result?.nameEn ?? 'product'}"'),
        ));
        return;
      }
    }

    setState(() => _saving = true);
    final shopId = ref.read(activeShopIdProvider).valueOrNull ?? '';

    for (final e in _edits) {
      if (e.job.status != ScanStatus.done || e.skip) continue;
      try {
        final result = e.job.result!;
        final productId = FirebaseFirestore.instance.collection('_').doc().id;
        final price = double.parse(e.priceCtrl.text.trim());
        final stock = int.tryParse(e.stockCtrl.text.trim());
        final now = DateTime.now();

        // Upload the scanned photo as the product image
        String imageUrl = result.imageUrl;
        String imageSource = result.imageUrl.isNotEmpty ? 'auto' : 'placeholder';
        try {
          final imgFile = File(e.job.imagePath);
          if (imgFile.existsSync()) {
            imageUrl = await StorageService.uploadProductImage(shopId, productId, imgFile);
            imageSource = 'owner';
          }
        } catch (_) {}

        final product = ProductModel(
          productId: productId,
          nameEn: e.nameCtrl.text.trim().isEmpty ? (result.nameEn) : e.nameCtrl.text.trim(),
          category: result.category,
          price: price,
          unit: result.unit,
          imageUrl: imageUrl,
          imageSource: imageSource,
          description: result.description.isNotEmpty ? result.description : null,
          stockQty: stock,
          attributes: result.attributes,
          createdAt: now,
          updatedAt: now,
        );

        await ProductRepository.add(shopId, product);
        setState(() => _savedCount++);
      } catch (_) {}
    }

    setState(() => _saving = false);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$_savedCount product${_savedCount == 1 ? '' : 's'} added successfully!'),
      backgroundColor: Colors.green,
    ));
    // Pop both this screen and the batch scan screen
    Navigator.of(context).popUntil((route) => route.isFirst || route.settings.name == '/products');
  }

  @override
  Widget build(BuildContext context) {
    final readyCount = _edits.where((e) => e.job.status == ScanStatus.done && !e.skip).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Review Products (${widget.jobs.length})'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: _edits.length,
              itemBuilder: (ctx, i) => _ProductCard(
                edit: _edits[i],
                onChanged: () => setState(() {}),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving || readyCount == 0 ? null : _saveAll,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  child: _saving
                      ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                          const SizedBox(width: 12),
                          Text('Adding $_savedCount / $readyCount...'),
                        ])
                      : Text('Add $readyCount Product${readyCount == 1 ? '' : 's'} to Shop'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Per-product edit state ────────────────────────────────────────────────────

class _EditState {
  final ScanJob job;
  final TextEditingController nameCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController stockCtrl;
  bool skip;

  _EditState({required this.job})
      : nameCtrl = TextEditingController(text: job.result?.nameEn ?? ''),
        priceCtrl = TextEditingController(),
        stockCtrl = TextEditingController(),
        skip = job.status == ScanStatus.failed;
}

// ── Product card widget ───────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final _EditState edit;
  final VoidCallback onChanged;
  const _ProductCard({required this.edit, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final job = edit.job;
    final result = job.result;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: edit.skip
              ? Colors.grey.shade300
              : job.status == ScanStatus.done
                  ? AppColors.primary.withOpacity(0.3)
                  : job.status == ScanStatus.failed
                      ? Colors.red.shade200
                      : Colors.orange.shade200,
          width: 1.5,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row — photo + status + skip toggle
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(job.imagePath),
                    width: 64, height: 64, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 64, height: 64,
                      color: Colors.grey.shade100,
                      child: const Icon(Icons.image, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (job.status == ScanStatus.scanning)
                        Row(children: [
                          SizedBox(width: 14, height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                          const SizedBox(width: 8),
                          const Text('Identifying...', style: TextStyle(color: Colors.orange, fontSize: 13)),
                        ])
                      else if (job.status == ScanStatus.failed)
                        const Text('Could not identify', style: TextStyle(color: Colors.red, fontSize: 13))
                      else ...[
                        Text(
                          result?.category.isNotEmpty == true ? result!.category : 'General',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          result?.unit ?? 'piece',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                        ),
                      ],
                    ],
                  ),
                ),
                // Skip toggle
                if (job.status != ScanStatus.scanning)
                  GestureDetector(
                    onTap: () { edit.skip = !edit.skip; onChanged(); },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: edit.skip ? Colors.grey.shade100 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: edit.skip ? Colors.grey.shade300 : Colors.red.shade200),
                      ),
                      child: Text(
                        edit.skip ? 'Skipped' : 'Skip',
                        style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: edit.skip ? Colors.grey : Colors.red,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Fields — only shown when identified and not skipped
          if (job.status == ScanStatus.done && !edit.skip) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name field
                  _Field(
                    label: 'Product Name',
                    controller: edit.nameCtrl,
                    hint: result?.nameEn ?? '',
                  ),
                  const SizedBox(height: 8),
                  // Description (read-only, from AI)
                  if (result?.description.isNotEmpty == true)
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(
                        result!.description,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: _Field(
                          label: 'Price (₹) *',
                          controller: edit.priceCtrl,
                          hint: '0.00',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Field(
                          label: 'Stock (optional)',
                          controller: edit.stockCtrl,
                          hint: 'e.g. 50',
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.primary)),
          ),
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }
}
