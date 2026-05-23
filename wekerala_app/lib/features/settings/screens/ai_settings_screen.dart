import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/shop_provider.dart';

class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  bool _enabled = false;
  bool _shareProductPrices = true;
  bool _shareStockStatus = true;
  bool _answerDelivery = true;
  bool _answerHours = true;
  String _replyLanguage = 'auto';
  final _noteCtrl = TextEditingController();
  final _gupshupCtrl = TextEditingController();
  bool _saving = false;
  bool _loaded = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    _gupshupCtrl.dispose();
    super.dispose();
  }

  void _loadFrom(Map<String, dynamic> s) {
    if (_loaded) return;
    _loaded = true;
    setState(() {
      _enabled = s['enabled'] as bool? ?? false;
      _shareProductPrices = s['shareProductPrices'] as bool? ?? true;
      _shareStockStatus = s['shareStockStatus'] as bool? ?? true;
      _answerDelivery = s['answerDelivery'] as bool? ?? true;
      _answerHours = s['answerHours'] as bool? ?? true;
      _replyLanguage = s['replyLanguage'] as String? ?? 'auto';
      _noteCtrl.text = s['customNote'] as String? ?? '';
      _gupshupCtrl.text = s['gupshupAppName'] as String? ?? '';
    });
  }

  Future<void> _save(String shopId) async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('shops').doc(shopId).update({
        'aiSettings': {
          'enabled': _enabled,
          'shareProductPrices': _shareProductPrices,
          'shareStockStatus': _shareStockStatus,
          'answerDelivery': _answerDelivery,
          'answerHours': _answerHours,
          'replyLanguage': _replyLanguage,
          'customNote': _noteCtrl.text.trim(),
          'gupshupAppName': _gupshupCtrl.text.trim(),
        },
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('AI settings saved'),
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
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text(e.toString()))),
      data: (shopId) {
        if (shopId == null || shopId.isEmpty) {
          return const Scaffold(body: Center(child: Text('No shop found')));
        }
        final shopStream = ref.watch(shopStreamProvider(shopId));
        shopStream.whenData((shop) => _loadFrom(shop.aiSettings));

        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          appBar: AppBar(
            title: const Text('WhatsApp AI Assistant'),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Info banner
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA5D6A7)),
                ),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFF2D6A4F)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'The AI chat widget appears on your storefront. Customers can ask questions and get instant answers — free, no WhatsApp costs.',
                        style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Master toggle
              _Card(children: [
                SwitchListTile(
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                  activeColor: AppColors.primary,
                  title: const Text('Enable AI Chat Widget',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    _enabled ? 'Chat button visible on your storefront' : 'Chat button hidden',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  secondary: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: _enabled
                          ? const Color(0xFF2D6A4F).withValues(alpha: 0.1)
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.smart_toy_outlined,
                        color: _enabled ? const Color(0xFF2D6A4F) : Colors.grey),
                  ),
                ),
              ]),
              const SizedBox(height: 16),

              // Gupshup setup
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Gupshup Setup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      const Text('Enter your Gupshup App Name to receive customer messages.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _gupshupCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Gupshup App Name',
                          hintText: 'e.g. myshop_whatsapp',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phonelink_setup),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(8)),
                        child: const Text('Webhook URL to set in Gupshup dashboard:\nhttps://us-central1-shoplink-prod.cloudfunctions.net/whatsappWebhook', style: TextStyle(fontSize: 11, fontFamily: 'monospace')),
                      ),
                    ],
                  ),
                ),
              ),

              // What AI can share
              _SectionLabel('What AI Can Share'),
              _Card(children: [
                _Toggle('Share product prices', _shareProductPrices,
                    (v) => setState(() => _shareProductPrices = v)),
                const Divider(height: 1, indent: 16),
                _Toggle('Share stock availability (in/out of stock)', _shareStockStatus,
                    (v) => setState(() => _shareStockStatus = v)),
                const Divider(height: 1, indent: 16),
                _Toggle('Answer delivery & charges questions', _answerDelivery,
                    (v) => setState(() => _answerDelivery = v)),
                const Divider(height: 1, indent: 16),
                _Toggle('Answer working hours questions', _answerHours,
                    (v) => setState(() => _answerHours = v)),
              ]),
              const SizedBox(height: 16),

              // Privacy (locked)
              _SectionLabel('Privacy Rules (Always ON)'),
              _Card(children: [
                _LockedTile(Icons.lock_outline, 'Never share owner\'s personal phone number'),
                const Divider(height: 1, indent: 56),
                _LockedTile(Icons.lock_outline, 'Never share owner\'s home address'),
              ]),
              const SizedBox(height: 16),

              // Reply language
              _SectionLabel('Reply Language'),
              _Card(children: [
                _RadioTile('Auto-detect (Malayalam / English)', 'auto', _replyLanguage,
                    (v) => setState(() => _replyLanguage = v!)),
                const Divider(height: 1, indent: 16),
                _RadioTile('Always English', 'english', _replyLanguage,
                    (v) => setState(() => _replyLanguage = v!)),
                const Divider(height: 1, indent: 16),
                _RadioTile('Always Malayalam', 'malayalam', _replyLanguage,
                    (v) => setState(() => _replyLanguage = v!)),
              ]),
              const SizedBox(height: 16),

              // Custom instructions
              _SectionLabel('Custom Instructions (optional)'),
              _Card(children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _noteCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'e.g. Always greet with Namaskaram. Never discuss other shops.',
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppColors.primary),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save Settings', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
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

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
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
    child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
  );
}

class _Toggle extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Toggle(this.title, this.value, this.onChanged);

  @override
  Widget build(BuildContext context) => SwitchListTile(
    dense: true,
    value: value,
    onChanged: onChanged,
    activeColor: AppColors.primary,
    title: Text(title, style: const TextStyle(fontSize: 14)),
  );
}

class _LockedTile extends StatelessWidget {
  final IconData icon;
  final String title;
  const _LockedTile(this.icon, this.title);

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    leading: Icon(icon, size: 20, color: Colors.grey[500]),
    title: Text(title, style: const TextStyle(fontSize: 14)),
    trailing: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text('Always ON', style: TextStyle(fontSize: 11, color: Color(0xFF2D6A4F), fontWeight: FontWeight.w600)),
    ),
  );
}

class _RadioTile extends StatelessWidget {
  final String title;
  final String value;
  final String groupValue;
  final ValueChanged<String?> onChanged;
  const _RadioTile(this.title, this.value, this.groupValue, this.onChanged);

  @override
  Widget build(BuildContext context) => RadioListTile<String>(
    dense: true,
    title: Text(title, style: const TextStyle(fontSize: 14)),
    value: value,
    groupValue: groupValue,
    activeColor: AppColors.primary,
    onChanged: onChanged,
  );
}
