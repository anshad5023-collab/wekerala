import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/google_auth_provider.dart';
import '../../../providers/role_provider.dart';

// Windows-only email/password sign-in form
class _WindowsSignInForm extends ConsumerStatefulWidget {
  const _WindowsSignInForm();
  @override
  ConsumerState<_WindowsSignInForm> createState() => _WindowsSignInFormState();
}

class _WindowsSignInFormState extends ConsumerState<_WindowsSignInForm> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(googleAuthProvider).status == GoogleAuthStatus.loading;

    if (_emailSent) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              children: [
                const Icon(Icons.mark_email_read, color: Colors.green, size: 40),
                const SizedBox(height: 8),
                Text(
                  'Password setup email sent to\n${_emailCtrl.text}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Open your email, click the link, and set a new password. Then come back and sign in.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() => _emailSent = false),
            child: const Text('Back to sign in'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passCtrl,
          obscureText: _obscure,
          decoration: InputDecoration(
            labelText: 'Password',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: isLoading
              ? null
              : () => ref
                  .read(googleAuthProvider.notifier)
                  .signInWithEmailPassword(_emailCtrl.text, _passCtrl.text),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                )
              : const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: isLoading
              ? null
              : () async {
                  if (_emailCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enter your email first.')),
                    );
                    return;
                  }
                  final ok = await ref
                      .read(googleAuthProvider.notifier)
                      .sendPasswordSetupEmail(_emailCtrl.text);
                  if (ok && mounted) setState(() => _emailSent = true);
                },
          child: const Text('First time? Set up a password →'),
        ),
      ],
    );
  }
}

class GoogleSignInScreen extends ConsumerStatefulWidget {
  const GoogleSignInScreen({super.key});

  @override
  ConsumerState<GoogleSignInScreen> createState() => _GoogleSignInScreenState();
}

class _GoogleSignInScreenState extends ConsumerState<GoogleSignInScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkExistingAuth());
  }

  Future<void> _checkExistingAuth() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !mounted) return;
    await ref.read(roleProvider.notifier).setRole('owner');
    final hasTypes =
        await ref.read(googleAuthProvider.notifier).hasCompletedBusinessRegistration();
    if (!mounted) return;
    context.go(hasTypes ? '/business/home' : '/business/type');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(googleAuthProvider);
    final isLoading = state.status == GoogleAuthStatus.loading;

    ref.listen(googleAuthProvider, (_, next) async {
      if (next.status == GoogleAuthStatus.success) {
        await ref.read(roleProvider.notifier).setRole('owner');
        final hasTypes =
            await ref.read(googleAuthProvider.notifier).hasCompletedBusinessRegistration();
        if (context.mounted) {
          context.go(hasTypes ? '/business/home' : '/business/type');
        }
      }
      if (next.status == GoogleAuthStatus.error && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage ?? 'Sign-in failed'),
            backgroundColor: AppColors.error,
          ),
        );
        ref.read(googleAuthProvider.notifier).reset();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: BackButton(onPressed: () => context.go('/language')),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(
                'Create your\nbusiness profile',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1.2,
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2),
              const SizedBox(height: 12),
              Text(
                'Sign in with Google to list your business on Oratas — free, no subscription needed.',
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.5),
              ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
              const SizedBox(height: 48),

              // Benefits
              ..._benefits
                  .asMap()
                  .entries
                  .map((e) => _Benefit(text: e.value, delay: 200 + e.key * 80)),

              const Spacer(),

              if (GoogleAuthNotifier.isWindowsPlatform)
                const _WindowsSignInForm()
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 500.ms)
                    .slideY(begin: 0.3)
              else
                _GoogleButton(
                  isLoading: isLoading,
                  onTap: isLoading ? null : () => ref.read(googleAuthProvider.notifier).signIn(),
                ).animate().fadeIn(duration: 400.ms, delay: 500.ms).slideY(begin: 0.3),

              const SizedBox(height: 16),
              if (!GoogleAuthNotifier.isWindowsPlatform)
                Center(
                  child: Text(
                    'By continuing you agree to Oratas Terms of Service',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 600.ms),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

const _benefits = [
  '✅  Get discovered by customers across Kerala',
  '✅  Free listing — no monthly fee for basic profile',
  '✅  Manage your profile anytime from the app',
];

class _Benefit extends StatelessWidget {
  final String text;
  final int delay;
  const _Benefit({required this.text, required this.delay});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        text,
        style: TextStyle(fontSize: 15, color: AppColors.textPrimary, height: 1.4),
      ).animate().fadeIn(duration: 400.ms, delay: Duration(milliseconds: delay)),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onTap;
  const _GoogleButton({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.surface),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: isLoading
            ? const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Google 'G' logo drawn with text (no asset needed)
                  const Text(
                    'G',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4285F4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Continue with Google',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
