import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../providers/language_provider.dart';
import '../../../providers/shop_provider.dart';

// Maps shopType → JSON asset path
const _kCatalogFiles = {
  'Pharmacy': 'assets/catalogs/pharmacy_kerala.json',
  'Grocery': 'assets/catalogs/grocery_kerala.json',
  'Hotel / Restaurant': 'assets/catalogs/restaurant_kerala.json',
  'Bakery': 'assets/catalogs/bakery_kerala.json',
  'Meat & Fish': 'assets/catalogs/meat_fish.json',
  'Stationery': 'assets/catalogs/stationery.json',
  'Textile': 'assets/catalogs/textile.json',
  'Electronics': 'assets/catalogs/electronics.json',
  'Fancy Store': 'assets/catalogs/fancy.json',
  'General Store': 'assets/catalogs/general_store.json',
  'Vegetable & Fruit': 'assets/catalogs/veg_fruit.json',
};

class StarterCatalogScreen extends ConsumerStatefulWidget {
  const StarterCatalogScreen({super.key});

  @override
  ConsumerState<StarterCatalogScreen> createState() =>
      _StarterCatalogScreenState();
}

class _StarterCatalogScreenState extends ConsumerState<StarterCatalogScreen> {
  List<Map<String, dynamic>> _products = [];
  Set<int> _selected = {};
  bool _loading = true;
  bool _importing = false;
  String _search = '';
  String _shopType = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final shopId =
        ref.read(activeShopIdProvider).valueOrNull ?? '';
    final shop = ref.read(shopStreamProvider(shopId)).value;
    _shopType = shop?.shopType ?? '';

    final file = _kCatalogFiles[_shopType];
    if (file == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final json = await rootBundle.loadString(file);
      final list = (jsonDecode(json) as List).cast<Map<String, dynamic>>();
      setState(() {
        _products = list;
        _selected = Set.from(Iterable.generate(list.length));
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _products;
    final q = _search.toLowerCase();
    return _products.where((p) {
      final name = (p['nameEn'] as String? ?? '').toLowerCase();
      final cat = (p['category'] as String? ?? '').toLowerCase();
      return name.contains(q) || cat.contains(q);
    }).toList();
  }

  Future<void> _import(String shopId) async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one product to import.')),
      );
      return;
    }
    setState(() => _importing = true);
    try {
      final db = FirebaseFirestore.instance;
      final toImport = _selected.map((i) => _products[i]).toList();
      final now = Timestamp.now();
      const chunkSize = 400;

      for (var i = 0; i < toImport.length; i += chunkSize) {
        final chunk = toImport.sublist(i, min(i + chunkSize, toImport.length));
        final batch = db.batch();
        for (final item in chunk) {
          final ref = db
              .collection('shops')
              .doc(shopId)
              .collection('products')
              .doc();
          batch.set(ref, {
            'productId': ref.id,
            'nameEn': item['nameEn'] ?? '',
            'nameMl': item['nameMl'] ?? '',
            'category': item['category'] ?? '',
            'unit': item['unit'] ?? 'piece',
            'price': 0.0,
            'offerPrice': 0.0,
            'minQty': 0.0,
            'imageUrl': '',
            'imageSource': 'placeholder',
            'isHidden': true, // hidden until owner sets a price
            'isOutOfStock': false,
            'hasVariants': false,
            'variants': [],
            'gstRate': item['gstRate'] ?? 0,
            if (item['hsnCode'] != null) 'hsnCode': item['hsnCode'],
            'priceIncludesGst': true,
            'attributes': item['attributes'] ?? {},
            'orderCount': 0,
            'lowStockThreshold': 5,
            'createdAt': now,
            'updatedAt': now,
          });
        }
        await batch.commit();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${toImport.length} products imported! Set prices to make them visible to customers.',
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 5),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final translations = ref.watch(translationsProvider);
    String t(String key) => translations[key] ?? key;
    final shopAsync = ref.watch(activeShopIdProvider);

    return shopAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text(e.toString()))),
      data: (shopId) {
        if (shopId == null) {
          return Scaffold(body: Center(child: Text(t('error_generic'))));
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Import Starter Catalog'),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            actions: [
              if (!_loading && _products.isNotEmpty)
                TextButton.icon(
                  onPressed: () => setState(() {
                    if (_selected.length == _products.length) {
                      _selected = {};
                    } else {
                      _selected = Set.from(Iterable.generate(_products.length));
                    }
                  }),
                  icon: Icon(
                    _selected.length == _products.length
                        ? Icons.deselect
                        : Icons.select_all,
                    color: Colors.white70,
                    size: 18,
                  ),
                  label: Text(
                    _selected.length == _products.length ? 'None' : 'All',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
            ],
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _products.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.inventory_2_outlined,
                              size: 56, color: AppColors.textSecondary),
                          const SizedBox(height: 12),
                          Text(
                            'No starter catalog available for $_shopType yet.',
                            style: const TextStyle(color: AppColors.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // Info banner
                        Container(
                          padding: const EdgeInsets.all(12),
                          color: AppColors.primary.withValues(alpha: 0.08),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 16, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${_selected.length} of ${_products.length} products selected. '
                                  'Imported items will be hidden until you set a price.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Search
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Search products...',
                              prefixIcon: const Icon(Icons.search),
                              filled: true,
                              fillColor: AppColors.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 0),
                            ),
                            onChanged: (v) => setState(() => _search = v),
                          ),
                        ),
                        // Product list
                        Expanded(
                          child: ListView.builder(
                            itemCount: _filtered.length,
                            itemBuilder: (ctx, i) {
                              final product = _filtered[i];
                              final globalIndex = _products.indexOf(product);
                              final selected = _selected.contains(globalIndex);
                              final attrs =
                                  (product['attributes'] as Map?)
                                      ?.cast<String, dynamic>() ??
                                  {};
                              final subtitle = [
                                product['category'] as String? ?? '',
                                if (attrs['composition'] != null)
                                  attrs['composition'] as String,
                                if (attrs['strength'] != null)
                                  attrs['strength'] as String,
                                if (attrs['fabric'] != null)
                                  attrs['fabric'] as String,
                                if (attrs['is_veg'] != null)
                                  attrs['is_veg'] as String,
                              ].where((s) => s.isNotEmpty).join(' · ');

                              return CheckboxListTile(
                                value: selected,
                                onChanged: (v) {
                                  setState(() {
                                    if (v == true) {
                                      _selected.add(globalIndex);
                                    } else {
                                      _selected.remove(globalIndex);
                                    }
                                  });
                                },
                                title: Text(
                                  product['nameEn'] as String? ?? '',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: subtitle.isNotEmpty
                                    ? Text(
                                        subtitle,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      )
                                    : null,
                                secondary: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      (product['gstRate'] as int? ?? 0) > 0
                                          ? '${product['gstRate']}%'
                                          : 'GST\n0%',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                activeColor: AppColors.primary,
                                dense: true,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
          bottomNavigationBar: _products.isEmpty
              ? null
              : SafeArea(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: ElevatedButton.icon(
                      onPressed: (_importing || _selected.isEmpty)
                          ? null
                          : () => _import(shopId),
                      icon: _importing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.download_rounded, size: 20),
                      label: Text(
                        _importing
                            ? 'Importing...'
                            : 'Import ${_selected.length} Products',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}
