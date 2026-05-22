import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_colors.dart';
import '../../shared/widgets/offline_banner.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/orders/screens/orders_list_screen.dart';
import '../../features/products/screens/products_list_screen.dart';
import '../../features/billing/screens/billing_screen.dart';
import '../../features/settings/screens/settings_hub_screen.dart';
import '../../providers/shop_provider.dart';
import '../../providers/orders_provider.dart';
import '../../providers/shell_tab_provider.dart';
import '../../providers/role_provider.dart';
import '../services/stock_notification_service.dart';
import 'breakpoints.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _notificationChecked = false;

  @override
  void initState() {
    super.initState();
    // Defer stock check until the first frame so providers are ready
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _checkNotifications());
  }

  Future<void> _checkNotifications() async {
    if (_notificationChecked) return;
    _notificationChecked = true;
    final shopId = ref.read(activeShopIdProvider).valueOrNull ?? '';
    if (shopId.isNotEmpty) {
      await StockNotificationService.checkAndNotify(shopId);
    }
  }

  static const List<_ShellDestination> _destinations = [
    _ShellDestination(label: 'Home',     icon: Icons.home_outlined,          selectedIcon: Icons.home),
    _ShellDestination(label: 'Orders',   icon: Icons.receipt_long_outlined,  selectedIcon: Icons.receipt_long),
    _ShellDestination(label: 'Products', icon: Icons.inventory_2_outlined,   selectedIcon: Icons.inventory_2),
    _ShellDestination(label: 'Billing',  icon: Icons.point_of_sale_outlined, selectedIcon: Icons.point_of_sale),
    _ShellDestination(label: 'Settings', icon: Icons.settings_outlined,      selectedIcon: Icons.settings),
  ];

  static const List<Widget> _bodies = [
    HomeScreen(),
    OrdersListScreen(),
    ProductsListScreen(),
    BillingScreen(),
    SettingsHubScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final shopAsync = ref.watch(activeShopIdProvider);
    final shopId = shopAsync.valueOrNull ?? '';

    // Live new-orders count for badge
    final newOrderCount = shopId.isNotEmpty
        ? ref
            .watch(ordersStreamProvider(shopId))
            .valueOrNull
            ?.where((o) => o.status == 'new')
            .length ?? 0
        : 0;

    // Shop name for sidebar header
    final shopName = shopId.isNotEmpty
        ? ref.watch(shopStreamProvider(shopId)).valueOrNull?.shopName ?? ''
        : '';

    // Role-based tab filtering — cashiers see only Home, Orders, Billing
    final isCashier = shopId.isNotEmpty
        ? ref.watch(isCashierProvider(shopId))
        : false;

    final visibleDestinations = isCashier
        ? [_destinations[0], _destinations[1], _destinations[3]] // Home, Orders, Billing
        : _destinations;
    final visibleBodies = isCashier
        ? [_bodies[0], _bodies[1], _bodies[3]]
        : _bodies;

    final selectedIndex = ref.watch(shellTabProvider);

    // Clamp selected index to visible tab count
    final clampedIndex = selectedIndex.clamp(0, visibleDestinations.length - 1);
    if (clampedIndex != selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => ref.read(shellTabProvider.notifier).state = clampedIndex);
    }

    final width = MediaQuery.of(context).size.width;
    if (width >= kDesktopBreakpoint) {
      return _DesktopShell(
        selectedIndex: clampedIndex,
        destinations: visibleDestinations,
        bodies: visibleBodies,
        newOrderCount: newOrderCount,
        shopName: shopName,
        onDestinationSelected: (i) =>
            ref.read(shellTabProvider.notifier).state = i,
      );
    }
    return _MobileShell(
      selectedIndex: clampedIndex,
      destinations: visibleDestinations,
      bodies: visibleBodies,
      newOrderCount: newOrderCount,
      onDestinationSelected: (i) =>
          ref.read(shellTabProvider.notifier).state = i,
    );
  }
}

