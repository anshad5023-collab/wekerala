import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_config.dart';
import '../../../providers/shop_provider.dart';

class SettingsHubScreen extends ConsumerWidget {
  const SettingsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopAsync = ref.watch(activeShopIdProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: shopAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (shopId) => _HubBody(shopId: shopId ?? ''),
      ),
    );
  }
}

class _HubBody extends ConsumerWidget {
  final String shopId;
  const _HubBody({required this.shopId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopStream = shopId.isNotEmpty
        ? ref.watch(shopStreamProvider(shopId))
        : null;

    final shopName = shopStream?.whenOrNull(data: (shop) => shop.shopName) ?? '';

    final storefrontUrl = shopStream?.whenOrNull(
      data: (shop) {
        final slug = shop.shopSlug;
        return slug.isNotEmpty
            ? 'https://wekerala.vercel.app/shops/$slug'
            : 'https://wekerala.vercel.app/shop?shopId=${shop.shopId}';
      },
    ) ?? '';

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final controlUrl = shopStream?.whenOrNull(
      data: (shop) => '${AppConfig.storefrontBaseUrl}/control/website?shopId=${shop.shopId}&uid=$uid',
    ) ?? '${AppConfig.storefrontBaseUrl}/control/website';

    return ListView(
      children: [
        // ── Shop Profile Card ─────────────────────────────
        _ShopProfileCard(shopName: shopName, shopId: shopId),

        // ── Shop ─────────────────────────────────────────
        _SectionHeader('Shop'),
        _SettingsCard(children: [
          _SettingsTile(
            icon: Icons.store_outlined,
            title: 'Shop Settings',
            iconColor: const Color(0xFF2D6A4F),
            onTap: () => context.push('/settings/shop'),
          ),
          _SettingsTile(
            icon: Icons.web_outlined,
            title: 'Website Builder',
            iconColor: const Color(0xFF1976D2),
            onTap: () => context.push('/website-builder', extra: controlUrl),
          ),
          _SettingsTile(
            icon: Icons.storefront_outlined,
            title: 'My Storefront',
            iconColor: const Color(0xFF7B1FA2),
            onTap: () => context.push('/website-builder', extra: storefrontUrl),
          ),
          _SettingsTile(
            icon: Icons.share_outlined,
            title: 'Share & QR Code',
            iconColor: const Color(0xFFF57C00),
            onTap: () => context.push('/share'),
          ),
          _SettingsTile(
            icon: Icons.bar_chart_outlined,
            title: 'Analytics',
            iconColor: const Color(0xFF00838F),
            onTap: () => context.push('/analytics'),
          ),
        ]),

        // ── Products & Stock ──────────────────────────────
        _SectionHeader('Products & Stock'),
        _SettingsCard(children: [
          _SettingsTile(
            icon: Icons.inventory_2_outlined,
            title: 'Products',
            iconColor: const Color(0xFF2D6A4F),
            onTap: () => context.push('/products'),
          ),
          _SettingsTile(
            icon: Icons.warning_amber_outlined,
            title: 'Stock Alerts',
            iconColor: const Color(0xFFD32F2F),
            onTap: () => context.push('/stock-alerts'),
          ),
          _SettingsTile(
            icon: Icons.file_upload_outlined,
            title: 'Import Products',
            iconColor: const Color(0xFF1976D2),
            onTap: () => context.push('/products/import'),
          ),
          _SettingsTile(
            icon: Icons.local_shipping_outlined,
            title: 'Suppliers',
            iconColor: const Color(0xFF5D4037),
            onTap: () => context.push('/suppliers'),
          ),
        ]),

        // ── Integrations ──────────────────────────────────
        _SectionHeader('Integrations'),
        _SettingsCard(children: [
          _SettingsTile(
            icon: Icons.smart_toy_outlined,
            title: 'WhatsApp AI Assistant',
            iconColor: const Color(0xFF2D6A4F),
            onTap: () => context.push('/settings/ai'),
          ),
          _SettingsTile(
            icon: Icons.hub_outlined,
            title: 'ONDC Integration',
            iconColor: const Color(0xFF1565C0),
            onTap: () => context.push('/settings/ondc'),
          ),
        ]),

        // ── Marketing & Growth ────────────────────────────
        _SectionHeader('Marketing & Growth'),
        _SettingsCard(
          children: [
            _SettingsTile(
              icon: Icons.campaign_outlined,
              title: 'WhatsApp Broadcast',
              subtitle: 'Send offers to all customers',
              iconColor: const Color(0xFF25D366),
              onTap: () => context.push('/marketing/broadcast'),
            ),
            _SettingsTile(
              icon: Icons.local_fire_department,
              title: 'Flash Sales',
              subtitle: 'Limited time offers with auto-WhatsApp',
              iconColor: const Color(0xFFFC8019),
              onTap: () => context.push('/marketing/flash-sale'),
            ),
            _SettingsTile(
              icon: Icons.star_outline,
              title: 'Loyalty Program',
              subtitle: 'Reward customers with points',
              iconColor: const Color(0xFFFF9900),
              onTap: () => context.push('/marketing/loyalty'),
            ),
            _SettingsTile(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Udhar Book',
              subtitle: 'Track credit & send reminders',
              iconColor: const Color(0xFF2D6A4F),
              onTap: () => context.push('/marketing/udhar'),
            ),
          ],
        ),

        // ── Orders & Sales ────────────────────────────────
        _SectionHeader('Orders & Sales'),
        _SettingsCard(children: [
          _SettingsTile(
            icon: Icons.receipt_long_outlined,
            title: 'Bill History',
            iconColor: const Color(0xFF43A047),
            onTap: () => context.push('/bill-history'),
          ),
          _SettingsTile(
            icon: Icons.account_balance_outlined,
            title: 'GST Summary (GSTR-1)',
            iconColor: const Color(0xFF1565C0),
            onTap: () => context.push('/gstr1'),
          ),
          _SettingsTile(
            icon: Icons.people_outline,
            title: 'Customers',
            iconColor: const Color(0xFF00838F),
            onTap: () => context.push('/customers'),
          ),
          _SettingsTile(
            icon: Icons.mic_outlined,
            title: 'Voice Order',
            iconColor: const Color(0xFF7B1FA2),
            onTap: () => context.push('/voice-order'),
          ),
          _SettingsTile(
            icon: Icons.auto_awesome_outlined,
            title: 'Reorder AI',
            iconColor: const Color(0xFFF57C00),
            onTap: () => context.push('/reorder'),
          ),
          _SettingsTile(
            icon: Icons.celebration_outlined,
            title: 'Festival Mode',
            iconColor: const Color(0xFFE53935),
            onTap: () => context.push('/festival'),
          ),
        ]),

        // ── Finance ───────────────────────────────────────
        _SectionHeader('Finance'),
        _SettingsCard(children: [
          _SettingsTile(
            icon: Icons.currency_rupee_outlined,
            title: 'Credit Ledger',
            subtitle: 'Track customer balances',
            iconColor: const Color(0xFFF4A261),
            onTap: () => context.push('/credits'),
          ),
        ]),

        // ── Staff & Devices ───────────────────────────────
        _SectionHeader('Staff & Devices'),
        _SettingsCard(children: [
          _SettingsTile(
            icon: Icons.people_outline,
            title: 'Staff Management',
            iconColor: const Color(0xFF1976D2),
            onTap: () => context.push('/settings/staff', extra: shopId),
          ),
          _SettingsTile(
            icon: Icons.print_outlined,
            title: 'Printer Settings',
            iconColor: const Color(0xFF546E7A),
            onTap: () => context.push('/settings/printer'),
          ),
        ]),

        // ── Account ───────────────────────────────────────
        _SectionHeader('Account'),
        _SettingsCard(children: [
          _SettingsTile(
            icon: Icons.manage_accounts_outlined,
            title: 'Account Settings',
            iconColor: const Color(0xFF2D6A4F),
            onTap: () => context.push('/settings/account'),
          ),
          _SettingsTile(
            icon: Icons.workspace_premium_outlined,
            title: 'Subscription',
            iconColor: const Color(0xFFFFB300),
            onTap: () => context.push('/subscription'),
          ),
          _SettingsTile(
            icon: Icons.help_outline,
            title: 'Help & Support',
            iconColor: const Color(0xFF546E7A),
            onTap: () => context.push('/help'),
          ),
        ]),

        // ── Danger Zone ───────────────────────────────────
        _SectionHeader('Danger Zone'),
        _SettingsCard(children: [
          _SettingsTile(
            icon: Icons.logout_rounded,
            title: 'Sign Out',
            iconColor: AppColors.error,
            trailing: const SizedBox.shrink(),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) context.go('/google-signin');
            },
          ),
        ]),

        const SizedBox(height: 32),
      ],
    );
  }
}

// ── Shop Profile Card ──────────────────────────────────────────────────────────

class _ShopProfileCard extends StatelessWidget {
  final String shopName;
  final String shopId;
  const _ShopProfileCard({required this.shopName, required this.shopId});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2D6A4F), Color(0xFF1B4332)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shopName.isEmpty ? 'My Shop' : shopName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Free Plan',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 20),
            onPressed: () => context.push('/settings/shop'),
            tooltip: 'Edit shop',
          ),
        ],
      ),
    );
  }
}

// ── Settings Tile ──────────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color iconColor;
  final VoidCallback onTap;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.iconColor,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFF1A2E22),
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            )
          : null,
      trailing: trailing ?? const Icon(Icons.chevron_right, color: Color(0xFF6B7280), size: 20),
      onTap: onTap,
    );
  }
}

// ── Settings Card ──────────────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            for (int i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1)
                const Divider(height: 1, indent: 64, endIndent: 16),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Section Header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}
