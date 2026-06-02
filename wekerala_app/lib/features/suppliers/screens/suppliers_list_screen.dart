import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/supplier_model.dart';
import '../../../providers/shop_provider.dart';
import '../../../providers/suppliers_provider.dart';
import '../../../shared/widgets/shimmer_list.dart';

class SuppliersListScreen extends ConsumerWidget {
  const SuppliersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopAsync = ref.watch(activeShopIdProvider);
    return shopAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: ShimmerList(),
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
        return _SuppliersBody(shopId: shopId);
      },
    );
  }
}

class _SuppliersBody extends ConsumerStatefulWidget {
  final String shopId;
  const _SuppliersBody({required this.shopId});

  @override
  ConsumerState<_SuppliersBody> createState() => _SuppliersBodyState();
}

class _SuppliersBodyState extends ConsumerState<_SuppliersBody> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<SupplierModel> _applySearch(List<SupplierModel> all) {
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all
        .where((s) =>
            s.name.toLowerCase().contains(q) ||
            s.phone.toLowerCase().contains(q) ||
            s.categories.any((c) => c.toLowerCase().contains(q)))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(suppliersStreamProvider(widget.shopId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Suppliers',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        automaticallyImplyLeading: false,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/stock-receive'),
            icon: const Icon(Icons.inventory_2_outlined,
                color: Colors.white, size: 18),
            label: const Text('Receive Stock',
                style: TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.success,
        foregroundColor: Colors.white,
        onPressed: () => context.push('/suppliers/add'),
        child: const Icon(Icons.add),
      ),
      body: suppliersAsync.when(
        loading: () => const ShimmerList(),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (allSuppliers) {
          final displayed = _applySearch(allSuppliers);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v.trim()),
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search by name, phone or category...',
                    hintStyle: const TextStyle(color: AppColors.textSecondary),
                    prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: displayed.isEmpty
                    ? _EmptyState(hasSuppliers: allSuppliers.isNotEmpty)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: displayed.length,
                        itemBuilder: (_, i) => _SupplierCard(
                          supplier: displayed[i],
                          shopId: widget.shopId,
                        )
                            .animate()
                            .fadeIn(duration: 250.ms, delay: (i * 30).ms)
                            .slideY(begin: 0.06, duration: 250.ms),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SupplierCard extends StatelessWidget {
  final SupplierModel supplier;
  final String shopId;

  const _SupplierCard({required this.supplier, required this.shopId});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: AppColors.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/suppliers/${supplier.supplierId}', extra: supplier),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary,
                child: Text(
                  supplier.name.isNotEmpty ? supplier.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      supplier.name.isNotEmpty ? supplier.name : 'Unknown',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      supplier.phone,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    if (supplier.categories.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: supplier.categories.take(3).map((cat) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              cat,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasSuppliers;

  const _EmptyState({required this.hasSuppliers});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasSuppliers
                  ? Icons.search_off_rounded
                  : Icons.local_shipping_outlined,
              size: 72,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              hasSuppliers
                  ? 'No suppliers match your search.'
                  : 'No suppliers yet.',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (!hasSuppliers)
              const Text(
                'Tap the + button to add your first supplier.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}
