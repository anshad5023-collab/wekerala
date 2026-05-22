import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_config.dart';
import '../../../core/services/fcm_service.dart';
import '../../../core/widgets/adaptive_scaffold.dart';
import '../../../providers/role_provider.dart';
import '../../../providers/shop_provider.dart';
import '../../billing/screens/billing_screen.dart';
import '../../analytics/screens/analytics_screen.dart';
import '../../credits/screens/credits_screen.dart';

class BusinessHomeScreen extends ConsumerStatefulWidget {
  const BusinessHomeScreen({super.key});

  @override
  ConsumerState<BusinessHomeScreen> createState() => _BusinessHomeScreenState();
}

class _BusinessHomeScreenState extends ConsumerState<BusinessHomeScreen> {
  int _tabIndex = 1; // default to Orders
  List<Map<String, dynamic>> _allBusinesses = [];
  Map<String, dynamic>? _activeBusiness;
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
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!mounted) return;
      final data = userDoc.data() ?? {};

      final results = <Map<String, dynamic>>[];

      // Always load shops — they are registered separately and may not be in businessTypes
      final shopSnap = await FirebaseFirestore.instance
          .collection('shops')
          .where('ownerId', isEqualTo: uid)
          .get();
      for (final doc in shopSnap.docs) {
        results.add({...doc.data(), '_id': doc.id, '_collection': 'shops'});
      }

      // Load other business types (exclude 'shops' to avoid duplicates)
      final types = List<String>.from(data['businessTypes'] as List? ?? [])
        ..remove('shops');
      for (final type in types) {
        try {
          final snap = await FirebaseFirestore.instance
              .collection(type)
              .where('ownerId', isEqualTo: uid)
              .get();
          for (final doc in snap.docs) {
            results.add({...doc.data(), '_id': doc.id, '_collection': type});
          }
        } catch (_) {
          // Skip collections we don't have permission to read
        }
      }
      if (!mounted) return;
      setState(() {
        _allBusinesses = results;
        _activeBusiness = results.isNotEmpty ? results.first : null;
        _loading = false;
      });

      // Sync activeShopId so Products/Analytics/Settings screens work correctly
      final firstShop = results.firstWhere(
        (b) => b['_collection'] == 'shops',
        orElse: () => <String, dynamic>{},
      );
      if (firstShop.isNotEmpty) {
        await _syncActiveShopId(firstShop['_id'] as String);
        if (mounted) ref.invalidate(activeShopIdProvider);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    await ref.read(roleProvider.notifier).clear();
    if (mounted) context.go('/google-signin');
  }

  Future<void> _syncActiveShopId(String shopId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'activeShopId': shopId});
    await FcmService.init(shopId);
  }

  void _openSelector() {
    if (_allBusinesses.length <= 1) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _BusinessSelectorSheet(
          businesses: _allBusinesses,
          active: _activeBusiness,
          onSelect: (biz) {
            setState(() => _activeBusiness = biz);
            if (biz['_collection'] == 'shops') {
              _syncActiveShopId(biz['_id'] as String);
            }
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bizId = _activeBusiness?['_id'] as String? ?? '';
    final shopId = bizId;
    final isCashier = shopId.isNotEmpty
        ? ref.watch(isCashierProvider(shopId))
        : false;

    // Clamp tab index so it never goes out of bounds when role changes.
    final maxIndex = isCashier ? 1 : 4;
    if (_tabIndex > maxIndex) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => setState(() => _tabIndex = 0));
    }

    // ── Destination lists based on role ──────────────────────────────────────
    const allDestinations = [
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Home',
      ),
      NavigationDestination(
        icon: Icon(Icons.receipt_long_outlined),
        selectedIcon: Icon(Icons.receipt_long),
        label: 'Orders',
      ),
      NavigationDestination(
        icon: Icon(Icons.bar_chart_outlined),
        selectedIcon: Icon(Icons.bar_chart),
        label: 'Analytics',
      ),
      NavigationDestination(
        icon: Icon(Icons.account_balance_wallet_outlined),
        selectedIcon: Icon(Icons.account_balance_wallet),
        label: 'Udhar',
      ),
      NavigationDestination(
        icon: Icon(Icons.menu_outlined),
        selectedIcon: Icon(Icons.menu),
        label: 'More',
      ),
    ];

    // Cashier sees: Billing (index 0) and Orders (index 1).
    const cashierDestinations = [
      NavigationDestination(
        icon: Icon(Icons.point_of_sale_outlined),
        selectedIcon: Icon(Icons.point_of_sale),
        label: 'Billing',
      ),
      NavigationDestination(
        icon: Icon(Icons.receipt_long_outlined),
        selectedIcon: Icon(Icons.receipt_long),
        label: 'Orders',
      ),
    ];

    final destinations =
        isCashier ? cashierDestinations : allDestinations;

    return AdaptiveScaffold(
      backgroundColor: AppColors.background,
      selectedIndex: _tabIndex.clamp(0, destinations.length - 1),
      onDestinationSelected: (i) => setState(() => _tabIndex = i),
      destinations: destinations,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.background,
        leading: null,
        title: GestureDetector(
          onTap: _openSelector,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_loading) ...[
                () {
                  final logo = _activeBusiness?['logoUrl'] as String? ?? '';
                  return logo.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: CachedNetworkImage(
                            imageUrl: logo,
                            width: 28,
                            height: 28,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const SizedBox.shrink(),
                          ),
                        )
                      : const SizedBox.shrink();
                }(),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  _loading
                      ? 'Loading...'
                      : (_activeBusiness?['name'] as String? ?? 'My Business'),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_allBusinesses.length > 1) ...[
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down, size: 22),
              ],
            ],
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.language),
            tooltip: 'Browse Oratas',
            onPressed: () => launchUrl(
              Uri.parse(AppConfig.storefrontBaseUrl),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
      ),
      floatingActionButton: (!isCashier && _activeBusiness?['_collection'] == 'shops')
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/billing'),
              backgroundColor: AppColors.accent,
              elevation: 4,
              icon: const Icon(Icons.receipt_long, color: Colors.white),
              label: const Text(
                'Quick Bill',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : bizId.isEmpty
              ? _NoShopPlaceholder(onSignOut: _signOut)
              : isCashier
                  ? IndexedStack(
                      index: _tabIndex.clamp(0, 1),
                      children: [
                        const BillingScreen(),
                        _OrdersTab(key: ValueKey('orders_$bizId'), biz: _activeBusiness),
                      ],
                    )
                  : IndexedStack(
                      index: _tabIndex,
                      children: [
                        _HomeTab(key: ValueKey('home_$bizId'), biz: _activeBusiness),
                        _OrdersTab(key: ValueKey('orders_$bizId'), biz: _activeBusiness),
                        const AnalyticsScreen(),
                        CreditsScreen(key: ValueKey('credits_$bizId')),
                        _MoreTab(biz: _activeBusiness, allBusinesses: _allBusinesses, onSignOut: _signOut, onReload: _load),
                      ],
                    ),
    );
  }
}

