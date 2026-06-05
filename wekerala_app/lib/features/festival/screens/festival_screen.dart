import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/festival_data.dart';
import '../../../models/customer_model.dart';
import '../../../providers/customers_provider.dart';
import '../../../providers/shop_provider.dart';
import '../../../shared/widgets/shimmer_list.dart';

class FestivalScreen extends ConsumerWidget {
  const FestivalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopAsync = ref.watch(activeShopIdProvider);
    return shopAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: ShimmerList(itemCount: 4, itemHeight: 100),
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
        return _FestivalBody(shopId: shopId);
      },
    );
  }
}

enum _CustomerFilter { all, regular, atRisk }

class _FestivalBody extends ConsumerStatefulWidget {
  final String shopId;
  const _FestivalBody({required this.shopId});

  @override
  ConsumerState<_FestivalBody> createState() => _FestivalBodyState();
}

class _FestivalBodyState extends ConsumerState<_FestivalBody> {
  Festival? _selected;
  bool _useMalayalam = false;
  _CustomerFilter _filter = _CustomerFilter.all;
  late TextEditingController _msgCtrl;

  @override
  void initState() {
    super.initState();
    _msgCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  String _resolvedShopName() {
    final shopAsync = ref.read(shopStreamProvider(widget.shopId));
    return shopAsync.maybeWhen(data: (s) => s.shopName, orElse: () => '');
  }

  String _applyShopName(String template) {
    final name = _resolvedShopName();
    return name.isNotEmpty ? template.replaceAll('{shopName}', name) : template;
  }

  void _selectFestival(Festival f) {
    setState(() {
      _selected = f;
      final template = _useMalayalam ? f.templateMl : f.templateEn;
      _msgCtrl.text = _applyShopName(template);
    });
  }

  void _toggleLang(bool ml) {
    setState(() {
      _useMalayalam = ml;
      if (_selected != null) {
        final template = ml ? _selected!.templateMl : _selected!.templateEn;
        _msgCtrl.text = _applyShopName(template);
      }
    });
  }

  List<CustomerModel> _filterCustomers(List<CustomerModel> all) {
    switch (_filter) {
      case _CustomerFilter.all:
        return all;
      case _CustomerFilter.regular:
        return all.where((c) => !c.isAtRisk && c.totalOrders >= 3).toList();
      case _CustomerFilter.atRisk:
        return all.where((c) => c.isAtRisk).toList();
    }
  }

  Future<void> _sendToAll(List<CustomerModel> customers) async {
    if (_msgCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write a message first.')),
      );
      return;
    }

    final filtered = _filterCustomers(customers);
    if (filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No customers in this group.')),
      );
      return;
    }

    final groupLabel = _filter == _CustomerFilter.all
        ? 'All Customers'
        : _filter == _CustomerFilter.regular
            ? 'Regular Customers'
            : 'At-Risk Customers';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Send to ${filtered.length} customers?'),
        content: Text(
          'Group: $groupLabel\n\n'
          'WhatsApp will open for each customer one by one. '
          'After sending, return to the app and tap Next.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Start Sending',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await _showSendingSheet(filtered);
  }

