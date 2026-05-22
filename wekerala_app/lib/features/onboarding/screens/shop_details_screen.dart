import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/language_provider.dart';
import '../../../providers/shop_provider.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';

const _keralaDistricts = [
  'Thiruvananthapuram',
  'Kollam',
  'Pathanamthitta',
  'Alappuzha',
  'Kottayam',
  'Idukki',
  'Ernakulam',
  'Thrissur',
  'Palakkad',
  'Malappuram',
  'Kozhikode',
  'Wayanad',
  'Kannur',
  'Kasaragod',
];

class ShopDetailsScreen extends ConsumerStatefulWidget {
  const ShopDetailsScreen({super.key});

  @override
  ConsumerState<ShopDetailsScreen> createState() => _ShopDetailsScreenState();
}

class _ShopDetailsScreenState extends ConsumerState<ShopDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameEnCtrl = TextEditingController();
  final _nameMlCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String? _district;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefill());
  }

  void _prefill() {
    final s = ref.read(onboardingProvider);
    if (s.shopName.isNotEmpty) {
      _nameEnCtrl.text = s.shopName;
      _nameMlCtrl.text = s.shopNameMl;
      _whatsappCtrl.text = s.ownerWhatsApp;
      _addressCtrl.text = s.address;
      if (s.district.isNotEmpty) setState(() => _district = s.district);
    } else {
      final phone = FirebaseAuth.instance.currentUser?.phoneNumber;
      if (phone != null) _whatsappCtrl.text = phone.replaceFirst('+91', '');
    }
  }

  @override
  void dispose() {
    _nameEnCtrl.dispose();
    _nameMlCtrl.dispose();
    _whatsappCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _continue() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_district == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.read(translationsProvider)['shop_details_district_required'] ??
                'Please select a district',
          ),
        ),
      );
      return;
    }
    ref.read(onboardingProvider.notifier).setDetails(
          shopName: _nameEnCtrl.text.trim(),
          shopNameMl: _nameMlCtrl.text.trim(),
          ownerWhatsApp: _whatsappCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          district: _district!,
        );
    context.go('/onboard/banner');
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
          t['shop_details_step'] ?? 'Step 2 of 5',
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t['shop_details_title'] ?? 'Tell us about your shop',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                AppTextField(
                  controller: _nameEnCtrl,
                  label: t['shop_details_name_en'] ?? 'Shop Name (English)',
                  hint: 'e.g. Ansar General Store',
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? (t['shop_details_name_required'] ?? 'Shop name is required')
                      : null,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _nameMlCtrl,
                  label: t['shop_details_name_ml'] ?? 'Shop Name (Malayalam) — Optional',
                  hint: 'e.g. അൻസർ ജനറൽ സ്റ്റോർ',
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _whatsappCtrl,
                  label: t['shop_details_whatsapp'] ?? 'WhatsApp Number',
                  hint: '9876543210',
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 10,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.trim().length != 10) {
                      return 'Enter a valid 10-digit WhatsApp number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _addressCtrl,
                  label: t['shop_details_address'] ?? 'Shop Address',
                  hint: 'Street, area, landmark...',
                  maxLines: 3,
                  textInputAction: TextInputAction.done,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? (t['shop_details_address_required'] ?? 'Address is required')
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _district,
                  decoration: InputDecoration(
                    labelText: t['shop_details_district'] ?? 'District',
                  ),
                  hint: Text(t['shop_details_district'] ?? 'Select district'),
                  items: _keralaDistricts
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (v) => setState(() => _district = v),
                ),
                const SizedBox(height: 32),
                AppButton(
                  label: t['shop_details_continue'] ?? 'Continue',
                  onPressed: _continue,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
