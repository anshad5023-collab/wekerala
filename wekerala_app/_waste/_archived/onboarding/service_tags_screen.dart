import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_colors.dart';
import '../../../providers/language_provider.dart';
import '../../../providers/shop_provider.dart';
import '../../../shared/widgets/app_button.dart';

// Fetches active service tags from Firestore
final _serviceTagsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final snap = await FirebaseFirestore.instance
      .collection('serviceTags')
      .where('isActive', isEqualTo: true)
      .get();
  final tags = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  tags.sort((a, b) {
    final s = (a['sector'] as String? ?? '').compareTo(b['sector'] as String? ?? '');
    return s != 0 ? s : (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? '');
  });
  return tags;
});

class ServiceTagsScreen extends ConsumerStatefulWidget {
  const ServiceTagsScreen({super.key});

  @override
  ConsumerState<ServiceTagsScreen> createState() => _ServiceTagsScreenState();
}

class _ServiceTagsScreenState extends ConsumerState<ServiceTagsScreen> {
  final Set<String> _selected = {};
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final shopId = ref.read(onboardingProvider).createdShopId;
      if (shopId != null && shopId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('shops').doc(shopId).update({
          'serviceTypes': _selected.toList(),
        });
      }
    } catch (_) {
      // Non-blocking — owner can update later from settings
    } finally {
      if (mounted) context.go('/onboard/done');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    final tagsAsync = ref.watch(_serviceTagsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          t['service_tags_step'] ?? 'Step 6 of 6',
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => context.go('/onboard/done'),
            child: Text(
              t['skip'] ?? 'Skip',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t['service_tags_title'] ?? 'What services do you offer?',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t['service_tags_subtitle'] ?? 'Customers find you when they search these tags',
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                  if (_selected.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${_selected.length} selected',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: tagsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (_, __) => Center(
                  child: Text(
                    t['service_tags_error'] ?? 'Could not load tags. You can set these later.',
                    style: const TextStyle(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),
                data: (tags) {
                  // Group by sector
                  final sectors = <String, List<Map<String, dynamic>>>{};
                  for (final tag in tags) {
                    final s = tag['sector'] as String? ?? 'Other';
                    sectors.putIfAbsent(s, () => []).add(tag);
                  }
                  final sectorNames = sectors.keys.toList()..sort();

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: sectorNames.length,
                    itemBuilder: (context, si) {
                      final sector = sectorNames[si];
                      final sectorTags = sectors[sector]!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                            child: Text(
                              sector.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: sectorTags.map((tag) {
                              final id = tag['id'] as String;
                              final name = tag['name'] as String? ?? '';
                              final nameMl = tag['nameMl'] as String? ?? '';
                              final isSelected = _selected.contains(id);
                              return _TagChip(
                                label: name,
                                sublabel: nameMl,
                                isSelected: isSelected,
                                onTap: () => setState(() {
                                  if (isSelected) {
                                    _selected.remove(id);
                                  } else {
                                    _selected.add(id);
                                  }
                                }),
                              );
                            }).toList(),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: AppButton(
                label: _saving
                    ? (t['saving'] ?? 'Saving…')
                    : (t['service_tags_continue'] ?? 'Continue'),
                onPressed: _saving ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool isSelected;
  final VoidCallback onTap;

  const _TagChip({
    required this.label,
    required this.sublabel,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.background : AppColors.textPrimary,
              ),
            ),
            if (sublabel.isNotEmpty)
              Text(
                sublabel,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected
                      ? AppColors.background.withValues(alpha: 0.7)
                      : AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
