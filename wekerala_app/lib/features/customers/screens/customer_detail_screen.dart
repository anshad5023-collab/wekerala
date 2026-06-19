import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/customer_model.dart';
import '../../../models/bill_model.dart';
import '../../../models/credit_model.dart';
import '../../../providers/shop_provider.dart';

// Provider: bills for a specific customer phone in a shop
final _customerBillsProvider = FutureProvider.family<List<BillModel>,
    ({String shopId, String phone})>((ref, args) async {
  final snap = await FirebaseFirestore.instance
      .collection('shops')
      .doc(args.shopId)
      .collection('bills')
      .where('customerPhone', isEqualTo: args.phone)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .get();
  return snap.docs.map(BillModel.fromFirestore).toList();
});

// Provider: live credit-limit + outstanding balance for a customer.
final _customerLimitProvider = FutureProvider.family<
    ({double creditLimit, double udharBalance}),
    ({String shopId, String phone})>((ref, args) async {
  final snap = await FirebaseFirestore.instance
      .collection('shops')
      .doc(args.shopId)
      .collection('customers')
      .doc(args.phone)
      .get();
  final d = snap.data() ?? {};
  return (
    creditLimit: (d['creditLimit'] as num?)?.toDouble() ?? 0,
    udharBalance: (d['udharBalance'] as num?)?.toDouble() ?? 0,
  );
});

// Provider: open credits for a specific customer
final _customerCreditsProvider = FutureProvider.family<List<CreditModel>,
    ({String shopId, String phone})>((ref, args) async {
  final snap = await FirebaseFirestore.instance
      .collection('shops')
      .doc(args.shopId)
      .collection('credits')
      .where('customerPhone', isEqualTo: args.phone)
      .where('status', whereNotIn: ['paid'])
      .orderBy('status')
      .orderBy('createdAt', descending: true)
      .get();
  return snap.docs.map(CreditModel.fromFirestore).toList();
});

class CustomerDetailScreen extends ConsumerWidget {
  final CustomerModel customer;
  const CustomerDetailScreen({super.key, required this.customer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopIdAsync = ref.watch(activeShopIdProvider);
    final moneyFmt = NumberFormat('#,##0', 'en_IN');

    return shopIdAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text(e.toString()))),
      data: (shopId) {
        if (shopId == null) return const Scaffold(body: SizedBox.shrink());

        final billsAsync = ref.watch(
            _customerBillsProvider((shopId: shopId, phone: customer.phone)));
        final creditsAsync = ref.watch(
            _customerCreditsProvider((shopId: shopId, phone: customer.phone)));

        final totalOutstanding = creditsAsync.whenOrNull(
              data: (list) => list.fold(0.0, (s, c) => s + c.outstanding),
            ) ??
            0.0;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(customer.name.isNotEmpty ? customer.name : 'Customer'),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Header card ───────────────────────────────────────────
              Card(
                color: AppColors.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                        child: Text(
                          customer.name.isNotEmpty
                              ? customer.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(customer.name,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(customer.phone,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 14)),
                      const SizedBox(height: 12),
                      // Stats row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatChip(
                              label: 'Total Spent',
                              value: '₹${moneyFmt.format(customer.totalSpent)}',
                              color: AppColors.primary),
                          _StatChip(
                              label: 'Orders',
                              value: '${customer.totalOrders}',
                              color: AppColors.success),
                          if (totalOutstanding > 0)
                            _StatChip(
                                label: 'Owes',
                                value:
                                    '₹${moneyFmt.format(totalOutstanding)}',
                                color: AppColors.error),
                          if (customer.loyaltyPoints > 0)
                            _StatChip(
                                label: 'Points',
                                value: '${customer.loyaltyPoints}⭐',
                                color: const Color(0xFFF59E0B)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.phone_outlined, size: 18),
                              label: const Text('Call'),
                              onPressed: () => launchUrl(
                                  Uri.parse('tel:${customer.phone}')),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.send, size: 18),
                              label: const Text('WhatsApp'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () {
                                final phone = customer.phone
                                    .replaceAll(RegExp(r'\D'), '');
                                final intl = phone.startsWith('91')
                                    ? phone
                                    : '91$phone';
                                launchUrl(
                                  Uri.parse('https://wa.me/$intl'),
                                  mode: LaunchMode.externalApplication,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Credit limit ──────────────────────────────────────────
              _CreditLimitCard(shopId: shopId, phone: customer.phone),
              const SizedBox(height: 20),

              // ── Open Credits ──────────────────────────────────────────
              creditsAsync.when(
                data: (credits) {
                  if (credits.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionLabel('OUTSTANDING UDHAR'),
                      const SizedBox(height: 8),
                      ...credits.map((c) => _CreditTile(credit: c, shopId: shopId)),
                      const SizedBox(height: 20),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              // ── Purchase History ──────────────────────────────────────
              const _SectionLabel('PURCHASE HISTORY'),
              const SizedBox(height: 8),
              billsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Text('Could not load bill history'),
                data: (bills) {
                  if (bills.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No bills found for this customer',
                            style: TextStyle(color: AppColors.textSecondary)),
                      ),
                    );
                  }
                  return Column(
                    children: bills
                        .map((b) => _BillTile(bill: b, onTap: () {
                              context.push('/bills/${b.billId}', extra: b);
                            }))
                        .toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 16, color: color)),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppColors.textSecondary));
  }
}

class _CreditLimitCard extends ConsumerWidget {
  final String shopId;
  final String phone;
  const _CreditLimitCard({required this.shopId, required this.phone});

