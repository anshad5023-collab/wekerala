import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/bill_model.dart';

class BillDetailScreen extends ConsumerWidget {
  final BillModel bill;
  const BillDetailScreen({super.key, required this.bill});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shortId = bill.billId.length > 8
        ? bill.billId.substring(0, 8).toUpperCase()
        : bill.billId.toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Bill #$shortId'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share bill',
            onPressed: () => _shareOnWhatsApp(bill),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Shop info
          _SectionCard(
            title: 'Shop',
            child: const Row(
              children: [
                Icon(Icons.store, color: AppColors.primary, size: 18),
                SizedBox(width: 8),
                Text('Oratas',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Customer section
          _SectionCard(
            title: 'Customer',
            child: Column(
              children: [
                _InfoRow(
                  label: 'Name',
                  value: bill.customerName.isNotEmpty
                      ? bill.customerName
                      : 'Walk-in Customer',
                ),
                if (bill.customerPhone.isNotEmpty)
                  _InfoRow(
                    label: 'Phone',
                    value: bill.customerPhone,
                    trailing: IconButton(
                      icon: const Icon(Icons.call,
                          color: AppColors.primary, size: 20),
                      tooltip: 'Call customer',
                      onPressed: () =>
                          _callPhone(context, bill.customerPhone),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Items section
          _SectionCard(
            title: 'Items',
            child: Column(
              children: [
                ...bill.items.map((item) => _BillItemRow(item: item)),
                const Divider(height: 20),
                // Totals
                _InfoRow(
                    label: 'Subtotal',
                    value: '₹${bill.totalAmount.toStringAsFixed(2)}'),
                if (bill.discountAmount > 0)
                  _InfoRow(
                    label: 'Discount',
                    value: '- ₹${bill.discountAmount.toStringAsFixed(2)}',
                    valueColor: AppColors.error,
                  ),
                if (bill.totalTax > 0) ...[
                  const SizedBox(height: 4),
                  // GST breakdown entries
                  ...bill.gstBreakdown.entries.map((entry) {
                    final rate = entry.key;
                    final breakdown = entry.value;
                    final tax = breakdown['tax'] ?? 0;
                    return _InfoRow(
                      label: 'GST $rate%',
                      value: '₹${tax.toStringAsFixed(2)}',
                      valueColor: AppColors.textSecondary,
                    );
                  }),
                  _InfoRow(
                    label: 'Total Tax',
                    value: '₹${bill.totalTax.toStringAsFixed(2)}',
                    valueColor: AppColors.textSecondary,
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Grand Total',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(
                      '₹${bill.finalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Payment info
          _SectionCard(
            title: 'Payment',
            child: Column(
              children: [
                _InfoRow(
                  label: 'Method',
                  value: _paymentLabel(bill.paymentMethod, bill.isUdhar),
                  valueColor: _paymentColor(bill.paymentMethod, bill.isUdhar),
                ),
                _InfoRow(
                  label: 'Date & Time',
                  value: DateFormat('d MMM yyyy, hh:mm a')
                      .format(bill.createdAt),
                ),
                if (bill.gstinSnapshot != null &&
                    bill.gstinSnapshot!.isNotEmpty)
                  _InfoRow(label: 'GSTIN', value: bill.gstinSnapshot!),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Bottom action buttons
          ElevatedButton.icon(
            onPressed: () => _shareOnWhatsApp(bill),
            icon: const Icon(Icons.send),
            label: const Text('Share on WhatsApp'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 10),
          Tooltip(
            message: 'Coming soon',
            child: OutlinedButton.icon(
              onPressed: null, // disabled — Wave 3
              icon: const Icon(Icons.print_outlined),
              label: const Text('Print'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey,
                side: const BorderSide(color: Colors.grey),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------

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

  String _paymentLabel(String method, bool isUdhar) {
    if (isUdhar) return 'Udhar (Credit)';
    switch (method) {
      case 'cash':
        return 'Cash';
      case 'upi':
        return 'UPI';
      default:
        return method.toUpperCase();
    }
  }

  Color _paymentColor(String method, bool isUdhar) {
    if (isUdhar) return Colors.orange;
    if (method == 'cash') return Colors.green.shade700;
    if (method == 'upi') return Colors.blue;
    return AppColors.textPrimary;
  }

  void _shareOnWhatsApp(BillModel bill) {
    final text = Uri.encodeComponent(_formatBillText(bill));
    launchUrl(
      Uri.parse('https://wa.me/?text=$text'),
      mode: LaunchMode.externalApplication,
    );
  }

  String _formatBillText(BillModel bill) {
    final shortId = bill.billId.length > 8
        ? bill.billId.substring(0, 8).toUpperCase()
        : bill.billId.toUpperCase();
    final dateStr =
        DateFormat('d MMM yyyy, hh:mm a').format(bill.createdAt);

    final buffer = StringBuffer();
    buffer.writeln('🧾 *Bill #$shortId*');
    buffer.writeln('📅 $dateStr');
    buffer.writeln();

    if (bill.customerName.isNotEmpty) {
      buffer.writeln('👤 *Customer:* ${bill.customerName}');
      if (bill.customerPhone.isNotEmpty) {
        buffer.writeln('📞 ${bill.customerPhone}');
      }
      buffer.writeln();
    }

    buffer.writeln('*Items:*');
    for (final item in bill.items) {
      final qty = item.qty % 1 == 0
          ? item.qty.toInt().toString()
          : item.qty.toStringAsFixed(2);
      buffer.writeln(
          '• ${item.productName} x$qty ${item.unit} — ₹${item.subtotal.toStringAsFixed(2)}');
    }
    buffer.writeln();

    if (bill.discountAmount > 0) {
      buffer.writeln(
          'Subtotal: ₹${bill.totalAmount.toStringAsFixed(2)}');
      buffer.writeln(
          'Discount: -₹${bill.discountAmount.toStringAsFixed(2)}');
    }
    if (bill.totalTax > 0) {
      buffer.writeln('Tax: ₹${bill.totalTax.toStringAsFixed(2)}');
    }
    buffer.writeln('*Total: ₹${bill.finalAmount.toStringAsFixed(2)}*');
    buffer.writeln();

    buffer.writeln(
        'Payment: ${_paymentLabel(bill.paymentMethod, bill.isUdhar)}');
    buffer.writeln();
    buffer.writeln('Thank you for shopping with us! 🙏');

    return buffer.toString();
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

class _BillItemRow extends StatelessWidget {
  final BillItemModel item;
  const _BillItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final qty = item.qty % 1 == 0
        ? item.qty.toInt().toString()
        : item.qty.toStringAsFixed(2);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productName,
                    style:
                        const TextStyle(fontWeight: FontWeight.w500)),
                Row(
                  children: [
                    if (item.hsnCode != null &&
                        item.hsnCode!.isNotEmpty) ...[
                      Text('HSN: ${item.hsnCode}',
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11)),
                      const SizedBox(width: 6),
                    ],
                    if (item.gstRate > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'GST ${item.gstRate}%',
                          style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 10,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('$qty ${item.unit}',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(width: 12),
          Text('₹${item.subtotal.toStringAsFixed(2)}',
              style:
                  const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
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
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
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

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
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
