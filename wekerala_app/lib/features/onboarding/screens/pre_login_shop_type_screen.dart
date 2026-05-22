import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_button.dart';

const _shopTypes = [
  ('Grocery / Kirana',       Icons.local_grocery_store,  'grocery'),
  ('Vegetable & Fruit',      Icons.eco,                   'veg_fruit'),
  ('Bakery',                 Icons.cake,                  'bakery'),
  ('Pharmacy',               Icons.local_pharmacy,        'pharmacy'),
  ('Meat & Fish',            Icons.lunch_dining,          'meat_fish'),
  ('Stationery',             Icons.edit_note,             'stationery'),
  ('Textile / Dress',        Icons.checkroom,             'textile'),
  ('Electronics',            Icons.devices,               'electronics'),
  ('Hotel / Restaurant',     Icons.restaurant,            'restaurant'),
  ('General Store',          Icons.store,                 'general'),
];

class PreLoginShopTypeScreen extends StatefulWidget {
  const PreLoginShopTypeScreen({super.key});

  @override
  State<PreLoginShopTypeScreen> createState() => _PreLoginShopTypeScreenState();
}

class _PreLoginShopTypeScreenState extends State<PreLoginShopTypeScreen> {
  String _selected = '';

  Future<void> _continue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pre_login_shop_type', _selected);
    if (mounted) context.go('/pre-onboard/state');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Brand mark
              Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text('O', style: TextStyle(
                        color: Colors.white, fontSize: 20,
                        fontWeight: FontWeight.w900,
                      )),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text('Oratas',
                      style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      )),
                ],
              ).animate().fadeIn(duration: 400.ms),
              const SizedBox(height: 28),
              const Text(
                'What type of shop\ndo you have?',
                style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary, height: 1.2,
                ),
              ).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 6),
              const Text(
                "We'll set up the right features for your shop",
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ).animate().fadeIn(delay: 150.ms),
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
                    final (label, icon, key) = _shopTypes[i];
                    final selected = _selected == key;
                    return GestureDetector(
                      onTap: () => setState(() => _selected = key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary.withValues(alpha: 0.1)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected ? AppColors.primary : Colors.grey.shade200,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(icon, size: 32,
                              color: selected ? AppColors.primary : AppColors.textSecondary),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                  color: selected ? AppColors.primary : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ).animate().fadeIn(delay: 200.ms),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Continue',
                onPressed: _selected.isEmpty ? null : _continue,
              ).animate().fadeIn(delay: 300.ms),
            ],
          ),
        ),
      ),
    );
  }
}
