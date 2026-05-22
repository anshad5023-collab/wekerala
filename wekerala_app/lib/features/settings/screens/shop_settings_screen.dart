import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/layout/breakpoints.dart';
import '../../../core/services/storage_service.dart';
import '../../../providers/language_provider.dart';
import '../../../providers/shop_provider.dart';

const _keralaDistricts = [
  'Thiruvananthapuram', 'Kollam', 'Pathanamthitta', 'Alappuzha', 'Kottayam',
  'Idukki', 'Ernakulam', 'Thrissur', 'Palakkad', 'Malappuram',
  'Kozhikode', 'Wayanad', 'Kannur', 'Kasaragod',
];

class ShopSettingsScreen extends ConsumerWidget {
  const ShopSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translations = ref.watch(translationsProvider);
    String t(String key) => translations[key] ?? key;
    final shopAsync = ref.watch(activeShopIdProvider);

    return shopAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text(e.toString()))),
      data: (shopId) {
        if (shopId == null) return Scaffold(body: Center(child: Text(t('error_generic'))));
        return _ShopSettingsBody(shopId: shopId, t: t);
      },
    );
  }
}

class _ShopSettingsBody extends ConsumerStatefulWidget {
  final String shopId;
  final String Function(String) t;
  const _ShopSettingsBody({required this.shopId, required this.t});

  @override
  ConsumerState<_ShopSettingsBody> createState() => _ShopSettingsBodyState();
}

class _ShopSettingsBodyState extends ConsumerState<_ShopSettingsBody> {
  final _formKey = GlobalKey<FormState>();
  final _nameEn = TextEditingController();
  final _nameMl = TextEditingController();
  final _whatsapp = TextEditingController();
  final _address = TextEditingController();
  // Phase 9.7 — website appearance
  final _promoBanner = TextEditingController();
  final _announcement = TextEditingController();
  final _deliveryTime = TextEditingController();
  // Phase 11 — external website URL
  final _externalUrl = TextEditingController();
  // GST details
  final _gstin = TextEditingController();
  final _gstBusinessName = TextEditingController();
  String? _district;
  String? _themeColor;
  String? _productLayout;
  List<String> _photos = [];
  bool _loaded = false;
  bool _saving = false;
  bool _uploadingPhoto = false;
  bool _autoSendWhatsapp = false;
  // Open/close control
  bool _isOpen = true;
  bool _useSchedule = false;
  TimeOfDay _openTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _closeTime = const TimeOfDay(hour: 21, minute: 0);

  static const _maxPhotos = 5;

