import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/layout/adaptive_layout.dart';
import '../../../models/customer_model.dart';
import '../../../providers/customers_provider.dart';
import '../../../providers/shop_provider.dart';
import '../../../shared/widgets/shimmer_list.dart';
import 'package:go_router/go_router.dart';

// ── Filter enum ───────────────────────────────────────────────────────────

enum _Filter { all, atRisk, regular, newCustomer }

extension _FilterLabel on _Filter {
  String get label {
    switch (this) {
      case _Filter.all:
        return 'All';
      case _Filter.atRisk:
        return 'At Risk';
      case _Filter.regular:
        return 'Regular';
      case _Filter.newCustomer:
        return 'New';
    }
  }
}

// ── Sort enum ─────────────────────────────────────────────────────────────

enum _SortOption { nameAZ, highestSpend, mostOrders, lastOrder }

// ── Root screen — waits for shopId ───────────────────────────────────────

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        return _CustomersBody(shopId: shopId);
      },
    );
  }
}

// ── Main body — stateful for search + filter + sort ───────────────────────

class _CustomersBody extends ConsumerStatefulWidget {
  final String shopId;
  const _CustomersBody({required this.shopId});

  @override
  ConsumerState<_CustomersBody> createState() => _CustomersBodyState();
}

class _CustomersBodyState extends ConsumerState<_CustomersBody> {
  final _searchCtrl = TextEditingController();
  _Filter _activeFilter = _Filter.all;
  String _query = '';
  _SortOption _sort = _SortOption.lastOrder;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // Apply filter chip + sort logic
  List<CustomerModel> _applyFilter(List<CustomerModel> all) {
    List<CustomerModel> filtered;
    switch (_activeFilter) {
      case _Filter.all:
        filtered = List<CustomerModel>.from(all);
        break;
      case _Filter.atRisk:
        filtered = all.where((c) => c.tag == 'At Risk').toList();
        break;
      case _Filter.regular:
        filtered = all.where((c) => c.tag == 'Regular').toList();
        break;
      case _Filter.newCustomer:
        filtered = all.where((c) => c.tag == 'New').toList();
        break;
    }

    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      filtered = filtered
          .where((c) =>
              c.name.toLowerCase().contains(q) ||
              c.phone.toLowerCase().contains(q))
          .toList();
    }

    switch (_sort) {
      case _SortOption.highestSpend:
        filtered.sort((a, b) => b.totalSpent.compareTo(a.totalSpent));
        break;
      case _SortOption.mostOrders:
        filtered.sort((a, b) => b.totalOrders.compareTo(a.totalOrders));
        break;
      case _SortOption.nameAZ:
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case _SortOption.lastOrder:
        filtered.sort((a, b) => b.lastOrderDate.compareTo(a.lastOrderDate));
        break;
    }

