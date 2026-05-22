import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/language_provider.dart';
import '../../../providers/shop_provider.dart';
import '../../../shared/widgets/app_button.dart';

const _shopTypes = [
  'Grocery',
  'Vegetable & Fruit',
  'Bakery',
  'Pharmacy',
  'Meat & Fish',
  'Stationery',
  'Textile',
  'Electronics',
  'Hotel / Restaurant',
  'General Store',
];

const _shopTypeKeys = [
  'shop_type_grocery',
  'shop_type_veg_fruit',
  'shop_type_bakery',
  'shop_type_pharmacy',
  'shop_type_meat_fish',
  'shop_type_stationery',
  'shop_type_textile',
  'shop_type_electronics',
  'shop_type_restaurant',
  'shop_type_general',
];

const _shopTypeIcons = [
  Icons.local_grocery_store,
  Icons.eco,
  Icons.cake,
  Icons.local_pharmacy,
  Icons.lunch_dining,
  Icons.edit_note,
  Icons.checkroom,
  Icons.devices,
  Icons.restaurant,
  Icons.store,
];

// Maps pre-login keys (SharedPreferences) to post-login ShopType labels
const _preLoginKeyToType = {
  'grocery': 'Grocery',
  'veg_fruit': 'Vegetable & Fruit',
  'bakery': 'Bakery',
  'pharmacy': 'Pharmacy',
  'meat_fish': 'Meat & Fish',
  'stationery': 'Stationery',
  'textile': 'Textile',
  'electronics': 'Electronics',
  'restaurant': 'Hotel / Restaurant',
  'general': 'General Store',
};

class ShopTypeScreen extends ConsumerStatefulWidget {
  const ShopTypeScreen({super.key});

  @override
  ConsumerState<ShopTypeScreen> createState() => _ShopTypeScreenState();
}

class _ShopTypeScreenState extends ConsumerState<ShopTypeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _preFill());
  }

  Future<void> _preFill() async {
    if (!mounted) return;
    final current = ref.read(onboardingProvider).shopType;
    if (current.isNotEmpty) return; // already selected
    final prefs = await SharedPreferences.getInstance();
    final preKey = prefs.getString('pre_login_shop_type');
    if (preKey == null) return;
    final mapped = _preLoginKeyToType[preKey];
    if (mapped != null && mounted) {
      ref.read(onboardingProvider.notifier).setShopType(mapped);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    final selected = ref.watch(onboardingProvider.select((s) => s.shopType));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          t['shop_type_step'] ?? 'Step 1 of 5',
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t['shop_type_title'] ?? 'What type of shop do you have?',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                t['shop_type_subtitle'] ?? "We'll set up the right categories for you",
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.3,
                  ),
                  itemCount: _shopTypes.length,
                  itemBuilder: (context, i) {
                    final type = _shopTypes[i];
                    final isSelected = selected == type;
                    return _ShopTypeCard(
                      label: t[_shopTypeKeys[i]] ?? type,
                      icon: _shopTypeIcons[i],
                      isSelected: isSelected,
                      onTap: () =>
                          ref.read(onboardingProvider.notifier).setShopType(type),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: t['shop_type_continue'] ?? 'Continue',
                onPressed: selected.isEmpty ? null : () => context.go('/onboard/details'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShopTypeCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ShopTypeCard({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
