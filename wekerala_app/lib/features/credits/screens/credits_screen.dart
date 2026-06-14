import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/layout/adaptive_layout.dart';
import '../../../models/credit_model.dart';
import '../../../providers/credits_provider.dart';
import '../../../providers/shop_provider.dart';
import '../../../shared/widgets/shimmer_list.dart';

// ─── Filter options ───────────────────────────────────────────────────────────

enum _Filter { allOpen, overdue, paid }

// ─── Screen ───────────────────────────────────────────────────────────────────

class CreditsScreen extends ConsumerStatefulWidget {
  const CreditsScreen({super.key});

  @override
  ConsumerState<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends ConsumerState<CreditsScreen> {
  _Filter _filter = _Filter.allOpen;

  @override
  Widget build(BuildContext context) {
    final shopAsync = ref.watch(activeShopIdProvider);

    return shopAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: ShimmerList(),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: Text(e.toString())),
      ),
      data: (shopId) {
        if (shopId == null) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: Text('No active shop found.')),
          );
        }
        return _CreditsBody(
          shopId: shopId,
          filter: _filter,
          onFilterChanged: (f) => setState(() => _filter = f),
        );
      },
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _CreditsBody extends ConsumerWidget {
  final String shopId;
  final _Filter filter;
  final ValueChanged<_Filter> onFilterChanged;

  const _CreditsBody({
    required this.shopId,
    required this.filter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creditsAsync = ref.watch(creditsStreamProvider(shopId));
    final shopAsync = ref.watch(shopStreamProvider(shopId));
    final shopName = shopAsync.value?.shopName ?? 'Our Shop';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Udhar Book',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Remind All — sends WhatsApp reminder to every open debtor
          creditsAsync.when(
            data: (credits) {
              final open = credits.where((c) => c.status != 'paid').toList();
              if (open.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.send_outlined),
                tooltip: 'Remind All (${open.length})',
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Remind All Debtors?'),
                      content: Text(
                          'Send a WhatsApp payment reminder to all ${open.length} customers with open Udhar?'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel')),
                        ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366),
                                foregroundColor: Colors.white),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Send All')),
                      ],
                    ),
                  );
                  if (confirm != true || !context.mounted) return;
                  final now = DateTime.now();
                  for (final credit in open) {
                    final rawPhone =
                        credit.customerPhone.replaceAll(RegExp(r'\D'), '');
                    final phone = rawPhone.startsWith('91')
                        ? rawPhone
                        : '91$rawPhone';
                    final msg = Uri.encodeComponent(
                        'Dear ${credit.customerName}, you have an outstanding balance of '
                        '₹${credit.outstanding.toStringAsFixed(0)} at $shopName. '
                        'Please settle at your earliest convenience. Thank you! 🙏');
                    final uri =
                        Uri.parse('https://wa.me/$phone?text=$msg');
                    await launchUrl(uri,
                        mode: LaunchMode.externalApplication);
                    // Log reminder time so owner knows who was last reminded
                    FirebaseFirestore.instance
                        .collection('shops')
                        .doc(shopId)
                        .collection('credits')
                        .doc(credit.creditId)
                        .update({'lastReminderSentAt': Timestamp.fromDate(now)})
                        .ignore();
                    await Future.delayed(const Duration(milliseconds: 500));
                  }
                },
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/credits/add'),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Udhar', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: creditsAsync.when(
        loading: () => const ShimmerList(itemCount: 5, itemHeight: 150),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                const SizedBox(height: 12),
                Text(
                  'Failed to load credits: $e',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(creditsStreamProvider(shopId)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (credits) {
          // ── Compute summary stats ─────────────────────────────────────────
          final totalOutstanding =
              credits.fold<double>(0, (acc, c) => acc + c.outstanding);
          final customerCount = credits.length;
          final overdueAmount = credits.fold<double>(
              0, (s, c) => c.isOverdue ? s + c.outstanding : s);
          final overdueCount = credits.where((c) => c.isOverdue).length;

          // ── Apply filter ──────────────────────────────────────────────────
          final filtered = filter == _Filter.overdue
              ? credits.where((c) => c.isOverdue).toList()
              : filter == _Filter.paid
                  ? credits.where((c) => c.status == 'paid').toList()
                  : credits.where((c) => c.status != 'paid').toList();

          // ── Sort: overdue first, then by outstanding desc ─────────────────
          final sorted = [...filtered]..sort((a, b) {
              if (a.isOverdue && !b.isOverdue) return -1;
              if (!a.isOverdue && b.isOverdue) return 1;
              return b.outstanding.compareTo(a.outstanding);
            });

          // ── Filter chips row ──────────────────────────────────────────────
          Widget filterChipsRow() => Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All Open',
                      selected: filter == _Filter.allOpen,
                      onTap: () => onFilterChanged(_Filter.allOpen),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Overdue',
                      selected: filter == _Filter.overdue,
                      onTap: () => onFilterChanged(_Filter.overdue),
                      selectedColor: AppColors.error,
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Paid',
                      selected: filter == _Filter.paid,
                      onTap: () => onFilterChanged(_Filter.paid),
                      selectedColor: AppColors.success,
                    ),
                  ],
                ),
              );

          // ── Shared header (summary + filter chips) ────────────────────────
          final header = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _SummaryCard(
                  totalOutstanding: totalOutstanding,
                  customerCount: customerCount,
                  overdueAmount: overdueAmount,
                  overdueCount: overdueCount,
                ),
              ),
              filterChipsRow(),
            ],
          );

          // ── Empty state label based on filter ─────────────────────────────
          String emptyLabel() {
            switch (filter) {
              case _Filter.overdue:
                return 'No overdue credits';
              case _Filter.paid:
                return 'No paid credits yet';
              case _Filter.allOpen:
                return 'No pending udhar 🎉';
            }
          }

          // ── Mobile list ───────────────────────────────────────────────────
          final mobileBody = CustomScrollView(
            slivers: [
              // ── Summary card ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _SummaryCard(
                    totalOutstanding: totalOutstanding,
                    customerCount: customerCount,
                    overdueAmount: overdueAmount,
                    overdueCount: overdueCount,
                  ),
                ),
              ),

              // ── Filter chips ──────────────────────────────────────────────
              SliverToBoxAdapter(child: filterChipsRow()),

              // ── Credit list ───────────────────────────────────────────────
              if (sorted.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 64,
                          color: AppColors.success,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          emptyLabel(),
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'All customers are up to date.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _CreditCard(
                        credit: sorted[i],
                        shopId: shopId,
                        shopName: shopName,
                        index: i,
                      ),
                      childCount: sorted.length,
                    ),
                  ),
                ),
            ],
          );

          // ── Desktop DataTable ─────────────────────────────────────────────
          final desktopBody = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: _DesktopCreditsTable(
                    credits: sorted,
                    shopId: shopId,
                    shopName: shopName,
                    emptyResult: sorted.isEmpty,
                    emptyLabel: emptyLabel(),
                  ),
                ),
              ),
            ],
          );

          return AdaptiveLayout(
            mobile: mobileBody,
            desktop: desktopBody,
          );
        },
      ),
    );
  }
}

