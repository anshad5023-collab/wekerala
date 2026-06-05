import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/shop_model.dart';
import '../../../providers/shop_provider.dart';

class WhatsappNotificationsScreen extends ConsumerStatefulWidget {
  const WhatsappNotificationsScreen({super.key});

  @override
  ConsumerState<WhatsappNotificationsScreen> createState() =>
      _WhatsappNotificationsScreenState();
}

class _WhatsappNotificationsScreenState
    extends ConsumerState<WhatsappNotificationsScreen> {
  // ── POS WhatsApp receipt (saved to autoSendWhatsappReceipt on shop doc) ────
  bool _autoSendReceipt = false;

  // ── Owner notification toggles (saved to whatsappSettings) ────────────────
  bool _newOrderAlert = false;
  bool _autoCancelAlert = true;
  bool _dailySummary = true;
  bool _monthlyReport = true;
  bool _lowStockAlert = true;
  bool _reorderAlert = false;
  bool _udharOverdueSummary = true;
  bool _flashSaleAlert = true;
  final _reminderDaysCtrl = TextEditingController(text: '7');

  // ── AI WhatsApp Assistant (saved to aiSettings) ───────────────────────────
  bool _aiEnabled = false;
  String _replyLanguage = 'auto'; // 'auto' | 'english' | 'malayalam'
  bool _shareProductPrices = true;
  bool _shareStockStatus = false;
  bool _answerDeliveryQuestions = true;
  bool _neverShareOwnerPhone = true;
  bool _neverShareOwnerAddress = true;
  bool _neverDiscussCompetitors = false;
  final _handoffKeywordCtrl = TextEditingController();
  final _customInstructionsCtrl = TextEditingController();

  bool _saving = false;
  bool _testingSend = false;
  bool _loaded = false;

  @override
  void dispose() {
    _reminderDaysCtrl.dispose();
    _handoffKeywordCtrl.dispose();
    _customInstructionsCtrl.dispose();
    super.dispose();
  }

  void _loadFrom(ShopModel shop) {
    if (_loaded) return;
    _loaded = true;
    final s = shop.whatsappSettings;
    final ai = shop.aiSettings;
    setState(() {
      _autoSendReceipt     = shop.autoSendWhatsappReceipt;
      // Notification toggles
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

      // AI settings
      _aiEnabled               = ai['enabled']                 as bool?   ?? false;
      _replyLanguage           = ai['replyLanguage']           as String? ?? 'auto';
      _shareProductPrices      = ai['shareProductPrices']      as bool?   ?? true;
      _shareStockStatus        = ai['shareStockStatus']        as bool?   ?? false;
      _answerDeliveryQuestions = ai['answerDeliveryQuestions'] as bool?   ?? true;
      _neverShareOwnerPhone    = ai['neverShareOwnerPhone']    as bool?   ?? true;
      _neverShareOwnerAddress  = ai['neverShareOwnerAddress']  as bool?   ?? true;
      _neverDiscussCompetitors = ai['neverDiscussCompetitors'] as bool?   ?? false;
      _handoffKeywordCtrl.text    = ai['humanHandoffKeyword']  as String? ?? '';
      _customInstructionsCtrl.text = ai['customInstructions'] as String? ?? '';
    });
  }

  Future<void> _save(String shopId) async {
    final days = int.tryParse(_reminderDaysCtrl.text.trim()) ?? 7;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('shops').doc(shopId).update({
        'autoSendWhatsappReceipt': _autoSendReceipt,
        'whatsappSettings': {
          'newOrderAlert':       _newOrderAlert,
          'autoCancelAlert':     _autoCancelAlert,
          'dailySummary':        _dailySummary,
          'monthlyReport':       _monthlyReport,
          'lowStockAlert':       _lowStockAlert,
          'reorderAlert':        _reorderAlert,
          'udharOverdueSummary': _udharOverdueSummary,
          'flashSaleAlert':      _flashSaleAlert,
          'udharReminderDays':   days.clamp(1, 90),
        },
        'aiSettings': {
          'enabled':                 _aiEnabled,
          'replyLanguage':           _replyLanguage,
          'shareProductPrices':      _shareProductPrices,
          'shareStockStatus':        _shareStockStatus,
          'answerDeliveryQuestions': _answerDeliveryQuestions,
          'neverShareOwnerPhone':    _neverShareOwnerPhone,
          'neverShareOwnerAddress':  _neverShareOwnerAddress,
          'neverDiscussCompetitors': _neverDiscussCompetitors,
          'humanHandoffKeyword':     _handoffKeywordCtrl.text.trim(),
          'customInstructions':      _customInstructionsCtrl.text.trim(),
        },
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Preferences saved'),
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

  Future<void> _sendTest(String shopId) async {
    setState(() => _testingSend = true);
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('sendTestWhatsApp');
      await callable.call({'shopId': shopId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Test message sent to your WhatsApp!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ ${e.message}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _testingSend = false);
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
        shopStream.whenData((shop) => _loadFrom(shop));

        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          appBar: AppBar(
            title: const Text('WhatsApp Settings'),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Connection Status ─────────────────────────────────────
              _ConnectionBanner(
                onTest: _testingSend ? null : () => _sendTest(shopId),
                testing: _testingSend,
              ),
              const SizedBox(height: 20),

              // ── AI WhatsApp Assistant ─────────────────────────────────
              _SectionLabel('AI WhatsApp Assistant'),
              _Card(children: [
                _PrefTile(
                  icon: Icons.smart_toy_outlined,
                  iconColor: const Color(0xFF7B1FA2),
                  title: 'Enable AI Auto-Reply',
                  subtitle:
                      'AI replies to customer WhatsApp messages using your product data',
                  value: _aiEnabled,
                  onChanged: (v) => setState(() => _aiEnabled = v),
                ),
                if (_aiEnabled) ...[
                  const Divider(height: 1, indent: 64),

                  // Reply language
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF7B1FA2).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.translate_outlined,
                              color: Color(0xFF7B1FA2), size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Reply Language',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500)),
                              Text(
                                  'Which language should AI use to reply?',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B7280))),
                            ],
                          ),
                        ),
                        DropdownButton<String>(
                          value: _replyLanguage,
                          underline: const SizedBox(),
                          borderRadius: BorderRadius.circular(10),
                          items: const [
                            DropdownMenuItem(
                                value: 'auto',
                                child: Text('Auto-detect')),
                            DropdownMenuItem(
                                value: 'malayalam',
                                child: Text('Malayalam')),
                            DropdownMenuItem(
                                value: 'english',
                                child: Text('English')),
                          ],
                          onChanged: (v) =>
                              setState(() => _replyLanguage = v ?? 'auto'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, indent: 64),

                  _PrefTile(
                    icon: Icons.price_change_outlined,
                    iconColor: const Color(0xFF2D6A4F),
                    title: 'Share Product Prices',
                    subtitle:
                        'AI tells customers the price of items they ask about',
                    value: _shareProductPrices,
                    onChanged: (v) =>
                        setState(() => _shareProductPrices = v),
                  ),
                  const Divider(height: 1, indent: 64),
                  _PrefTile(
                    icon: Icons.inventory_outlined,
                    iconColor: const Color(0xFF2D6A4F),
                    title: 'Share Stock Availability',
                    subtitle:
                        'AI tells customers if an item is in stock or out of stock',
                    value: _shareStockStatus,
                    onChanged: (v) =>
                        setState(() => _shareStockStatus = v),
                  ),
                  const Divider(height: 1, indent: 64),
                  _PrefTile(
                    icon: Icons.local_shipping_outlined,
                    iconColor: const Color(0xFF1976D2),
                    title: 'Answer Delivery Questions',
                    subtitle:
                        'AI shares delivery charge, min order, and free delivery details',
                    value: _answerDeliveryQuestions,
                    onChanged: (v) =>
                        setState(() => _answerDeliveryQuestions = v),
                  ),
                  const Divider(height: 1, indent: 64),

                  // Human handoff keyword
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFE53935).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.support_agent_outlined,
                              color: Color(0xFFE53935), size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Human Handoff Word',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500)),
                              SizedBox(height: 2),
                              Text(
                                'When customer types this, AI pauses and alerts you',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B7280)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 100,
                          child: TextField(
                            controller: _handoffKeywordCtrl,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'e.g. human',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    BorderSide(color: AppColors.primary),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ]),
              const SizedBox(height: 16),

              // ── Privacy Controls (only when AI enabled) ───────────────
              if (_aiEnabled) ...[
                _SectionLabel('AI Privacy Controls'),
                _Card(children: [
                  _PrefTile(
                    icon: Icons.phone_locked_outlined,
                    iconColor: const Color(0xFFE53935),
                    title: 'Never Share Your Phone Number',
                    subtitle:
                        'AI will not give customers your personal number',
                    value: _neverShareOwnerPhone,
                    onChanged: (v) =>
                        setState(() => _neverShareOwnerPhone = v),
                  ),
                  const Divider(height: 1, indent: 64),
                  _PrefTile(
                    icon: Icons.home_work_outlined,
                    iconColor: const Color(0xFFE53935),
                    title: 'Never Share Your Home Address',
                    subtitle:
                        'AI will not reveal your personal or home address',
                    value: _neverShareOwnerAddress,
                    onChanged: (v) =>
                        setState(() => _neverShareOwnerAddress = v),
                  ),
                  const Divider(height: 1, indent: 64),
                  _PrefTile(
                    icon: Icons.store_outlined,
                    iconColor: const Color(0xFF546E7A),
                    title: 'Never Mention Competitors',
                    subtitle:
                        'AI will not recommend or compare other shops',
                    value: _neverDiscussCompetitors,
                    onChanged: (v) =>
                        setState(() => _neverDiscussCompetitors = v),
                  ),
                ]),
                const SizedBox(height: 16),

                // Custom instructions
                _SectionLabel('Custom AI Instructions'),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Special instructions for the AI',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1A2E22)),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Example: "Always greet in Malayalam. If asked about fish, say we only sell vegetables."',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _customInstructionsCtrl,
                        maxLines: 4,
                        maxLength: 500,
                        decoration: InputDecoration(
                          hintText: 'Type custom instructions here...',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                BorderSide(color: AppColors.primary),
                          ),
                          contentPadding: const EdgeInsets.all(10),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── POS Billing ───────────────────────────────────────────
              _SectionLabel('POS Billing'),
              _Card(children: [
                _PrefTile(
                  icon: Icons.receipt_long_outlined,
                  iconColor: const Color(0xFF25D366),
                  title: 'WhatsApp receipt after billing',
                  subtitle:
                      'Opens WhatsApp with pre-filled receipt after each POS payment — you tap Send',
                  value: _autoSendReceipt,
                  onChanged: (v) => setState(() => _autoSendReceipt = v),
                ),
              ]),
              const SizedBox(height: 16),

              // ── Order Alerts ──────────────────────────────────────────
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
                  subtitle:
                      'Alert when order is cancelled after 45 min of no action',
                  value: _autoCancelAlert,
                  onChanged: (v) => setState(() => _autoCancelAlert = v),
                ),
              ]),
              const SizedBox(height: 16),

              // ── Reports ───────────────────────────────────────────────
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
                  subtitle:
                      'Full revenue and top products — sent on the 1st of month',
                  value: _monthlyReport,
                  onChanged: (v) => setState(() => _monthlyReport = v),
                ),
              ]),
              const SizedBox(height: 16),

              // ── Stock Alerts ──────────────────────────────────────────
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

              // ── Udhar ─────────────────────────────────────────────────
              _SectionLabel('Credit (Udhar) Alerts'),
              _Card(children: [
                _PrefTile(
                  icon: Icons.account_balance_wallet_outlined,
                  iconColor: const Color(0xFF2D6A4F),
                  title: 'Overdue Summary',
                  subtitle:
                      'Daily list of customers with overdue payments — sent at 10 AM',
                  value: _udharOverdueSummary,
                  onChanged: (v) =>
                      setState(() => _udharOverdueSummary = v),
                ),
                const Divider(height: 1, indent: 64),
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
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Customer Reminder Gap',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500)),
                            SizedBox(height: 2),
                            Text(
                              'Days before due date to remind the customer',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF6B7280)),
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
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: InputDecoration(
                            suffixText: 'd',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: AppColors.primary),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 16),

              // ── Promotions ────────────────────────────────────────────
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
                          width: 22, height: 22,
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

// ── Connection Status Banner ──────────────────────────────────────────────────

class _ConnectionBanner extends StatelessWidget {
  final VoidCallback? onTest;
  final bool testing;
  const _ConnectionBanner({required this.onTest, required this.testing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFF2D6A4F).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.chat_outlined, color: Color(0xFF25D366), size: 20),
            SizedBox(width: 8),
            Text(
              'WhatsApp via Meta Cloud API',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A2E22)),
            ),
          ]),
          const SizedBox(height: 6),
          const Text(
            'Messages are sent from the weKerala business number using '
            "Meta's official API. No third-party service. No monthly platform fee.",
            style: TextStyle(fontSize: 12, color: Color(0xFF2D6A4F)),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                side: const BorderSide(color: Color(0xFF2D6A4F)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              icon: testing
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF2D6A4F)))
                  : const Icon(Icons.send_outlined,
                      color: Color(0xFF2D6A4F), size: 16),
              label: Text(
                testing
                    ? 'Sending...'
                    : 'Send Test Message to My WhatsApp',
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF2D6A4F)),
              ),
              onPressed: onTest,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────

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
        width: 38, height: 38,
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
          style:
              const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
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
