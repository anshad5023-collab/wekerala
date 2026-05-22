import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/language_provider.dart';
import '../../../providers/shop_provider.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/loading_overlay.dart';

class PaymentSetupScreen extends ConsumerStatefulWidget {
  const PaymentSetupScreen({super.key});

  @override
  ConsumerState<PaymentSetupScreen> createState() => _PaymentSetupScreenState();
}

class _PaymentSetupScreenState extends ConsumerState<PaymentSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _upiCtrl = TextEditingController();
  bool _cashEnabled = true;
  bool _upiEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = ref.read(onboardingProvider);
      setState(() {
        _cashEnabled = s.paymentMethods.contains('cash');
        _upiEnabled = s.paymentMethods.contains('upi');
      });
      if (s.upiId.isNotEmpty) _upiCtrl.text = s.upiId;
    });
  }

  @override
  void dispose() {
    _upiCtrl.dispose();
    super.dispose();
  }

  Future<void> _createShop() async {
    if (_upiEnabled && !(_formKey.currentState?.validate() ?? true)) return;
    if (!_cashEnabled && !_upiEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one payment method')),
      );
      return;
    }

    final methods = [
      if (_cashEnabled) 'cash',
      if (_upiEnabled) 'upi',
    ];
    ref.read(onboardingProvider.notifier).setPayment(
          paymentMethods: methods,
          upiId: _upiEnabled ? _upiCtrl.text.trim() : '',
        );

    final ok = await ref.read(onboardingProvider.notifier).createShop();
    if (!mounted) return;
    if (ok) {
      context.go('/onboard/done');
    } else {
      final error = ref.read(onboardingProvider).error ?? 'Failed to create shop';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    final isLoading = ref.watch(onboardingProvider.select((s) => s.isLoading));

    return LoadingOverlay(
      isLoading: isLoading,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          foregroundColor: AppColors.textPrimary,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: Text(
            t['payment_step'] ?? 'Step 5 of 5',
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t['payment_title'] ?? 'Payment Methods',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t['payment_subtitle'] ?? 'How will customers pay you?',
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 28),
                  _PaymentToggle(
                    icon: Icons.money_outlined,
                    label: t['payment_cash'] ?? 'Cash',
                    sublabel: 'Pay at delivery / pickup',
                    isEnabled: _cashEnabled,
                    onChanged: (v) => setState(() => _cashEnabled = v),
                  ),
                  const SizedBox(height: 12),
                  _PaymentToggle(
                    icon: Icons.qr_code_outlined,
                    label: t['payment_upi'] ?? 'UPI',
                    sublabel: 'GPay, PhonePe, Paytm...',
                    isEnabled: _upiEnabled,
                    onChanged: (v) => setState(() => _upiEnabled = v),
                  ),
                  if (_upiEnabled) ...[
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _upiCtrl,
                      label: t['payment_upi_id'] ?? 'Your UPI ID',
                      hint: t['payment_upi_hint'] ?? 'example@upi',
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'UPI ID is required';
                        }
                        if (!RegExp(r'^[\w.\-+]+@[\w.]+$')
                            .hasMatch(v.trim())) {
                          return t['payment_upi_invalid'] ??
                              'Enter a valid UPI ID';
                        }
                        return null;
                      },
                    ),
                  ],
                  const Spacer(),
                  AppButton(
                    label: t['payment_create_shop'] ?? 'Create My Shop',
                    onPressed: isLoading ? null : _createShop,
                    isLoading: isLoading,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final bool isEnabled;
  final ValueChanged<bool> onChanged;

  const _PaymentToggle({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.isEnabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isEnabled
            ? AppColors.primary.withValues(alpha: 0.08)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEnabled ? AppColors.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: isEnabled ? AppColors.primary : AppColors.textSecondary,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isEnabled ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
                Text(
                  sublabel,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Switch(
            value: isEnabled,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
