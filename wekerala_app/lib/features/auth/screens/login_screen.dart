import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/loading_overlay.dart';

const _termsText = '''
Welcome to Oratas

By using Oratas, you agree to the following terms:

1. Service
Oratas connects customers with local shops in Kerala for browsing and ordering products. We are a platform and are not responsible for the quality of goods sold by individual shops.

2. User Conduct
You agree to use the app only for lawful purposes and not to misuse the platform, post false information, or engage in fraudulent orders.

3. Orders & Payments
Orders are placed directly with the shop. Oratas does not process payments and is not liable for disputes between customers and shop owners.

4. Privacy
We collect your phone number for authentication only. We do not share your personal information with third parties without your consent.

5. Shop Owners
Shop owners are responsible for the accuracy of their product listings, pricing, and timely fulfillment of orders.

6. Changes
We may update these terms at any time. Continued use of the app constitutes acceptance of the updated terms.

7. Contact
For support, contact us via WhatsApp from the help section in the app.

By tapping "I Agree", you confirm you have read and accepted these terms and our Privacy Policy.
''';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  bool _termsAccepted = false;

  @override
  void initState() {
    super.initState();
    _loadTermsStatus();
  }

  Future<void> _loadTermsStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _termsAccepted = prefs.getBool('terms_accepted') ?? false;
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_termsAccepted) {
      await _showTermsDialog();
      if (!mounted) return;
      if (!_termsAccepted) return; // user cancelled — don't send
      // terms just accepted — fall through and send OTP automatically
    }
    final phone = _phoneController.text.trim();
    if (phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid 10-digit phone number')),
      );
      return;
    }
    ref.read(authProvider.notifier).sendOtp(phone);
  }

  Future<void> _showTermsDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _TermsDialog(
        onAccepted: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('terms_accepted', true);
          setState(() => _termsAccepted = true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.status == AuthStatus.loading;

    ref.listen<AuthState>(authProvider, (_, next) {
      if (next.status == AuthStatus.otpSent) {
        context.go('/verify', extra: next.phoneNumber ?? '');
      }
      // Auto-verification: Android detected SMS and signed in without OTP screen
      if (next.status == AuthStatus.authenticated) {
        ref.read(authProvider.notifier).hasShops().then((hasShop) {
          if (context.mounted) context.go(hasShop ? '/home' : '/onboard/type');
        });
      }
      if (next.status == AuthStatus.error && next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.error,
          ),
        );
      }
    });

    return LoadingOverlay(
      isLoading: isLoading,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),
                // Logo mark
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      'w',
                      style: TextStyle(
                        color: AppColors.background,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Oratas',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Enter Your Phone Number',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "We'll send a 6-digit OTP to verify your number",
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 32),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        child: Text(
                          '+91',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(width: 1, height: 24, color: AppColors.textSecondary.withValues(alpha: 0.3)),
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                          ),
                          decoration: const InputDecoration(
                            hintText: '9876543210',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16),
                            counterText: '',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AppButton(onPressed: _sendOtp, label: 'Send OTP'),
                const SizedBox(height: 20),
                Center(
                  child: GestureDetector(
                    onTap: _showTermsDialog,
                    child: Text(
                      'By continuing, you agree to our Terms & Conditions',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TermsDialog extends StatefulWidget {
  final VoidCallback onAccepted;
  const _TermsDialog({required this.onAccepted});

  @override
  State<_TermsDialog> createState() => _TermsDialogState();
}

class _TermsDialogState extends State<_TermsDialog> {
  bool _scrolledToBottom = false;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.atEdge &&
          _scrollController.position.pixels > 0) {
        setState(() => _scrolledToBottom = true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      'w',
                      style: TextStyle(
                        color: AppColors.background,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Terms & Conditions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                child: const Text(
                  _termsText,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.6,
                  ),
                ),
              ),
            ),
            if (!_scrolledToBottom)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Scroll to the bottom to accept',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      side: const BorderSide(color: AppColors.textSecondary),
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _scrolledToBottom
                        ? () {
                            widget.onAccepted();
                            Navigator.pop(context);
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.background,
                      disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.3),
                    ),
                    child: const Text('I Agree'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
