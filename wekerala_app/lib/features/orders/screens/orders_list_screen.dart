import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/layout/adaptive_layout.dart';
import '../../../models/product_model.dart';
import '../../../providers/language_provider.dart';
import '../../../providers/products_provider.dart';
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

// Status color, nextStatus, nextStatusLabel are on OrderModel — no duplication here.

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
  bool _showTodayOnly = false;

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
          showTodayOnly: _showTodayOnly,
          onTodayToggled: (v) => setState(() => _showTodayOnly = v),
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
  final bool showTodayOnly;
  final ValueChanged<bool> onTodayToggled;

  const _OrdersBody({
    required this.shopId,
    required this.tabs,
    required this.t,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.showTodayOnly,
    required this.onTodayToggled,
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
            final badgeColor = s == 'new' ? Colors.red : OrderModel.statusColor(s);
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
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'voice_order',
            onPressed: () => context.push('/voice-order'),
            backgroundColor: Colors.deepPurple,
            tooltip: 'Voice Order',
            child: const Icon(Icons.mic, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'create_order',
            onPressed: () => _showCreateOrderSheet(context, shopId, ref),
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Create Order', style: TextStyle(color: Colors.white)),
          ),
        ],
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
          // Today / All filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Today'),
                  selected: showTodayOnly,
                  onSelected: onTodayToggled,
                  selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: showTodayOnly ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: showTodayOnly ? FontWeight.w700 : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('All Orders'),
                  selected: !showTodayOnly,
                  onSelected: (v) => onTodayToggled(!v),
                  selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: !showTodayOnly ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: !showTodayOnly ? FontWeight.w700 : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ordersAsync.when(
              loading: () => const ShimmerList(),
              error: (e, _) =>
                  NoInternetWidget(onRetry: () => ref.invalidate(ordersStreamProvider)),
              data: (orders) => TabBarView(
                controller: tabs,
                children: _kStatuses.map((s) {
                  // Today filter
                  final todayStart = DateTime.now();
                  final startOfDay = DateTime(todayStart.year, todayStart.month, todayStart.day);
                  final dateFiltered = showTodayOnly
                      ? orders.where((o) => o.createdAt.isAfter(startOfDay)).toList()
                      : orders;

                  // Status filter
                  final statusFiltered = s == 'all'
                      ? dateFiltered
                      : dateFiltered.where((o) => o.status == s).toList();

                  // Search filter (by customer name OR order number)
                  final q = searchQuery.trim().toLowerCase();
                  final filtered = q.isEmpty
                      ? statusFiltered
                      : statusFiltered.where((o) {
                          return o.customerName.toLowerCase().contains(q) ||
                              o.orderNumber.toString().contains(q);
                        }).toList();

                  if (filtered.isEmpty) {
                    return LottieEmptyState(
                      title: t('orders_empty'),
                      subtitle: q.isNotEmpty ? 'Try a different search term' : null,
                    );
                  }

                  final mobileList = RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () async {
                      ref.invalidate(ordersStreamProvider(shopId));
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
                                OrderModel.nextStatusLabel(order.status),
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
                            final nextStatus = OrderModel.nextStatus(order.status);
                            if (nextStatus != null) {
                              final prevStatus = order.status;
                              await updateOrderStatus(shopId, order.orderId, nextStatus);
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text('Order moved to ${nextStatus[0].toUpperCase()}${nextStatus.substring(1)}'),
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 5),
                                    action: SnackBarAction(
                                      label: nextStatus == 'ready' && order.customerPhone.isNotEmpty
                                          ? 'Notify Customer'
                                          : 'Undo',
                                      onPressed: nextStatus == 'ready' && order.customerPhone.isNotEmpty
                                          ? () {
                                              final phone = order.customerPhone.replaceAll(RegExp(r'\D'), '');
                                              final intl = phone.startsWith('91') ? phone : '91${phone.substring(phone.length - 10)}';
                                              final msg = Uri.encodeComponent(
                                                'Hi ${order.customerName.isNotEmpty ? order.customerName : "Customer"}, '
                                                'your order #${order.orderNumber} is READY for pickup! 🎉');
                                              launchUrl(Uri.parse('https://wa.me/$intl?text=$msg'), mode: LaunchMode.externalApplication);
                                            }
                                          : () => updateOrderStatus(shopId, order.orderId, prevStatus),
                                    ),
                                  ),
                                );
                              }
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
                              // Offer to notify customer via WhatsApp
                              final phone = order.customerPhone
                                  .replaceAll(RegExp(r'\D'), '');
                              if (ctx.mounted && phone.length >= 10) {
                                final intlPhone = phone.startsWith('91')
                                    ? phone : '91${phone.substring(phone.length - 10)}';
                                final msg = Uri.encodeComponent(
                                    'Hi ${order.customerName.isNotEmpty ? order.customerName : "Customer"}, '
                                    'your order #${order.orderNumber} has been cancelled. '
                                    '${reason.isNotEmpty ? "Reason: $reason." : ""} '
                                    'Sorry for the inconvenience.');
                                await launchUrl(
                                  Uri.parse('https://wa.me/$intlPhone?text=$msg'),
                                  mode: LaunchMode.externalApplication,
                                );
                              }
                            }
                            return false;
                          }
                        },
                        child: _OrderTile(order: order, shopId: shopId, t: t),
                      ).animate(delay: (i * 40).ms)
                          .fadeIn(duration: 250.ms)
                          .slideY(begin: 0.06, curve: Curves.easeOut);
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
                    final chipColor = OrderModel.statusColor(order.status);
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
                        Flexible(
                          child: Text('• ${order.items.length} ${t('orders_item_count')}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 12)),
                        ),
                        const SizedBox(width: 6),
                        _DeliveryPill(isDelivery: isDelivery, t: t),
                        const Spacer(),
                        Text(timeStr,
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 11)),
                      ],
                    ),
                    if (order.scheduledFor != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.schedule_outlined,
                              size: 12, color: Colors.deepPurple),
                          const SizedBox(width: 4),
                          Text(
                            'Due: ${DateFormat('d MMM, hh:mm a').format(order.scheduledFor!)}',
                            style: const TextStyle(
                                color: Colors.deepPurple,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
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

// ─── Create Manual Order Sheet ────────────────────────────────────────────────

void _showCreateOrderSheet(BuildContext context, String shopId, WidgetRef ref) {
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  DateTime? scheduledFor;
  String deliveryType = 'pickup';
  final Map<String, int> selectedQty = {}; // productId → qty
  List<ProductModel> products = ref.read(productsStreamProvider(shopId)).valueOrNull ?? [];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        final total = products
            .where((p) => (selectedQty[p.productId] ?? 0) > 0)
            .fold(0.0, (s, p) => s + p.price * (selectedQty[p.productId] ?? 0));

        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (ctx2, scroll) => Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.add_shopping_cart_outlined,
                        color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('Create Manual Order',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    // Customer details
                    TextField(
                      controller: nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Customer Name',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Delivery type
                    Row(
                      children: [
                        const Text('Type: ',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        ChoiceChip(
                          label: const Text('Pickup'),
                          selected: deliveryType == 'pickup',
                          onSelected: (_) => setS(() => deliveryType = 'pickup'),
                          selectedColor: AppColors.primary.withValues(alpha: 0.15),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Delivery'),
                          selected: deliveryType == 'delivery',
                          onSelected: (_) => setS(() => deliveryType = 'delivery'),
                          selectedColor: AppColors.primary.withValues(alpha: 0.15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Scheduled for
                    OutlinedButton.icon(
                      icon: Icon(
                        Icons.schedule_outlined,
                        color: scheduledFor != null
                            ? Colors.deepPurple
                            : AppColors.textSecondary,
                      ),
                      label: Text(
                        scheduledFor != null
                            ? 'Due: ${DateFormat('d MMM, hh:mm a').format(scheduledFor!)}'
                            : 'Set delivery date/time (optional)',
                        style: TextStyle(
                          color: scheduledFor != null
                              ? Colors.deepPurple
                              : AppColors.textSecondary,
                        ),
                      ),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate:
                              DateTime.now().add(const Duration(hours: 2)),
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 30)),
                        );
                        if (d == null || !ctx.mounted) return;
                        final t = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay.now(),
                        );
                        if (t != null) {
                          setS(() => scheduledFor = DateTime(
                              d.year, d.month, d.day, t.hour, t.minute));
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    // Products
                    const Text('Add Products',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 6),
                    ...products.map((p) {
                      final qty = selectedQty[p.productId] ?? 0;
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(p.nameEn,
                            style: const TextStyle(fontSize: 13)),
                        subtitle: Text(
                            '₹${p.price.toStringAsFixed(0)} / ${p.unit}',
                            style: const TextStyle(fontSize: 11)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (qty > 0)
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline,
                                    size: 20),
                                color: AppColors.error,
                                onPressed: () => setS(() {
                                  if (qty > 1) {
                                    selectedQty[p.productId] = qty - 1;
                                  } else {
                                    selectedQty.remove(p.productId);
                                  }
                                }),
                              ),
                            if (qty > 0)
                              Text('$qty',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline,
                                  size: 20),
                              color: AppColors.primary,
                              onPressed: () => setS(() =>
                                  selectedQty[p.productId] = qty + 1),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 10),
                    TextField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Order note (optional)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              // Bottom: total + save
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, -2))
                  ],
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
                        Text('₹${total.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: AppColors.primary)),
                      ],
                    ),
                    const Spacer(),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                      ),
                      onPressed: selectedQty.isEmpty
                          ? null
                          : () async {
                              final items = selectedQty.entries
                                  .map((e) {
                                    final p = products.firstWhere(
                                        (p) => p.productId == e.key);
                                    final q = e.value.toDouble();
                                    return OrderItemModel(
                                      productId: p.productId,
                                      productName: p.nameEn,
                                      qty: q,
                                      price: p.price,
                                      unit: p.unit,
                                      subtotal: p.price * q,
                                    );
                                  })
                                  .toList();

                              final orderNumber =
                                  DateTime.now().millisecondsSinceEpoch % 100000;
                              final now = DateTime.now();

                              final data = <String, dynamic>{
                                'shopId': shopId,
                                'orderNumber': orderNumber,
                                'status': 'confirmed',
                                'customerName': nameCtrl.text.trim(),
                                'customerPhone': phoneCtrl.text.trim(),
                                'customerLocation': '',
                                'deliveryType': deliveryType,
                                'orderNote': noteCtrl.text.trim(),
                                'items': items.map((i) => i.toMap()).toList(),
                                'totalAmount': total,
                                'paymentMethod': 'cash',
                                'paymentStatus': 'pending',
                                'cancelReason': '',
                                'createdAt': Timestamp.fromDate(now),
                                'updatedAt': Timestamp.fromDate(now),
                                if (scheduledFor != null)
                                  'scheduledFor':
                                      Timestamp.fromDate(scheduledFor!),
                              };

                              await FirebaseFirestore.instance
                                  .collection('shops')
                                  .doc(shopId)
                                  .collection('orders')
                                  .add(data);

                              if (ctx.mounted) Navigator.pop(ctx);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Order created! ✅'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              }
                            },
                      child: const Text('Create Order'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}