  Future<void> _sendBroadcast() async {
    final msg = _msgCtrl.text.trim();
    if (msg.isEmpty) return;
    final uri =
        Uri.parse('https://wa.me/?text=${Uri.encodeComponent(msg)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _showSendingSheet(List<CustomerModel> customers) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SendingSheet(
        customers: customers,
        message: _msgCtrl.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersStreamProvider(widget.shopId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Festival Auto-Pilot 🎉',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: customersAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (customers) {
          final filtered = _filterCustomers(customers);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              // Step 1: Pick festival
              const Text(
                'STEP 1 — PICK A FESTIVAL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: kFestivals.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.85,
                ),
                itemBuilder: (_, i) {
                  final f = kFestivals[i];
                  final isSelected = _selected?.name == f.name;
                  return GestureDetector(
                    onTap: () => _selectFestival(f),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary.withValues(alpha: 0.15),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(f.emoji, style: const TextStyle(fontSize: 26)),
                          const SizedBox(height: 4),
                          Text(
                            f.name,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ).animate().fadeIn(
                          duration: 250.ms,
                          delay: Duration(milliseconds: i * 30),
                        ),
                  );
                },
              ),

              if (_selected != null) ...[
                const SizedBox(height: 24),

                // Step 2: Edit message
                const Text(
                  'STEP 2 — EDIT MESSAGE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),

                // Language toggle
                Row(
                  children: [
                    const Text('Language: ',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(width: 8),
                    _LangChip(
                        label: 'English',
                        selected: !_useMalayalam,
                        onTap: () => _toggleLang(false)),
                    const SizedBox(width: 8),
                    _LangChip(
                        label: 'Malayalam',
                        selected: _useMalayalam,
                        onTap: () => _toggleLang(true)),
                  ],
                ),
                const SizedBox(height: 10),

                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color:
                            AppColors.textSecondary.withValues(alpha: 0.2)),
                  ),
                  child: TextField(
                    controller: _msgCtrl,
                    maxLines: 7,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(14),
                      hintText: 'Your festival message...',
                      hintStyle:
                          TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Step 3: Choose recipients
                const Text(
                  'STEP 3 — CHOOSE RECIPIENTS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    _FilterChip2(
                      label: 'All (${customers.length})',
                      selected: _filter == _CustomerFilter.all,
                      onTap: () => setState(() => _filter = _CustomerFilter.all),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip2(
                      label: 'Regular (${customers.where((c) => !c.isAtRisk && c.totalOrders >= 3).length})',
                      selected: _filter == _CustomerFilter.regular,
                      onTap: () => setState(() => _filter = _CustomerFilter.regular),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip2(
                      label: 'At Risk (${customers.where((c) => c.isAtRisk).length})',
                      selected: _filter == _CustomerFilter.atRisk,
                      onTap: () => setState(() => _filter = _CustomerFilter.atRisk),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Send buttons
                ElevatedButton.icon(
                  onPressed: () => _sendToAll(customers),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366), // WhatsApp green
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.send),
                  label: Text(
                    'Send to ${filtered.length} customer${filtered.length == 1 ? '' : 's'} via WhatsApp',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),

                const SizedBox(height: 10),

                OutlinedButton.icon(
                  onPressed: _sendBroadcast,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    minimumSize: const Size(double.infinity, 46),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.group, size: 18),
                  label: const Text(
                    'Share to WhatsApp Group',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ── Sending sheet — one customer at a time ────────────────────────────────

class _SendingSheet extends StatefulWidget {
  final List<CustomerModel> customers;
  final String message;
  const _SendingSheet({required this.customers, required this.message});

  @override
  State<_SendingSheet> createState() => _SendingSheetState();
}

class _SendingSheetState extends State<_SendingSheet> {
  int _current = 0;

  Future<void> _openWhatsApp() async {
    final c = widget.customers[_current];
    final raw = c.phone.replaceAll(RegExp(r'\D'), '');
    final phone =
        raw.startsWith('0') ? raw.substring(1) : raw;
    final countryPhone = phone.startsWith('91') ? phone : '91$phone';
    final uri = Uri.parse(
        'https://wa.me/$countryPhone?text=${Uri.encodeComponent(widget.message)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = _current >= widget.customers.length;
    final total = widget.customers.length;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              done ? 'All Done! 🎉' : 'Sending Messages',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              done
                  ? 'Festival messages sent to $total customers.'
                  : 'Customer ${_current + 1} of $total',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
            ),

            const SizedBox(height: 20),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: done ? 1.0 : _current / total,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                color: AppColors.primary,
                minHeight: 8,
              ),
            ),

            if (!done) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                      child: Text(
                        widget.customers[_current].name.isNotEmpty
                            ? widget.customers[_current].name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.customers[_current].name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary),
                          ),
                          Text(
                            widget.customers[_current].phone,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _openWhatsApp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.send),
                label: const Text('Open WhatsApp & Send',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  if (_current < total - 1) {
                    setState(() => _current++);
                  } else {
                    setState(() => _current = total);
                  }
                },
                child: Text(
                  _current < total - 1 ? 'Next Customer →' : 'Mark as Done',
                  style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
              ),
            ] else ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Done',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────

class _LangChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _LangChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.textSecondary.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _FilterChip2 extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip2({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.textSecondary.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
