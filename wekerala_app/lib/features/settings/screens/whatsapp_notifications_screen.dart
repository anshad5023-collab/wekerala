import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/shop_provider.dart';

class WhatsappNotificationsScreen extends ConsumerStatefulWidget {
  const WhatsappNotificationsScreen({super.key});

  @override
  ConsumerState<WhatsappNotificationsScreen> createState() =>
      _WhatsappNotificationsScreenState();
}

class _WhatsappNotificationsScreenState
    extends ConsumerState<WhatsappNotificationsScreen> {
  // ── Owner notification toggles ─────────────────────────────────────────────
  bool _newOrderAlert = false;       // OFF by default — owners prefer in-app push
  bool _autoCancelAlert = true;
  bool _dailySummary = true;
  bool _monthlyReport = true;
  bool _lowStockAlert = true;
  bool _reorderAlert = false;        // OFF by default — fires every 6h, can be noisy
  bool _udharOverdueSummary = true;
  bool _flashSaleAlert = true;

  // ── Udhar reminder ────────────────────────────────────────────────────────
  final _reminderDaysCtrl = TextEditingController(text: '7');

  bool _saving = false;
  bool _loaded = false;

  @override
  void dispose() {
    _reminderDaysCtrl.dispose();
    super.dispose();
  }

  void _loadFrom(Map<String, dynamic>? s) {
    if (_loaded || s == null) return;
    _loaded = true;
    setState(() {
      _newOrderAlert       = s['newOrderAlert']       as bool? ?? false;
      _autoCancelAlert     = s['autoCancelAlert']     as bool? ?? true;
      _dailySummary        = s['dailySummary']        as bool? ?? true;
      _monthlyReport       = s['monthlyReport']       as bool? ?? true;
      _lowStockAlert       = s['lowStockAlert']       as bool? ?? true;
      _reorderAlert        = s['reorderAlert']        as bool? ?? false;
      _udharOverdueSummary = s['udharOverdueSummary'] as bool? ?? true;
      _flashSaleAlert      = s['flashSaleAlert']      as bool? ?? true;
      final days = s['udharReminderDays'];
      _reminderDaysCtrl.text = days?.toString() ?? '7';
    });
  }

  Future<void> _save(String shopId) async {
    final days = int.tryParse(_reminderDaysCtrl.text.trim()) ?? 7;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('shops').doc(shopId).update({
        'whatsappSettings': {
          'newOrderAlert': _newOrderAlert,
          'autoCancelAlert': _autoCancelAlert,
          'dailySummary': _dailySummary,
          'monthlyReport': _monthlyReport,
          'lowStockAlert': _lowStockAlert,
          'reorderAlert': _reorderAlert,
          'udharOverdueSummary': _udharOverdueSummary,
          'flashSaleAlert': _flashSaleAlert,
          'udharReminderDays': days.clamp(1, 90),
        },
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Notification preferences saved'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopAsync = ref.watch(activeShopIdProvider);

    return shopAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text(e.toString()))),
      data: (shopId) {
        if (shopId == null || shopId.isEmpty) {
          return const Scaffold(body: Center(child: Text('No shop found')));
        }
        final shopStream = ref.watch(shopStreamProvider(shopId));
        shopStream.whenData((shop) => _loadFrom(shop.whatsappSettings));

        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          appBar: AppBar(
            title: const Text('WhatsApp Notifications'),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Info banner
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF2D6A4F).withValues(alpha: 0.3)),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline, size: 18, color: Color(0xFF2D6A4F)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Choose which WhatsApp alerts you receive. Turning off saves cost — you still get in-app notifications for everything.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF2D6A4F)),
                    ),
                  ),
                ]),
              ),

              // ── Orders ─────────────────────────────────────────────────────
              _SectionLabel('Order Alerts'),
              _Card(children: [
                _PrefTile(
                  icon: Icons.shopping_bag_outlined,
                  iconColor: const Color(0xFF25D366),
                  title: 'New Order Alert',
                  subtitle: 'WhatsApp when a customer places a new order',
                  badge: _newOrderAlert ? null : 'OFF by default',
                  value: _newOrderAlert,
                  onChanged: (v) => setState(() => _newOrderAlert = v),
                ),
                const Divider(height: 1, indent: 64),
                _PrefTile(
                  icon: Icons.timer_off_outlined,
                  iconColor: const Color(0xFFE53935),
                  title: 'Auto-Cancel Warning',
                  subtitle: 'Alert when an order is cancelled after 45 min of no action',
                  value: _autoCancelAlert,
                  onChanged: (v) => setState(() => _autoCancelAlert = v),
                ),
              ]),
              const SizedBox(height: 16),

              // ── Reports ────────────────────────────────────────────────────
              _SectionLabel('Reports'),
              _Card(children: [
                _PrefTile(
                  icon: Icons.bar_chart_outlined,
                  iconColor: const Color(0xFF1976D2),
                  title: 'Daily Sales Summary',
                  subtitle: 'Revenue, top item, low stock — sent at 9:30 PM',
                  value: _dailySummary,
                  onChanged: (v) => setState(() => _dailySummary = v),
                ),
                const Divider(height: 1, indent: 64),
                _PrefTile(
                  icon: Icons.calendar_month_outlined,
                  iconColor: const Color(0xFF7B1FA2),
                  title: 'Monthly Business Report',
                  subtitle: 'Full revenue and top products — sent on the 1st of month',
                  value: _monthlyReport,
                  onChanged: (v) => setState(() => _monthlyReport = v),
                ),
              ]),
              const SizedBox(height: 16),

              // ── Stock ──────────────────────────────────────────────────────
              _SectionLabel('Stock Alerts'),
              _Card(children: [
                _PrefTile(
                  icon: Icons.warning_amber_outlined,
                  iconColor: const Color(0xFFF57C00),
                  title: 'Low Stock Warning',
                  subtitle: 'Alert when a product drops below its threshold',
                  value: _lowStockAlert,
                  onChanged: (v) => setState(() => _lowStockAlert = v),
                ),
                const Divider(height: 1, indent: 64),
                _PrefTile(
                  icon: Icons.inventory_2_outlined,
                  iconColor: const Color(0xFF546E7A),
                  title: 'Out-of-Stock Reorder Alert',
                  subtitle: 'Sent every 6 hours for zero-stock items',
                  badge: _reorderAlert ? null : 'OFF by default',
                  value: _reorderAlert,
                  onChanged: (v) => setState(() => _reorderAlert = v),
                ),
              ]),
              const SizedBox(height: 16),

              // ── Udhar ──────────────────────────────────────────────────────
              _SectionLabel('Credit (Udhar) Alerts'),
              _Card(children: [
                _PrefTile(
                  icon: Icons.account_balance_wallet_outlined,
                  iconColor: const Color(0xFF2D6A4F),
                  title: 'Overdue Summary',
                  subtitle: 'Daily list of customers with overdue payments — sent at 10 AM',
                  value: _udharOverdueSummary,
                  onChanged: (v) => setState(() => _udharOverdueSummary = v),
                ),
                const Divider(height: 1, indent: 64),
                // Reminder days field
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D6A4F).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.schedule_outlined,
                            color: Color(0xFF2D6A4F), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Customer Reminder Gap',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 2),
                            const Text(
                              'How many days before due date to remind the customer',
                              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 64,
                        child: TextField(
                          controller: _reminderDaysCtrl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: InputDecoration(
                            suffixText: 'd',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: AppColors.primary),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 16),

              // ── Promotions ─────────────────────────────────────────────────
              _SectionLabel('Promotions'),
              _Card(children: [
                _PrefTile(
                  icon: Icons.local_fire_department_outlined,
                  iconColor: const Color(0xFFFC8019),
                  title: 'Flash Sale Started',
                  subtitle: 'Alert when a flash sale you created goes live',
                  value: _flashSaleAlert,
                  onChanged: (v) => setState(() => _flashSaleAlert = v),
                ),
              ]),
              const SizedBox(height: 24),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saving ? null : () => _save(shopId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Save Preferences',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}

// ── Widgets ──────────────────────────────────────────────────────────────────

class _PrefTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? badge;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PrefTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      secondary: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Row(children: [
        Expanded(
          child: Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A2E22))),
        ),
        if (badge != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(badge!,
                style:
                    const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
          ),
        ],
      ]),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.primary,
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(children: children),
      );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey)),
      );
}