  Future<void> _edit(BuildContext context, WidgetRef ref, double current) async {
    final ctrl = TextEditingController(
        text: current > 0 ? current.toStringAsFixed(0) : '');
    final newLimit = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Set Credit Limit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Maximum udhar this customer can owe at once. '
                'New credit is blocked above this. Set 0 for no limit.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Credit limit (₹)',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, double.tryParse(ctrl.text.trim()) ?? 0),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (newLimit == null) return;
    await FirebaseFirestore.instance
        .collection('shops').doc(shopId)
        .collection('customers').doc(phone)
        .set({'creditLimit': newLimit}, SetOptions(merge: true));
    ref.invalidate(_customerLimitProvider((shopId: shopId, phone: phone)));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(newLimit > 0
            ? 'Credit limit set to ₹${newLimit.toStringAsFixed(0)}'
            : 'Credit limit removed'),
        backgroundColor: AppColors.success,
      ));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync =
        ref.watch(_customerLimitProvider((shopId: shopId, phone: phone)));
    return dataAsync.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (d) {
        final f = NumberFormat('#,##0', 'en_IN');
        final hasLimit = d.creditLimit > 0;
        final ratio =
            hasLimit ? (d.udharBalance / d.creditLimit).clamp(0.0, 1.0) : 0.0;
        final over = hasLimit && d.udharBalance > d.creditLimit;
        final near = hasLimit && !over && ratio >= 0.8;
        final barColor = over || near ? AppColors.error : AppColors.success;
        return Card(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.credit_score,
                        size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Credit Limit',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                    TextButton(
                      onPressed: () => _edit(context, ref, d.creditLimit),
                      child: Text(hasLimit ? 'Edit' : 'Set limit'),
                    ),
                  ],
                ),
                if (hasLimit) ...[
                  const SizedBox(height: 4),
                  Text('Owes ₹${f.format(d.udharBalance)} of '
                      '₹${f.format(d.creditLimit)}',
                      style: TextStyle(
                          fontSize: 13,
                          color: barColor,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(barColor),
                    ),
                  ),
                  if (over)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text('Over limit — new udhar is blocked',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.error)),
                    )
                  else if (near)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text('Near limit',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.error)),
                    ),
                ] else
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('No limit set — customer can take unlimited udhar',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CreditTile extends StatelessWidget {
  final CreditModel credit;
  final String shopId;
  const _CreditTile({required this.credit, required this.shopId});

  Future<void> _recordPayment(BuildContext context) async {
    final outstanding = credit.outstanding;
    final ctrl = TextEditingController(text: outstanding.toStringAsFixed(0));
    final amount = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Record Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Outstanding: ₹${outstanding.toStringAsFixed(0)}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount received (₹)',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text.trim());
              if (v == null || v <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a valid amount')),
                );
                return;
              }
              if (v > outstanding + 0.01) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Cannot exceed outstanding ₹${outstanding.toStringAsFixed(0)}')),
                );
                return;
              }
              Navigator.pop(context, v);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (amount == null) return;

    final newPaid = credit.paidAmount + amount;
    final newStatus = newPaid >= credit.amount - 0.01 ? 'paid' : 'partial';
    await FirebaseFirestore.instance
        .collection('shops').doc(shopId)
        .collection('credits').doc(credit.creditId)
        .update({
      'paidAmount': newPaid,
      'status': newStatus,
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus == 'paid'
              ? '✓ Credit fully paid off!'
              : '₹${amount.toStringAsFixed(0)} recorded. ₹${(credit.amount - newPaid).toStringAsFixed(0)} still outstanding.'),
          backgroundColor: newStatus == 'paid' ? AppColors.success : null,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.error.withValues(alpha: 0.05),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.account_balance_wallet_outlined,
                color: AppColors.error, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('₹${credit.outstanding.toStringAsFixed(0)} outstanding',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, color: AppColors.error, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(
                      'Since ${DateFormat('d MMM yy').format(credit.createdAt)} · '
                      'Total: ₹${credit.amount.toStringAsFixed(0)} · Paid: ₹${credit.paidAmount.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () => _recordPayment(context),
              icon: const Icon(Icons.payments_outlined, size: 14),
              label: const Text('Pay', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.success,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BillTile extends StatelessWidget {
  final BillModel bill;
  final VoidCallback onTap;
  const _BillTile({required this.bill, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('d MMM yyyy, hh:mm a').format(bill.createdAt);
    final invoiceId = bill.invoiceNumber != null
        ? '#${bill.invoiceNumber}'
        : '#${bill.billId.substring(0, 8).toUpperCase()}';

    Color methodColor;
    switch (bill.paymentMethod) {
      case 'upi':
        methodColor = const Color(0xFF1565C0);
        break;
      case 'udhar':
        methodColor = AppColors.accent;
        break;
      default:
        methodColor = AppColors.success;
    }

    return Card(
      color: AppColors.surface,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(invoiceId,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(dateStr,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text('${bill.items.length} item${bill.items.length != 1 ? "s" : ""}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹${bill.finalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: methodColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      bill.paymentMethod.toUpperCase(),
                      style: TextStyle(
                          fontSize: 10,
                          color: methodColor,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right,
                  color: AppColors.textSecondary, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
