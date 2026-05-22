import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
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
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    // Run OTA check and language load in parallel — cuts up to 5s off startup
    final parallel = await Future.wait([
      OtaService.check().timeout(const Duration(seconds: 4), onTimeout: () => OtaStatus.none),
      SharedPreferences.getInstance(),
    ]);
    if (!mounted) return;

    final otaStatus = parallel[0] as OtaStatus;
    final prefs = parallel[1] as SharedPreferences;

    // Maintenance mode blocks everything
    if (otaStatus.maintenanceMode) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => MaintenanceScreen(message: otaStatus.maintenanceMessage),
      ));
      return;
    }

    // Force update blocks navigation
    if (otaStatus.forceUpdate) {
      await UpdateDialog.showIfNeeded(context, otaStatus);
      if (!mounted) return;
      return;
    }

    final savedLang = prefs.getString('language');
    if (savedLang != null) {
      ref.read(languageProvider.notifier).setLanguage(savedLang);
    }

    if (!mounted) return;

    if (savedLang == null) {
      context.go('/language');
      return;
    }

    final authState = ref.read(authProvider);
    final isAuthenticated = authState.status == AuthStatus.authenticated;

    // Navigate immediately — don't wait for optional update dialog
    if (!isAuthenticated) {
      // Phone OTP doesn't work on Windows — use email/password login instead
      final isWindows = !kIsWeb && Platform.isWindows;
      context.go(isWindows ? '/google-signin' : '/login');
    } else {
      context.go('/business/home');
    }

    // Show optional update notification after navigation (non-blocking)
    if (otaStatus.hasUpdate && !otaStatus.forceUpdate && mounted) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) await UpdateDialog.showIfNeeded(context, otaStatus);
    }
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