// ─── Mobile ───────────────────────────────────────────────────────────────────

class _MobileShell extends StatelessWidget {
  const _MobileShell({
    required this.selectedIndex,
    required this.destinations,
    required this.bodies,
    required this.newOrderCount,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final List<_ShellDestination> destinations;
  final List<Widget> bodies;
  final int newOrderCount;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OfflineBanner(child: bodies[selectedIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        indicatorColor: AppColors.primary.withValues(alpha: 0.15),
        destinations: destinations.asMap().entries.map((entry) {
          final i = entry.key;
          final d = entry.value;
          // Show badge on Orders tab (index 1)
          final showBadge = i == 1 && newOrderCount > 0;
          final iconWidget = showBadge
              ? Badge(
                  label: Text('$newOrderCount',
                      style: const TextStyle(fontSize: 10, color: Colors.white)),
                  backgroundColor: AppColors.error,
                  child: Icon(d.icon),
                )
              : Icon(d.icon);
          final selectedIconWidget = showBadge
              ? Badge(
                  label: Text('$newOrderCount',
                      style: const TextStyle(fontSize: 10, color: Colors.white)),
                  backgroundColor: AppColors.error,
                  child: Icon(d.selectedIcon, color: AppColors.primary),
                )
              : Icon(d.selectedIcon, color: AppColors.primary);
          return NavigationDestination(
            icon: iconWidget,
            selectedIcon: selectedIconWidget,
            label: d.label,
          );
        }).toList(),
      ),
    );
  }
}

// ─── Desktop ──────────────────────────────────────────────────────────────────

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({
    required this.selectedIndex,
    required this.destinations,
    required this.bodies,
    required this.newOrderCount,
    required this.shopName,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final List<_ShellDestination> destinations;
  final List<Widget> bodies;
  final int newOrderCount;
  final String shopName;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _Sidebar(
            selectedIndex: selectedIndex,
            destinations: destinations,
            newOrderCount: newOrderCount,
            shopName: shopName,
            onDestinationSelected: onDestinationSelected,
          ),
          Expanded(child: OfflineBanner(child: bodies[selectedIndex])),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selectedIndex,
    required this.destinations,
    required this.newOrderCount,
    required this.shopName,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final List<_ShellDestination> destinations;
  final int newOrderCount;
  final String shopName;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: AppColors.primaryDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Brand header ──────────────────────────────────────────────────
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text(
                      'W',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Oratas',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      'Your shop, smarter',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // ── Shop name ────────────────────────────────────────────────────
          if (shopName.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.storefront_outlined, size: 14, color: Colors.white60),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        shopName,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
          const SizedBox(height: 12),
          // ── Nav items ────────────────────────────────────────────────────
          ...destinations.asMap().entries.map((entry) {
            final i = entry.key;
            final d = entry.value;
            final isSelected = i == selectedIndex;
            final showBadge = i == 1 && newOrderCount > 0;

            return _SidebarItem(
              icon: isSelected ? d.selectedIcon : d.icon,
              label: d.label,
              isSelected: isSelected,
              badgeCount: showBadge ? newOrderCount : 0,
              onTap: () => onDestinationSelected(i),
            );
          }),
          const Spacer(),
          // ── Footer ───────────────────────────────────────────────────────
          Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Oratas v1.0',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: isSelected
            ? BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              )
            : null,
        child: Row(
          children: [
            badgeCount > 0
                ? Badge(
                    label: Text('$badgeCount',
                        style: const TextStyle(fontSize: 10, color: Colors.white)),
                    backgroundColor: AppColors.error,
                    child: Icon(icon,
                        size: 20,
                        color: isSelected ? Colors.white : Colors.white60),
                  )
                : Icon(icon,
                    size: 20,
                    color: isSelected ? Colors.white : Colors.white60),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Data class ───────────────────────────────────────────────────────────────

class _ShellDestination {
  const _ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
