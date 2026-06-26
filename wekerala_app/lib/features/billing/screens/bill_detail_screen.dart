import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
            icon: const Icon(Icons.copy_outlined),
            tooltip: 'Copy invoice ID',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: shortId));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$shortId copied'), duration: const Duration(seconds: 2)),
              );
            },
          ),
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

          // Return banner
          if (_bill.isReturn) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.assignment_return_outlined,
                      color: Colors.orange.shade800, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'RETURN / REFUND',
                    style: TextStyle(
                      color: Colors.orange.shade800,
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
                if (_bill.billNote != null && _bill.billNote!.isNotEmpty)
                  _InfoRow(label: 'Note', value: _bill.billNote!),
                if (_bill.billedByName != null && _bill.billedByName!.isNotEmpty)
                  _InfoRow(
                      label: 'Billed by',
                      value: _bill.billedByName!),
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
                if (_bill.roundOff.abs() >= 0.01)
                  _InfoRow(
                    label: 'Round off',
                    value:
                        '${_bill.roundOff >= 0 ? '+ ' : '- '}₹${_bill.roundOff.abs().toStringAsFixed(2)}',
                    valueColor: AppColors.textSecondary,
                  ),
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
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1565C0),
                side: const BorderSide(color: Color(0xFF1565C0)),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.email_outlined),
              label: const Text('Send via Email',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => _sendEmail(_bill),
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
            // Return / Refund button (not for return bills themselves)
            if (!_bill.isReturn) ...[
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange.shade800,
                  side: BorderSide(color: Colors.orange.shade400),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.assignment_return_outlined),
                label: const Text('Return / Refund',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: _showReturnSheet,
              ),
              const SizedBox(height: 10),
            ],
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
                        _bill = _bill.copyWith(
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

  Future<void> _showReturnSheet() async {
    // Per-item return qty (defaults to the full qty sold) + which are selected.
    final returnQty = <String, double>{
      for (final i in _bill.items) i.productId: i.qty
    };
    final selected = <String>{..._bill.items.map((i) => i.productId)};
    String refundMethod = _bill.isUdhar
        ? 'udhar'
        : (_bill.paymentMethod == 'upi' ? 'upi' : 'cash');
    final paidRatio =
        _bill.totalAmount > 0 ? _bill.finalAmount / _bill.totalAmount : 1.0;
    bool saving = false;

    String fmtQty(double q) =>
        q % 1 == 0 ? q.toInt().toString() : q.toStringAsFixed(2);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) {
          double gross = 0;
          for (final i in _bill.items) {
            if (selected.contains(i.productId)) {
              gross += i.price * (returnQty[i.productId] ?? 0);
            }
          }
          final refund = double.parse((gross * paidRatio).toStringAsFixed(2));

          Widget methodChip(String value, String label) => ChoiceChip(
                label: Text(label),
                selected: refundMethod == value,
                onSelected: (_) => setSheet(() => refundMethod = value),
                selectedColor: AppColors.primary.withValues(alpha: 0.15),
              );

          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.assignment_return_outlined,
                            color: Colors.orange.shade800),
                        const SizedBox(width: 8),
                        const Text('Return / Refund',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('Pick the items and quantities coming back.',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: _bill.items.map((i) {
                          final isSel = selected.contains(i.productId);
                          final q = returnQty[i.productId] ?? i.qty;
                          return Row(
                            children: [
                              Checkbox(
                                value: isSel,
                                onChanged: (v) => setSheet(() {
                                  if (v == true) {
                                    selected.add(i.productId);
                                  } else {
                                    selected.remove(i.productId);
                                  }
                                }),
                              ),
                              Expanded(
                                child: Text(i.productName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13)),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.remove_circle_outline,
                                    size: 20),
                                onPressed: !isSel || q <= i.qtyStep
                                    ? null
                                    : () => setSheet(() => returnQty[i.productId] =
                                        (q - i.qtyStep)),
                              ),
                              Text('${fmtQty(q)} ${i.unit}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12)),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.add_circle_outline,
                                    size: 20),
                                onPressed: !isSel || q >= i.qty
                                    ? null
                                    : () => setSheet(() => returnQty[i.productId] =
                                        (q + i.qtyStep) > i.qty
                                            ? i.qty
                                            : (q + i.qtyStep)),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                    const Divider(),
                    Row(
                      children: [
                        const Text('Refund via',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.textSecondary)),
                        const SizedBox(width: 10),
                        methodChip('cash', 'Cash'),
                        const SizedBox(width: 6),
                        methodChip('upi', 'UPI'),
                        const SizedBox(width: 6),
                        methodChip('udhar', 'Udhar'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check),
                        label: Text(saving
                            ? 'Processing...'
                            : 'Refund ₹${refund.toStringAsFixed(2)}'),
                        onPressed: (refund <= 0 || saving)
                            ? null
                            : () async {
                                final items = <BillItemModel>[];
                                for (final i in _bill.items) {
                                  if (!selected.contains(i.productId)) continue;
                                  final qv = returnQty[i.productId] ?? 0;
                                  if (qv <= 0) continue;
                                  items.add(i.copyWith(
                                      qty: qv, subtotal: i.price * qv));
                                }
                                if (items.isEmpty) return;
                                setSheet(() => saving = true);
                                final messenger =
                                    ScaffoldMessenger.of(context);
                                try {
                                  await ref
                                      .read(billingProvider.notifier)
                                      .createReturn(
                                        original: _bill,
                                        returnedItems: items,
                                        refundMethod: refundMethod,
                                      );
                                  if (sheetCtx.mounted) {
                                    Navigator.pop(sheetCtx);
                                  }
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Return recorded — ₹${refund.toStringAsFixed(2)} refunded, stock restored.'),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                } catch (e) {
                                  setSheet(() => saving = false);
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text('Return failed: $e'),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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


  void _sendEmail(BillModel bill) {
    final invoiceId = bill.invoiceNumber != null
        ? '#${bill.invoiceNumber}'
        : '#${bill.billId.substring(0, 8).toUpperCase()}';
    final dateStr = DateFormat('d MMM yyyy, hh:mm a').format(bill.createdAt);
    final subject = Uri.encodeComponent('Receipt $invoiceId – $dateStr');
    final body = Uri.encodeComponent(_formatBillText(bill).replaceAll('*', ''));
    // Opens email compose — recipient left blank since email isn't stored on bills
    launchUrl(
      Uri.parse('mailto:?subject=$subject&body=$body'),
      mode: LaunchMode.externalApplication,
    );
  }
  void _shareOnWhatsApp(BillModel bill) {
    final text = Uri.encodeComponent(_formatBillText(bill));
    // If we know the customer's number, open chat with them directly
    final phone = bill.customerPhone.replaceAll(RegExp(r'\D'), '');
    final number = phone.length == 10 ? '91$phone' : (phone.length == 12 ? phone : '');
    final url = number.isNotEmpty
        ? 'https://wa.me/$number?text=$text'
        : 'https://wa.me/?text=$text';
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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
    if (bill.billNote != null && bill.billNote!.isNotEmpty) {
      buffer.writeln('📝 *Note:* ${bill.billNote}');
      buffer.writeln();
    }

    buffer.writeln('*Items:*');
    for (final item in bill.items) {
      final qty = item.qty % 1 == 0
          ? item.qty.toInt().toString()
          : item.qty.toStringAsFixed(2);
      buffer.writeln(
          '• ${item.productName} x$qty ${item.unit} — ₹${item.subtotal.toStringAsFixed(2)}');
      if (item.batchNumber != null && item.batchNumber!.isNotEmpty) {
        buffer.writeln('  Batch: ${item.batchNumber}');
      }
      if (item.modifiers.isNotEmpty) {
        buffer.writeln('  + ${item.modifiers.join(', ')}');
      }
      if (item.itemNote != null && item.itemNote!.isNotEmpty) {
        buffer.writeln('  📝 ${item.itemNote}');
      }
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
                if (item.batchNumber != null && item.batchNumber!.isNotEmpty)
                  Text('Batch: ${item.batchNumber}',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11)),
                if (item.modifiers.isNotEmpty)
                  Text('+ ${item.modifiers.join(', ')}',
                      style: const TextStyle(
                          color: AppColors.primary, fontSize: 11)),
                if (item.itemNote != null && item.itemNote!.isNotEmpty)
                  Text('📝 ${item.itemNote}',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11)),
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
