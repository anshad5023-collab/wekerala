import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _handoffCtrl = TextEditingController();
  final _phoneNumberIdCtrl = TextEditingController();
  bool _saving = false;
  bool _loaded = false;

  static const _webhookUrl =
      'https://us-central1-shoplink-prod.cloudfunctions.net/whatsappWebhook';
  static const _verifyToken = 'wekerala_webhook_secret';

  @override
  void dispose() {
    _noteCtrl.dispose();
    _handoffCtrl.dispose();
    _phoneNumberIdCtrl.dispose();
    super.dispose();
  }

  void _loadFrom(Map<String, dynamic> s, String phoneNumberId) {
    if (_loaded) return;
    _loaded = true;
    setState(() {
      _enabled = s['enabled'] as bool? ?? false;
      _shareProductPrices = s['shareProductPrices'] as bool? ?? true;
      _shareStockStatus = s['shareStockStatus'] as bool? ?? true;
      _answerDelivery = s['answerDeliveryQuestions'] as bool? ?? true;
      _answerHours = s['answerHoursQuestions'] as bool? ?? true;
      _replyLanguage = s['replyLanguage'] as String? ?? 'auto';
      // Read customInstructions (new name); fall back to customNote for old data
      _noteCtrl.text = (s['customInstructions'] ?? s['customNote']) as String? ?? '';
      _handoffCtrl.text = s['humanHandoffKeyword'] as String? ?? '';
      _phoneNumberIdCtrl.text = phoneNumberId;
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
          'answerDeliveryQuestions': _answerDelivery,
          'answerHoursQuestions': _answerHours,
          'replyLanguage': _replyLanguage,
          'customInstructions': _noteCtrl.text.trim(),
          'humanHandoffKeyword': _handoffCtrl.text.trim().toLowerCase(),
          'neverShareOwnerPhone': true,
          'neverShareOwnerAddress': true,
          'neverDiscussCompetitors': true,
          'autoSendStorefrontLink': true,
        },
        'whatsappPhoneNumberId': _phoneNumberIdCtrl.text.trim(),
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

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Copied to clipboard'),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 1),
    ));
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
        shopStream.whenData((shop) => _loadFrom(shop.aiSettings, shop.whatsappPhoneNumberId));

        // Plan gate: Lite shops don't have WhatsApp API access
        final isLocked = shopStream.valueOrNull?.plan == 'lite';

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
              // Master toggle
              _Card(children: [
                SwitchListTile(
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                  activeColor: AppColors.primary,
                  title: const Text('Enable AI Auto-Reply',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    _enabled ? 'AI will reply to customer WhatsApp messages' : 'AI replies are off',
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

              // Plan gate banner for Lite shops
              if (isLocked) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(children: [
                    const Icon(Icons.lock_outline, color: Colors.amber, size: 22),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('WhatsApp AI — Standard Plan & above',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        SizedBox(height: 3),
                        Text(
                          'Upgrade to Standard (₹799/month) to enable WhatsApp AI auto-replies and broadcasts.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ]),
                    ),
                  ]),
                ),
              ],

              // Meta setup
              _SectionLabel('Meta WhatsApp Setup'),
              Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1877F2).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.facebook, color: Color(0xFF1877F2), size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Text('Connect via Meta Developer',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ]),
                      const SizedBox(height: 12),
                      _StepTile(
                        step: '1',
                        text: 'Go to developers.facebook.com → Create App → Add WhatsApp product',
                      ),
                      _StepTile(
                        step: '2',
                        text: 'Register your shop WhatsApp number and verify it with an OTP',
                      ),
                      _StepTile(
                        step: '3',
                        text: 'Copy your Phone Number ID from the API Setup page and paste below',
                      ),
                      _StepTile(
                        step: '4',
                        text: 'Under Webhooks, set the Callback URL and Verify Token shown below',
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _phoneNumberIdCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        maxLength: 20,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number ID',
                          hintText: 'e.g. 123456789012345',
                          helperText: 'Numbers only, typically 15 digits',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.tag),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 12),
                      _CopyBox(
                        label: 'Webhook Callback URL',
                        value: _webhookUrl,
                        onCopy: () => _copy(_webhookUrl),
                      ),
                      const SizedBox(height: 8),
                      _CopyBox(
                        label: 'Verify Token',
                        value: _verifyToken,
                        onCopy: () => _copy(_verifyToken),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(children: [
                          Icon(Icons.check_circle_outline, color: Color(0xFF2D6A4F), size: 16),
                          SizedBox(width: 8),
                          Expanded(child: Text(
                            'Meta gives 1000 free conversations/month. Customer-initiated messages cost nothing.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF2D6A4F)),
                          )),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

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
                    maxLength: 500,
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
              const SizedBox(height: 16),

              // Human handoff keyword
              _SectionLabel('Human Handoff Keyword (optional)'),
              _Card(children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _handoffCtrl,
                        maxLines: 1,
                        decoration: InputDecoration(
                          hintText: 'e.g. speak to owner',
                          hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppColors.primary),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                          prefixIcon: const Icon(Icons.handshake_outlined, size: 18),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'When a customer types this phrase, the AI stops replying and you get a WhatsApp alert to take over the conversation.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: (_saving || isLocked) ? null : () => _save(shopId),
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

class _StepTile extends StatelessWidget {
  final String step;
  final String text;
  const _StepTile({required this.step, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 22, height: 22,
        decoration: BoxDecoration(
          color: const Color(0xFF2D6A4F),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Center(child: Text(step,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
    ]),
  );
}

class _CopyBox extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onCopy;
  const _CopyBox({required this.label, required this.value, required this.onCopy});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFF5F5F5),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.grey[300]!),
    ),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
      ])),
      IconButton(
        icon: const Icon(Icons.copy, size: 18),
        onPressed: onCopy,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    ]),
  );
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
