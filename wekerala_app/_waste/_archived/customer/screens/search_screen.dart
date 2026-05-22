import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_config.dart';

const _browseCategories = [
  (id: 'shops', emoji: '🛒', label: 'Shops'),
  (id: 'services', emoji: '🔧', label: 'Services'),
  (id: 'restaurants', emoji: '🍽️', label: 'Restaurants'),
  (id: 'hotels', emoji: '🏨', label: 'Hotels'),
  (id: 'doctors', emoji: '🩺', label: 'Doctors'),
  (id: 'hospitals', emoji: '🏥', label: 'Hospitals'),
  (id: 'education', emoji: '🎓', label: 'Education'),
  (id: 'homeServices', emoji: '🏠', label: 'Home Services'),
  (id: 'beauty', emoji: '💇', label: 'Beauty'),
  (id: 'theaters', emoji: '🎬', label: 'Theaters'),
];

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  String _query = '';
  List<String> _suggestions = [];
  List<Map<String, dynamic>> _results = [];
  bool _loadingSuggestions = false;
  bool _loadingResults = false;
  bool _hasSearched = false;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    _controller.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final q = _controller.text.trim();
    setState(() => _query = q);

    _debounce?.cancel();
    if (q.isEmpty) {
      setState(() {
        _suggestions = [];
        _results = [];
        _hasSearched = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () => _fetchSuggestions(q));
  }

  Future<void> _fetchSuggestions(String q) async {
    setState(() => _loadingSuggestions = true);
    try {
      final uri = Uri.parse('${AppConfig.storefrontBaseUrl}/api/autocomplete?q=${Uri.encodeComponent(q)}');
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        final list = (json['suggestions'] as List? ?? json as List? ?? [])
            .map((e) => e.toString())
            .toList();
        if (mounted) setState(() => _suggestions = list);
      }
    } catch (_) {
      // Silently ignore suggestion errors
    } finally {
      if (mounted) setState(() => _loadingSuggestions = false);
    }
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) return;
    _focusNode.unfocus();
    setState(() {
      _loadingResults = true;
      _hasSearched = true;
      _suggestions = [];
    });
    try {
      final uri = Uri.parse('${AppConfig.storefrontBaseUrl}/api/search?q=${Uri.encodeComponent(q.trim())}');
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final list = List<Map<String, dynamic>>.from(json['results'] as List? ?? []);
        if (mounted) setState(() => _results = list);
      }
    } catch (_) {
      if (mounted) setState(() => _results = []);
    } finally {
      if (mounted) setState(() => _loadingResults = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.background,
        titleSpacing: 0,
        leading: BackButton(onPressed: () => context.pop()),
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          textInputAction: TextInputAction.search,
          onSubmitted: _search,
          style: TextStyle(color: AppColors.background, fontSize: 16),
          cursorColor: AppColors.accent,
          decoration: InputDecoration(
            hintText: 'Search businesses, services…',
            hintStyle: TextStyle(color: AppColors.background.withValues(alpha: 0.55)),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: AppColors.background.withValues(alpha: 0.7)),
                    onPressed: () {
                      _controller.clear();
                    },
                  )
                : null,
          ),
        ),
        actions: [
          if (_loadingSuggestions || _loadingResults)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Show suggestions if query non-empty and not yet searched
    if (_query.isNotEmpty && _suggestions.isNotEmpty && !_hasSearched) {
      return _SuggestionList(
        suggestions: _suggestions,
        onTap: (s) {
          _controller.text = s;
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: s.length),
          );
          _search(s);
        },
      );
    }

    // Empty state: browse categories
    if (_query.isEmpty) {
      return _BrowseCategories(
        onCategoryTap: (id) => context.go('/customer/listings/$id'),
      );
    }

    // Loading results
    if (_loadingResults) {
      return const Center(child: CircularProgressIndicator());
    }

    // Results
    if (_hasSearched) {
      if (_results.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🔍', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text(
                'No results for "$_query"',
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                'Try a different keyword',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        );
      }

      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _results.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final item = _results[i];
          return _BusinessCard(
            item: item,
            delay: i * 40,
            onTap: () {
              final collection = item['collection'] as String? ?? '';
              final id = item['id'] as String? ?? '';
              if (collection.isNotEmpty && id.isNotEmpty) {
                context.go('/customer/listing/$collection/$id');
              }
            },
          ).animate().fadeIn(duration: 300.ms, delay: Duration(milliseconds: i * 40));
        },
      );
    }

    return const SizedBox.shrink();
  }
}

class _SuggestionList extends StatelessWidget {
  final List<String> suggestions;
  final ValueChanged<String> onTap;

  const _SuggestionList({required this.suggestions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: suggestions.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: AppColors.surface,
        indent: 16,
        endIndent: 16,
      ),
      itemBuilder: (context, i) {
        final s = suggestions[i];
        return ListTile(
          leading: Icon(Icons.search, color: AppColors.textSecondary, size: 18),
          title: Text(s, style: TextStyle(fontSize: 14, color: AppColors.textPrimary)),
          onTap: () => onTap(s),
          trailing: Icon(Icons.north_west, color: AppColors.textSecondary, size: 16),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          dense: true,
        );
      },
    );
  }
}

class _BrowseCategories extends StatelessWidget {
  final ValueChanged<String> onCategoryTap;

  const _BrowseCategories({required this.onCategoryTap});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Browse by category',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _browseCategories.map((cat) {
              return GestureDetector(
                onTap: () => onCategoryTap(cat.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(cat.emoji, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        cat.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _BusinessCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final int delay;
  final VoidCallback onTap;

  const _BusinessCard({required this.item, required this.delay, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = item['name'] as String? ?? '';
    final category = item['category'] as String? ?? (item['collection'] as String? ?? '');
    final district = item['district'] as String? ?? '';
    final avgRating = (item['avgRating'] as num?)?.toDouble() ?? 0.0;
    final isVerified = item['isVerified'] as bool? ?? false;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 20,
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isVerified) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, size: 12, color: AppColors.primary),
                              const SizedBox(width: 2),
                              Text(
                                'Verified',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (category.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      category,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (district.isNotEmpty) ...[
                        Icon(Icons.location_on_outlined,
                            size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: 2),
                        Text(
                          district,
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                      if (avgRating > 0) ...[
                        const Spacer(),
                        const Text('⭐', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 2),
                        Text(
                          avgRating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
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
    );
  }
}
