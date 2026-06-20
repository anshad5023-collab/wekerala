import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
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

        // Honour the owner's image choice: web image vs their own photo.
        // Falls back to whichever exists if the preferred one isn't available.
        String imageUrl = '';
        String imageSource = 'placeholder';
        final hasWeb = result.imageUrl.isNotEmpty;
        if (e.useWebImage && hasWeb) {
          imageUrl = result.imageUrl;
          imageSource = 'auto';
        } else {
          try {
            final imgFile = File(e.job.imagePath);
            if (imgFile.existsSync()) {
              imageUrl = await StorageService.uploadProductImage(shopId, productId, imgFile);
              imageSource = 'owner';
            }
          } catch (_) {}
          if (imageUrl.isEmpty && hasWeb) {
            imageUrl = result.imageUrl;
            imageSource = 'auto';
          }
        }

        // Owner-edited category + attributes (from the "More details" editor),
        // falling back to what Gemini extracted.
        final category = e.categoryCtrl.text.trim();
        final attributes = <String, dynamic>{
          for (final entry in e.attrCtrls.entries)
            if (entry.value.text.trim().isNotEmpty)
              entry.key: entry.value.text.trim()
        };

        final product = ProductModel(
          productId: productId,
          nameEn: e.nameCtrl.text.trim().isEmpty ? (result.nameEn) : e.nameCtrl.text.trim(),
          category: category,
          price: price,
          unit: result.unit,
          imageUrl: imageUrl,
          imageSource: imageSource,
          description: result.description.isNotEmpty ? result.description : null,
          stockQty: stock,
          attributes: attributes,
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
    // Identified (and still-scanning) items stay visible; unreadable shots are
    // tucked into a collapsed section so they don't clutter the review.
    final identified =
        _edits.where((e) => e.job.status != ScanStatus.failed).toList();
    final unclear =
        _edits.where((e) => e.job.status == ScanStatus.failed).toList();

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
            child: ListView(
              padding: const EdgeInsets.all(14),
              children: [
                for (final e in identified)
                  _ProductCard(edit: e, onChanged: () => setState(() {})),
                if (unclear.isNotEmpty) _UnclearSection(edits: unclear),
              ],
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
  final TextEditingController categoryCtrl;

  /// Editable controllers for every attribute Gemini auto-extracted
  /// (colour, sizes, fabric, material, strength, …). Hidden behind the
  /// "More details" toggle so the owner only sees them if they want to edit.
  final Map<String, TextEditingController> attrCtrls;

  bool skip;

  /// Whether to use the web image (true) or the owner's own captured photo
  /// (false) as the product image. Defaults to the web image when one was
  /// found, but the owner can switch — important for shoes/clothing where the
  /// web image may be a different colour variant.
  bool useWebImage;

  /// Whether the per-product "More details" editor is expanded.
  bool expanded;

  _EditState({required this.job})
      : nameCtrl = TextEditingController(text: job.result?.nameEn ?? ''),
        priceCtrl = TextEditingController(
            text: (job.result?.price ?? 0) > 0
                ? ((job.result!.price % 1 == 0)
                    ? job.result!.price.toInt().toString()
                    : job.result!.price.toStringAsFixed(2))
                : ''),
        stockCtrl = TextEditingController(),
        categoryCtrl = TextEditingController(text: job.result?.category ?? ''),
        attrCtrls = {
          for (final e in (job.result?.attributes ?? const {}).entries)
            e.key: TextEditingController(text: e.value?.toString() ?? '')
        },
        skip = job.status == ScanStatus.failed,
        useWebImage = job.result?.imageUrl.isNotEmpty ?? false,
        expanded = false;
}

/// Turn an attribute key like `care_instructions` into `Care Instructions`.
String _prettyLabel(String key) => key
    .replaceAll('_', ' ')
    .split(' ')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

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
                // Thumbnail — shows the owner's chosen image (web or own photo)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: (result?.imageUrl.isNotEmpty == true && edit.useWebImage)
                      ? CachedNetworkImage(
                          imageUrl: result!.imageUrl,
                          width: 64, height: 64, fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Image.file(
                            File(job.imagePath), width: 64, height: 64, fit: BoxFit.cover,
                          ),
                        )
                      : Image.file(
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
                          edit.categoryCtrl.text.trim().isNotEmpty
                              ? edit.categoryCtrl.text.trim()
                              : 'Tap "More details" to set category',
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
                  // Image source toggle — only when a web image was found
                  if (result?.imageUrl.isNotEmpty == true)
                    GestureDetector(
                      onTap: () {
                        edit.useWebImage = !edit.useWebImage;
                        onChanged();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade100),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              edit.useWebImage
                                  ? Icons.cloud_outlined
                                  : Icons.photo_camera_outlined,
                              size: 16,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                edit.useWebImage
                                    ? 'Using web image — tap to use your photo'
                                    : 'Using your photo — tap to use web image',
                                style: TextStyle(
                                    fontSize: 11.5, color: Colors.blue.shade700),
                              ),
                            ),
                            Icon(Icons.swap_horiz,
                                size: 16, color: Colors.blue.shade700),
                          ],
                        ),
                      ),
                    ),
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

                  // "More details" — collapsed by default. Lets the owner edit
                  // the auto-filled category and every attribute Gemini pulled
                  // out (colour, sizes, material, strength, …) only if they want.
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () {
                      edit.expanded = !edit.expanded;
                      onChanged();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(
                            edit.expanded
                                ? Icons.expand_less
                                : Icons.expand_more,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            edit.expanded ? 'Hide details' : 'More details / edit',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (edit.expanded) ...[
                    const SizedBox(height: 4),
                    _Field(
                      label: 'Category',
                      controller: edit.categoryCtrl,
                      hint: 'e.g. Footwear, Men\'s Wear',
                    ),
                    for (final entry in edit.attrCtrls.entries) ...[
                      const SizedBox(height: 8),
                      _Field(
                        label: _prettyLabel(entry.key),
                        controller: entry.value,
                        hint: '',
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Collapsed list of shots Gemini couldn't identify (blurry frames, box sides,
/// anything without a clear label). These are auto-skipped — never added — and
/// hidden here so they don't clutter the main review list.
class _UnclearSection extends StatelessWidget {
  final List<_EditState> edits;
  const _UnclearSection({required this.edits});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(Icons.help_outline, color: Colors.grey.shade500),
          title: Text(
            '${edits.length} shot${edits.length == 1 ? '' : 's'} couldn\'t be identified',
            style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700),
          ),
          subtitle: const Text('Skipped — not added',
              style: TextStyle(fontSize: 11, color: Colors.grey)),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in edits)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(e.job.imagePath),
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 64,
                        height: 64,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image, color: Colors.grey),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
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
