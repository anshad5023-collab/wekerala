import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/language_provider.dart';
import '../../../providers/shop_provider.dart';
import '../../../providers/products_provider.dart';
import '../../../models/product_model.dart';
import '../../../core/utils/sheets_parser.dart';

class ImportProductsScreen extends ConsumerStatefulWidget {
  const ImportProductsScreen({super.key});

  @override
  ConsumerState<ImportProductsScreen> createState() => _ImportProductsScreenState();
}

class _ImportProductsScreenState extends ConsumerState<ImportProductsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  final _pasteCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();

  List<ProductRow> _preview = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _pasteCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  void _parsePaste() {
    final text = _pasteCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _error = null;
      _preview = SheetsParser.parsePasted(text);
      if (_preview.isEmpty) _error = 'No valid rows found. Check the format.';
    });
  }

  Future<void> _fetchUrl() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _preview = [];
    });
    try {
      final rows = await SheetsParser.fetchFromUrl(url);
      setState(() {
        _preview = rows;
        if (_preview.isEmpty) _error = 'Sheet is empty or has no valid rows.';
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _import(String shopId) async {
    if (_preview.isEmpty) return;
    setState(() => _loading = true);
    try {
      final now = DateTime.now();
      final products = _preview.map((row) {
        final id = FirebaseFirestore.instance.collection('_').doc().id;
        return ProductModel(
          productId: id,
          nameEn: row['nameEn'] as String,
          category: row['category'] as String? ?? '',
          price: row['price'] as double,
          offerPrice: row['offerPrice'] as double? ?? 0,
          unit: row['unit'] as String? ?? 'piece',
          minQty: row['minQty'] as double? ?? 0,
          searchAlias: row['searchAlias'] as String?,
          description: row['description'] as String?,
          barcode: row['barcode'] as String?,
          createdAt: now,
          updatedAt: now,
        );
      }).toList();

      await ProductRepository.batchAdd(shopId, products);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${products.length} products imported successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
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
        if (shopId == null) return Scaffold(body: Center(child: Text(t('error_generic'))));
        return _buildBody(context, t, shopId);
      },
    );
  }

  Widget _buildBody(BuildContext context, String Function(String) t, String shopId) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(t('import_title')),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          onTap: (_) => setState(() {
            _preview = [];
            _error = null;
          }),
          tabs: [
            Tab(text: t('import_tab_paste')),
            Tab(text: t('import_tab_sheets')),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _PasteTab(
                  controller: _pasteCtrl,
                  onParse: _parsePaste,
                ),
                _SheetsTab(
                  controller: _urlCtrl,
                  loading: _loading,
                  onFetch: _fetchUrl,
                ),
              ],
            ),
          ),
          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.error.withValues(alpha: 0.1),
              child: Text(_error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13)),
            ),
          if (_preview.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${_preview.length} ${t('import_rows_found')}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextButton(
                    onPressed: () => setState(() => _preview = []),
                    child: Text(t('import_clear')),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 180,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DataTable(
                    columnSpacing: 16,
                    headingRowHeight: 32,
                    dataRowMinHeight: 28,
                    dataRowMaxHeight: 40,
                    columns: const [
                      DataColumn(label: Text('Name', style: TextStyle(fontSize: 12))),
                      DataColumn(label: Text('Price', style: TextStyle(fontSize: 12))),
                      DataColumn(label: Text('Unit', style: TextStyle(fontSize: 12))),
                      DataColumn(label: Text('Offer', style: TextStyle(fontSize: 12))),
                      DataColumn(label: Text('Category', style: TextStyle(fontSize: 12))),
                    ],
                    rows: _preview.take(50).map((row) => DataRow(cells: [
                      DataCell(Text(row['nameEn'] as String,
                          style: const TextStyle(fontSize: 12))),
                      DataCell(Text('₹${row['price']}',
                          style: const TextStyle(fontSize: 12))),
                      DataCell(Text(row['unit'] as String,
                          style: const TextStyle(fontSize: 12))),
                      DataCell(Text(
                          (row['offerPrice'] as double) > 0
                              ? '₹${row['offerPrice']}'
                              : '-',
                          style: const TextStyle(fontSize: 12))),
                      DataCell(Text(row['category'] as String? ?? '',
                          style: const TextStyle(fontSize: 12))),
                    ])).toList(),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: ElevatedButton(
                onPressed: _loading ? null : () => _import(shopId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(t('import_add_products')),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PasteTab extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onParse;

  const _PasteTab({required this.controller, required this.onParse});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Paste data from Google Sheets or Excel.\nColumns: Name · Price · Unit · Offer Price · Min Qty · Category',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Tomato\t30\tkg\t25\t0\tVegetables\nOnion\t20\tkg\t\t\t',
                hintStyle:
                    const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                alignLabelWithHint: true,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onParse,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Preview'),
          ),
        ],
      ),
    );
  }
}

class _SheetsTab extends StatelessWidget {
  final TextEditingController controller;
  final bool loading;
  final VoidCallback onFetch;

  const _SheetsTab({
    required this.controller,
    required this.loading,
    required this.onFetch,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Paste the Google Sheets URL. The sheet must be publicly visible.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'https://docs.google.com/spreadsheets/d/...',
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: loading ? null : onFetch,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Fetch & Preview'),
          ),
          const SizedBox(height: 24),
          const Text(
            'Sheet column order:\n1. Product Name  2. Price  3. Unit  4. Offer Price  5. Min Qty  6. Category',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
