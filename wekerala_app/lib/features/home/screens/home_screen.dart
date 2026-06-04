import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
import '../../../providers/billing_provider.dart';
import '../../../shared/widgets/shimmer_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

      // Query only the last 2 days of orders for revenue stats — no need to load all history.
      final twoDaysAgo = Timestamp.fromDate(
          DateTime.now().subtract(const Duration(days: 2)));
      final ordersSnap = await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('orders')
          .where('createdAt', isGreaterThanOrEqualTo: twoDaysAgo)
          .orderBy('createdAt', descending: true)
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
    final shopName = biz['shopName'] as String? ?? 'Your Shop';

    // Watch new orders + today's billing revenue
    final ordersAsync = ref.watch(ordersStreamProvider(shopId));
    final newOrderCount = ordersAsync.valueOrNull?.where((o) => o.status == 'new').length ?? 0;
    final billingSummary = ref.watch(dailySalesSummaryProvider(shopId));
    final billingRevenue = (billingSummary['totalSales'] ?? 0.0) as double;
    final billingCount = ((billingSummary['billCount'] ?? 0.0) as double).toInt();
    // Total revenue = orders delivered today + POS bills today
    final totalTodayRevenue = _todayRevenue + billingRevenue;
    // Completed today = delivered orders + POS bills
    final totalCompletedToday = _completedToday + billingCount;

    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good Morning'
        : now.hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';
    final dateStr = DateFormat('EEE, d MMM').format(now);

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

    final isOpen = biz['isOpen'] as bool? ?? true;

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

          // ── First-use guide (shown only until dismissed) ─
          _FirstUseTipsCard(shopId: shopId),

          // ── Open / Close toggle ──────────────────────────
          _OpenCloseToggle(shopId: shopId, isOpen: isOpen, onChanged: (v) {
            setState(() => _biz = {...biz, 'isOpen': v});
          }),
          const SizedBox(height: 12),

          // Greeting
          _GreetingRow(shopName: shopName, greeting: greeting, dateStr: dateStr)
              .animate()
              .fadeIn(duration: 400.ms),
          const SizedBox(height: 20),

          // Row 1 — Hero KPI tile: Today's Revenue (full width)
          _HeroRevenueTile(revenue: totalTodayRevenue, yesterday: _yesterdayRevenue)
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
            completedToday: totalCompletedToday,
          ).animate().fadeIn(duration: 400.ms, delay: 220.ms),
          const SizedBox(height: 12),

          // Row 3a.5 — Cash / UPI breakdown for today
          _PaymentBreakdownRow(shopId: shopId)
              .animate().fadeIn(duration: 400.ms, delay: 230.ms),
          const SizedBox(height: 12),

          // Row 3b — Expiry alerts (shows only if any products expiring within 7 days)
          _ExpiryAlertsCard(shopId: shopId)
              .animate().fadeIn(duration: 400.ms, delay: 240.ms),

          // Row 3c — Share your store banner
          _ShareStoreBanner(
            shopId: shopId,
            shopSlug: biz['shopSlug'] as String? ?? '',
            shopName: shopName,
          ).animate().fadeIn(duration: 400.ms, delay: 270.ms),
          const SizedBox(height: 20),

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
              _QuickAccessItem(
                icon: Icons.receipt_long_outlined,
                label: 'Bill History',
                color: const Color(0xFF00897B),
                onTap: () => context.push('/bill-history'),
              ),
              _QuickAccessItem(
                icon: Icons.local_shipping_outlined,
                label: 'Suppliers',
                color: const Color(0xFF6D4C41),
                onTap: () => context.push('/suppliers'),
              ),
              _QuickAccessItem(
                icon: Icons.bar_chart_outlined,
                label: 'Analytics',
                color: const Color(0xFF1565C0),
                onTap: () => context.push('/analytics'),
              ),
              _QuickAccessItem(
                icon: Icons.calculate_outlined,
                label: 'Cash Counter',
                color: const Color(0xFF558B2F),
                onTap: () => context.push('/cash-counter'),
              ),
              _QuickAccessItem(
                icon: Icons.campaign_outlined,
                label: 'Marketing',
                color: const Color(0xFFAD1457),
                onTap: () => context.push('/marketing/broadcast'),
              ),
              _QuickAccessItem(
                icon: Icons.mic_outlined,
                label: 'Voice Order',
                color: const Color(0xFF6A1B9A),
                onTap: () => context.push('/voice-order'),
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
  final Color? highlightColor;
  final VoidCallback onTap;

  const _InfoTile({
    required this.icon,
    required this.value,
    required this.label,
    this.highlight = false,
    this.highlightColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final errorColor = highlightColor ?? AppColors.error;
    final borderColor = highlight ? errorColor : AppColors.primary;
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

// ─── Share Store Banner ────────────────────────────────────────────────────────

class _ShareStoreBanner extends StatelessWidget {
  final String shopId;
  final String shopSlug;
  final String shopName;
  const _ShareStoreBanner({
    required this.shopId,
    required this.shopSlug,
    required this.shopName,
  });

  @override
  Widget build(BuildContext context) {
    final url = shopSlug.isNotEmpty
        ? 'https://wekerala.vercel.app/shops/$shopSlug'
        : 'https://wekerala.vercel.app/shop?shopId=$shopId';

    return GestureDetector(
      onTap: () => context.push('/share'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF25D366), Color(0xFF1DA851)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF25D366).withValues(alpha: 0.30),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.share_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Share your store',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    url,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 14),
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
    final orderRevenue =
        todayDelivered.fold<double>(0, (acc, o) => acc + o.totalAmount);
    final billingSummary = ref.watch(dailySalesSummaryProvider(shopId));
    final billingRevenue = (billingSummary['totalSales'] ?? 0.0) as double;
    final billingCount = ((billingSummary['billCount'] ?? 0.0) as double).toInt();
    final streamRevenue = orderRevenue + billingRevenue;
    final completedToday = todayDelivered.length + billingCount;
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

  @override
  Widget build(BuildContext context) {
    final status = order.status;
    final color = OrderModel.statusColor(status);
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

// ── Open / Close toggle card ──────────────────────────────────────────────────

class _OpenCloseToggle extends StatefulWidget {
  final String shopId;
  final bool isOpen;
  final ValueChanged<bool> onChanged;
  const _OpenCloseToggle({required this.shopId, required this.isOpen, required this.onChanged});

  @override
  State<_OpenCloseToggle> createState() => _OpenCloseToggleState();
}

class _OpenCloseToggleState extends State<_OpenCloseToggle> {
  bool _saving = false;

  Future<void> _toggle(bool value) async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.shopId)
          .update({'isOpen': value});
      widget.onChanged(value);
    } catch (_) {} finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final open = widget.isOpen;
    return GestureDetector(
      onTap: _saving ? null : () => _toggle(!open),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: open ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: open ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: open ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                open ? Icons.store : Icons.store_mall_directory_outlined,
                color: Colors.white, size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    open ? 'Shop is Open' : 'Shop is Closed',
                    style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: open ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                    ),
                  ),
                  Text(
                    open ? 'Tap to close your shop' : 'Tap to open your shop',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (_saving)
              const SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Switch(
                value: open,
                activeColor: const Color(0xFF22C55E),
                inactiveThumbColor: const Color(0xFFEF4444),
                inactiveTrackColor: const Color(0xFFFECACA),
                onChanged: _toggle,
              ),
          ],
        ),
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



// ─── Payment Breakdown Row (today's cash / UPI / udhar totals) ───────────────

class _PaymentBreakdownRow extends ConsumerWidget {
  final String shopId;
  const _PaymentBreakdownRow({required this.shopId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dailySalesSummaryProvider(shopId));
    final cash = summary['cashTotal'] ?? 0;
    final upi = summary['upiTotal'] ?? 0;
    final udhar = summary['udharTotal'] ?? 0;

    String fmt(double v) => '₹${v.toStringAsFixed(0)}';

    return Row(
      children: [
        Expanded(
          child: _MiniTile(
            icon: Icons.payments_outlined,
            label: 'Cash Today',
            value: fmt(cash),
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniTile(
            icon: Icons.qr_code_scanner_outlined,
            label: 'UPI Today',
            value: fmt(upi),
            color: const Color(0xFF1565C0),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniTile(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Udhar Given',
            value: fmt(udhar),
            color: udhar > 0 ? AppColors.accent : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _MiniTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MiniTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}// ─── Expiry Alerts Card ───────────────────────────────────────────────────────

class _ExpiryAlertsCard extends ConsumerWidget {
  final String shopId;
  const _ExpiryAlertsCard({required this.shopId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expiring = ref.watch(expiringProductsProvider(shopId));
    if (expiring.isEmpty) return const SizedBox.shrink();

    final now = DateTime.now();
    final expired = expiring.where((p) => p.expiryDate!.isBefore(now)).toList();
    final soonCount = expiring.length - expired.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: expired.isNotEmpty
            ? const Color(0xFFFFEBEE)
            : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: expired.isNotEmpty
              ? const Color(0xFFEF9A9A)
              : const Color(0xFFFFCC02),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: expired.isNotEmpty ? Colors.red.shade700 : Colors.orange.shade700,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expired.isNotEmpty
                      ? '${expired.length} product${expired.length > 1 ? "s" : ""} expired!'
                      : '$soonCount product${soonCount > 1 ? "s" : ""} expiring within 7 days',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: expired.isNotEmpty
                        ? Colors.red.shade800
                        : Colors.orange.shade800,
                  ),
                ),
                Text(
                  expiring.take(3).map((p) => p.nameEn).join(', ') +
                      (expiring.length > 3 ? ' +${expiring.length - 3} more' : ''),
                  style: TextStyle(
                    fontSize: 11,
                    color: expired.isNotEmpty
                        ? Colors.red.shade700
                        : Colors.orange.shade700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => GoRouter.of(context).push('/products'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'View',
              style: TextStyle(
                fontSize: 12,
                color: expired.isNotEmpty
                    ? Colors.red.shade700
                    : Colors.orange.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}class _ShopTypeFeatures extends StatelessWidget {
  final String shopType;
  const _ShopTypeFeatures({required this.shopType});

  // Returns feature cards relevant to the given shopType
  List<_FeatureCard> _cards(BuildContext context) {
    final type = shopType.toLowerCase();

    final isRestaurant = type.contains('restaurant') || type.contains('hotel');
    final isPharmacy   = type.contains('pharmacy');
    final isMeat       = type.contains('meat') || type.contains('fish');
    final isBakery     = type.contains('bakery');
    final isFancy      = type.contains('fancy') || type.contains('gift') || type.contains('stationery');

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

    if (isFancy) {
      return [
        _FeatureCard(
          icon: Icons.bolt_outlined,
          title: 'Flash Sale',
          subtitle: 'Category discounts for events',
          color: const Color(0xFFE91E63),
          onTap: () => GoRouter.of(context).push('/marketing/flash-sale'),
        ),
        _FeatureCard(
          icon: Icons.card_giftcard_outlined,
          title: 'Loyalty Program',
          subtitle: 'Reward repeat customers',
          color: const Color(0xFF7B1FA2),
          onTap: () => GoRouter.of(context).push('/marketing/loyalty'),
        ),
        _FeatureCard(
          icon: Icons.campaign_outlined,
          title: 'Broadcast',
          subtitle: 'Announce new arrivals',
          color: const Color(0xFF1565C0),
          onTap: () => GoRouter.of(context).push('/marketing/broadcast'),
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

// ─── First-Use Tips Card ──────────────────────────────────────────────────────

class _FirstUseTipsCard extends StatefulWidget {
  final String shopId;
  const _FirstUseTipsCard({required this.shopId});

  @override
  State<_FirstUseTipsCard> createState() => _FirstUseTipsCardState();
}

class _FirstUseTipsCardState extends State<_FirstUseTipsCard> {
  bool _visible = false;
  bool _loaded = false;
  static const _key = 'home_tips_dismissed';

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool(_key) ?? false;
    if (mounted) setState(() { _visible = !dismissed; _loaded = true; });
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
    if (mounted) setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || !_visible) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Getting started',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        fontSize: 14)),
              ),
              GestureDetector(
                onTap: _dismiss,
                child: const Icon(Icons.close,
                    size: 18, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _TipRow(
            number: '1',
            title: 'Add your products',
            subtitle: 'Tap Products tab → + button',
            onTap: () => context.push('/products/add'),
          ),
          const SizedBox(height: 8),
          _TipRow(
            number: '2',
            title: 'Bill a customer',
            subtitle: 'Search product → Add to cart → Cash / UPI',
            onTap: () => context.push('/billing'),
          ),
          const SizedBox(height: 8),
          _TipRow(
            number: '3',
            title: 'Track Udhar (credit)',
            subtitle: 'Billing → payment: Udhar → enter customer name',
            onTap: () => context.push('/credits'),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _dismiss,
              child: const Text('Got it, hide this',
                  style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  final String number;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _TipRow({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.primary,
            child: Text(number,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right,
              size: 16, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}