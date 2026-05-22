import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/language_provider.dart';
import '../../../providers/shop_provider.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';

class DeliverySetupScreen extends ConsumerStatefulWidget {
  const DeliverySetupScreen({super.key});

  @override
  ConsumerState<DeliverySetupScreen> createState() => _DeliverySetupScreenState();
}

class _DeliverySetupScreenState extends ConsumerState<DeliverySetupScreen> {
  String _deliveryType = 'both';
  final _minOrderCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = ref.read(onboardingProvider);
      setState(() => _deliveryType = s.deliveryType);
      if (s.minOrderValue > 0) {
        _minOrderCtrl.text = s.minOrderValue.toStringAsFixed(0);
      }
    });
  }

  @override
  void dispose() {
    _minOrderCtrl.dispose();
    super.dispose();
  }

  void _continue() {
    ref.read(onboardingProvider.notifier).setDelivery(
          deliveryType: _deliveryType,
          minOrderValue: double.tryParse(_minOrderCtrl.text) ?? 0,
        );
    context.go('/onboard/payment');
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);

    return Scaffold(
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
          t['delivery_step'] ?? 'Step 4 of 5',
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t['delivery_title'] ?? 'Delivery Setup',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                t['delivery_subtitle'] ?? 'How will you fulfil orders?',
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 28),
              _DeliveryOption(
                icon: Icons.local_shipping_outlined,
                label: t['delivery_option'] ?? 'Delivery',
                value: 'delivery',
                selected: _deliveryType,
                onTap: () => setState(() => _deliveryType = 'delivery'),
              ),
              const SizedBox(height: 12),
              _DeliveryOption(
                icon: Icons.storefront_outlined,
                label: t['pickup_option'] ?? 'Pickup',
                value: 'pickup',
                selected: _deliveryType,
                onTap: () => setState(() => _deliveryType = 'pickup'),
              ),
              const SizedBox(height: 12),
              _DeliveryOption(
                icon: Icons.compare_arrows,
                label: t['both_option'] ?? 'Delivery + Pickup',
                value: 'both',
                selected: _deliveryType,
                onTap: () => setState(() => _deliveryType = 'both'),
              ),
              const SizedBox(height: 28),
              AppTextField(
                controller: _minOrderCtrl,
                label: t['min_order_label'] ?? 'Minimum Order Value (₹)',
                hint: t['min_order_hint'] ?? '0 for no minimum',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const Spacer(),
              AppButton(
                label: t['delivery_continue'] ?? 'Continue',
                onPressed: _continue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeliveryOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String selected;
  final VoidCallback onTap;

  const _DeliveryOption({
    required this.icon,
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.primary, size: 22),
          ],
        ),
      ),
    );
  }
}
