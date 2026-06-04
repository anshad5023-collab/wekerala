import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/language_provider.dart';
import '../../../providers/shop_provider.dart';

class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  ConsumerState<AccountSettingsScreen> createState() =>
      _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationsPref();
  }

  Future<void> _loadNotificationsPref() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    });
  }

  Future<void> _setNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    setState(() => _notificationsEnabled = value);
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) context.go('/login');
  }

  Future<void> _editName() async {
    final user = FirebaseAuth.instance.currentUser;
    final ctrl = TextEditingController(text: user?.displayName ?? '');
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Name'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Your name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != null && saved.isNotEmpty) {
      await FirebaseAuth.instance.currentUser?.updateDisplayName(saved);
      setState(() {});
    }
  }

  Future<void> _editEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    final ctrl = TextEditingController(text: user?.email ?? '');
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(user?.email == null ? 'Add Email' : 'Edit Email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email address'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Used for account recovery and billing receipts.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != null && saved.isNotEmpty) {
      try {
        await FirebaseAuth.instance.currentUser
            ?.verifyBeforeUpdateEmail(saved);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verification email sent. Check your inbox to confirm.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final translations = ref.watch(translationsProvider);
    String t(String key) => translations[key] ?? key;
    final user = FirebaseAuth.instance.currentUser;
    final shopIdAsync = ref.watch(activeShopIdProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(t('settings_account')),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Section 1: Account Info ──────────────────────────────────
          const _SectionHeader(title: 'ACCOUNT INFO'),
          const SizedBox(height: 8),
          Card(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person, color: AppColors.textSecondary),
                  title: const Text('Name'),
                  subtitle: Text(user?.displayName?.isNotEmpty == true
                      ? user!.displayName!
                      : 'Tap to set your name'),
                  trailing: const Icon(Icons.edit_outlined,
                      size: 18, color: AppColors.textSecondary),
                  onTap: _editName,
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.email, color: AppColors.textSecondary),
                  title: const Text('Email'),
                  subtitle: Text(user?.email?.isNotEmpty == true
                      ? user!.email!
                      : 'Tap to add email (for recovery & receipts)'),
                  trailing: const Icon(Icons.edit_outlined,
                      size: 18, color: AppColors.textSecondary),
                  onTap: _editEmail,
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.phone, color: AppColors.textSecondary),
                  title: const Text('Phone'),
                  subtitle: Text(user?.phoneNumber ?? '—'),
                  trailing: Tooltip(
                    message: 'Phone number is your login ID and cannot be changed here',
                    child: const Icon(Icons.lock_outline,
                        size: 18, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Section 2: Subscription ──────────────────────────────────
          const _SectionHeader(title: 'SUBSCRIPTION'),
          const SizedBox(height: 8),
          shopIdAsync.when(
            loading: () => const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (shopId) {
              if (shopId == null) return const SizedBox.shrink();
              final shopAsync = ref.watch(shopStreamProvider(shopId));
              return shopAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (shop) {
                  final status = shop.subscriptionStatus;
                  final trialEnd = shop.trialEndDate;
                  final now = DateTime.now();
                  final daysLeft = trialEnd.difference(now).inDays;
                  final isActive = status == 'active';
                  final isTrial = status == 'trial';
                  final isExpired = status == 'expired' ||
                      (isTrial && now.isAfter(trialEnd));

                  Color statusColor = isActive
                      ? AppColors.success
                      : isExpired
                          ? AppColors.error
                          : Colors.orange;

                  String statusLabel = isActive
                      ? 'Active — ₹500/month'
                      : isExpired
                          ? 'Expired'
                          : 'Free Trial';

                  String renewalText = isActive
                      ? 'Next renewal: ${_formatDate(trialEnd)}'
                      : isTrial && !isExpired
                          ? '$daysLeft days left in free trial'
                          : 'Trial ended ${_formatDate(trialEnd)}';

                  return Card(
                    color: AppColors.surface,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(
                            isActive ? Icons.verified : Icons.access_time,
                            color: statusColor,
                          ),
                          title: Text(statusLabel,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: statusColor)),
                          subtitle: Text(renewalText),
                        ),
                        if (!isActive) ...[
                          const Divider(height: 1, indent: 56),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.rocket_launch_outlined,
                                    size: 18),
                                label: const Text('Upgrade to Pro — ₹500/month'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Contact support at oratas4ai@gmail.com to upgrade.'),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                        const Divider(height: 1, indent: 16),
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.history,
                              color: AppColors.textSecondary, size: 20),
                          title: const Text('What your plan includes',
                              style: TextStyle(fontSize: 13)),
                          subtitle: const Text(
                            '• Unlimited products & orders\n'
                            '• WhatsApp notifications\n'
                            '• AI product scan & website builder\n'
                            '• Customer credit (Udhar) tracker\n'
                            '• Billing & POS system',
                            style: TextStyle(fontSize: 12, height: 1.6),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 24),

          // ── Section 3: App Settings ──────────────────────────────────
          const _SectionHeader(title: 'APP SETTINGS'),
          const SizedBox(height: 8),
          Card(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.language,
                      color: AppColors.textSecondary),
                  title: const Text('Language'),
                  trailing: const Icon(Icons.chevron_right,
                      color: AppColors.textSecondary),
                  onTap: () => context.push('/language'),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.notifications_outlined,
                      color: AppColors.textSecondary),
                  title: const Text('Notifications'),
                  trailing: Switch(
                    value: _notificationsEnabled,
                    activeColor: AppColors.primary,
                    onChanged: _setNotifications,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Section 4: Danger Zone ───────────────────────────────────
          const _SectionHeader(title: 'DANGER ZONE'),
          const SizedBox(height: 8),
          Card(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.logout, color: AppColors.error),
                label: const Text('Sign Out',
                    style: TextStyle(color: AppColors.error)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _signOut,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: AppColors.textSecondary,
      ),
    );
  }
}