// ─── Summary card ─────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final double totalOutstanding;
  final int customerCount;
  final double overdueAmount;
  final int overdueCount;

  const _SummaryCard({
    required this.totalOutstanding,
    required this.customerCount,
    required this.overdueAmount,
    required this.overdueCount,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##,##0.00', 'en_IN');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.accent, Color(0xFFC8864A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Outstanding',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '₹${fmt.format(totalOutstanding)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$customerCount ${customerCount == 1 ? 'customer owes' : 'customers owe'} you',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              const Spacer(),
              if (overdueCount > 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${fmt.format(overdueAmount)} overdue',
                      style: TextStyle(
                        color: Colors.red.shade200,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '$overdueCount overdue',
                      style: TextStyle(
                        color: Colors.red.shade200,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Filter chip ──────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedColor;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? selectedColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? selectedColor : AppColors.textSecondary,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ─── Credit card ──────────────────────────────────────────────────────────────

class _CreditCard extends ConsumerWidget {
  final CreditModel credit;
  final String shopId;
  final String shopName;
  final int index;

  const _CreditCard({
    required this.credit,
    required this.shopId,
    required this.shopName,
    required this.index,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat('#,##,##0.00', 'en_IN');
    final overdue = credit.isOverdue;
    final dueFmt = credit.dueDate != null
        ? DateFormat('d MMM yyyy').format(credit.dueDate!)
        : null;

    Color statusColor;
    String statusLabel;
    switch (credit.status) {
      case 'partial':
        statusColor = Colors.orange.shade700;
        statusLabel = 'Partial';
        break;
      case 'paid':
        statusColor = AppColors.success;
        statusLabel = 'Paid';
        break;
      default:
        statusColor = AppColors.error;
        statusLabel = 'Open';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: overdue ? AppColors.error.withValues(alpha: 0.4) : Colors.grey.shade200,
          width: overdue ? 1.5 : 1,
        ),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: name + amount ────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        credit.customerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.phone_outlined,
                            size: 12,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            credit.customerPhone,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${fmt.format(credit.outstanding)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: credit.outstanding > 0
                            ? AppColors.error
                            : AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // ── Partial payment progress ──────────────────────────────────
            if (credit.paidAmount > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (credit.paidAmount / credit.amount).clamp(0.0, 1.0),
                        backgroundColor: Colors.grey.shade200,
                        color: AppColors.success,
                        minHeight: 5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '₹${fmt.format(credit.paidAmount)} paid',
                    style: const TextStyle(
                      color: AppColors.success,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],

            // ── Note ──────────────────────────────────────────────────────
            if (credit.note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.notes_rounded,
                      size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      credit.note,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            // ── Due date ──────────────────────────────────────────────────
            if (dueFmt != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    overdue ? Icons.warning_amber_rounded : Icons.calendar_today_outlined,
                    size: 13,
                    color: overdue ? AppColors.error : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    overdue ? 'Overdue — Due $dueFmt' : 'Due $dueFmt',
                    style: TextStyle(
                      color: overdue ? AppColors.error : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: overdue ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ],

            // ── Last reminder ─────────────────────────────────────────────
            if (credit.lastReminderSentAt != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.notifications_outlined, size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    'Last reminded ${DateFormat('d MMM').format(credit.lastReminderSentAt!)}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // ── Action buttons ────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.chat_rounded,
                    label: 'WhatsApp',
                    color: const Color(0xFF25D366),
                    onTap: () => _sendWhatsApp(context, credit, shopName),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.payments_outlined,
                    label: 'Partial Pay',
                    color: Colors.orange.shade700,
                    onTap: () => _showPartialPayDialog(context, ref, credit),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Mark Paid',
                    color: AppColors.success,
                    onTap: () => _confirmMarkPaid(context, ref, credit),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: 60 * index))
        .fadeIn(duration: 350.ms)
        .slideY(begin: 0.1, end: 0, duration: 350.ms, curve: Curves.easeOut);
  }

  // ── WhatsApp monthly statement ─────────────────────────────────────────────

  Future<void> _sendWhatsApp(
    BuildContext context,
    CreditModel credit,
    String shopName,
  ) async {
    final fmt = NumberFormat('#,##,##0.00', 'en_IN');
    final now = DateTime.now();
    final monthName = DateFormat('MMMM yyyy').format(now);
    final message = Uri.encodeComponent(
      '📋 *Monthly Statement — $monthName*\n'
      '*${credit.customerName}* — $shopName\n\n'
      'Total Credit: ₹${fmt.format(credit.amount)}\n'
      'Amount Paid: ₹${fmt.format(credit.paidAmount)}\n'
      '*Outstanding: ₹${fmt.format(credit.outstanding)}*\n\n'
      'Please settle at your earliest convenience 🙏',
    );
    final phone = credit.customerPhone.replaceAll(RegExp(r'\D'), '');
    final countryPhone = phone.startsWith('91') ? phone : '91$phone';
    final uri = Uri.parse('https://wa.me/$countryPhone?text=$message');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WhatsApp not installed or number invalid.')),
        );
      }
    }
  }

  // ── Partial pay dialog ─────────────────────────────────────────────────────

  Future<void> _showPartialPayDialog(
    BuildContext context,
    WidgetRef ref,
    CreditModel credit,
  ) async {
    final ctrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final fmt = NumberFormat('#,##,##0.00', 'en_IN');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Record Payment',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Outstanding: ₹${fmt.format(credit.outstanding)}',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: ctrl,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount Received (₹)',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
                validator: (v) {
                  final val = double.tryParse(v ?? '');
                  if (val == null || val <= 0) return 'Enter a valid amount';
                  if (val > credit.outstanding) {
                    return 'Cannot exceed outstanding ₹${fmt.format(credit.outstanding)}';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final amount = double.tryParse(ctrl.text) ?? 0;
      if (amount <= 0) return;
      try {
        await CreditsRepository.recordPartialPayment(
            shopId, credit.creditId, amount);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Payment of ₹${NumberFormat('#,##,##0.00', 'en_IN').format(amount)} recorded.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
    ctrl.dispose();
  }

  // ── Mark paid confirm ──────────────────────────────────────────────────────

  Future<void> _confirmMarkPaid(
    BuildContext context,
    WidgetRef ref,
    CreditModel credit,
  ) async {
    final fmt = NumberFormat('#,##,##0.00', 'en_IN');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Mark as Paid?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Mark ₹${fmt.format(credit.outstanding)} from ${credit.customerName} as fully paid?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Yes, Mark Paid'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await CreditsRepository.markPaid(shopId, credit.creditId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '${credit.customerName}\'s credit marked as paid.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
}

// ─── Desktop DataTable ────────────────────────────────────────────────────────

class _DesktopCreditsTable extends ConsumerWidget {
  final List<CreditModel> credits;
  final String shopId;
  final String shopName;
  final bool emptyResult;
  final String emptyLabel;

  const _DesktopCreditsTable({
    required this.credits,
    required this.shopId,
    required this.shopName,
    required this.emptyResult,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (credits.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                size: 64,
                color: AppColors.success,
              ),
              const SizedBox(height: 16),
              Text(
                emptyLabel,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'All customers are up to date.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final fmt = NumberFormat('#,##,##0.00', 'en_IN');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            AppColors.primary.withValues(alpha: 0.06),
          ),
          headingTextStyle: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          dataTextStyle: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
          ),
          columnSpacing: 20,
          horizontalMargin: 16,
          columns: const [
            DataColumn(label: Text('Customer Name')),
            DataColumn(label: Text('Phone')),
            DataColumn(label: Text('Total Credit'), numeric: true),
            DataColumn(label: Text('Paid'), numeric: true),
            DataColumn(label: Text('Outstanding'), numeric: true),
            DataColumn(label: Text('Due Date')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Actions')),
          ],
          rows: credits.map((credit) {
            final overdue = credit.isOverdue;
            final dueFmt = credit.dueDate != null
                ? DateFormat('d MMM yyyy').format(credit.dueDate!)
                : '—';

            // ── Status chip colour ───────────────────────────────────────
            Color chipColor;
            String chipLabel;
            if (overdue) {
              chipColor = AppColors.error;
              chipLabel = 'Overdue';
            } else {
              switch (credit.status) {
                case 'partial':
                  chipColor = const Color(0xFF1976D2);
                  chipLabel = 'Partial';
                  break;
                case 'paid':
                  chipColor = AppColors.success;
                  chipLabel = 'Paid';
                  break;
                default:
                  chipColor = AppColors.accent;
                  chipLabel = 'Open';
              }
            }

            return DataRow(
              cells: [
                // Customer Name
                DataCell(
                  Text(
                    credit.customerName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                // Phone
                DataCell(Text(credit.customerPhone)),
                // Total Credit
                DataCell(Text('₹${fmt.format(credit.amount)}')),
                // Paid
                DataCell(Text(
                  '₹${fmt.format(credit.paidAmount)}',
                  style: const TextStyle(color: AppColors.success),
                )),
                // Outstanding — bold accent colour
                DataCell(Text(
                  '₹${fmt.format(credit.outstanding)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
                  ),
                )),
                // Due Date
                DataCell(Text(
                  dueFmt,
                  style: TextStyle(
                    color: overdue ? AppColors.error : AppColors.textSecondary,
                    fontWeight:
                        overdue ? FontWeight.w600 : FontWeight.normal,
                  ),
                )),
                // Status chip
                DataCell(
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: chipColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: chipColor.withValues(alpha: 0.4), width: 1),
                    ),
                    child: Text(
                      chipLabel,
                      style: TextStyle(
                        color: chipColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                // Actions
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (credit.status != 'paid') ...[
                        IconButton(
                          icon: const Icon(Icons.payments_outlined,
                              color: AppColors.accent),
                          tooltip: 'Partial Pay',
                          onPressed: () =>
                              _showPartialPayDialog(context, ref, credit, shopId),
                        ),
                        IconButton(
                          icon: const Icon(Icons.check_circle_outline,
                              color: AppColors.success),
                          tooltip: 'Mark Paid',
                          onPressed: () =>
                              _confirmMarkPaid(context, ref, credit, shopId),
                        ),
                      ],
                      IconButton(
                        icon: const Icon(Icons.chat,
                            color: Color(0xFF25D366)),
                        tooltip: 'Send Monthly Statement',
                        onPressed: () => _sendWhatsApp(
                            context, credit, shopName),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── WhatsApp monthly statement ───────────────────────────────────────────

  Future<void> _sendWhatsApp(
    BuildContext context,
    CreditModel credit,
    String shopName,
  ) async {
    final fmt = NumberFormat('#,##,##0.00', 'en_IN');
    final now = DateTime.now();
    final monthName = DateFormat('MMMM yyyy').format(now);
    final message = Uri.encodeComponent(
      '📋 *Monthly Statement — $monthName*\n'
      '*${credit.customerName}* — $shopName\n\n'
      'Total Credit: ₹${fmt.format(credit.amount)}\n'
      'Amount Paid: ₹${fmt.format(credit.paidAmount)}\n'
      '*Outstanding: ₹${fmt.format(credit.outstanding)}*\n\n'
      'Please settle at your earliest convenience 🙏',
    );
    final phone = credit.customerPhone.replaceAll(RegExp(r'\D'), '');
    final countryPhone = phone.startsWith('91') ? phone : '91$phone';
    final uri = Uri.parse('https://wa.me/$countryPhone?text=$message');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('WhatsApp not installed or number invalid.')),
        );
      }
    }
  }

  // ── Mark paid confirm ────────────────────────────────────────────────────

  Future<void> _confirmMarkPaid(
    BuildContext context,
    WidgetRef ref,
    CreditModel credit,
    String shopId,
  ) async {
    final fmt = NumberFormat('#,##,##0.00', 'en_IN');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Mark as Paid?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Mark ₹${fmt.format(credit.outstanding)} from ${credit.customerName} as fully paid?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Yes, Mark Paid'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await CreditsRepository.markPaid(shopId, credit.creditId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('${credit.customerName}\'s credit marked as paid.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _showPartialPayDialog(
    BuildContext context,
    WidgetRef ref,
    CreditModel credit,
    String shopId,
  ) async {
    final ctrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final fmt = NumberFormat('#,##,##0.00', 'en_IN');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Record Payment',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Outstanding: ₹${fmt.format(credit.outstanding)}',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: ctrl,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount Received (₹)',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
                validator: (v) {
                  final val = double.tryParse(v ?? '');
                  if (val == null || val <= 0) return 'Enter a valid amount';
                  if (val > credit.outstanding) {
                    return 'Cannot exceed ₹${fmt.format(credit.outstanding)}';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final amount = double.tryParse(ctrl.text) ?? 0;
      if (amount <= 0) {
        ctrl.dispose();
        return;
      }
      try {
        await CreditsRepository.recordPartialPayment(
            shopId, credit.creditId, amount);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Payment of ₹${fmt.format(amount)} recorded.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
    ctrl.dispose();
  }
}

// ─── Action button widget ─────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
