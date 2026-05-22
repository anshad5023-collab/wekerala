import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_config.dart';

final _listingsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, collection) async {
  final base = AppConfig.storefrontBaseUrl;
  final uri = Uri.parse('$base/api/listings?collection=$collection');
  final res = await http.get(uri);
  if (res.statusCode != 200) return [];
  final json = jsonDecode(res.body) as Map<String, dynamic>;
  return List<Map<String, dynamic>>.from(json['listings'] as List? ?? []);
});

const _categoryMeta = {
  'shops': (emoji: '🛒', label: 'Shops'),
  'services': (emoji: '🔧', label: 'Services'),
  'theaters': (emoji: '🎬', label: 'Theaters'),
  'hotels': (emoji: '🏨', label: 'Hotels'),
  'restaurants': (emoji: '🍽️', label: 'Restaurants'),
  'beauty': (emoji: '💇', label: 'Beauty & Wellness'),
};

class CustomerListingsScreen extends ConsumerStatefulWidget {
  final String collection;
  const CustomerListingsScreen({super.key, required this.collection});

  @override
  ConsumerState<CustomerListingsScreen> createState() => _CustomerListingsScreenState();
}

class _CustomerListingsScreenState extends ConsumerState<CustomerListingsScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meta = _categoryMeta[widget.collection];
    final listingsAsync = ref.watch(_listingsProvider(widget.collection));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.background,
        title: Text(
          '${meta?.emoji ?? ''} ${meta?.label ?? widget.collection}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        leading: BackButton(onPressed: () => context.go('/customer/home')),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search ${meta?.label ?? ''}…',
                hintStyle: TextStyle(color: AppColors.textSecondary),
                prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Listings
          Expanded(
            child: listingsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('😕', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to load. Check your connection.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    TextButton(
                      onPressed: () => ref.invalidate(_listingsProvider(widget.collection)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (listings) {
                final filtered = _query.isEmpty
                    ? listings
                    : listings.where((l) {
                        final name = (l['name'] as String? ?? '').toLowerCase();
                        final district = (l['district'] as String? ?? '').toLowerCase();
                        return name.contains(_query) || district.contains(_query);
                      }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🔍', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: 12),
                        Text(
                          _query.isNotEmpty ? 'No results for "$_query"' : 'No listings yet',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final item = filtered[i];
                    return _ListingCard(
                      item: item,
                      delay: i * 40,
                      onTap: () {
                        final externalUrl = item['externalUrl'] as String? ?? '';
                        final name = item['name'] as String? ?? '';
                        if (externalUrl.isNotEmpty) {
                          context.go(
                            '/customer/business',
                            extra: {'url': externalUrl, 'name': name},
                          );
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final int delay;
  final VoidCallback onTap;

  const _ListingCard({required this.item, required this.delay, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = item['name'] as String? ?? '';
    final district = item['district'] as String? ?? '';
    final location = item['location'] as String? ?? '';
    final description = item['description'] as String? ?? '';
    final serviceType = item['serviceType'] as String?;
    final externalUrl = item['externalUrl'] as String? ?? '';
    final hasWebsite = externalUrl.isNotEmpty;

    return Animate(
      effects: [
        FadeEffect(duration: 350.ms, delay: Duration(milliseconds: delay)),
        SlideEffect(begin: const Offset(0, 0.05), duration: 350.ms, delay: Duration(milliseconds: delay)),
      ],
      child: GestureDetector(
        onTap: hasWebsite ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (serviceType != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        serviceType,
                        style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                      ),
                    ],
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.3),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: 2),
                        Text(
                          district.isNotEmpty ? district : location,
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        if (hasWebsite) ...[
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Visit Website →',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
