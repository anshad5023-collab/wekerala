import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/layout/adaptive_layout.dart';
import '../../../providers/language_provider.dart';
import '../../../providers/shop_provider.dart';
import '../../../providers/orders_provider.dart';
import '../../../models/order_model.dart';
import '../../../shared/widgets/shimmer_list.dart';

const _kStatuses = ['all', 'new', 'confirmed', 'processing', 'ready', 'delivered'];

// ─── Helpers ─────────────────────────────────────────────────────────────────

String _relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  return '${diff.inDays}d ago';
}

Color _statusChipColor(String status) {
  switch (status) {
    case 'new':
      return const Color(0xFFF57C00); // amber
    case 'confirmed':
      return const Color(0xFF1976D2); // blue
    case 'processing':
      return const Color(0xFF7B1FA2); // purple
    case 'ready':
      return const Color(0xFF2E7D32); // dark green
    case 'delivered':
      return const Color(0xFF43A047); // green
    case 'cancelled':
      return const Color(0xFFD32F2F); // red
    default:
      return AppColors.textSecondary;
  }
}

String _nextStatusLabel(String status) {
  switch (status) {
    case 'new':
      return 'Confirm';
    case 'confirmed':
      return 'Process';
    case 'processing':
      return 'Ready';
    case 'ready':
      return 'Delivered';
    default:
      return '';
  }
}

