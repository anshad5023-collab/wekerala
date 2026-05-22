import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_config.dart';

// Firestore project ID and API key
const _firestoreProject = 'shoplink-prod';
const _firestoreApiKey = 'AIzaSyCFB9YZL3_bXjvRMoWaYFv8nTs_ote52GQ';

dynamic _parseField(Map<String, dynamic> field) {
  if (field.containsKey('stringValue')) return field['stringValue'];
  if (field.containsKey('booleanValue')) return field['booleanValue'];
  if (field.containsKey('integerValue')) {
    return int.tryParse(field['integerValue'].toString()) ?? 0;
  }
  if (field.containsKey('doubleValue')) return (field['doubleValue'] as num).toDouble();
  if (field.containsKey('arrayValue')) {
    final values = field['arrayValue']['values'] as List? ?? [];
    return values.map((v) => _parseField(v as Map<String, dynamic>)).toList();
  }
  return null;
}

Map<String, dynamic> _parseFields(Map<String, dynamic> fields) {
  return fields.map((k, v) => MapEntry(k, _parseField(v as Map<String, dynamic>)));
}

class BusinessProfileScreen extends StatefulWidget {
  final String collection;
  final String businessId;

  const BusinessProfileScreen({
    super.key,
    required this.collection,
    required this.businessId,
  });

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchBusiness();
  }

  Future<void> _fetchBusiness() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final url =
          'https://firestore.googleapis.com/v1/projects/$_firestoreProject/databases/(default)/documents/${widget.collection}/${widget.businessId}?key=$_firestoreApiKey';
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final fields = json['fields'] as Map<String, dynamic>? ?? {};
        setState(() => _data = _parseFields(fields));
      } else {
        setState(() => _error = 'Business not found (${res.statusCode})');
      }
    } catch (e) {
      setState(() => _error = 'Could not load business. Check your connection.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _share() {
    final name = _data?['name'] as String? ?? 'Business';
    final url =
        '${AppConfig.storefrontBaseUrl}/listing/${widget.collection}/${widget.businessId}';
    Share.share('Check out $name on wekerala!\n$url');
  }

  @override
  Widget build(BuildContext context) {
    final name = _data?['name'] as String? ?? widget.businessId;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.background,
        title: Text(
          _loading ? 'Loading…' : name,
          style: const TextStyle(fontWeight: FontWeight.w700),
          overflow: TextOverflow.ellipsis,
        ),
        leading: BackButton(onPressed: () => context.pop()),
        actions: [
          if (!_loading && _data != null)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share',
              onPressed: _share,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('😕', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchBusiness,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.background,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_data == null) return const SizedBox.shrink();

    final d = _data!;
    final name = d['name'] as String? ?? '';
    final isVerified = d['isVerified'] as bool? ?? false;
    final category = d['category'] as String? ?? widget.collection;
    final district = d['district'] as String? ?? '';
    final avgRating = (d['avgRating'] as num?)?.toDouble() ?? 0.0;
    final ratingCount = (d['ratingCount'] as num?)?.toInt() ?? 0;
    final about = d['about'] as String? ?? (d['description'] as String? ?? '');
    final workingHours = d['workingHours'] as String? ?? '';
    final priceRange = d['priceRange'] as String? ?? '';
    final phone = d['phone'] as String? ?? (d['phoneNumber'] as String? ?? '');
    final whatsapp = d['whatsapp'] as String? ?? phone;
    final photoUrl = d['photoUrl'] as String? ??
        (d['bannerImageUrl'] as String? ?? (d['imageUrl'] as String? ?? ''));
    final serviceTypes = (d['serviceTypes'] as List?)?.cast<String>() ?? [];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero image
          if (photoUrl.isNotEmpty)
            SizedBox(
              width: double.infinity,
              height: 200,
              child: Image.network(
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.surface,
                  child: Center(
                    child: Icon(Icons.image_not_supported,
                        color: AppColors.textSecondary, size: 40),
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 400.ms)
          else
            Container(
              width: double.infinity,
              height: 120,
              color: AppColors.primary,
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                    color: AppColors.background.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + verified badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          height: 1.2,
                        ),
                      ),
                    ),
                    if (isVerified) ...[
                      const SizedBox(width: 8),
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified, size: 14, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              'Verified',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ).animate().fadeIn(duration: 400.ms, delay: 100.ms),

                const SizedBox(height: 8),

                // Category + district
                Row(
                  children: [
                    Icon(Icons.category_outlined, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      category,
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    if (district.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.location_on_outlined,
                          size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        district,
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ).animate().fadeIn(duration: 400.ms, delay: 150.ms),

                // Rating
                if (avgRating > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('⭐', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      Text(
                        avgRating.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (ratingCount > 0) ...[
                        Text(
                          ' · $ratingCount ratings',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                ],

                const SizedBox(height: 20),

                // Action buttons: Call + WhatsApp
                if (phone.isNotEmpty || whatsapp.isNotEmpty)
                  Row(
                    children: [
                      if (phone.isNotEmpty)
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.phone,
                            label: 'Call',
                            onTap: () => _launchUrl('tel:$phone'),
                          ),
                        ),
                      if (phone.isNotEmpty && whatsapp.isNotEmpty)
                        const SizedBox(width: 12),
                      if (whatsapp.isNotEmpty)
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.chat,
                            label: 'WhatsApp',
                            color: const Color(0xFF25D366),
                            onTap: () {
                              final cleaned = whatsapp.replaceAll(RegExp(r'\D'), '');
                              _launchUrl('https://wa.me/$cleaned');
                            },
                          ),
                        ),
                    ],
                  ).animate().fadeIn(duration: 400.ms, delay: 250.ms),

                const SizedBox(height: 20),
                _Divider(),

                // About
                if (about.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SectionTitle('About'),
                  const SizedBox(height: 8),
                  Text(
                    about,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
                  const SizedBox(height: 16),
                  _Divider(),
                ],

                // Working hours
                if (workingHours.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SectionTitle('Working Hours'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        workingHours,
                        style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                      ),
                    ],
                  ).animate().fadeIn(duration: 400.ms, delay: 320.ms),
                  const SizedBox(height: 16),
                  _Divider(),
                ],

                // Price range
                if (priceRange.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SectionTitle('Price Range'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.currency_rupee, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        priceRange,
                        style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                      ),
                    ],
                  ).animate().fadeIn(duration: 400.ms, delay: 340.ms),
                  const SizedBox(height: 16),
                  _Divider(),
                ],

                // Service types / tags
                if (serviceTypes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SectionTitle('Services'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: serviceTypes.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      );
                    }).toList(),
                  ).animate().fadeIn(duration: 400.ms, delay: 360.ms),
                  const SizedBox(height: 16),
                  _Divider(),
                ],

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final btnColor = color ?? AppColors.primary;
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: btnColor,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, color: AppColors.surface);
  }
}