  String _fmtTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final p = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $p';
  }

  String _fmtWorkingHours() => '${_fmtTime(_openTime)} - ${_fmtTime(_closeTime)}';

  static const _themeSwatches = [
    {'color': 0xFF22c55e, 'hex': '#22c55e'},
    {'color': 0xFF3b82f6, 'hex': '#3b82f6'},
    {'color': 0xFFf97316, 'hex': '#f97316'},
    {'color': 0xFFa855f7, 'hex': '#a855f7'},
    {'color': 0xFFef4444, 'hex': '#ef4444'},
  ];

  @override
  void dispose() {
    _nameEn.dispose();
    _nameMl.dispose();
    _whatsapp.dispose();
    _address.dispose();
    _promoBanner.dispose();
    _announcement.dispose();
    _deliveryTime.dispose();
    _externalUrl.dispose();
    _gstin.dispose();
    _gstBusinessName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shopAsync = ref.watch(shopStreamProvider(widget.shopId));
    String t(String key) => widget.t(key);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(t('settings_shop')),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: shopAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (shop) {
          if (!_loaded) {
            _nameEn.text = shop.shopName;
            _nameMl.text = shop.shopNameMl;
            _whatsapp.text = shop.ownerWhatsApp;
            _address.text = shop.address;
            _district = shop.district;
            _themeColor = shop.themeColor;
            _promoBanner.text = shop.promotionalBanner ?? '';
            _announcement.text = shop.announcementText ?? '';
            _deliveryTime.text = shop.deliveryTimeEstimate ?? '';
            _isOpen = shop.isOpen;
            // Parse stored workingHours "HH:MM AM - HH:MM AM" back into TimeOfDay
            final wh = shop.workingHours ?? '';
            if (wh.isNotEmpty) {
              _useSchedule = true;
              final match = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)?\s*[-–]\s*(\d{1,2}):(\d{2})\s*(AM|PM)?', caseSensitive: false).firstMatch(wh);
              if (match != null) {
                int oh = int.parse(match.group(1)!);
                final om = int.parse(match.group(2)!);
                final oap = match.group(3)?.toUpperCase();
                int ch = int.parse(match.group(4)!);
                final cm = int.parse(match.group(5)!);
                final cap = match.group(6)?.toUpperCase();
                if (oap == 'PM' && oh != 12) oh += 12;
                if (oap == 'AM' && oh == 12) oh = 0;
                if (cap == 'PM' && ch != 12) ch += 12;
                if (cap == 'AM' && ch == 12) ch = 0;
                _openTime = TimeOfDay(hour: oh, minute: om);
                _closeTime = TimeOfDay(hour: ch, minute: cm);
              }
            }
            _productLayout = shop.productLayout ?? 'grid2';
            _externalUrl.text = shop.externalUrl ?? '';
            _gstin.text = shop.gstin ?? '';
            _gstBusinessName.text = shop.gstBusinessName ?? '';
            _autoSendWhatsapp = shop.autoSendWhatsappReceipt;
            _photos = List.from(shop.photos);
            _loaded = true;
          }

          final desktop = isDesktop(context);

          // ── Paired-field helper (desktop: side-by-side, mobile: stacked) ──
          Widget pairedRow(Widget left, Widget right) {
            if (desktop) {
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(width: 360, child: left),
                  SizedBox(width: 360, child: right),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                left,
                const SizedBox(height: 12),
                right,
              ],
            );
          }

          Widget formContent = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Shop Open / Close ────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _isOpen ? Colors.green.shade200 : Colors.red.shade200),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(_isOpen ? Icons.store : Icons.store_mall_directory_outlined,
                            color: _isOpen ? Colors.green : Colors.red),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('Shop Status',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                        ),
                        Switch(
                          value: _isOpen,
                          activeColor: Colors.green,
                          inactiveThumbColor: Colors.red,
                          inactiveTrackColor: Colors.red.shade100,
                          onChanged: (v) => setState(() => _isOpen = v),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _isOpen ? Colors.green.shade50 : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _isOpen ? 'Open' : 'Closed',
                            style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700,
                              color: _isOpen ? Colors.green.shade700 : Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Checkbox(
                          value: _useSchedule,
                          activeColor: AppColors.primary,
                          onChanged: (v) => setState(() => _useSchedule = v ?? false),
                        ),
                        const Text('Auto open/close by time', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                    if (_useSchedule) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final t = await showTimePicker(context: context, initialTime: _openTime);
                                if (t != null) setState(() => _openTime = t);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.grey.shade50,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.wb_sunny_outlined, size: 16, color: Colors.orange),
                                    const SizedBox(width: 6),
                                    Text('Open: ${_fmtTime(_openTime)}', style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final t = await showTimePicker(context: context, initialTime: _closeTime);
                                if (t != null) setState(() => _closeTime = t);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.grey.shade50,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.nights_stay_outlined, size: 16, color: Colors.indigo),
                                    const SizedBox(width: 6),
                                    Text('Close: ${_fmtTime(_closeTime)}', style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Shop will automatically show as Open/Closed on the website based on this schedule.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // ── Shop Name pair ──────────────────────────────
              pairedRow(
                _field(t('shop_details_name_en'), _nameEn,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? t('shop_details_name_required') : null),
                _field(t('shop_details_name_ml'), _nameMl),
              ),
              const SizedBox(height: 12),
              // ── WhatsApp + District pair ─────────────────────
              pairedRow(
                _field(t('shop_details_whatsapp'), _whatsapp,
                    keyboardType: TextInputType.phone),
                DropdownButtonFormField<String>(
                  value: _district,
                  decoration: InputDecoration(
                    labelText: t('shop_details_district'),
                    border: const OutlineInputBorder(),
                    filled: true, fillColor: Colors.white,
                  ),
                  hint: Text(t('shop_details_district')),
                  items: _keralaDistricts
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (v) => setState(() => _district = v),
                  validator: (v) => v == null ? t('shop_details_district_required') : null,
                ),
              ),
              const SizedBox(height: 12),
              // ── Address — full width ─────────────────────────
              _field(t('shop_details_address'), _address,
                  maxLines: 2,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? t('shop_details_address_required') : null),
              const SizedBox(height: 24),
              // ── GST Details ──────────────────────────────────
              Align(
                alignment: Alignment.centerLeft,
                child: Text('GST Details',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 4),
              Text(
                'Only needed if your shop is GST registered.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              pairedRow(
                _field('GSTIN (15-digit GST number)', _gstin),
                _field('Business Name (as on GST certificate)', _gstBusinessName),
              ),
              const SizedBox(height: 24),
              // ── Website Appearance ───────────────────────────
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Website Appearance',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Theme Color', style: Theme.of(context).textTheme.bodyMedium),
              ),
              const SizedBox(height: 8),
              Row(
                children: _themeSwatches.map((s) {
                  final hex = s['hex'] as String;
                  final selected = _themeColor == hex;
                  return GestureDetector(
                    onTap: () => setState(() => _themeColor = hex),
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(s['color'] as int),
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(color: Colors.black, width: 2.5)
                            : null,
                      ),
                      child: selected
                          ? const Icon(Icons.check, color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              // ── Promotional Banner — full width ──────────────
              _field('Promotional Banner (e.g. "20% off today!")', _promoBanner),
              const SizedBox(height: 12),
              // ── Announcement — full width ────────────────────
              _field('Announcement Popup (shown once per customer)', _announcement),
              const SizedBox(height: 12),
              // ── Delivery Time + Product Layout pair ──────────
              pairedRow(
                _field('Delivery Time Estimate (e.g. "30–45 min")', _deliveryTime),
                DropdownButtonFormField<String>(
                  value: _productLayout ?? 'grid2',
                  decoration: const InputDecoration(
                    labelText: 'Product Layout',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'grid2', child: Text('2-Column Grid')),
                    DropdownMenuItem(value: 'grid3', child: Text('3-Column Grid')),
                    DropdownMenuItem(value: 'list', child: Text('List')),
                  ],
                  onChanged: (v) => setState(() => _productLayout = v),
                ),
              ),
              const SizedBox(height: 24),
              // ── External Website ─────────────────────────────
              Align(
                alignment: Alignment.centerLeft,
                child: Text('External Website',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              Text(
                'Customers can visit your own website at wekerala.in/your-shop.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              _field('My Website URL (optional)', _externalUrl,
                  keyboardType: TextInputType.url),
              const SizedBox(height: 24),
              // ── Shop Photos — full width ─────────────────────
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Shop Photos',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 4),
              Text(
                'Add up to $_maxPhotos photos of your shop. These appear in search results.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 90,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ..._photos.asMap().entries.map((e) => _PhotoThumbnail(
                      url: e.value,
                      onDelete: () => setState(() => _photos.removeAt(e.key)),
                    )),
                    if (_photos.length < _maxPhotos)
                      _AddPhotoButton(
                        loading: _uploadingPhoto,
                        onTap: () => _pickAndUploadPhoto(widget.shopId),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // ── WhatsApp Auto-Send ───────────────────────────
              Align(
                alignment: Alignment.centerLeft,
                child: Text('WhatsApp Receipt',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: _autoSendWhatsapp,
                onChanged: (v) => setState(() => _autoSendWhatsapp = v),
                title: const Text('Auto-send WhatsApp receipt'),
                subtitle: const Text('Opens WhatsApp automatically after each payment'),
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 24),
              // ── Save Button — full width ─────────────────────
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _saving
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(t('shop_settings_save')),
              ),
            ],
          );

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (desktop)
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: formContent,
                    ),
                  )
                else
                  formContent,
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickAndUploadPhoto(String shopId) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked == null || !mounted) return;
    setState(() => _uploadingPhoto = true);
    try {
      final photoId = DateTime.now().millisecondsSinceEpoch.toString();
      final url = await StorageService.uploadShopPhoto(shopId, photoId, File(picked.path));
      if (mounted) setState(() => _photos.add(url));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Widget _field(String label, TextEditingController ctrl,
      {TextInputType? keyboardType, int maxLines = 1,
      String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session expired. Please sign out and sign in again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await user.getIdToken(true); // Force-refresh auth token before Firestore write
      final color = _themeColor ?? '#22c55e';
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.shopId)
          .update({
        'shopName': _nameEn.text.trim(),
        'shopNameMl': _nameMl.text.trim(),
        'ownerWhatsApp': _whatsapp.text.trim(),
        'ownerPhone': _whatsapp.text.trim(),
        'address': _address.text.trim(),
        'district': _district,
        'themeColor': color,
        'promotionalBanner': _promoBanner.text.trim(),
        'announcementText': _announcement.text.trim(),
        'isOpen': _isOpen,
        'deliveryTimeEstimate': _deliveryTime.text.trim(),
        'workingHours': _useSchedule ? _fmtWorkingHours() : '',
        'productLayout': _productLayout ?? 'grid2',
        'externalUrl': _externalUrl.text.trim(),
        'gstin': _gstin.text.trim(),
        'gstBusinessName': _gstBusinessName.text.trim(),
        'autoSendWhatsappReceipt': _autoSendWhatsapp,
        'photos': _photos,
        // Bridge to storefront website config
        'website.isPublished': true,
        'website.siteName': _nameEn.text.trim(),
        'website.primaryColor': color,
        'website.whatsappEnabled': _whatsapp.text.trim().isNotEmpty,
        'website.whatsappNumber': _whatsapp.text.trim(),
        'website.announcementBar': _announcement.text.trim(),
        'website.announcementBarEnabled': _announcement.text.trim().isNotEmpty,
        'website.storeHoursText': _deliveryTime.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.t('shop_settings_saved'))),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _PhotoThumbnail extends StatelessWidget {
  final String url;
  final VoidCallback onDelete;
  const _PhotoThumbnail({required this.url, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      margin: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedNetworkImage(
              imageUrl: url,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: Colors.grey[200]),
              errorWidget: (_, __, ___) => Container(color: Colors.grey[200], child: const Icon(Icons.broken_image)),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, size: 12, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddPhotoButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _AddPhotoButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.primary, width: 1.5),
          borderRadius: BorderRadius.circular(10),
          color: AppColors.primary.withValues(alpha: 0.05),
        ),
        child: loading
            ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
            : const Icon(Icons.add_a_photo_outlined, color: AppColors.primary, size: 26),
      ),
    );
  }
}
