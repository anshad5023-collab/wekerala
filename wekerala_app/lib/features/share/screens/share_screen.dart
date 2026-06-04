import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_config.dart';
import '../../../providers/language_provider.dart';
import '../../../providers/shop_provider.dart';

class ShareScreen extends ConsumerWidget {
  const ShareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translations = ref.watch(translationsProvider);
    String t(String key) => translations[key] ?? key;
    final shopAsync = ref.watch(activeShopIdProvider);

    return shopAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text(e.toString()))),
      data: (shopId) {
        if (shopId == null) return Scaffold(body: Center(child: Text(t('error_generic'))));
        return _ShareBody(shopId: shopId, t: t);
      },
    );
  }
}

class _ShareBody extends ConsumerWidget {
  final String shopId;
  final String Function(String) t;
  const _ShareBody({required this.shopId, required this.t});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopAsync = ref.watch(shopStreamProvider(shopId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(t('share_title')),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: shopAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (shop) {
          // Use pretty slug URL if available (e.g. wekerala.vercel.app/shops/rajan-store)
          final url = shop.shopSlug.isNotEmpty
              ? 'https://wekerala.vercel.app/shops/${shop.shopSlug}'
              : '${AppConfig.storefrontBaseUrl}?shopId=$shopId';
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // QR Code
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Column(children: [
                    QrImageView(data: url, size: 200, backgroundColor: Colors.white),
                    const SizedBox(height: 8),
                    Text(shop.shopName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(url,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ]),
                ),
              ),
              const SizedBox(height: 24),

              // Link row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(children: [
                  const Icon(Icons.link, color: AppColors.textSecondary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(url,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis)),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.copy, size: 18, color: AppColors.primary),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: url));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(t('share_link_copied'))),
                      );
                    },
                  ),
                ]),
              ),
              const SizedBox(height: 12),

              // Share buttons
              ElevatedButton.icon(
                icon: const Icon(Icons.share),
                label: Text(t('share_button')),
                onPressed: () => Share.share(
                    '${t('share_message')}\n$url',
                    subject: shop.shopName),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.chat, color: Color(0xFF25D366)),
                label: Text(t('share_whatsapp'),
                    style: const TextStyle(color: Color(0xFF25D366))),
                onPressed: () {
                  final msg = Uri.encodeComponent('${t('share_message')}\n$url');
                  launchUrl(Uri.parse('https://wa.me/?text=$msg'),
                      mode: LaunchMode.externalApplication);
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF25D366)),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
