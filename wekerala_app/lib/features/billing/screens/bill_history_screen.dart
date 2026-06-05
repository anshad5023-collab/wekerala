import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/bill_model.dart';
import '../../../providers/billing_provider.dart';
import '../../../providers/shop_provider.dart';
import '../../../shared/widgets/shimmer_list.dart';

class BillHistoryScreen extends ConsumerStatefulWidget {
  const BillHistoryScreen({super.key});

  @override
  ConsumerState<BillHistoryScreen> createState() => _BillHistoryScreenState();
}

class _BillHistoryScreenState extends ConsumerState<BillHistoryScreen> {
  // Default: today
  DateTime _start = DateTime(
      DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime _end = DateTime(
      DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59);
  String _searchQuery = '';
  String _selectedPeriod = 'Today';
  String _paymentFilter = 'all'; // 'all' | 'cash' | 'upi' | 'udhar'

  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _selectPeriod(String period) {
    final now = DateTime.now();
    setState(() {
      _selectedPeriod = period;
      switch (period) {
        case 'Today':
          _start = DateTime(now.year, now.month, now.day);
          _end = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'This Week':
          // Monday of the current week
          final daysFromMonday = now.weekday - 1;
          _start = DateTime(now.year, now.month, now.day - daysFromMonday);
          _end = now;
          break;
        case 'This Month':
          _start = DateTime(now.year, now.month, 1);
          _end = now;
          break;
      }
    });
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _start, end: _end),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedPeriod = 'Custom';
        _start = picked.start;
        _end = DateTime(
            picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
    }
  }