String? _nextStatusValue(String status) {
  switch (status) {
    case 'new':
      return 'confirmed';
    case 'confirmed':
      return 'processing';
    case 'processing':
      return 'ready';
    case 'ready':
      return 'delivered';
    default:
      return null;
  }
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class OrdersListScreen extends ConsumerStatefulWidget {
  const OrdersListScreen({super.key});

  @override
  ConsumerState<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends ConsumerState<OrdersListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _kStatuses.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final translations = ref.watch(translationsProvider);
    String t(String key) => translations[key] ?? key;
    final shopAsync = ref.watch(activeShopIdProvider);

    return shopAsync.when(
      loading: () => const Scaffold(body: ShimmerList()),
      error: (e, _) => Scaffold(body: Center(child: Text(e.toString()))),
      data: (shopId) {
        if (shopId == null) return Scaffold(body: Center(child: Text(t('error_generic'))));
        return _OrdersBody(
          shopId: shopId,
          tabs: _tabs,
          t: t,
          searchQuery: _searchQuery,
          onSearchChanged: (v) => setState(() => _searchQuery = v),
        );
      },
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _OrdersBody extends ConsumerWidget {
  final String shopId;
  final TabController tabs;
  final String Function(String) t;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;

  const _OrdersBody({
    required this.shopId,
    required this.tabs,
    required this.t,
    required this.searchQuery,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersStreamProvider(shopId));
    final allOrders = ordersAsync.value ?? [];
    final countByStatus = {
      for (final s in _kStatuses) s: allOrders.where((o) => o.status == s).length,
    };

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(t('orders_title')),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: tabs,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: _kStatuses.map((s) {
            final count = countByStatus[s] ?? 0;
            final badgeColor = s == 'new' ? Colors.red : _statusChipColor(s);
            if (s != 'all' && count > 0) {
              return Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(t('orders_tab_$s')),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('$count',
                          style: const TextStyle(fontSize: 11, color: Colors.white)),
                    ),
                  ],
                ),
              );
            }
            return Tab(text: t(s == 'all' ? 'orders_tab_all' : 'orders_tab_$s'));
          }).toList(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/voice-order'),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.mic, color: Colors.white),
        label: const Text('Voice Order', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          // ── Search bar ──────────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: TextField(
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: t('orders_search_hint'),
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                ),
              ),
            ),
          ),
          // ── Tab content ─────────────────────────────────────────────────────
          Expanded(
            child: ordersAsync.when(
              loading: () => const ShimmerList(),
              error: (e, _) =>
                  NoInternetWidget(onRetry: () => ref.invalidate(ordersStreamProvider)),
              data: (orders) => TabBarView(
                controller: tabs,
                children: _kStatuses.map((s) {
                  // Status filter
                  final statusFiltered = s == 'all'
                      ? orders
                      : orders.where((o) => o.status == s).toList();

                  // Search filter (by customer name OR order number)
                  final q = searchQuery.trim().toLowerCase();
                  final filtered = q.isEmpty
                      ? statusFiltered
                      : statusFiltered.where((o) {
                          return o.customerName.toLowerCase().contains(q) ||
                              o.orderNumber.toString().contains(q);
                        }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.receipt_long_outlined,
                              size: 64, color: AppColors.textSecondary),
                          const SizedBox(height: 12),
                          Text(t('orders_empty'),
                              style: const TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
                    );
                  }

                  final mobileList = RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () async {
                      ref.invalidate(ordersStreamProvider(shopId));
                      await Future.delayed(const Duration(milliseconds: 500));
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                      final order = filtered[i];
                      return Dismissible(
                        key: Key(order.orderId),
                        direction: DismissDirection.horizontal,
                        resizeDuration: null,
                        background: Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 20),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_outline,
                                  color: Color(0xFF2E7D32), size: 28),
                              const SizedBox(width: 8),
                              Text(
                                _nextStatusLabel(order.status),
                                style: const TextStyle(
                                    color: Color(0xFF2E7D32),
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        secondaryBackground: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Cancel',
                                  style: TextStyle(
                                      color: Color(0xFFD32F2F),
                                      fontWeight: FontWeight.w600)),
                              SizedBox(width: 8),
                              Icon(Icons.cancel_outlined,
                                  color: Color(0xFFD32F2F), size: 28),
                            ],
                          ),
                        ),
                        confirmDismiss: (direction) async {
                          if (direction == DismissDirection.startToEnd) {
                            final nextStatus = _nextStatusValue(order.status);
                            if (nextStatus != null) {
                              await updateOrderStatus(
                                  shopId, order.orderId, nextStatus);
                            }
                            return false;
                          } else {
                            if (order.status == 'delivered' ||
                                order.status == 'cancelled') {
                              return false;
                            }
                            final reason = await showDialog<String>(
                              context: ctx,
                              builder: (_) =>
                                  CancelReasonDialog(orderId: order.orderId),
                            );
                            if (reason != null) {
                              await updateOrderStatus(
                                  shopId, order.orderId, 'cancelled',
                                  cancelReason: reason);
                            }
                            return false;
                          }
                        },
                        child: _OrderTile(order: order, shopId: shopId, t: t),
                      );
                    },
                  ),
                  );

                  return AdaptiveLayout(
                    mobile: mobileList,
                    desktop: _OrdersDesktopTable(
                        orders: filtered, shopId: shopId, t: t),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Desktop Table ────────────────────────────────────────────────────────────

class _OrdersDesktopTable extends StatelessWidget {
  final List<OrderModel> orders;
  final String shopId;
  final String Function(String) t;

  const _OrdersDesktopTable({
    required this.orders,
    required this.shopId,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        color: Colors.white,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            children: [
              // ── Header row ─────────────────────────────────────────────────
              Container(
                color: AppColors.primary.withValues(alpha: 0.08),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    _headerCell(t('order_number'), flex: 2),
                    _headerCell(t('customer_name'), flex: 3),
                    _headerCell(t('amount'), flex: 2),
                    _headerCell(t('status'), flex: 2),
                    _headerCell(t('delivery_type'), flex: 2),
                    _headerCell(t('date'), flex: 2),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.grey.shade200),
              // ── Data rows ──────────────────────────────────────────────────
              Expanded(
                child: ListView.separated(
                  itemCount: orders.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: Colors.grey.shade100),
                  itemBuilder: (ctx, i) {
                    final order = orders[i];
                    final chipColor = _statusChipColor(order.status);
                    final dateStr =
                        DateFormat('d MMM yyyy').format(order.createdAt);
                    final isDelivery = order.deliveryType == 'delivery';
                    return InkWell(
                      onTap: () => context.push('/orders/${order.orderId}'),
                      hoverColor: AppColors.primary.withValues(alpha: 0.04),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text('#${order.orderNumber}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(order.customerName,
                                  style: const TextStyle(fontSize: 13)),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '₹${order.totalAmount.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                    fontSize: 13),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Chip(
                                label: Text(
                                  t('status_${order.status}'),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600),
                                ),
                                backgroundColor: chipColor,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 0),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: _DeliveryPill(isDelivery: isDelivery, t: t),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(dateStr,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary)),
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

  Widget _headerCell(String label, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.primaryDark,
          fontSize: 13,
        ),
      ),
    );
  }
}

// ─── Mobile Card ──────────────────────────────────────────────────────────────

class _OrderTile extends StatelessWidget {
  final OrderModel order;
  final String shopId;
  final String Function(String) t;

  const _OrderTile({required this.order, required this.shopId, required this.t});

  @override
  Widget build(BuildContext context) {
    final color = OrderModel.statusColor(order.status);
    final timeStr = _relativeTime(order.createdAt);
    final isDelivery = order.deliveryType == 'delivery';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => context.push('/orders/${order.orderId}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Left status accent bar
              Container(
                width: 4,
                height: 56,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: order number + status badge
                    Row(
                      children: [
                        Text('#${order.orderNumber}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(t('status_${order.status}'),
                              style: TextStyle(color: color, fontSize: 11)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Row 2: customer name
                    Text(order.customerName,
                        style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 4),
                    // Row 3: amount • items count • delivery pill • relative time
                    Row(
                      children: [
                        Text('₹${order.totalAmount.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary)),
                        const SizedBox(width: 6),
                        Text('• ${order.items.length} ${t('orders_item_count')}',
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
                        const SizedBox(width: 6),
                        _DeliveryPill(isDelivery: isDelivery, t: t),
                        const Spacer(),
                        Text(timeStr,
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 11)),
                      ],
                    ),
                    if (order.cancelReason.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Reason: ${order.cancelReason}',
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Delivery pill widget ────────────────────────────────────────────────────

class _DeliveryPill extends StatelessWidget {
  final bool isDelivery;
  final String Function(String) t;

  const _DeliveryPill({required this.isDelivery, required this.t});

  @override
  Widget build(BuildContext context) {
    final color =
        isDelivery ? const Color(0xFF1976D2) : const Color(0xFF7B1FA2);
    final label = isDelivery ? t('delivery_type_delivery') : t('delivery_type_pickup');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── Cancel Reason Dialog ─────────────────────────────────────────────────────

class CancelReasonDialog extends StatefulWidget {
  final String orderId;
  const CancelReasonDialog({super.key, required this.orderId});

  @override
  State<CancelReasonDialog> createState() => CancelReasonDialogState();
}

class CancelReasonDialogState extends State<CancelReasonDialog> {
  static const _reasons = [
    'Customer requested cancellation',
    'Item out of stock',
    'Duplicate order',
    'Delivery not possible',
    'Payment issue',
    'Other',
  ];

  String _selected = 'Customer requested cancellation';
  final _otherCtrl = TextEditingController();

  @override
  void dispose() {
    _otherCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cancel Order'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select a reason:',
              style: TextStyle(fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 8),
          ..._reasons.map(
            (r) => RadioListTile<String>(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(r, style: const TextStyle(fontSize: 13)),
              value: r,
              groupValue: _selected,
              onChanged: (v) => setState(() => _selected = v!),
            ),
          ),
          if (_selected == 'Other')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextField(
                controller: _otherCtrl,
                decoration: const InputDecoration(
                  hintText: 'Describe reason...',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Back'),
        ),
        FilledButton(
          onPressed: () {
            final reason = _selected == 'Other'
                ? (_otherCtrl.text.trim().isNotEmpty
                    ? _otherCtrl.text.trim()
                    : 'Other')
                : _selected;
            Navigator.of(context).pop(reason);
          },
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Cancel Order'),
        ),
      ],
    );
  }
}
