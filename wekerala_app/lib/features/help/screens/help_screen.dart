import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_config.dart';
import '../../../providers/language_provider.dart';

class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translations = ref.watch(translationsProvider);
    String t(String key) => translations[key] ?? key;
    final lang = ref.watch(languageProvider);

    final faqs = _getFaqs(lang);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(t('help_title')),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(t('help_faq_section'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          ...faqs.map((faq) => _FaqTile(question: faq[0], answer: faq[1])),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('help_support_title'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(t('help_support_subtitle'),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.chat, size: 18),
                  label: Text(t('help_whatsapp_support')),
                  onPressed: () {
                    final msg = Uri.encodeComponent(t('help_support_message'));
                    final raw = AppConfig.supportWhatsApp.replaceAll(RegExp(r'\D'), '');
                    final number = raw.startsWith('91') ? raw : '91$raw';
                    launchUrl(Uri.parse('https://wa.me/$number?text=$msg'),
                        mode: LaunchMode.externalApplication);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  List<List<String>> _getFaqs(String lang) {
    if (lang == 'ml') {
      return [
        ['എന്റെ ഷോപ്പ് ലിങ്ക് എവിടെ കിട്ടും?', 'ഡാഷ്ബോർഡിൽ "ഷോപ്പ് ലിങ്ക്" വിഭാഗത്തിൽ നിങ്ങളുടെ ലിങ്ക് കാണാം. അത് കോപ്പി ചെയ്ത് കസ്റ്റമർക്ക് അയക്കാം.'],
        ['ഓർഡർ എങ്ങനെ confirm ചെയ്യും?', 'Orders ടാബ് തുറന്ന് ഓർഡർ tap ചെയ്ത് "Confirm Order" ബട്ടൺ ക്ലിക്ക് ചെയ്യുക.'],
        ['ഷോപ്പ് open/close ചെയ്യുന്നത് എങ്ങനെ?', 'ഡാഷ്ബോർഡിൽ ഷോപ്പ് നാമത്തിനു അടുത്ത് switch toggle ചെയ്ത് open/close ആക്കാം.'],
        ['പ്രൊഡക്ടുകൾ import ചെയ്യുന്നത് എങ്ങനെ?', 'Products ടാബിൽ Import ബട്ടൺ tap ചെയ്ത് Google Sheets ൽ നിന്ന് paste ചെയ്ത് import ചെയ്യാം.'],
        ['Trial period എത്ര ദിവസം?', 'നിങ്ങൾക്ക് 30 ദിവസം free trial ലഭ്യമാണ്. അതിന് ശേഷം ₹349/month മുതൽ subscription ആവശ്യമാണ്.'],
        ['UPI ID എങ്ങനെ add ചെയ്യും?', 'Shop Settings → Payment Methods ൽ UPI ID enter ചെയ്യാം.'],
      ];
    }
    return [
      ['Where can I find my shop link?', 'Your shop link is on the Dashboard under "Shop Link". Tap the copy icon to copy it and share with customers.'],
      ['How do I confirm an order?', 'Go to the Orders tab, tap the order, then tap "Confirm Order". You can track it through each step until delivery.'],
      ['How do I open or close my shop?', 'On the Dashboard, toggle the Open/Closed switch next to your shop name. When closed, customers cannot place new orders.'],
      ['How do I import products?', 'Go to the Products tab and tap Import. You can paste a product list or import from Google Sheets.'],
      ['How long is the free trial?', 'You get 30 days free. After that, plans start from ₹349/month to keep your shop active.'],
      ['How do I add my UPI ID?', 'Go to Shop Settings → Payment Methods and enter your UPI ID there.'],
    ];
  }
}

class _FaqTile extends StatelessWidget {
  final String question;
  final String answer;
  const _FaqTile({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        title: Text(question,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        children: [
          Text(answer,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }
}
