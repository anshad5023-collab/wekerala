import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/product_model.dart';
import '../../../providers/products_provider.dart';
import '../../../providers/shop_provider.dart';
import '../../../shared/widgets/shimmer_list.dart';

class StockAlertsScreen extends ConsumerWidget {
  const StockAlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopAsync = ref.watch(activeShopIdProvider);

    return shopAsync.when(
      loading: () => const Scaffold(body: ShimmerList()),
      error: (e, _) => Scaffold(body: Center(child: Text(e.toString()))),
      data: (shopId) {
        if (shopId == null) {
          return const Scaffold(body: Center(child: Text('No shop found')));
        }
        return _StockAlertsBody(shopId: shopId);
      },
    );
  }
}

class _StockAlertsBody extends ConsumerWidget {
  final String shopId;
  const _StockAlertsBody({required this.shopId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lowStockProducts = ref.watch(lowStockProductsProvider(shopId));
    final zeroStockProducts = ref.watch(zeroStockProductsProvider(shopId));
    final allProductsAsync = ref.watch(productsStreamProvider(shopId));

    // Sort by urgency: zero-stock first, then lowest ratio
    final sorted = [...lowStockProducts]..sort((a, b) {
        final ratioA = a.lowStockThreshold > 0
            ? (a.stockQty ?? 0) / a.lowStockThreshold
            : 1.0;
        final ratioB = b.lowStockThreshold > 0
            ? (b.stockQty ?? 0) / b.lowStockThreshold
            : 1.0;
        return ratioA.compareTo(ratioB);
      });

    final now = DateTime.now();
    final thirtyDaysFromNow = now.add(const Duration(days: 30));
    // Include both already-expired and expiring-soon products
    final expiringProducts = allProductsAsync.when(
      data: (products) => products
          .where((p) => p.expiryDate != null &&
              p.expiryDate!.isBefore(thirtyDaysFromNow))
          .toList()
        ..sort((a, b) => a.expiryDate!.compareTo(b.expiryDate!)),
      loading: () => <ProductModel>[],
      error: (_, __) => <ProductModel>[],
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Stock Alerts'),
        backgroundColor: AppColors.error,
        foregroundColor: Colors.white,
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.warning_amber_rounded, color: Colors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary chip
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: sorted.isEmpty
                    ? AppColors.success.withValues(alpha: 0.1)
                    : AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: sorted.isEmpty
                      ? AppColors.success.withValues(alpha: 0.3)
                      : AppColors.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    sorted.isEmpty
                        ? Icons.check_circle_outline
                        : Icons.inventory_2_outlined,
                    color: sorted.isEmpty ? AppColors.success : AppColors.error,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    sorted.isEmpty
                        ? 'All products are well stocked!'
                        : '${sorted.length} product${sorted.length == 1 ? '' : 's'} need restocking',
                    style: TextStyle(
                      color: sorted.isEmpty ? AppColors.success : AppColors.error,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // List or empty state
          Expanded(
            child: sorted.isEmpty && expiringProducts.isEmpty && zeroStockProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 80, color: AppColors.success.withValues(alpha: 0.7)),
                        const SizedBox(height: 16),
                        const Text(
                          'All products are well stocked!',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'No restocking needed right now.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 80),
                    children: [
                      // OUT OF STOCK — shown first, most urgent
                      if (zeroStockProducts.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Row(children: [
                            const Icon(Icons.block_outlined,
                                color: AppColors.error, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'OUT OF STOCK (${zeroStockProducts.length})',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: AppColors.error),
                            ),
                          ]),
                        ),
                        ...zeroStockProducts.map((p) => _StockAlertTile(shopId: shopId, product: p)),
                        const Divider(height: 1),
                      ],

                      // Expiring Soon section
                      if (expiringProducts.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  color: Color(0xFFF57C00), size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'Expiring / Expired (${expiringProducts.length})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: Color(0xFFF57C00),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text('within 30 days',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        ...expiringProducts.map((p) => _ExpiryTile(product: p)),
                        const Divider(height: 1),
                      ],
                      // Low Stock section
                      if (sorted.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Row(
                            children: [
                              const Icon(Icons.inventory_2_outlined,
                                  color: AppColors.error, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'Low Stock (${sorted.length})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppColors.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...sorted.map((p) => Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              child: _StockAlertTile(
                                  shopId: shopId, product: p),
                            )),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _StockAlertTile extends StatelessWidget {
  final String shopId;
  final ProductModel product;

  const _StockAlertTile({required this.shopId, required this.product});

  Future<void> _showUpdateDialog(BuildContext context) async {
    final controller = TextEditingController(
      text: product.stockQty?.toString() ?? '',
    );

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Update Stock: ${product.nameEn}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current stock: ${product.stockQty ?? 'N/A'} | Threshold: ${product.lowStockThreshold}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'New stock quantity',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                suffixText: product.unit,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              final qty = int.tryParse(controller.text.trim());
              if (qty == null || qty < 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid whole number (0 or more)')),
                );
                return;
              }
              Navigator.of(ctx).pop(qty);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('products')
          .doc(product.productId)
          .update({
        'stockQty': result,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final stock = product.stockQty ?? 0;
    final threshold = product.lowStockThreshold;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Warning icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: AppColors.error, size: 20),
            ),
            const SizedBox(width: 12),
            // Product info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.nameEn,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
                          width: 0.8),
                    ),
                    child: Text(
                      '$stock in stock / threshold: $threshold',
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (product.category.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      product.category,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            // Action buttons column
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showUpdateDialog(context),
                  child: const Text(
                    'Update\nStock',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF25D366),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    final msg = Uri.encodeComponent(
                        'Hi, please send ${product.nameEn} urgently. '
                        'Current stock: $stock ${product.unit}.');
                    await launchUrl(
                      Uri.parse('https://wa.me/?text=$msg'),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  child: const Text(
                    'Reorder\nWhatsApp',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
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

class _ExpiryTile extends StatelessWidget {
  final ProductModel product;
  const _ExpiryTile({required this.product});

  String _daysUntilExpiry() {
    final days = product.expiryDate!.difference(DateTime.now()).inDays;
    if (days < 0) return 'EXPIRED ${-days} day${-days == 1 ? '' : 's'} ago!';
    if (days == 0) return 'Expires today!';
    if (days == 1) return 'Expires tomorrow';
    return 'Expires in $days days';
  }

  Color _urgencyColor() {
    final days = product.expiryDate!.difference(DateTime.now()).inDays;
    if (days < 0) return AppColors.error;
    if (days <= 3) return AppColors.error;
    if (days <= 7) return const Color(0xFFF57C00);
    return const Color(0xFF1976D2);
  }

  @override
  Widget build(BuildContext context) {
    final color = _urgencyColor();
    final days = product.expiryDate!.difference(DateTime.now()).inDays;
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: days < 0
              ? Icon(Icons.warning_rounded, color: color, size: 22)
              : Text(
                  '$days\nd',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    height: 1.1,
                  ),
                ),
        ),
      ),
      title: Text(product.nameEn,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_daysUntilExpiry(),
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w500)),
          if (product.batchNumber != null && product.batchNumber!.isNotEmpty)
            Text('Batch: ${product.batchNumber}',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11)),
        ],
      ),
      trailing: Text(
        '${product.stockQty ?? '–'} ${product.unit}',
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
    );
  }
}
