import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/shop_model.dart';
import '../../../providers/shop_provider.dart';

/// Multi-shop screen: lists every shop the owner has, shows which is active,
/// lets them switch the active shop (the whole app re-scopes to it), and add a
/// new shop. Foundational dashboard — quick per-shop stats; deeper aggregation
/// can come later.
class ManageShopsScreen extends ConsumerWidget {
  const ManageShopsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopsAsync = ref.watch(myShopsProvider);
    final activeId = ref.watch(activeShopIdProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Shops'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/shops/new'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_business),
        label: const Text('Add Shop'),
      ),
      body: shopsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (shops) {
          if (shops.isEmpty) {
            return const Center(child: Text('No shops found.'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              if (shops.length > 1)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8, left: 4),
                  child: Text('Tap a shop to switch to it',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ),
              ...shops.map((s) => _ShopCard(
                    shop: s,
                    isActive: s.shopId == activeId,
                    onSwitch: () async {
                      if (s.shopId == activeId) return;
                      await switchActiveShop(ref, s.shopId);
                      ref.invalidate(myShopsProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Switched to ${s.shopName}'),
                          backgroundColor: AppColors.success,
                        ));
                        context.go('/home');
                      }
                    },
                  )),
            ],
          );
        },
      ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  final ShopModel shop;
  final bool isActive;
  final VoidCallback onSwitch;
  const _ShopCard(
      {required this.shop, required this.isActive, required this.onSwitch});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isActive
              ? AppColors.primary
              : AppColors.textSecondary.withValues(alpha: 0.15),
          width: isActive ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onSwitch,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  shop.shopName.isNotEmpty ? shop.shopName[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shop.shopName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (shop.shopType.isNotEmpty) shop.shopType,
                        if (shop.district.isNotEmpty) shop.district,
                      ].join(' · '),
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text('${shop.totalOrders} orders · ${shop.plan}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              if (isActive)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle,
                          size: 14, color: AppColors.primary),
                      SizedBox(width: 4),
                      Text('Active',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary)),
                    ],
                  ),
                )
              else
                const Icon(Icons.swap_horiz, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
