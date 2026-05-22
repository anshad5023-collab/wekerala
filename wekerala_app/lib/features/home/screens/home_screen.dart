import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/layout/breakpoints.dart';
import '../../../core/services/fcm_service.dart';
import '../../../models/order_model.dart';
import '../../../providers/customers_provider.dart';
import '../../../providers/orders_provider.dart';
import '../../../providers/products_provider.dart';
import '../../../providers/shell_tab_provider.dart'; // also exports ShellTabX extension
import '../../../providers/shop_provider.dart';
import '../../../shared/widgets/shimmer_list.dart';

/// Home dashboard body — no Scaffold, no navigation.
/// Drop it directly into a shell/tab body.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Map<String, dynamic>? _biz;
  int _pendingOrders = 0;
  double _outstanding = 0;
  double _todayRevenue = 0;
  double _yesterdayRevenue = 0;
  int _completedToday = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final shopSnap = await FirebaseFirestore.instance
          .collection('shops')
          .where('ownerId', isEqualTo: uid)
          .limit(1)
          .get();
      if (shopSnap.docs.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final shopDoc = shopSnap.docs.first;
      final shopId = shopDoc.id;
      final biz = {...shopDoc.data(), '_id': shopId, '_collection': 'shops'};

      // Query ALL orders so we can compute revenue from delivered ones too.
      final ordersSnap = await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('orders')
          .get();

      final creditsSnap = await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('credits')
          .where('status', whereIn: ['open', 'partial'])
          .get();

      // Compute udhar owed.
      double owed = 0;
      for (final d in creditsSnap.docs) {
        final amount = (d.data()['amount'] as num?)?.toDouble() ?? 0;
        final paid = (d.data()['paidAmount'] as num?)?.toDouble() ?? 0;
        owed += (amount - paid);
      }

      // Compute today's revenue from delivered orders and pending order count.
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      double revenue = 0;
      int completed = 0;
      int pending = 0;
      const activeStatuses = {'new', 'confirmed', 'processing', 'ready'};
      for (final d in ordersSnap.docs) {
        final status = d.data()['status'] as String? ?? '';
        final ts = d.data()['createdAt'];
        DateTime? createdAt;
        if (ts is Timestamp) createdAt = ts.toDate();
        if (status == 'delivered' &&
            createdAt != null &&
            createdAt.isAfter(todayStart)) {
          revenue += (d.data()['totalAmount'] as num?)?.toDouble() ?? 0;
          completed++;
        }
        if (activeStatuses.contains(status)) {
          pending++;
        }
      }

      // Compute yesterday's revenue.
      final yesterday = DateTime(today.year, today.month, today.day - 1);
      double yRevenue = 0;
      for (final d in ordersSnap.docs) {
        final status = d.data()['status'] as String? ?? '';
        final ts = d.data()['createdAt'];
        DateTime? createdAt;
        if (ts is Timestamp) createdAt = ts.toDate();
        if (createdAt != null &&
            createdAt.isAfter(yesterday) &&
            createdAt.isBefore(todayStart)) {
          if (status == 'delivered' ||
              status == 'ready' ||
              status == 'processing' ||
              status == 'confirmed') {
            yRevenue += (d.data()['totalAmount'] as num?)?.toDouble() ?? 0;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _biz = biz;
        _pendingOrders = pending;
        _outstanding = owed;
        _todayRevenue = revenue;
        _yesterdayRevenue = yRevenue;
        _completedToday = completed;
        _loading = false;
      });

      // Write activeShopId so OrdersListScreen / ProductsListScreen can find it.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'activeShopId': shopId});
      await FcmService.init(shopId); // no-op on Windows/web
      if (mounted) ref.invalidate(activeShopIdProvider);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ShimmerList();
    }
    final biz = _biz;
    if (biz == null) {
      return const Center(
        child: Text('No shop found.', style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    final shopId = biz['_id'] as String;
    final shopName = biz['name'] as String? ?? 'Your Shop';

    // Watch new orders
    final ordersAsync = ref.watch(ordersStreamProvider(shopId));
    final newOrderCount = ordersAsync.valueOrNull?.where((o) => o.status == 'new').length ?? 0;

    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good Morning'
        : now.hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';
    final dateStr = '${_weekday(now.weekday)}, ${now.day} ${_month(now.month)}';

    // ── Desktop: 3-column dashboard ──────────────────────────────────────────
    if (isDesktop(context)) {
      return _DesktopDashboard(
        shopId: shopId,
        shopName: shopName,
        greeting: greeting,
        dateStr: dateStr,
        pendingOrders: _pendingOrders,
        outstanding: _outstanding,
        todayRevenue: _todayRevenue,
        onRefresh: () async {
          setState(() => _loading = true);
          await _load();
        },
      );
    }

    // ── Mobile: KPI dashboard ListView ──────────────────────────────────────
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        setState(() => _loading = true);
        await _load();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        children: [
          if (newOrderCount > 0)
            _NewOrdersBanner(count: newOrderCount),

          // Greeting
          _GreetingRow(shopName: shopName, greeting: greeting, dateStr: dateStr)
              .animate()
              .fadeIn(duration: 400.ms),
          const SizedBox(height: 20),

          // Row 1 — Hero KPI tile: Today's Revenue (full width)
          _HeroRevenueTile(revenue: _todayRevenue, yesterday: _yesterdayRevenue)
              .animate()
              .fadeIn(duration: 400.ms, delay: 80.ms),
          const SizedBox(height: 12),

          // Row 2 — Orders Today + Udhar Owed
          Row(
            children: [
              Expanded(
                child: _KpiTile(
                  value: '$_pendingOrders',
                  label: 'Active orders',
                  background: AppColors.primary,
                  onTap: () => context.switchTab(1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KpiTile(
                  value: '₹${_outstanding.toStringAsFixed(0)}',
                  label: 'Outstanding',
                  background: AppColors.accent,
                  onTap: () => context.push('/credits'),
                ),
              ),
            ],
          ).animate().fadeIn(duration: 400.ms, delay: 150.ms),
          const SizedBox(height: 12),

          // Row 3 — Low Stock + Completed Today (info tiles)
          _InfoTilesRow(
            shopId: shopId,
            completedToday: _completedToday,
          ).animate().fadeIn(duration: 400.ms, delay: 220.ms),
          const SizedBox(height: 28),

          // Row 4 — Quick Access grid
          const Text(
            'QUICK ACCESS',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.9,
            children: [
              _QuickAccessItem(
                icon: Icons.inventory_2_outlined,
                label: 'Products',
                color: const Color(0xFF5C6BC0),
                onTap: () => context.switchTab(2),
              ),
              _QuickAccessItem(
                icon: Icons.people_outline,
                label: 'Customers',
                color: const Color(0xFF26A69A),
                onTap: () => context.push('/customers'),
              ),
              _QuickAccessItem(
                icon: Icons.auto_awesome,
                label: 'Reorder AI',
                color: const Color(0xFF8D6E63),
                onTap: () => context.push('/reorder'),
              ),
              _QuickAccessItem(
                icon: Icons.celebration,
                label: 'Festival',
                color: const Color(0xFFE53935),
                onTap: () => context.push('/festival'),
              ),
            ],
          ).animate().fadeIn(duration: 400.ms, delay: 300.ms),

          // Shop-type-specific feature highlights
          _ShopTypeFeatures(
            shopType: biz['shopType'] as String? ?? '',
          ).animate().fadeIn(duration: 400.ms, delay: 380.ms),
        ],
      ),
    );
  }

  String _weekday(int d) =>
      ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d - 1];
  String _month(int m) => [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m - 1];
}

// ─── Mobile KPI Widgets ───────────────────────────────────────────────────────

/// Row 1 — Full-width hero revenue tile with dark-green gradient.
class _HeroRevenueTile extends StatelessWidget {
  final double revenue;
  final double yesterday;
  const _HeroRevenueTile({required this.revenue, required this.yesterday});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Today's Revenue",
            style: TextStyle(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 6),
          Text(
            '₹${revenue.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryLight,
              height: 1.1,
            ),
          ),
          if (yesterday > 0 || revenue > 0) ...[
            const SizedBox(height: 6),
            Builder(builder: (ctx) {
              if (yesterday == 0 && revenue == 0) return const SizedBox.shrink();
              final isUp = revenue >= yesterday;
              final pct = yesterday == 0
                  ? 100.0
                  : ((revenue - yesterday) / yesterday * 100).abs();
              final pctStr = pct >= 100
                  ? '${pct.toStringAsFixed(0)}%'
                  : '${pct.toStringAsFixed(1)}%';
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isUp
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      color: isUp
                          ? const Color(0xFFB7E4C7)
                          : const Color(0xFFFF8A80),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$pctStr vs yesterday',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

/// Row 2 — Solid-background KPI tile (Orders Today / Udhar Owed).
class _KpiTile extends StatelessWidget {
  final String value;
  final String label;
  final Color background;
  final VoidCallback onTap;

  const _KpiTile({
    required this.value,
    required this.label,
    required this.background,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: background.withValues(alpha: 0.40),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

/// Row 3 — Two compact info tiles: Low Stock + Completed Today.
class _InfoTilesRow extends ConsumerWidget {
  final String shopId;
  final int completedToday;

  const _InfoTilesRow({required this.shopId, required this.completedToday});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lowStockItems = ref.watch(lowStockProductsProvider(shopId));
    final lowStockCount = lowStockItems.length;

    return Row(
      children: [
        Expanded(
          child: _InfoTile(
            icon: Icons.inventory_2_outlined,
            value: '$lowStockCount',
            label: 'Low Stock Items',
            highlight: lowStockCount > 0,
            onTap: () => context.switchTab(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _InfoTile(
            icon: Icons.check_circle_outline,
            value: '$completedToday',
            label: 'Completed Today',
            onTap: () => context.switchTab(1),
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final bool highlight;
  final VoidCallback onTap;

  const _InfoTile({
    required this.icon,
    required this.value,
    required this.label,
    this.highlight = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = highlight ? AppColors.error : AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 20,
                color: highlight ? AppColors.error : AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: highlight ? AppColors.error : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Desktop 3-column layout ──────────────────────────────────────────────────

class _DesktopDashboard extends ConsumerWidget {
  final String shopId;
  final String shopName;
  final String greeting;
  final String dateStr;
  final int pendingOrders;
  final double outstanding;
  final double todayRevenue;
  final Future<void> Function() onRefresh;

  const _DesktopDashboard({
    required this.shopId,
    required this.shopName,
    required this.greeting,
    required this.dateStr,
    required this.pendingOrders,
    required this.outstanding,
    required this.todayRevenue,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersStreamProvider(shopId));
    final lowStockItems = ref.watch(lowStockProductsProvider(shopId));
    final atRiskCustomers = ref.watch(atRiskCustomersProvider(shopId));

    final allOrders = ordersAsync.valueOrNull ?? [];
    final todayDelivered = allOrders.today
        .where((o) => o.status == 'delivered')
        .toList();
    final streamRevenue =
        todayDelivered.fold<double>(0, (acc, o) => acc + o.totalAmount);
    final completedToday = todayDelivered.length;
    final recentOrders = allOrders.take(5).toList();

    // Prefer stream-derived revenue when available; fall back to Firestore value.
    final displayRevenue =
        ordersAsync.hasValue ? streamRevenue : todayRevenue;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Column 1: Summary ─────────────────────────────────────────────
          Expanded(
            flex: 2,
            child: _SummaryColumn(
              shopName: shopName,
              greeting: greeting,
              dateStr: dateStr,
              pendingOrders: pendingOrders,
              outstanding: outstanding,
            ),
          ),
          const SizedBox(width: 16),
          // ── Column 2: Live Orders ─────────────────────────────────────────
          Expanded(
            flex: 3,
            child: _LiveOrdersColumn(
              orders: recentOrders,
              isLoading: ordersAsync.isLoading,
            ),
          ),
          const SizedBox(width: 16),
          // ── Column 3: Quick Stats ─────────────────────────────────────────
          Expanded(
            flex: 2,
            child: _QuickStatsColumn(
              todayRevenue: displayRevenue,
              completedToday: completedToday,
              lowStockCount: lowStockItems.length,
              atRiskCount: atRiskCustomers.length,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Column 1 widget ───────────────────────────────────────────────────────────

class _SummaryColumn extends StatelessWidget {
  final String shopName;
  final String greeting;
  final String dateStr;
  final int pendingOrders;
  final double outstanding;

  const _SummaryColumn({
    required this.shopName,
    required this.greeting,
    required this.dateStr,
    required this.pendingOrders,
    required this.outstanding,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GreetingRow(shopName: shopName, greeting: greeting, dateStr: dateStr),
        const SizedBox(height: 20),
        _SummaryCard(
          icon: Icons.receipt_long,
          iconBg: AppColors.primary.withValues(alpha: 0.12),
          iconColor: AppColors.primary,
          value: '$pendingOrders',
          label: 'Pending Orders',
          onTap: () => context.switchTab(1),
        ),
        const SizedBox(height: 12),
        _SummaryCard(
          icon: Icons.account_balance_wallet,
          iconBg: AppColors.accent.withValues(alpha: 0.12),
          iconColor: AppColors.accent,
          value: '₹${outstanding.toStringAsFixed(0)}',
          label: 'Udhar Owed',
          onTap: () => context.push('/credits'),
        ),
        const SizedBox(height: 24),
        const Text(
          'QUICK ACCESS',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.15,
          children: [
            _QuickAccessItem(
              icon: Icons.inventory_2_outlined,
              label: 'Products',
              color: const Color(0xFF5C6BC0),
              onTap: () => context.switchTab(2),
            ),
            _QuickAccessItem(
              icon: Icons.people_outline,
              label: 'Customers',
              color: const Color(0xFF26A69A),
              onTap: () => context.push('/customers'),
            ),
            _QuickAccessItem(
              icon: Icons.point_of_sale_outlined,
              label: 'Billing',
              color: const Color(0xFF8D6E63),
              onTap: () => context.push('/billing'),
            ),
            _QuickAccessItem(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Credits',
              color: const Color(0xFFE53935),
              onTap: () => context.push('/credits'),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Column 2 widget ───────────────────────────────────────────────────────────

class _LiveOrdersColumn extends StatelessWidget {
  final List<OrderModel> orders;
  final bool isLoading;

  const _LiveOrdersColumn({required this.orders, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Live Orders',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (orders.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined,
                        size: 48, color: AppColors.textSecondary),
                    const SizedBox(height: 8),
                    const Text('No orders yet',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            )
          else
            ...orders.map((order) => _OrderRow(order: order)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.switchTab(1),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: EdgeInsets.zero,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('View all',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward, size: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  final OrderModel order;
  const _OrderRow({required this.order});

  static const _statusColors = {
    'new': Color(0xFFFFA000),
    'confirmed': Color(0xFF1976D2),
    'processing': Color(0xFFF57C00),
    'ready': Color(0xFF43A047),
    'delivered': Color(0xFF757575),
    'cancelled': Color(0xFFD32F2F),
  };

  @override
  Widget build(BuildContext context) {
    final status = order.status;
    final color = _statusColors[status] ?? const Color(0xFFFFA000);
    final orderNum = order.orderNumber > 0
        ? '#${order.orderNumber}'
        : '#${order.orderId.substring(order.orderId.length > 6 ? order.orderId.length - 6 : 0)}';
    final name = order.customerName.isNotEmpty ? order.customerName : 'Customer';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(orderNum,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textPrimary)),
                Text(name,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '₹${order.totalAmount.toStringAsFixed(0)}',
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.textPrimary),
          ),
          const SizedBox(width: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status[0].toUpperCase() + status.substring(1),
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Column 3 widget ───────────────────────────────────────────────────────────

class _QuickStatsColumn extends StatelessWidget {
  final double todayRevenue;
  final int completedToday;
  final int lowStockCount;
  final int atRiskCount;

  const _QuickStatsColumn({
    required this.todayRevenue,
    required this.completedToday,
    required this.lowStockCount,
    required this.atRiskCount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TODAY',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),
        // Hero revenue tile in desktop column 3
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDark.withValues(alpha: 0.30),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Today's Revenue",
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 4),
              Text(
                '₹${todayRevenue.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryLight,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _StatTile(
          icon: Icons.check_circle_outline,
          iconColor: AppColors.primary,
          label: 'Orders Completed',
          value: '$completedToday',
        ),
        const SizedBox(height: 20),
        const Text(
          'ALERTS',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),
        _StatTile(
          icon: Icons.inventory_2_outlined,
          iconColor: lowStockCount > 0 ? AppColors.error : AppColors.textSecondary,
          label: 'Low Stock Products',
          value: '$lowStockCount',
          highlight: lowStockCount > 0,
        ),
        const SizedBox(height: 10),
        _StatTile(
          icon: Icons.people_outline,
          iconColor: atRiskCount > 0 ? AppColors.accent : AppColors.textSecondary,
          label: 'At-Risk Customers',
          value: '$atRiskCount',
          highlight: atRiskCount > 0,
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool highlight;

  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: highlight
            ? iconColor.withValues(alpha: 0.06)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: highlight
            ? Border.all(color: iconColor.withValues(alpha: 0.25))
            : null,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
          ),
          Text(
            value,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: highlight ? iconColor : AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _GreetingRow extends StatelessWidget {
  final String shopName;
  final String greeting;
  final String dateStr;

  const _GreetingRow({
    required this.shopName,
    required this.greeting,
    required this.dateStr,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.storefront, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                shopName,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '$greeting  •  $dateStr',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String value;
  final String label;
  final VoidCallback onTap;

  const _SummaryCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 12),
            Text(value,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _QuickAccessItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAccessItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── New Orders Banner ────────────────────────────────────────────────────────

class _NewOrdersBanner extends StatefulWidget {
  final int count;
  const _NewOrdersBanner({required this.count});

  @override
  State<_NewOrdersBanner> createState() => _NewOrdersBannerState();
}

class _NewOrdersBannerState extends State<_NewOrdersBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.7, end: 1.0).animate(_pulse);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.switchTab(1),
      child: FadeTransition(
        opacity: _opacity,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFD32F2F), Color(0xFFB71C1C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD32F2F).withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${widget.count}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.count} new ${widget.count == 1 ? 'order' : 'orders'} waiting!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const Text(
                      'Tap to confirm and process',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white70, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Shop-type Feature Cards ──────────────────────────────────────────────────

class _ShopTypeFeatures extends StatelessWidget {
  final String shopType;
  const _ShopTypeFeatures({required this.shopType});

  // Returns feature cards relevant to the given shopType
  List<_FeatureCard> _cards(BuildContext context) {
    final type = shopType.toLowerCase();

    final isRestaurant = type.contains('restaurant') || type.contains('hotel');
    final isPharmacy   = type.contains('pharmacy');
    final isMeat       = type.contains('meat') || type.contains('fish');
    final isBakery     = type.contains('bakery');

    if (isRestaurant) {
      return [
        _FeatureCard(
          icon: Icons.receipt_outlined,
          title: 'Kitchen Orders (KOT)',
          subtitle: 'Print & manage table orders',
          color: const Color(0xFFE53935),
          onTap: () => GoRouter.of(context).push('/kot'),
        ),
        _FeatureCard(
          icon: Icons.point_of_sale_outlined,
          title: 'Quick Billing',
          subtitle: 'Fast POS for dine-in',
          color: const Color(0xFF43A047),
          onTap: () => GoRouter.of(context).push('/billing'),
        ),
        _FeatureCard(
          icon: Icons.mic_outlined,
          title: 'Voice Order',
          subtitle: 'Take orders by voice',
          color: const Color(0xFF7B1FA2),
          onTap: () => GoRouter.of(context).push('/voice-order'),
        ),
      ];
    }

    if (isPharmacy) {
      return [
        _FeatureCard(
          icon: Icons.warning_amber_outlined,
          title: 'Stock Alerts',
          subtitle: 'Low stock & expiry alerts',
          color: const Color(0xFFE53935),
          onTap: () => GoRouter.of(context).push('/stock-alerts'),
        ),
        _FeatureCard(
          icon: Icons.account_balance_outlined,
          title: 'GST / GSTR-1',
          subtitle: 'Monthly tax summary',
          color: const Color(0xFF1565C0),
          onTap: () => GoRouter.of(context).push('/gstr1'),
        ),
        _FeatureCard(
          icon: Icons.inventory_outlined,
          title: 'Batch Tracking',
          subtitle: 'Track batch & expiry',
          color: const Color(0xFF00838F),
          onTap: () => GoRouter.of(context).push('/products'),
        ),
      ];
    }

    if (isMeat || isBakery) {
      return [
        _FeatureCard(
          icon: Icons.warning_amber_outlined,
          title: 'Expiry Alerts',
          subtitle: 'Track perishable items',
          color: const Color(0xFFE53935),
          onTap: () => GoRouter.of(context).push('/stock-alerts'),
        ),
        _FeatureCard(
          icon: Icons.mic_outlined,
          title: 'Voice Order',
          subtitle: 'Hands-free order entry',
          color: const Color(0xFF7B1FA2),
          onTap: () => GoRouter.of(context).push('/voice-order'),
        ),
        _FeatureCard(
          icon: Icons.point_of_sale_outlined,
          title: 'Quick Billing',
          subtitle: 'POS & receipts',
          color: const Color(0xFF43A047),
          onTap: () => GoRouter.of(context).push('/billing'),
        ),
      ];
    }

    // Default — grocery / general
    return [
      _FeatureCard(
        icon: Icons.auto_awesome_outlined,
        title: 'Reorder AI',
        subtitle: 'Smart restocking suggestions',
        color: const Color(0xFF8D6E63),
        onTap: () => GoRouter.of(context).push('/reorder'),
      ),
      _FeatureCard(
        icon: Icons.warning_amber_outlined,
        title: 'Stock Alerts',
        subtitle: 'Never run out of stock',
        color: const Color(0xFFE53935),
        onTap: () => GoRouter.of(context).push('/stock-alerts'),
      ),
      _FeatureCard(
        icon: Icons.account_balance_outlined,
        title: 'GST / GSTR-1',
        subtitle: 'Monthly tax summary',
        color: const Color(0xFF1565C0),
        onTap: () => GoRouter.of(context).push('/gstr1'),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (shopType.isEmpty) return const SizedBox.shrink();
    final cards = _cards(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        const Text(
          'FEATURES FOR YOUR SHOP',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        ...cards.map((c) => _FeatureTile(card: c)),
      ],
    );
  }
}

class _FeatureCard {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}

class _FeatureTile extends StatelessWidget {
  final _FeatureCard card;
  const _FeatureTile({required this.card});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: card.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: card.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(card.icon, color: card.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(card.title,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  Text(card.subtitle,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
