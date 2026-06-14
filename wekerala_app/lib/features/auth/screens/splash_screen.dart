import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_config.dart';
import '../../../core/services/ota_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/language_provider.dart';
import '../../update/maintenance_screen.dart';
import '../../update/update_dialog.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _redirect());
  }

  Future<void> _redirect() async {
    // Minimal delay — enough for logo fade-in to be visible
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final savedLang = prefs.getString('language');

    if (savedLang != null) {
      ref.read(languageProvider.notifier).setLanguage(savedLang);
    }

    if (!mounted) return;

    // First-ever launch — no language chosen yet
    if (savedLang == null) {
      context.go('/language');
      _checkOtaInBackground();
      return;
    }

    // Firebase currentUser is synchronous (reads local cache — no network needed).
    // Use this for instant navigation instead of waiting for the auth stream.
    final cachedUser = FirebaseAuth.instance.currentUser;

    if (cachedUser == null) {
      context.go('/login');
      _checkOtaInBackground();
      return;
    }

    // Restore language from Firestore only if missing locally
    if (savedLang == null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(cachedUser.uid)
            .get();
        final cloudLang = userDoc.data()?['language'] as String?;
        final lang = (cloudLang != null && cloudLang.isNotEmpty) ? cloudLang : 'en';
        await ref.read(languageProvider.notifier).setLanguage(lang);
      } catch (_) {
        await ref.read(languageProvider.notifier).setLanguage('en');
      }
      if (!mounted) return;
    }

    final hasShop = await ref.read(authProvider.notifier).hasShops();
    if (!mounted) return;
    context.go(hasShop ? '/home' : '/onboard/type');

    // OTA check runs AFTER navigation — never blocks the user
    _checkOtaInBackground();
  }

  Future<void> _checkOtaInBackground() async {
    try {
      final otaStatus = await OtaService.check()
          .timeout(const Duration(seconds: 4), onTimeout: () => OtaStatus.none);
      if (!mounted) return;

      if (otaStatus.maintenanceMode) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => MaintenanceScreen(message: otaStatus.maintenanceMessage),
        ));
        return;
      }
      if (otaStatus.forceUpdate) {
        await UpdateDialog.showIfNeeded(context, otaStatus);
        return;
      }
      if (otaStatus.hasUpdate) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) await UpdateDialog.showIfNeeded(context, otaStatus);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _LogoWidget(),
              const SizedBox(height: 16),
              Text(
                AppConfig.appVersion,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoWidget extends StatelessWidget {
  const _LogoWidget();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Center(
            child: Text(
              'O',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 52,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Oratas',
          style: TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'AI-powered shop intelligence',
          style: TextStyle(
            color: Colors.white60,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