// ─── Business Selector Sheet ─────────────────────────────────────────────────

class _BusinessSelectorSheet extends StatelessWidget {
  final List<Map<String, dynamic>> businesses;
  final Map<String, dynamic>? active;
  final ValueChanged<Map<String, dynamic>> onSelect;

  const _BusinessSelectorSheet({
    required this.businesses,
    required this.active,
    required this.onSelect,
  });

  static const _icons = {
    'shops': Icons.storefront,
    'services': Icons.build,
    'theaters': Icons.theaters,
    'hotels': Icons.hotel,
    'restaurants': Icons.restaurant,
    'beauty': Icons.spa,
  };

  static const _labels = {
    'shops': 'Shop',
    'services': 'Service',
    'theaters': 'Theater',
    'hotels': 'Hotel',
    'restaurants': 'Restaurant',
    'beauty': 'Beauty',
  };

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'Switch Business',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          ...businesses.map((biz) {
            final col = biz['_collection'] as String? ?? 'shops';
            final isActive = biz['_id'] == active?['_id'];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Icon(_icons[col] ?? Icons.business, color: AppColors.primary, size: 20),
              ),
              title: Text(biz['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(_labels[col] ?? col),
              trailing: isActive ? Icon(Icons.check_circle, color: AppColors.accent) : null,
              onTap: () => onSelect(biz),
            );
          }),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ─── Tab 0: Home (Dashboard) ─────────────────────────────────────────────────

class _HomeTab extends StatefulWidget {
  final Map<String, dynamic>? biz;
  const _HomeTab({super.key, required this.biz});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  int _pendingOrders = 0;
  double _outstanding = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final shopId = widget.biz?['_id'] as String? ?? '';
    if (shopId.isEmpty || widget.biz?['_collection'] != 'shops') {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final ordersSnap = await FirebaseFirestore.instance
        .collection('shops').doc(shopId).collection('orders')
        .where('status', whereIn: ['new', 'confirmed', 'processing', 'ready'])
        .get();
    final creditsSnap = await FirebaseFirestore.instance
        .collection('shops').doc(shopId).collection('credits')
        .where('status', whereIn: ['open', 'partial'])
        .get();
    double owed = 0;
    for (final d in creditsSnap.docs) {
      final amount = (d.data()['amount'] as num?)?.toDouble() ?? 0;
      final paid = (d.data()['paidAmount'] as num?)?.toDouble() ?? 0;
      owed += (amount - paid);
    }
    if (!mounted) return;
    setState(() {
      _pendingOrders = ordersSnap.docs.length;
      _outstanding = owed;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final biz = widget.biz;
    if (biz == null) return const Center(child: Text('No business selected.'));
    if (biz['_collection'] != 'shops') return _ListingInfoCard(biz: biz);

    final shopName = biz['name'] as String? ?? 'Your Shop';
    final now = DateTime.now();
    final greeting = now.hour < 12 ? 'Good Morning' : now.hour < 17 ? 'Good Afternoon' : 'Good Evening';
    final dateStr = '${_weekday(now.weekday)}, ${now.day} ${_month(now.month)}';

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async { setState(() => _loading = true); await _load(); },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        children: [
          // ── Greeting ─────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 48, height: 48,
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
                    Text(shopName,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      overflow: TextOverflow.ellipsis),
                    Text('$greeting  •  $dateStr',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ).animate().fadeIn(duration: 400.ms),

          const SizedBox(height: 24),

          // ── Summary cards ─────────────────────────────────────────────────
          if (_loading)
            const Center(child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: CircularProgressIndicator(color: AppColors.primary),
            ))
          else
            Row(
              children: [
                Expanded(child: _SummaryCard(
                  icon: Icons.receipt_long,
                  iconBg: AppColors.primary.withValues(alpha: 0.12),
                  iconColor: AppColors.primary,
                  value: '$_pendingOrders',
                  label: 'Pending Orders',
                  onTap: () {},
                )),
                const SizedBox(width: 12),
                Expanded(child: _SummaryCard(
                  icon: Icons.account_balance_wallet,
                  iconBg: AppColors.accent.withValues(alpha: 0.12),
                  iconColor: AppColors.accent,
                  value: '₹${_outstanding.toStringAsFixed(0)}',
                  label: 'Udhar Owed',
                  onTap: () {},
                )),
              ],
            ).animate().fadeIn(duration: 400.ms, delay: 100.ms),

          const SizedBox(height: 28),

          // ── Quick access ──────────────────────────────────────────────────
          const Text('QUICK ACCESS',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.9,
            children: [
              _QuickAccessItem(icon: Icons.inventory_2_outlined, label: 'Products',
                  color: const Color(0xFF5C6BC0), onTap: () => context.push('/products')),
              _QuickAccessItem(icon: Icons.people_outline, label: 'Customers',
                  color: const Color(0xFF26A69A), onTap: () => context.push('/customers')),
              _QuickAccessItem(icon: Icons.auto_awesome, label: 'Reorder AI',
                  color: const Color(0xFF8D6E63), onTap: () => context.push('/reorder')),
              _QuickAccessItem(icon: Icons.celebration, label: 'Festival',
                  color: const Color(0xFFE53935), onTap: () => context.push('/festival')),
            ],
          ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
        ],
      ),
    );
  }

