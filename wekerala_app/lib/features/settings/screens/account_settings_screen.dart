import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/language_provider.dart';

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
    setState(() {
      _notificationsEnabled = value;
    });
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final translations = ref.watch(translationsProvider);
    String t(String key) => translations[key] ?? key;
    final user = FirebaseAuth.instance.currentUser;

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
          _SectionHeader(title: 'ACCOUNT INFO'),
          const SizedBox(height: 8),
          Card(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person,
                      color: AppColors.textSecondary),
                  title: const Text('Name'),
                  subtitle: Text(user?.displayName ?? '—'),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.email,
                      color: AppColors.textSecondary),
                  title: const Text('Email'),
                  subtitle: Text(user?.email ?? '—'),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.phone,
                      color: AppColors.textSecondary),
                  title: const Text('Phone'),
                  subtitle: Text(user?.phoneNumber ?? '—'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Section 2: App Settings ──────────────────────────────────
          _SectionHeader(title: 'APP SETTINGS'),
          const SizedBox(height: 8),
          Card(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
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

          // ── Section 3: Danger Zone ───────────────────────────────────
          _SectionHeader(title: 'DANGER ZONE'),
          const SizedBox(height: 8),
          Card(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.logout, color: AppColors.error),
                label: const Text(
                  'Sign Out',
                  style: TextStyle(color: AppColors.error),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _signOut,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Private helpers ─────────────────────────────────────────────────────────

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