  List<BillModel> _filterBills(List<BillModel> bills) {
    var result = bills;
    if (_paymentFilter != 'all') {
      result = result.where((b) => b.paymentMethod == _paymentFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((b) {
        return b.customerName.toLowerCase().contains(q) ||
            b.customerPhone.toLowerCase().contains(q);
      }).toList();
    }
    return result;
  }

  // Export filtered bills as CSV — for accountant monthly reconciliation
  void _exportCsv(BuildContext context) {
    final shopAsync = ref.read(activeShopIdProvider);
    shopAsync.whenData((shopId) {
      if (shopId == null) return;
      final range = BillDateRange(_start, _end);
      final allBillsAsync = ref.read(billHistoryProvider((shopId: shopId, range: range)));
      final filtered = (allBillsAsync.valueOrNull ?? []).where((b) => !b.isVoided).toList();

      if (filtered.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No bills in selected period to export')),
        );
        return;
      }

      final fmt = DateFormat('yyyy-MM-dd HH:mm');
      final buf = StringBuffer();
      buf.writeln('Invoice,Date,Customer,Phone,Items,Cash,UPI,Udhar,Total,Note,BilledBy');
      for (final b in filtered) {
        final inv = b.invoiceNumber?.toString() ?? b.billId.substring(0, 8).toUpperCase();
        final date = fmt.format(b.createdAt);
        final customer = b.customerName.replaceAll(',', ' ');
        final phone = b.customerPhone;
        final items = b.items.length;
        final cash = (b.cashAmount ?? 0).toStringAsFixed(2);
        final upi = (b.upiAmount ?? 0).toStringAsFixed(2);
        final udhar = b.paymentMethod == 'udhar' ? b.finalAmount.toStringAsFixed(2) : '0.00';
        final total = b.finalAmount.toStringAsFixed(2);
        final note = (b.billNote ?? '').replaceAll(',', ' ');
        final billedBy = (b.billedByName ?? '').replaceAll(',', ' ');
        buf.writeln('$inv,$date,$customer,$phone,$items,$cash,$upi,$udhar,$total,$note,$billedBy');
      }

      final total = filtered.fold(0.0, (s, b) => s + b.finalAmount).toStringAsFixed(0);
      Share.share(
        buf.toString(),
        subject: 'Bills Export – $_selectedPeriod | ${filtered.length} bills | ₹$total',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final shopAsync = ref.watch(activeShopIdProvider);

    return shopAsync.when(
      loading: () => const Scaffold(body: ShimmerList()),
      error: (e, _) => Scaffold(body: Center(child: Text(e.toString()))),
      data: (shopId) {
        if (shopId == null) {
          return const Scaffold(
              body: Center(child: Text('No active shop found.')));
        }
        return _BillHistoryBody(
          shopId: shopId,
          start: _start,
          end: _end,
          selectedPeriod: _selectedPeriod,
          searchQuery: _searchQuery,
          searchController: _searchController,
          onPeriodSelected: _selectPeriod,
          onCustomRange: _pickCustomRange,
          onSearchChanged: (q) => setState(() => _searchQuery = q),
          filterBills: _filterBills,
          onExportCsv: _exportCsv,
          paymentFilter: _paymentFilter,
          onPaymentFilterChanged: (v) => setState(() => _paymentFilter = v),
        );
      },
    );
  }
}

class _BillHistoryBody extends ConsumerWidget {
  final String shopId;
  final DateTime start;
  final DateTime end;
  final String selectedPeriod;
  final String searchQuery;
  final TextEditingController searchController;
  final void Function(String) onPeriodSelected;
  final VoidCallback onCustomRange;
  final void Function(String) onSearchChanged;
  final List<BillModel> Function(List<BillModel>) filterBills;
  final void Function(BuildContext) onExportCsv;
  final String paymentFilter;
  final void Function(String) onPaymentFilterChanged;

  const _BillHistoryBody({
    required this.shopId,
    required this.start,
    required this.end,
    required this.selectedPeriod,
    required this.searchQuery,
    required this.searchController,
    required this.onPeriodSelected,
    required this.onCustomRange,
    required this.onSearchChanged,
    required this.filterBills,
    required this.onExportCsv,
    required this.paymentFilter,
    required this.onPaymentFilterChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = BillDateRange(start, end);
    final billsAsync =
        ref.watch(billHistoryProvider((shopId: shopId, range: range)));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Bill History'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.point_of_sale_outlined),
            tooltip: 'Cash Counter',
            onPressed: () => context.push('/cash-counter'),
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'GSTR-1 Export',
            onPressed: () => context.push('/gstr1'),
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Export CSV for Accountant',
            onPressed: () => onExportCsv(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Period selector chips
          Container(
            color: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _PeriodChip(
                    label: 'Today',
                    selected: selectedPeriod == 'Today',
                    onTap: () => onPeriodSelected('Today'),
                  ),
                  const SizedBox(width: 8),
                  _PeriodChip(
                    label: 'This Week',
                    selected: selectedPeriod == 'This Week',
                    onTap: () => onPeriodSelected('This Week'),
                  ),
                  const SizedBox(width: 8),
                  _PeriodChip(
                    label: 'This Month',
                    selected: selectedPeriod == 'This Month',
                    onTap: () => onPeriodSelected('This Month'),
                  ),
                  const SizedBox(width: 8),
                  _PeriodChip(
                    label: selectedPeriod == 'Custom'
                        ? '${DateFormat('d MMM').format(start)} – ${DateFormat('d MMM').format(end)}'
                        : 'Custom',
                    selected: selectedPeriod == 'Custom',
                    onTap: onCustomRange,
                  ),
                ],
              ),
            ),
          ),

          // Search bar
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search by customer name or phone…',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),

          // Payment method filter chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final entry in [
                    ('all', 'All'),
                    ('cash', 'Cash'),
                    ('upi', 'UPI'),
                    ('udhar', 'Udhar'),
                  ]) ...[
                    FilterChip(
                      label: Text(entry.$2,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      selected: paymentFilter == entry.$1,
                      onSelected: (_) => onPaymentFilterChanged(entry.$1),
                      selectedColor: AppColors.primary.withValues(alpha: 0.15),
                      checkmarkColor: AppColors.primary,
                      side: BorderSide(
                        color: paymentFilter == entry.$1
                            ? AppColors.primary
                            : Colors.grey.shade300,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ),

          // Bills list
          Expanded(
            child: billsAsync.when(
              loading: () => const ShimmerList(),
              error: (e, _) => Center(child: Text(e.toString())),
              data: (bills) {
                final filtered = filterBills(bills);
                if (filtered.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long,
                            size: 56, color: AppColors.textSecondary),
                        SizedBox(height: 12),
                        Text('No bills found for this period.',
                            style:
                                TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    // GST Summary card
                    _GstSummaryCard(bills: filtered),
                    const SizedBox(height: 8),

                    // Bill tiles
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final bill = filtered[index];
                          return _BillTile(bill: bill);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BillTile extends StatelessWidget {
  final BillModel bill;
  const _BillTile({required this.bill});

  @override
  Widget build(BuildContext context) {
    final isCash = bill.paymentMethod == 'cash';

    final avatarBg = isCash
        ? Colors.green.shade100
        : bill.isUdhar
            ? Colors.orange.shade100
            : Colors.blue.shade100;

    final avatarColor = isCash
        ? Colors.green
        : bill.isUdhar
            ? Colors.orange
            : Colors.blue;

    final avatarIcon = isCash
        ? Icons.money
        : bill.isUdhar
            ? Icons.credit_card
            : Icons.phone_android;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      elevation: 0,
      color: Colors.white,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: avatarBg,
          child: Icon(avatarIcon, color: avatarColor, size: 18),
        ),
        title: Text(
          bill.customerName.isNotEmpty
              ? bill.customerName
              : 'Walk-in Customer',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          DateFormat('hh:mm a').format(bill.createdAt),
          style:
              const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        trailing: bill.isVoided
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹${bill.finalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          decoration: TextDecoration.lineThrough,
                          color: AppColors.textSecondary)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(4)),
                    child: const Text('VOID',
                        style: TextStyle(
                            fontSize: 9,
                            color: Colors.red,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              )
            : Text('₹${bill.finalAmount.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        onTap: () => context.push('/bills/${bill.billId}', extra: bill),
      ),
    );
  }
}

class _GstSummaryCard extends StatelessWidget {
  final List<BillModel> bills;
  const _GstSummaryCard({required this.bills});

  @override
  Widget build(BuildContext context) {
    if (bills.isEmpty) return const SizedBox.shrink();

    double totalRevenue = 0;
    double totalTax = 0;
    double totalCgst = 0;
    double totalSgst = 0;
    // Exclude voided bills from summary totals (show them in list but not in totals)
    final activeBills = bills.where((b) => !b.isVoided).toList();
    int billCount = activeBills.length;

    for (final bill in activeBills) {
      totalRevenue += bill.finalAmount;
      totalTax += bill.totalTax;
      for (final entry in bill.gstBreakdown.entries) {
        totalCgst += (entry.value['cgst'] ?? 0);
        totalSgst += (entry.value['sgst'] ?? 0);
      }
    }

    if (activeBills.isEmpty) return const SizedBox.shrink();

    final hasTax = totalTax > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long_outlined, color: AppColors.primary, size: 18),
                const SizedBox(width: 6),
                Text(
                  '$billCount ${billCount == 1 ? 'Bill' : 'Bills'}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                ),
                const Spacer(),
                Text(
                  '₹${totalRevenue.toStringAsFixed(0)} total',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.primary),
                ),
              ],
            ),
            if (hasTax) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('GST Summary', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1976D2).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Total Tax: ₹${totalTax.toStringAsFixed(2)}',
                      style: const TextStyle(color: Color(0xFF1976D2), fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _TaxChip(label: 'CGST', amount: totalCgst),
                  const SizedBox(width: 8),
                  _TaxChip(label: 'SGST', amount: totalSgst),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TaxChip extends StatelessWidget {
  final String label;
  final double amount;
  const _TaxChip({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        '$label: ₹${amount.toStringAsFixed(2)}',
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color:
              selected ? AppColors.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
