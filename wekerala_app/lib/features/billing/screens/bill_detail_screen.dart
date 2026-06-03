import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/invoice_pdf_service.dart';
import '../../../core/services/print_service.dart';
import '../../../models/bill_model.dart';
import '../../../providers/billing_provider.dart';
import '../../../providers/shop_provider.dart';

class BillDetailScreen extends ConsumerStatefulWidget {
  final BillModel bill;
  const BillDetailScreen({super.key, required this.bill});

  @override
  ConsumerState<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends ConsumerState<BillDetailScreen> {
  bool _printing = false;
  bool _sharingPdf = false;
  late BillModel _bill;

  @override
  void initState() {
    super.initState();
    _bill = widget.bill;
  }

  @override
  Widget build(BuildContext context) {
    final shopAsync = ref.watch(shopStreamProvider(_bill.shopId));
    final shortId = _bill.invoiceNumber != null
        ? '#${_bill.invoiceNumber}'
        : '#${_bill.billId.substring(0, 8).toUpperCase()}';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Bill $shortId'),
        backgroundColor: _bill.isVoided ? Colors.red.shade700 : AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share bill',
            onPressed: _bill.isVoided ? null : () => _shareOnWhatsApp(_bill),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Voided banner
          if (_bill.isVoided) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.cancel_outlined, color: Colors.red.shade700, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'VOIDED${_bill.voidedAt != null ? ' on ${DateFormat('d MMM yyyy').format(_bill.voidedAt!)}' : ''}',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Shop info
          shopAsync.when(
            data: (shop) => _SectionCard(
              title: 'Shop',
              child: Row(
                children: [
                  const Icon(Icons.store, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(shop.shopName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15)),
                        if (shop.address.isNotEmpty)
                          Text(shop.address,
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),

          // Customer section
          _SectionCard(
            title: 'Customer',
            child: Column(
              children: [
                _InfoRow(
                  label: 'Name',
                  value: _bill.customerName.isNotEmpty
                      ? _bill.customerName
                      : 'Walk-in Customer',
                ),
                if (_bill.customerPhone.isNotEmpty)
                  _InfoRow(
                    label: 'Phone',
                    value: _bill.customerPhone,
                    trailing: IconButton(
                      icon: const Icon(Icons.call,
                          color: AppColors.primary, size: 20),
                      tooltip: 'Call customer',
                      onPressed: () => _callPhone(context, _bill.customerPhone),
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
                ..._bill.items.map((item) => _BillItemRow(item: item)),
                const Divider(height: 20),
                _InfoRow(
                    label: 'Subtotal',
                    value: '₹${_bill.totalAmount.toStringAsFixed(2)}'),
                if (_bill.discountAmount > 0)
                  _InfoRow(
                    label: 'Discount',
                    value: '- ₹${_bill.discountAmount.toStringAsFixed(2)}',
                    valueColor: AppColors.error,
                  ),
                if (_bill.totalTax > 0) ...[
                  const SizedBox(height: 4),
                  ..._bill.gstBreakdown.entries.expand((entry) {
                    final rate = int.tryParse(entry.key) ?? 0;
                    final data = entry.value;
                    return [
                      _InfoRow(
                        label: 'CGST ${rate / 2}%',
                        value: '₹${(data['cgst'] ?? 0).toStringAsFixed(2)}',
                        valueColor: AppColors.textSecondary,
                      ),
                      _InfoRow(
                        label: 'SGST ${rate / 2}%',
                        value: '₹${(data['sgst'] ?? 0).toStringAsFixed(2)}',
                        valueColor: AppColors.textSecondary,
                      ),
                    ];
                  }),
                  _InfoRow(
                    label: 'Total Tax',
                    value: '₹${_bill.totalTax.toStringAsFixed(2)}',
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
                      '₹${_bill.finalAmount.toStringAsFixed(2)}',
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
                  value: _paymentLabel(_bill.paymentMethod, _bill.isUdhar),
                  valueColor: _paymentColor(_bill.paymentMethod, _bill.isUdhar),
                ),
                _InfoRow(
                  label: 'Date & Time',
                  value: DateFormat('d MMM yyyy, hh:mm a').format(_bill.createdAt),
                ),
                if (_bill.gstinSnapshot != null && _bill.gstinSnapshot!.isNotEmpty)
                  _InfoRow(label: 'GSTIN', value: _bill.gstinSnapshot!),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Action buttons (hidden if voided)
          if (!_bill.isVoided) ...[
            ElevatedButton.icon(
              onPressed: () => _shareOnWhatsApp(_bill),
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
            // PDF Invoice share
            shopAsync.when(
              data: (shop) => OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: const BorderSide(color: AppColors.primary),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: _sharingPdf
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined,
                        color: AppColors.primary),
                label: Text(
                  _sharingPdf ? 'Generating...' : 'Download PDF Invoice',
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold),
                ),
                onPressed: _sharingPdf
                    ? null
                    : () async {
                        setState(() => _sharingPdf = true);
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await InvoicePdfService.shareInvoice(_bill, shop);
                        } catch (e) {
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('PDF failed: $e'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _sharingPdf = false);
                        }
                      },
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 10),
            // Print button — wired to PrintService
            shopAsync.when(
              data: (shop) => OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: const BorderSide(color: AppColors.primary),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: _printing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary),
                      )
                    : const Icon(Icons.print_outlined, color: AppColors.primary),
                label: Text(
                  _printing ? 'Printing...' : 'Print Receipt',
                  style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
                onPressed: _printing
                    ? null
                    : () async {
                        setState(() => _printing = true);
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await PrintService.printBill(_bill, shop);
                          if (mounted) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Printed successfully'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Print failed: $e'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _printing = false);
                        }
                      },
              ),
              loading: () => OutlinedButton.icon(
                onPressed: null,
                icon: const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                label: const Text('Loading...'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 10),
            // Void bill button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: BorderSide(color: AppColors.error.withValues(alpha: 0.6)),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Void Bill',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Void This Bill?'),
                    content: const Text(
                      'This will mark the bill as voided and restore stock. This cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Void'),
                      ),
                    ],
                  ),
                );
                if (confirm == true && mounted) {
                  try {
                    await ref.read(billingProvider.notifier).voidBill(_bill);
                    if (mounted) {
                      setState(() {
                        _bill = BillModel(
                          billId: _bill.billId,
                          shopId: _bill.shopId,
                          items: _bill.items,
                          totalAmount: _bill.totalAmount,
                          discountAmount: _bill.discountAmount,
                          finalAmount: _bill.finalAmount,
                          paymentMethod: _bill.paymentMethod,
                          customerName: _bill.customerName,
                          customerPhone: _bill.customerPhone,
                          isUdhar: _bill.isUdhar,
                          createdAt: _bill.createdAt,
                          gstBreakdown: _bill.gstBreakdown,
                          totalTax: _bill.totalTax,
                          gstinSnapshot: _bill.gstinSnapshot,
                          invoiceNumber: _bill.invoiceNumber,
                          isVoided: true,
                          voidedAt: DateTime.now(),
                        );
                      });
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Bill voided. Stock restored.'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Failed to void: $e')),
                    );
                  }
                }
              },
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

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
    final invoiceId = bill.invoiceNumber != null
        ? '#${bill.invoiceNumber}'
        : '#${bill.billId.substring(0, 8).toUpperCase()}';
    final dateStr = DateFormat('d MMM yyyy, hh:mm a').format(bill.createdAt);

    final buffer = StringBuffer();
    buffer.writeln('🧾 *Bill $invoiceId*');
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
      buffer.writeln('Subtotal: ₹${bill.totalAmount.toStringAsFixed(2)}');
      buffer.writeln('Discount: -₹${bill.discountAmount.toStringAsFixed(2)}');
    }
    if (bill.totalTax > 0) {
      buffer.writeln('Tax: ₹${bill.totalTax.toStringAsFixed(2)}');
    }
    buffer.writeln('*Total: ₹${bill.finalAmount.toStringAsFixed(2)}*');
    buffer.writeln();
    buffer.writeln('Payment: ${_paymentLabel(bill.paymentMethod, bill.isUdhar)}');
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
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                Row(
                  children: [
                    if (item.hsnCode != null && item.hsnCode!.isNotEmpty) ...[
                      Text('HSN: ${item.hsnCode}',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 11)),
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
              style: const TextStyle(fontWeight: FontWeight.w600)),
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
