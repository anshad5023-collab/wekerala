import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/gemini_service.dart';
import '../../../models/product_model.dart';
import '../../../providers/orders_provider.dart';
import '../../../providers/products_provider.dart';
import '../../../providers/shop_provider.dart';

class ReorderScreen extends ConsumerWidget {
  const ReorderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopAsync = ref.watch(activeShopIdProvider);
    return shopAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: Text(e.toString())),
      ),
      data: (shopId) {
        if (shopId == null) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: Text('No active shop found.')),
          );
        }
        return _ReorderBody(shopId: shopId);
      },
    );
  }
}

class _ReorderBody extends ConsumerStatefulWidget {
  final String shopId;
  const _ReorderBody({required this.shopId});

  @override
  ConsumerState<_ReorderBody> createState() => _ReorderBodyState();
}

class _ReorderBodyState extends ConsumerState<_ReorderBody> {
  bool _askingGemini = false;
  String? _suggestion;
  final Set<String> _orderedProductIds = {};

  Future<void> _askGemini(List<ProductModel> products, Map<String, int> salesMap) async {
    setState(() { _askingGemini = true; _suggestion = null; });

    final context = products.map((p) => {
      'name': p.nameEn,
      'stock': p.stockQty ?? 0,
      'threshold': p.lowStockThreshold,
      'soldThisWeek': salesMap[p.productId] ?? 0,
      'unit': p.unit,
      'price': p.price.toStringAsFixed(0),
    }).toList();

    final result = await GeminiService.getReorderSuggestions(context);
    if (mounted) setState(() { _suggestion = result; _askingGemini = false; });
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsStreamProvider(widget.shopId));
    final ordersAsync = ref.watch(ordersStreamProvider(widget.shopId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Smart Reorder 🤖', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (products) {
          // Build 7-day sales map
          final salesMap = <String, int>{};
          ordersAsync.whenData((orders) {
            final weekStart = DateTime.now().subtract(const Duration(days: 7));
            for (final o in orders.where((o) => o.createdAt.isAfter(weekStart))) {
              for (final item in o.items) {
                salesMap[item.productId] =
                    (salesMap[item.productId] ?? 0) + item.qty.toInt();
              }
            }
          });

          // Sort: low stock first, then by weekly sales descending
          final sorted = [...products]..sort((a, b) {
            final aLow = a.isLowStock ? 0 : 1;
            final bLow = b.isLowStock ? 0 : 1;
            if (aLow != bLow) return aLow.compareTo(bLow);
            final aSales = salesMap[a.productId] ?? 0;
            final bSales = salesMap[b.productId] ?? 0;
            return aSales.compareTo(bSales);
          });

          final lowStockCount = sorted.where((p) => p.isLowStock).length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              // Summary banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: lowStockCount > 0
                      ? Colors.red.shade50
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: lowStockCount > 0
                        ? Colors.red.shade200
                        : AppColors.textSecondary.withValues(alpha: 0.15),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          lowStockCount > 0
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle_outline,
                          color: lowStockCount > 0 ? Colors.red : AppColors.success,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lowStockCount > 0
                                    ? '$lowStockCount product${lowStockCount == 1 ? '' : 's'} running low'
                                    : 'All products well stocked',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: lowStockCount > 0
                                      ? Colors.red.shade700
                                      : AppColors.success,
                                ),
                              ),
                              Text(
                                '${sorted.length} products tracked  •  past 7 days',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (lowStockCount > 0) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy to WhatsApp'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () {
                          final lowStockProducts = sorted.where((p) =>
                              p.stockQty != null &&
                              p.stockQty! < p.lowStockThreshold).toList();
                          final buf = StringBuffer();
                          buf.writeln('📦 *Reorder List*');
                          buf.writeln('─────────────────');
                          for (final p in lowStockProducts) {
                            final suggestQty = (p.lowStockThreshold * 2 - (p.stockQty ?? 0)).clamp(1, 9999);
                            buf.writeln('• ${p.nameEn}: $suggestQty ${p.unit}');
                          }
                          buf.writeln('─────────────────');
                          buf.writeln('Please arrange ASAP. Thank you!');
                          Clipboard.setData(ClipboardData(text: buf.toString().trim()));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Reorder list copied!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms),

              const SizedBox(height: 16),

              // Ask Gemini button
              ElevatedButton.icon(
                onPressed: _askingGemini ? null : () => _askGemini(sorted, salesMap),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: _askingGemini
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  _askingGemini ? 'Asking Gemini AI...' : 'Ask Gemini for Suggestions',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ).animate().fadeIn(duration: 300.ms, delay: 100.ms),

              // AI Suggestion card
              if (_suggestion != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome,
                              color: AppColors.primary, size: 18),
                          const SizedBox(width: 6),
                          const Text(
                            'Gemini Suggestions',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.primary,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.copy,
                                size: 18, color: AppColors.textSecondary),
                            tooltip: 'Copy',
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: _suggestion!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Copied to clipboard'),
                                    duration: Duration(seconds: 2)),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _suggestion!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms),
              ],

              const SizedBox(height: 20),

              // Section header
              const Text(
                'PRODUCT INVENTORY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),

              // Product rows
              if (sorted.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      'No products found.\nAdd products to track stock.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                ...sorted.asMap().entries.map((e) {
                  final i = e.key;
                  final p = e.value;
                  final weekSales = salesMap[p.productId] ?? 0;
                  return _ProductRow(
                    product: p,
                    weekSales: weekSales,
                    isOrdered: _orderedProductIds.contains(p.productId),
                    onMarkOrdered: () => setState(() {
                      _orderedProductIds.add(p.productId);
                    }),
                  ).animate().fadeIn(
                        duration: 250.ms,
                        delay: Duration(milliseconds: 40 + i * 30),
                      );
                }),
            ],
          );
        },
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  final ProductModel product;
  final int weekSales;
  final bool isOrdered;
  final VoidCallback onMarkOrdered;

  const _ProductRow({
    required this.product,
    required this.weekSales,
    required this.isOrdered,
    required this.onMarkOrdered,
  });

  @override
  Widget build(BuildContext context) {
    final isLow = product.isLowStock;
    final stockQty = product.stockQty;
    final suggestQty = isLow
        ? (product.lowStockThreshold * 2 - (stockQty ?? 0)).clamp(1, 9999)
        : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOrdered
              ? Colors.green.shade200
              : isLow
                  ? Colors.red.shade200
                  : AppColors.textSecondary.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status dot
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 4),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOrdered
                    ? Colors.green
                    : isLow
                        ? Colors.red
                        : AppColors.success,
              ),
            ),
          ),
          // Product info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.nameEn,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  weekSales > 0
                      ? 'Sold this week: $weekSales ${product.unit}'
                      : 'No sales this week',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                if (isLow && !isOrdered) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Order: $suggestQty ${product.unit}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  TextButton(
                    onPressed: onMarkOrdered,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.green.shade700,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Mark Ordered',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Stock badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isOrdered
                      ? Colors.green.shade50
                      : isLow
                          ? Colors.red.shade50
                          : AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  stockQty != null
                      ? '$stockQty ${product.unit}'
                      : 'Not tracked',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isOrdered
                        ? Colors.green.shade700
                        : isLow
                            ? Colors.red.shade700
                            : AppColors.primary,
                  ),
                ),
              ),
              if (isOrdered)
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.check_circle, color: Colors.green, size: 16),
                )
              else if (isLow)
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text(
                    'LOW STOCK',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.red,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
