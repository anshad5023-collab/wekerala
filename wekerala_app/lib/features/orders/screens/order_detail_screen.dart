import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/layout/adaptive_layout.dart';
import '../../../providers/language_provider.dart';
import '../../../providers/shop_provider.dart';
import '../../../providers/orders_provider.dart';
import '../../../models/order_model.dart';

class OrderDetailScreen extends ConsumerWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translations = ref.watch(translationsProvider);
    String t(String key) => translations[key] ?? key;
    final shopAsync = ref.watch(activeShopIdProvider);

    return shopAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text(e.toString()))),
      data: (shopId) {
        if (shopId == null) return Scaffold(body: Center(child: Text(t('error_generic'))));
        return _OrderDetailBody(orderId: orderId, shopId: shopId, t: t);
      },
    );
  }
}

class _OrderDetailBody extends ConsumerWidget {
  final String orderId;
  final String shopId;
  final String Function(String) t;

  const _OrderDetailBody({
    required this.orderId,
    required this.shopId,
    required this.t,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(
        orderDetailProvider((shopId: shopId, orderId: orderId)));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: orderAsync.when(
          loading: () => Text(t('order_detail_title')),
          error: (_, __) => Text(t('order_detail_title')),
          data: (order) => order != null
              ? Text('Order #${order.orderNumber}')
              : Text(t('order_detail_title')),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (orderAsync.valueOrNull?.customerPhone.isNotEmpty ?? false)
            IconButton(
              icon: const Icon(Icons.chat_outlined),
              tooltip: 'WhatsApp customer',
              onPressed: () {
                final phone = orderAsync.valueOrNull!.customerPhone;
                final msg = Uri.encodeComponent(
                    'Hello, your order #${orderAsync.valueOrNull!.orderNumber} is ready!');
                launchUrl(Uri.parse('https://wa.me/91$phone?text=$msg'),
                    mode: LaunchMode.externalApplication);
              },
            ),
        ],
      ),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (order) {
          if (order == null) {
            return Center(child: Text(t('error_generic')));
          }
          final content = _OrderContent(order: order, shopId: shopId, t: t);
          return AdaptiveLayout(
            mobile: content,
            desktop: Card(
              margin: const EdgeInsets.all(24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: content,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OrderContent extends StatelessWidget {
  final OrderModel order;
  final String shopId;
  final String Function(String) t;

  const _OrderContent({required this.order, required this.shopId, required this.t});

  void _callPhone(BuildContext context, String phone) {
    if (!kIsWeb && Platform.isAndroid) {
      launchUrl(Uri.parse('tel:$phone'));
    } else {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Phone Number'),
          content: SelectableText(phone),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = OrderModel.statusColor(order.status);
    final dateStr = DateFormat('d MMM yyyy, h:mm a').format(order.createdAt);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        Row(
          children: [
            Text('${t('order_number')}${order.orderNumber}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(t('status_${order.status}'),
                  style: TextStyle(color: color, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(dateStr,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 16),

        // Customer card
        _SectionCard(
          title: t('order_customer'),
          child: Column(
            children: [
              _InfoRow(label: t('order_customer'), value: order.customerName),
              _InfoRow(
                label: t('order_phone'),
                value: order.customerPhone,
                trailing: IconButton(
                  icon: const Icon(Icons.call, color: AppColors.primary, size: 20),
                  onPressed: () =>
                      _callPhone(context, order.customerPhone),
                ),
              ),
              if (order.customerLocation.isNotEmpty)
                _InfoRow(label: t('order_location'), value: order.customerLocation),
              _InfoRow(
                  label: t('order_delivery_type'),
                  value: order.deliveryType == 'delivery'
                      ? 'Delivery'
                      : 'Pickup'),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Items
        _SectionCard(
          title: t('order_items'),
          child: Column(
            children: [
              ...order.items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.productName,
                                  style: const TextStyle(fontWeight: FontWeight.w500)),
                              if (item.variantName.isNotEmpty)
                                Text(item.variantName,
                                    style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12)),
                            ],
                          ),
                        ),
                        Text('${item.qty} ${item.unit}',
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                        const SizedBox(width: 12),
                        Text('₹${item.subtotal.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(t('order_total'),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('₹${order.totalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          fontSize: 16)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Payment
        _SectionCard(
          title: t('order_payment'),
          child: Column(
            children: [
              _InfoRow(label: t('order_payment'), value: order.paymentMethod.toUpperCase()),
              _InfoRow(
                label: 'Status',
                value: order.paymentStatus == 'paid' ? 'Paid' : 'Pending',
                valueColor: order.paymentStatus == 'paid'
                    ? AppColors.success
                    : AppColors.error,
              ),
            ],
          ),
        ),

        if (order.orderNote.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SectionCard(
            title: t('order_note'),
            child: Text(order.orderNote),
          ),
        ],

        const SizedBox(height: 20),
        _ActionButtons(order: order, shopId: shopId, t: t),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final OrderModel order;
  final String shopId;
  final String Function(String) t;

  const _ActionButtons({required this.order, required this.shopId, required this.t});

  @override
  Widget build(BuildContext context) {
    final next = _nextStatus(order.status);
    final nextLabel = _nextLabel(order.status, t);

    if (next == null) return const SizedBox.shrink();

    return Column(
      children: [
        ElevatedButton(
          onPressed: () => updateOrderStatus(shopId, order.orderId, next),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(nextLabel),
        ),
        if (order.status != 'delivered' && order.status != 'cancelled') ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => updateOrderStatus(shopId, order.orderId, 'cancelled'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(t('order_btn_cancel')),
          ),
        ],
      ],
    );
  }

  String? _nextStatus(String status) {
    switch (status) {
      case 'new': return 'confirmed';
      case 'confirmed': return 'processing';
      case 'processing': return 'ready';
      case 'ready': return 'delivered';
      default: return null;
    }
  }

  String _nextLabel(String status, String Function(String) t) {
    switch (status) {
      case 'new': return t('order_btn_confirm');
      case 'confirmed': return t('order_btn_processing');
      case 'processing': return t('order_btn_ready');
      case 'ready': return t('order_btn_delivered');
      default: return '';
    }
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final Widget? trailing;

  const _InfoRow({required this.label, required this.value, this.valueColor, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: valueColor ?? AppColors.textPrimary)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
