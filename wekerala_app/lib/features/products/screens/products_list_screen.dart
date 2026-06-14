import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/layout/adaptive_layout.dart';
import '../../../providers/language_provider.dart';
import '../../../providers/shop_provider.dart';
import '../../../providers/products_provider.dart';
import '../../../models/product_model.dart';
import '../../../shared/widgets/shimmer_list.dart';

class ProductsListScreen extends ConsumerStatefulWidget {
  const ProductsListScreen({super.key});

  @override
  ConsumerState<ProductsListScreen> createState() => _ProductsListScreenState();
}

class _ProductsListScreenState extends ConsumerState<ProductsListScreen> {
  String _search = '';
  String _selectedCategory = 'All';
  bool _showLowStockOnly = false;

  @override
  Widget build(BuildContext context) {
    final translations = ref.watch(translationsProvider);
    String t(String key) => translations[key] ?? key;
    final shopAsync = ref.watch(activeShopIdProvider);

    return shopAsync.when(
      loading: () => const Scaffold(body: ShimmerList()),
      error: (e, _) => Scaffold(body: Center(child: Text(e.toString()))),
      data: (shopId) {
        if (shopId == null) {
          return Scaffold(body: Center(child: Text(t('error_generic'))));
        }
        return _ProductsBody(
          shopId: shopId,
          search: _search,
          selectedCategory: _selectedCategory,
          showLowStockOnly: _showLowStockOnly,
          onSearchChanged: (v) => setState(() => _search = v),
          onCategoryChanged: (v) => setState(() => _selectedCategory = v),
          onLowStockToggled: (v) => setState(() => _showLowStockOnly = v),
        );
      },
    );
  }
}

class _ProductsBody extends ConsumerWidget {
  final String shopId;
  final String search;
  final String selectedCategory;
  final bool showLowStockOnly;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<bool> onLowStockToggled;