    return filtered;
  }

  // ── Shared top section (stats + top customer + search + filter chips) ───
  List<Widget> _buildTopSection(
    List<CustomerModel> allCustomers,
    int atRiskCount,
    double avgSpend,
  ) {
    return [
      // ── Stats cards ──────────────────────────────────────────
      _StatsRow(
        totalCount: allCustomers.length,
        atRiskCount: atRiskCount,
        avgSpend: avgSpend,
      ),

      // ── Top customer highlight ────────────────────────────────
      if (allCustomers.isNotEmpty) ...[
        Builder(builder: (_) {
          final topCustomer = allCustomers
              .reduce((a, b) => a.totalSpent >= b.totalSpent ? a : b);
          return _TopCustomerCard(customer: topCustomer);
        }),
      ],

      // ── Search bar ───────────────────────────────────────────
      Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _query = v.trim()),
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Search by name or phone...',
            hintStyle:
                const TextStyle(color: AppColors.textSecondary),
            prefixIcon: const Icon(Icons.search,
                color: AppColors.textSecondary),
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear,
                        color: AppColors.textSecondary),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _query = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),

      // ── Filter chips ─────────────────────────────────────────
      SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: _Filter.values.map((f) {
            final isSelected = _activeFilter == f;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(f.label),
                selected: isSelected,
                onSelected: (_) =>
                    setState(() => _activeFilter = f),
                selectedColor:
                    AppColors.primary.withValues(alpha: 0.15),
                checkmarkColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  fontWeight: isSelected
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
                backgroundColor: AppColors.surface,
                side: BorderSide(
                  color: isSelected
                      ? AppColors.primary
                      : Colors.transparent,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            );
          }).toList(),
        ),
      ),

      const SizedBox(height: 8),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersStreamProvider(widget.shopId));
    final atRiskCustomers = ref.watch(atRiskCustomersProvider(widget.shopId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Customers',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        automaticallyImplyLeading: false,
        elevation: 0,
        actions: [
          // Export customer list for owner records
          IconButton(
            icon: const Icon(Icons.ios_share, color: Colors.white),
            tooltip: 'Export Customer List',
            onPressed: () {
              final data = customersAsync.valueOrNull ?? [];
              if (data.isEmpty) return;
              final buf = StringBuffer();
              buf.writeln('Customer Name,Phone,Total Orders,Total Spent');
              for (final c in data) {
                buf.writeln('${c.name},${c.phone},${c.totalOrders},${c.totalSpent.toStringAsFixed(0)}');
              }
              Share.share(buf.toString(), subject: 'Customer List Export');
            },
          ),
          PopupMenuButton<_SortOption>(
            icon: const Icon(Icons.sort, color: Colors.white),
            tooltip: 'Sort',
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: _SortOption.lastOrder, child: Text('Last Order')),
              PopupMenuItem(
                  value: _SortOption.highestSpend,
                  child: Text('Highest Spend')),
              PopupMenuItem(
                  value: _SortOption.mostOrders, child: Text('Most Orders')),
              PopupMenuItem(
                  value: _SortOption.nameAZ, child: Text('Name A–Z')),
            ],
          ),
        ],
      ),
      body: customersAsync.when(
        loading: () => const ShimmerList(),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (allCustomers) {
          final avgSpend = allCustomers.isEmpty
              ? 0.0
              : allCustomers.fold<double>(0, (s, c) => s + c.totalSpent) /
                  allCustomers.length;

          final displayed = _applyFilter(allCustomers);
          final topWidgets = _buildTopSection(
              allCustomers, atRiskCustomers.length, avgSpend);

          // ── Mobile list ──────────────────────────────────────────────────
          final mobileList = displayed.isEmpty
              ? _EmptyState(hasCustomers: allCustomers.isNotEmpty)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: displayed.length,
                  itemBuilder: (_, i) => _CustomerCard(
                    customer: displayed[i],
                    shopName: ref.read(shopStreamProvider(widget.shopId)).maybeWhen(
                      data: (s) => s.shopName, orElse: () => ''),
                  )
                      .animate()
                      .fadeIn(
                        duration: 250.ms,
                        delay: (i * 30).ms,
                      )
                      .slideY(begin: 0.06, duration: 250.ms),
                );

          // ── Desktop DataTable ────────────────────────────────────────────
          final desktopTable = displayed.isEmpty
              ? _EmptyState(hasCustomers: allCustomers.isNotEmpty)
              : _CustomersDesktopTable(customers: displayed);

          return AdaptiveLayout(
            // ── MOBILE layout ──────────────────────────────────────────
            mobile: Column(
              children: [
                ...topWidgets,
                Expanded(child: mobileList),
              ],
            ),

            // ── DESKTOP layout — DataTable ─────────────────────────────
            desktop: Column(
              children: [
                ...topWidgets,
                Expanded(child: desktopTable),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Desktop DataTable ─────────────────────────────────────────────────────

class _CustomersDesktopTable extends StatelessWidget {
  final List<CustomerModel> customers;

  const _CustomersDesktopTable({required this.customers});

  Color _tagColor(String tag) {
    switch (tag) {
      case 'Regular':
        return AppColors.success;
      case 'At Risk':
        return AppColors.accent;
      default:
        return const Color(0xFF1976D2);
    }
  }

  String _lastOrderLabel(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  Future<void> _sendWinBack(BuildContext context, CustomerModel customer) async {
    final name = customer.name.isNotEmpty ? customer.name : 'there';
    final rawPhone = customer.phone.replaceAll(RegExp(r'\D'), '');
    final phone =
        rawPhone.startsWith('0') ? rawPhone.substring(1) : rawPhone;
    final countryPhone =
        phone.startsWith('91') ? phone : '91$phone';
    final sn = ref.read(shopStreamProvider(widget.shopId)).maybeWhen(
          data: (s) => s.shopName, orElse: () => '');
    final shopLabel = sn.isNotEmpty ? sn : 'our shop';

    final message = Uri.encodeComponent(
      'Hi $name! We miss you at $shopLabel. '
      "Here's a special 10% discount on your next order! "
      'Visit us soon 🙏',
    );
    final uri = Uri.parse('https://wa.me/$countryPhone?text=$message');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final moneyFmt = NumberFormat('#,##0.00', 'en_IN');

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          color: AppColors.surface,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              AppColors.primary.withValues(alpha: 0.07),
            ),
            headingTextStyle: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            dataTextStyle: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
            ),
            dividerThickness: 0.5,
            columnSpacing: 24,
            columns: const [
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Phone')),
              DataColumn(label: Text('Total Orders'), numeric: true),
              DataColumn(label: Text('Total Spent'), numeric: true),
              DataColumn(label: Text('Last Order')),
              DataColumn(label: Text('Tag')),
              DataColumn(label: Text('Actions')),
            ],
            rows: customers.map((c) {
              final color = _tagColor(c.tag);
              return DataRow(
                cells: [
                  // Name
                  DataCell(
                    Text(
                      c.name.isNotEmpty ? c.name : 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  // Phone
                  DataCell(Text(c.phone)),
                  // Total Orders
                  DataCell(Text('${c.totalOrders}')),
                  // Total Spent
                  DataCell(Text('₹${moneyFmt.format(c.totalSpent)}')),
                  // Last Order
                  DataCell(Text(_lastOrderLabel(c.lastOrderDate))),
                  // Tag chip
                  DataCell(
                    Chip(
                      label: Text(
                        c.tag,
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      backgroundColor: color.withValues(alpha: 0.12),
                      side: BorderSide(color: color.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  // Actions — WhatsApp
                  DataCell(
                    IconButton(
                      tooltip: 'Send WhatsApp message',
                      icon: const Icon(
                        Icons.chat,
                        color: Color(0xFF25D366),
                      ),
                      onPressed: () => _sendWinBack(context, c),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final int totalCount;
  final int atRiskCount;
  final double avgSpend;

  const _StatsRow({
    required this.totalCount,
    required this.atRiskCount,
    required this.avgSpend,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##,##0', 'en_IN');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              label: 'Total Customers',
              value: '$totalCount',
              icon: Icons.people_alt_outlined,
              iconColor: AppColors.primary,
              valueColor: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              label: 'At Risk',
              value: '$atRiskCount',
              icon: Icons.warning_amber_rounded,
              iconColor: Colors.deepOrange,
              valueColor: Colors.deepOrange,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              label: 'Avg Spend',
              value: '₹${fmt.format(avgSpend)}',
              icon: Icons.currency_rupee,
              iconColor: AppColors.success,
              valueColor: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color valueColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: valueColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Top Customer highlight card ───────────────────────────────────────────

class _TopCustomerCard extends StatelessWidget {
  final CustomerModel customer;
  const _TopCustomerCard({required this.customer});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##,##0', 'en_IN');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.08),
              const Color(0xFF52B788).withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.star_rounded,
                  color: Color(0xFFFFB300), size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Top Customer',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    customer.name.isNotEmpty ? customer.name : 'Unknown',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${fmt.format(customer.totalSpent)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  '${customer.totalOrders} orders',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Customer card ─────────────────────────────────────────────────────────

class _CustomerCard extends StatelessWidget {
  final CustomerModel customer;
  final String shopName;

  const _CustomerCard({required this.customer, this.shopName = ''});

  Color get _tagColor {
    switch (customer.tag) {
      case 'Regular':
        return AppColors.success;
      case 'At Risk':
        return Colors.deepOrange;
      default:
        return Colors.blue.shade600;
    }
  }

  String _daysAgoLabel() {
    final days =
        DateTime.now().difference(customer.lastOrderDate).inDays;
    if (days == 0) return 'Today';
    if (days == 1) return '1 day ago';
    return '$days days ago';
  }

  Future<void> _sendWinBack(BuildContext context) async {
    final name = customer.name.isNotEmpty ? customer.name : 'there';
    // Strip any leading + or country code for wa.me
    final rawPhone = customer.phone.replaceAll(RegExp(r'\D'), '');
    final phone =
        rawPhone.startsWith('0') ? rawPhone.substring(1) : rawPhone;
    final countryPhone =
        phone.startsWith('91') ? phone : '91$phone';
    final shopLabel = shopName.isNotEmpty ? shopName : 'our shop';

    final message = Uri.encodeComponent(
      'Hi $name! We miss you at $shopLabel. '
      "Here's a special 10% discount on your next order! "
      'Visit us soon 🙏',
    );
    final uri = Uri.parse('https://wa.me/$countryPhone?text=$message');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayLabel = _daysAgoLabel();
    final isAtRisk = customer.isAtRisk;
    final moneyFmt = NumberFormat('#,##0.00', 'en_IN');

    return GestureDetector(
      onTap: () => context.push('/customers/detail', extra: customer),
      child: Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: avatar + info + tag chip ──────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar with gradient
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF2D6A4F), // AppColors.primary
                        Color(0xFF1B4332), // AppColors.primaryDark
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      customer.name.isNotEmpty
                          ? customer.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + tag chip
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              customer.name.isNotEmpty
                                  ? customer.name
                                  : 'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _TagChip(label: customer.tag, color: _tagColor),
                        ],
                      ),
                      const SizedBox(height: 3),
                      // Phone
                      Text(
                        customer.phone,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ── Spend + orders row ──────────────────────────────────
            Row(
              children: [
                const Icon(Icons.currency_rupee,
                    size: 14, color: AppColors.textSecondary),
                Expanded(
                  child: Text(
                    '${moneyFmt.format(customer.totalSpent)} spent',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Text(
                  '  •  ',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                Text(
                  '${customer.totalOrders} order${customer.totalOrders == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // ── Last order ──────────────────────────────────────────
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 14,
                  color: isAtRisk ? Colors.deepOrange : AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Last order: $dayLabel',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        isAtRisk ? Colors.deepOrange : AppColors.textSecondary,
                    fontWeight:
                        isAtRisk ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),

            // ── Win-back button (At Risk only) ──────────────────────
            if (isAtRisk) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _sendWinBack(context),
                  icon: const Icon(Icons.chat, size: 18),
                  label: const Text('Send Win-Back Message'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.deepOrange,
                    side: const BorderSide(color: Colors.deepOrange),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
    );
  }
}

// ── Tag chip ──────────────────────────────────────────────────────────────

class _TagChip extends StatelessWidget {
  final String label;
  final Color color;

  const _TagChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  /// True when there ARE customers but the current search/filter yields nothing.
  final bool hasCustomers;

  const _EmptyState({required this.hasCustomers});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasCustomers
                  ? Icons.search_off_rounded
                  : Icons.people_outline_rounded,
              size: 72,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              hasCustomers
                  ? 'No customers match your search.'
                  : 'No customers yet.',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (!hasCustomers)
              const Text(
                'Customers will appear here when they place orders.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}