  String _weekday(int d) => ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][d - 1];
  String _month(int m) => ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m - 1];
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String value;
  final String label;
  final VoidCallback onTap;
  const _SummaryCard({required this.icon, required this.iconBg, required this.iconColor, required this.value, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
  const _QuickAccessItem({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 6),
          Text(label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            textAlign: TextAlign.center,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ─── Tab 1: Orders ───────────────────────────────────────────────────────────

class _OrdersTab extends StatefulWidget {
  final Map<String, dynamic>? biz;
  const _OrdersTab({super.key, required this.biz});

  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  String? _filterStatus;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    final biz = widget.biz;
    if (biz == null || biz['_collection'] != 'shops') {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final snap = await FirebaseFirestore.instance
        .collection('shops').doc(biz['_id'] as String)
        .collection('orders')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();
    if (!mounted) return;
    setState(() {
      _orders = snap.docs.map((d) => {...d.data(), '_id': d.id}).toList();
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _filtered =>
      _filterStatus == null ? _orders
      : _orders.where((o) => (o['status'] as String? ?? 'new') == _filterStatus).toList();

  int _count(String s) => _orders.where((o) => (o['status'] as String? ?? 'new') == s).length;

  @override
  Widget build(BuildContext context) {
    if (widget.biz?['_collection'] != 'shops') {
      return const Center(child: Text('Orders are only available for shops.'));
    }
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));

    final filtered = _filtered;
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async { setState(() => _loading = true); await _loadOrders(); },
      child: Column(
        children: [
          // Status filter chips
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _StatusChip(label: 'All', count: _orders.length, selected: _filterStatus == null,
                      color: AppColors.primary, onTap: () => setState(() => _filterStatus = null)),
                  const SizedBox(width: 8),
                  _StatusChip(label: 'New', count: _count('new'), selected: _filterStatus == 'new',
                      color: const Color(0xFFFFA000), onTap: () => setState(() => _filterStatus = _filterStatus == 'new' ? null : 'new')),
                  const SizedBox(width: 8),
                  _StatusChip(label: 'Confirmed', count: _count('confirmed'), selected: _filterStatus == 'confirmed',
                      color: const Color(0xFF1976D2), onTap: () => setState(() => _filterStatus = _filterStatus == 'confirmed' ? null : 'confirmed')),
                  const SizedBox(width: 8),
                  _StatusChip(label: 'Done', count: _count('delivered'), selected: _filterStatus == 'delivered',
                      color: const Color(0xFF43A047), onTap: () => setState(() => _filterStatus = _filterStatus == 'delivered' ? null : 'delivered')),
                ],
              ),
            ),
          ),
          // Orders list
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.textSecondary),
                        const SizedBox(height: 16),
                        Text(_filterStatus == null ? 'No orders yet' : 'No $_filterStatus orders',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        if (_filterStatus == null) ...[
                          const SizedBox(height: 8),
                          const Text('Share your storefront to start\nreceiving orders.',
                              style: TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _OrderCard(order: filtered[i])
                          .animate().fadeIn(duration: 300.ms, delay: Duration(milliseconds: i * 40)),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}


class _StatusChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _StatusChip({required this.label, required this.count, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : color),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: selected ? Colors.white.withValues(alpha: 0.25) : color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: selected ? Colors.white : color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListingInfoCard extends StatelessWidget {
  final Map<String, dynamic> biz;
  const _ListingInfoCard({required this.biz});

  static const _icons = {
    'services': Icons.build,
    'theaters': Icons.theaters,
    'hotels': Icons.hotel,
    'restaurants': Icons.restaurant,
    'beauty': Icons.spa,
  };

  @override
  Widget build(BuildContext context) {
    final col = biz['_collection'] as String? ?? '';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: Icon(_icons[col] ?? Icons.business, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            biz['name'] as String? ?? '',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            biz['district'] as String? ?? '',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if ((biz['description'] as String?)?.isNotEmpty == true) ...[
                  const SizedBox(height: 14),
                  Text(
                    biz['description'] as String,
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.5),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.language, color: AppColors.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Switch to Web tab to preview and share your listing.',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  const _OrderCard({required this.order});

  static const _statusColors = {
    'new': Color(0xFFFFA000),
    'confirmed': Color(0xFF43A047),
    'delivered': Color(0xFF1976D2),
    'cancelled': Color(0xFFD32F2F),
  };

  @override
  Widget build(BuildContext context) {
    final status = (order['status'] as String? ?? 'new').toLowerCase();
    final color = _statusColors[status] ?? const Color(0xFFFFA000);
    final orderId = (order['_id'] as String? ?? '------');
    final shortId = orderId.length > 6 ? orderId.substring(orderId.length - 6) : orderId;
    final items = order['items'] as List? ?? [];
    final total = order['total'] ?? order['totalAmount'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#$shortId',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${items.length} item${items.length == 1 ? '' : 's'}  •  ₹$total',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status[0].toUpperCase() + status.substring(1),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tab 2: Web ──────────────────────────────────────────────────────────────

class _WebTab extends StatefulWidget {
  final Map<String, dynamic>? biz;
  const _WebTab({required this.biz});

  @override
  State<_WebTab> createState() => _WebTabState();
}

class _WebTabState extends State<_WebTab> {
  WebViewController? _controller;
  bool _webLoading = true;

  String get _storefrontUrl {
    final biz = widget.biz;
    if (biz == null) return AppConfig.storefrontBaseUrl;
    final col = biz['_collection'] as String? ?? '';
    final id = biz['_id'] as String? ?? '';
    if (col == 'shops') {
      final websiteMap = biz['website'] as Map<String, dynamic>?;
      // Always use preview=true in the Web Tab — bypasses isPublished cache and
      // lets owners see their site even before publishing.
      if (websiteMap != null) {
        return '${AppConfig.storefrontBaseUrl}/sites/$id?preview=true';
      }
      return '${AppConfig.storefrontBaseUrl}?shopId=$id';
    }
    final ext = biz['externalUrl'] as String?;
    if (ext != null && ext.isNotEmpty) return ext;
    return '${AppConfig.storefrontBaseUrl}/$id';
  }

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) async {
          final url = request.url;
          if (!url.startsWith('http://') && !url.startsWith('https://')) {
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _webLoading = false);
        },
      ))
      ..loadRequest(Uri.parse(_storefrontUrl));
  }

  @override
  void didUpdateWidget(_WebTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldHasWebsite = oldWidget.biz?['website'] != null;
    final newHasWebsite = widget.biz?['website'] != null;
    if (!oldHasWebsite && newHasWebsite) {
      setState(() => _webLoading = true);
      _controller?.loadRequest(Uri.parse(_storefrontUrl));
    }
  }

  void _copyUrl() {
    Clipboard.setData(ClipboardData(text: _storefrontUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied!'), duration: Duration(seconds: 2)),
    );
  }

  void _shareUrl() {
    Share.share(_storefrontUrl, subject: widget.biz?['name'] as String? ?? 'My Store');
  }

  void _openFullScreen() {
    context.push('/website-builder', extra: _storefrontUrl);
  }

  @override
  Widget build(BuildContext context) {
    final biz = widget.biz;
    final isShop = biz?['_collection'] == 'shops';
    final controller = _controller;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action row
          Row(
            children: [
              if (isShop) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/products'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Products', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              _IconBtn(icon: Icons.copy, label: 'Copy', onTap: _copyUrl),
              const SizedBox(width: 8),
              _IconBtn(icon: Icons.share, label: 'Share', onTap: _shareUrl),
            ],
          ).animate().fadeIn(duration: 300.ms),

          const SizedBox(height: 12),

          // URL card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.link, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _storefrontUrl,
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms, delay: 60.ms),

          const SizedBox(height: 14),

          // Live preview
          Text(
            'Live Preview',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),

          Container(
            height: 400,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.surface),
              borderRadius: BorderRadius.circular(14),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                if (controller != null)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      const scale = 0.55;
                      final w = constraints.maxWidth;
                      const h = 400.0;
                      return SizedBox(
                        width: w,
                        height: h,
                        child: OverflowBox(
                          maxWidth: w / scale,
                          maxHeight: h / scale,
                          alignment: Alignment.topLeft,
                          child: Transform.scale(
                            scale: scale,
                            alignment: Alignment.topLeft,
                            child: SizedBox(
                              width: w / scale,
                              height: h / scale,
                              child: WebViewWidget(controller: controller),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                if (_webLoading)
                  Container(
                    color: AppColors.surface,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 120.ms),

          const SizedBox(height: 12),

          // Open full screen
          Center(
            child: TextButton.icon(
              onPressed: _openFullScreen,
              icon: Icon(Icons.open_in_full, size: 16, color: AppColors.primary),
              label: Text(
                'Open full screen',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _IconBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ─── Tab 4: More ─────────────────────────────────────────────────────────────

class _MoreTab extends StatelessWidget {
  final Map<String, dynamic>? biz;
  final List<Map<String, dynamic>> allBusinesses;
  final Future<void> Function() onSignOut;
  final Future<void> Function() onReload;
  const _MoreTab({required this.biz, required this.allBusinesses, required this.onSignOut, required this.onReload});

  Map<String, dynamic>? get _shop {
    final shops = allBusinesses.where((b) => b['_collection'] == 'shops');
    return shops.isNotEmpty ? shops.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final isShop = biz?['_collection'] == 'shops';
    final shop = _shop;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SettingsSection(
          title: 'Store',
          children: [
            if (isShop)
              _SettingsRow(
                icon: Icons.storefront,
                title: 'Shop Settings',
                onTap: () => context.push('/settings/shop'),
              )
            else
              _SettingsRow(
                icon: Icons.edit_outlined,
                title: 'Edit My Listing',
                onTap: () => context.push('/business/listing-form'),
              ),
            if (isShop)
              _SettingsRow(
                icon: Icons.group_outlined,
                title: 'Staff Management',
                onTap: () {
                  final shopId = biz?['_id'] as String? ?? '';
                  context.push('/settings/staff', extra: shopId);
                },
              ),
            if (isShop)
              _SettingsRow(
                icon: Icons.print_outlined,
                title: 'Printer Setup',
                onTap: () => context.push('/settings/printer'),
              ),
            _SettingsRow(
              icon: Icons.share,
              title: 'Share My Listing',
              onTap: () => context.push('/share'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsSection(
          title: 'Business',
          children: [
            _SettingsRow(
              icon: Icons.add_business,
              title: 'Add Another Listing',
              onTap: () => context.push('/business/type'),
            ),
            Builder(builder: (ctx) {
              final targetShop = isShop ? biz : shop;
              final hasWebsite = targetShop?['website'] != null;
              return _SettingsRow(
                icon: Icons.language,
                title: hasWebsite ? 'Edit Website' : 'Create a Website',
                onTap: () {
                  if (targetShop == null) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Register a shop first to build a website.')),
                    );
                    return;
                  }
                  final id = targetShop['_id'] as String? ?? '';
                  final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                  final url = '${AppConfig.storefrontBaseUrl}/control/website?shopId=$id&uid=$uid';
                  ctx.push('/website-builder', extra: url).then((_) => onReload());
                },
              );
            }),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsSection(
          title: 'Reports & Customers',
          children: [
            _SettingsRow(
              icon: Icons.bar_chart,
              title: 'Analytics',
              onTap: () => context.push('/analytics'),
            ),
            _SettingsRow(
              icon: Icons.people,
              title: 'Customers',
              onTap: () => context.push('/customers'),
            ),
            _SettingsRow(
              icon: Icons.person_outline,
              title: 'Account Settings',
              onTap: () => context.push('/settings/account'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsSection(
          title: 'AI Tools',
          children: [
            _SettingsRow(
              icon: Icons.auto_awesome,
              title: 'Smart Reorder 🤖',
              onTap: () => context.push('/reorder'),
            ),
            _SettingsRow(
              icon: Icons.celebration,
              title: 'Festival Auto-Pilot 🎉',
              onTap: () => context.push('/festival'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Sign Out'),
                content: const Text('Are you sure you want to sign out?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
            if (confirmed == true) await onSignOut();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade50,
            foregroundColor: Colors.red,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          icon: const Icon(Icons.logout),
          label: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: children
                .asMap()
                .entries
                .map((e) => Column(
                      children: [
                        e.value,
                        if (e.key < children.length - 1)
                          Divider(height: 1, indent: 52, color: AppColors.textSecondary.withValues(alpha: 0.15)),
                      ],
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _SettingsRow({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 22),
      title: Text(title, style: TextStyle(fontSize: 15, color: AppColors.textPrimary)),
      trailing: Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}

class _NoShopPlaceholder extends StatelessWidget {
  final VoidCallback onSignOut;
  const _NoShopPlaceholder({required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.store_outlined, size: 72, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No shop found for this account.',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'This Windows account is not linked to your Android shop data.\n'
            'Sign out and sign in with the same email you use on Android.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