  const _ProductsBody({
    required this.shopId,
    required this.search,
    required this.selectedCategory,
    required this.showLowStockOnly,
    required this.onSearchChanged,
    required this.onCategoryChanged,
    required this.onLowStockToggled,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translations = ref.watch(translationsProvider);
    String t(String key) => translations[key] ?? key;
    final productsAsync = ref.watch(productsStreamProvider(shopId));
    final shopAsync = ref.watch(shopStreamProvider(shopId));
    final categories = ['All', ...?shopAsync.value?.categories];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(t('products_title')),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            tooltip: 'Receive Stock',
            onPressed: () => context.push('/stock-receive'),
          ),
          IconButton(
            icon: const Icon(Icons.warning_amber_rounded),
            tooltip: 'Stock Alerts',
            onPressed: () => context.push('/stock-alerts'),
          ),
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: t('products_import'),
            onPressed: () => context.push('/products/import'),
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome_outlined),
            tooltip: 'Starter Catalog',
            onPressed: () => context.push('/products/catalog'),
          ),
        ],
      ),
      body: productsAsync.when(
        loading: () => const ShimmerList(itemHeight: 80),
        error: (e, _) => NoInternetWidget(onRetry: () => ref.invalidate(productsStreamProvider)),
        data: (products) {
          // KPI computations
          final total = products.length;
          final currentLimit = ref.watch(productLimitProvider(shopId));
          final atLimit = total >= currentLimit;
          final lowStockCount = products.where((p) => p.isLowStock).length;
          final totalValue = products.fold<double>(0, (acc, p) {
            final qty = (p.stockQty ?? 0).clamp(0, 999999);
            return acc + (p.price * qty);
          });

          // Filtered list
          final filtered = products.where((p) {
            final matchCat = selectedCategory == 'All' || p.category == selectedCategory;
            final q = search.toLowerCase();
            final matchSearch = search.isEmpty ||
                p.nameEn.toLowerCase().contains(q) ||
                (p.nameMl.isNotEmpty && p.nameMl.toLowerCase().contains(q)) ||
                (p.searchAlias != null && p.searchAlias!.toLowerCase().contains(q)) ||
                (p.barcode != null && p.barcode!.contains(search));
            final matchLowStock = !showLowStockOnly || p.isLowStock;
            return matchCat && matchSearch && matchLowStock;
          }).toList();

          return Column(
            children: [
              // ── Inventory KPI banner ──────────────────────────────────
              _InventoryBanner(
                total: total,
                lowStock: lowStockCount,
                totalValue: totalValue,
              ),
              // ── Search bar ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: t('products_search_hint'),
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: onSearchChanged,
                ),
              ),
              // ── Category / filter chips ───────────────────────────────
              SizedBox(
                height: 40,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  scrollDirection: Axis.horizontal,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: const Text('Low Stock'),
                        selected: showLowStockOnly,
                        onSelected: onLowStockToggled,
                        selectedColor: AppColors.error.withValues(alpha: 0.15),
                        checkmarkColor: AppColors.error,
                        labelStyle: TextStyle(
                          color: showLowStockOnly ? AppColors.error : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: showLowStockOnly ? FontWeight.w600 : FontWeight.normal,
                        ),
                        avatar: showLowStockOnly
                            ? null
                            : const Icon(Icons.warning_amber_rounded,
                                size: 14, color: AppColors.textSecondary),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    if (categories.length > 1)
                      ...categories.asMap().entries.map((entry) {
                        final cat = entry.value;
                        final selected = cat == selectedCategory;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(cat),
                            selected: selected,
                            onSelected: (_) => onCategoryChanged(cat),
                            selectedColor: AppColors.primary.withValues(alpha: 0.2),
                            checkmarkColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: selected ? AppColors.primary : AppColors.textSecondary,
                              fontSize: 12,
                            ),
                            padding: EdgeInsets.zero,
                          ),
                        );
                      }),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // ── Search result count ───────────────────────────────────
              if (search.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Showing ${filtered.length} result${filtered.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              // ── Product list / empty state ────────────────────────────
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(Icons.inventory_2_outlined,
                                    size: 40, color: AppColors.primary),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No products found',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Add your first product to get started',
                                style: TextStyle(
                                    fontSize: 13, color: AppColors.textSecondary),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: () => context.push('/products/add'),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add Product'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(160, 44),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: () => context.push('/products/catalog'),
                                icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                                label: const Text('Import Starter Catalog'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(color: AppColors.primary),
                                  minimumSize: const Size(160, 44),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : AdaptiveLayout(
                        mobile: Column(
                          children: [
                            // Table header — matches desktop columns
                            Container(
                              color: AppColors.primary.withValues(alpha: 0.07),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Row(
                                children: [
                                  const SizedBox(width: 56), // thumb
                                  const SizedBox(width: 12),
                                  const Expanded(
                                      flex: 4,
                                      child: Text('Name',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textSecondary))),
                                  const Expanded(
                                      flex: 2,
                                      child: Text('Price',
                                          textAlign: TextAlign.end,
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textSecondary))),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                      flex: 2,
                                      child: Text('Stock',
                                          textAlign: TextAlign.end,
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textSecondary))),
                                  const SizedBox(width: 68), // status + edit
                                ],
                              ),
                            ),
                            Expanded(
                              child: RefreshIndicator(
                                color: AppColors.primary,
                                onRefresh: () async {
                                  ref.invalidate(productsStreamProvider(shopId));
                                  await Future.delayed(
                                      const Duration(milliseconds: 500));
                                },
                                child: ListView.builder(
                                  padding:
                                      const EdgeInsets.only(bottom: 80),
                                  itemCount: filtered.length + (atLimit ? 1 : 0),
                                  itemBuilder: (_, i) {
                                    if (i == filtered.length) {
                                      // Load More footer
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16, horizontal: 24),
                                        child: OutlinedButton.icon(
                                          icon: const Icon(Icons.expand_more),
                                          label: Text(
                                              'Showing ${filtered.length} products — Load more'),
                                          onPressed: () {
                                            final notifier = ref.read(
                                                productLimitProvider(shopId).notifier);
                                            notifier.state += 200;
                                          },
                                          style: OutlinedButton.styleFrom(
                                            minimumSize:
                                                const Size.fromHeight(48),
                                          ),
                                        ),
                                      );
                                    }
                                    return _ProductTile(
                                        shopId: shopId,
                                        product: filtered[i]);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        desktop: _ProductsDesktopTable(shopId: shopId, products: filtered),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/products/add'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(t('products_add')),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Inventory KPI Banner
// ---------------------------------------------------------------------------

class _InventoryBanner extends StatelessWidget {
  final int total;
  final int lowStock;
  final double totalValue;

  const _InventoryBanner({
    required this.total,
    required this.lowStock,
    required this.totalValue,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##,##0', 'en_IN');
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: [
          _BannerChip(
            label: '$total Products',
            icon: Icons.inventory_2_outlined,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          _BannerChip(
            label: lowStock > 0 ? '$lowStock Low Stock' : 'Stock OK',
            icon: lowStock > 0
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline,
            color: lowStock > 0 ? AppColors.error : AppColors.success,
          ),
          const SizedBox(width: 8),
          _BannerChip(
            label: '₹${fmt.format(totalValue)}',
            icon: Icons.currency_rupee,
            color: AppColors.success,
          ),
        ],
      ),
    );
  }
}

class _BannerChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _BannerChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick stock update bottom sheet
// ---------------------------------------------------------------------------

Future<void> _showQuickStockUpdate(
    BuildContext context, String shopId, ProductModel product) async {
  if (product.stockQty == null) {
    await showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(product.nameEn,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            const Text('Stock tracking is not enabled for this product.',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(context);
                context.push('/products/${product.productId}');
              },
              child: const Text('Edit Product to Enable'),
            ),
          ],
        ),
      ),
    );
    return;
  }

  final currentQty = product.stockQty ?? 0;
  int newQty = currentQty;
  final ctrl = TextEditingController(text: currentQty.toString());
  final priceCtrl = TextEditingController(
      text: product.price > 0 ? product.price.toStringAsFixed(0) : '');

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Text(product.nameEn,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text('Current stock: $currentQty ${product.unit}',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    if (newQty > 0) {
                      setModalState(() {
                        newQty--;
                        ctrl.text = newQty.toString();
                      });
                    }
                  },
                  icon: const Icon(Icons.remove_circle_outline,
                      color: AppColors.error, size: 28),
                ),
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (v) => newQty = int.tryParse(v) ?? newQty,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setModalState(() {
                      newQty++;
                      ctrl.text = newQty.toString();
                    });
                  },
                  icon: const Icon(Icons.add_circle_outline,
                      color: AppColors.success, size: 28),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Quick price update — for meat/fish shops with daily price changes
            TextField(
              controller: priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Price per ${product.unit} (₹)',
                hintText: 'Leave blank to keep current ₹${product.price.toStringAsFixed(0)}',
                border: const OutlineInputBorder(),
                isDense: true,
                prefixText: '₹ ',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    await FirebaseFirestore.instance
                        .collection('shops')
                        .doc(shopId)
                        .collection('products')
                        .doc(product.productId)
                        .update({
                          'stockQty': newQty,
                          if (priceCtrl.text.trim().isNotEmpty &&
                              double.tryParse(priceCtrl.text.trim()) != null &&
                              double.parse(priceCtrl.text.trim()) != product.price)
                            'price': double.parse(priceCtrl.text.trim()),
                          'updatedAt': Timestamp.now(),
                        });
                    if (context.mounted) {
                      final newPrice = double.tryParse(priceCtrl.text.trim()) ?? product.price;
                      final priceChanged = newPrice != product.price;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(priceChanged
                              ? 'Updated: ${product.nameEn} — ₹${newPrice.toStringAsFixed(0)}, $newQty ${product.unit}'
                              : 'Updated: ${product.nameEn} → $newQty ${product.unit}'),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to update: $e'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  ctrl.dispose();
}

// ---------------------------------------------------------------------------
// Product tile (mobile — matches desktop table row style)
// ---------------------------------------------------------------------------

class _ProductTile extends ConsumerWidget {
  final String shopId;
  final ProductModel product;

  const _ProductTile({required this.shopId, required this.product});

  ({String label, Color color}) get _stockStatus {
    if (product.isExpired) return (label: 'Expired', color: const Color(0xFF7B1E1E));
    if (product.isOutOfStock) return (label: 'Out of Stock', color: AppColors.error);
    if (product.isLowStock) return (label: 'Low Stock', color: AppColors.accent);
    return (label: 'In Stock', color: AppColors.success);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = _stockStatus;
    final hasOffer = product.offerPrice > 0 && product.offerPrice < product.price;

    return InkWell(
      onTap: () => context.push('/products/${product.productId}'),
      onLongPress: () => _showQuickStockUpdate(context, shopId, product),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
        ),
        child: Row(
          children: [
            // ── Thumbnail ─────────────────────────────────────────────────
            _ProductThumb(url: product.imageUrl),
            const SizedBox(width: 12),

            // ── Name + Category ───────────────────────────────────────────
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.nameEn,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (product.category.isNotEmpty)
                    Text(
                      product.category,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),

            // ── Price ─────────────────────────────────────────────────────
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${hasOffer ? product.offerPrice.toStringAsFixed(0) : product.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.textPrimary),
                  ),
                  if (hasOffer)
                    Text(
                      '₹${product.price.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                          decoration: TextDecoration.lineThrough),
                    ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // ── Stock ─────────────────────────────────────────────────────
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    product.stockQty != null
                        ? '${product.stockQty!.clamp(0, 999999)}'
                        : '—',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: product.isLowStock ? AppColors.error : AppColors.textPrimary),
                  ),
                  const Text('units',
                      style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // ── Status chip ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: status.color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: status.color.withValues(alpha: 0.3)),
              ),
              child: Text(
                status.label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: status.color),
              ),
            ),

            const SizedBox(width: 8),

            // ── Edit icon ─────────────────────────────────────────────────
            GestureDetector(
              onTap: () => context.push('/products/${product.productId}'),
              child: const Icon(Icons.edit_outlined,
                  size: 18, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductThumb extends StatelessWidget {
  final String url;
  const _ProductThumb({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.image_outlined, color: AppColors.textSecondary),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: url,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(width: 56, height: 56, color: AppColors.surface),
        errorWidget: (_, __, ___) => Container(
          width: 56,
          height: 56,
          color: AppColors.surface,
          child: const Icon(Icons.broken_image_outlined, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Desktop-only DataTable view
// ---------------------------------------------------------------------------

class _ProductsDesktopTable extends StatelessWidget {
  final String shopId;
  final List<ProductModel> products;

  const _ProductsDesktopTable({required this.shopId, required this.products});

  ({String label, Color color}) _stockStatus(ProductModel p) {
    if (p.isExpired) return (label: 'Expired', color: const Color(0xFF7B1E1E));
    if (p.isOutOfStock) return (label: 'Out of Stock', color: AppColors.error);
    if (p.isLowStock) return (label: 'Low Stock', color: AppColors.accent);
    return (label: 'In Stock', color: AppColors.success);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        color: AppColors.surface,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            children: [
              // ── Header ──────────────────────────────────────────────────
              Container(
                color: AppColors.primary.withValues(alpha: 0.07),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const SizedBox(width: 48), // image col
                    const SizedBox(width: 12),
                    _hdr('Name', flex: 4),
                    _hdr('Category', flex: 3),
                    _hdr('Price', flex: 2),
                    _hdr('Stock', flex: 2),
                    _hdr('Status', flex: 2),
                    const SizedBox(width: 48), // actions col
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.grey.shade200),
              // ── Rows ────────────────────────────────────────────────────
              Expanded(
                child: ListView.separated(
                  itemCount: products.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: Colors.grey.shade100),
                  itemBuilder: (ctx, i) {
                    final p = products[i];
                    final status = _stockStatus(p);
                    return InkWell(
                      onTap: () => GoRouter.of(context).push('/products/${p.productId}'),
                      hoverColor: AppColors.primary.withValues(alpha: 0.04),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            _DesktopProductThumb(url: p.imageUrl),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 4,
                              child: Text(
                                p.nameEn,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                p.category.isEmpty ? '—' : p.category,
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: p.offerPrice > 0
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '₹${p.offerPrice.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13),
                                        ),
                                        Text(
                                          '₹${p.price.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 11,
                                              decoration:
                                                  TextDecoration.lineThrough),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      '₹${p.price.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13),
                                    ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                p.stockQty != null
                                    ? p.stockQty!.clamp(0, 999999).toString()
                                    : '—',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: p.isLowStock
                                      ? AppColors.accent
                                      : AppColors.textPrimary,
                                  fontWeight: p.isLowStock
                                      ? FontWeight.w700
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Chip(
                                label: Text(
                                  status.label,
                                  style: TextStyle(
                                    color: status.color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                backgroundColor:
                                    status.color.withValues(alpha: 0.12),
                                side: BorderSide(
                                    color:
                                        status.color.withValues(alpha: 0.35)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              color: AppColors.primary,
                              iconSize: 20,
                              tooltip: 'Edit',
                              onPressed: () => GoRouter.of(context)
                                  .push('/products/${p.productId}'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hdr(String label, {required int flex}) => Expanded(
        flex: flex,
        child: Text(
          label,
          style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDark,
              fontSize: 13),
        ),
      );
}

class _DesktopProductThumb extends StatelessWidget {
  final String url;
  const _DesktopProductThumb({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Icon(Icons.image_outlined, size: 20, color: AppColors.textSecondary),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: CachedNetworkImage(
        imageUrl: url,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        placeholder: (_, __) =>
            Container(width: 40, height: 40, color: AppColors.surface),
        errorWidget: (_, __, ___) => Container(
          width: 40,
          height: 40,
          color: AppColors.surface,
          child: const Icon(Icons.broken_image_outlined,
              size: 20, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
