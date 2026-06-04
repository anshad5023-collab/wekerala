import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/services/product_lookup_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/layout/breakpoints.dart';
import '../../../providers/language_provider.dart'; // translationsProvider
import '../../../providers/shop_provider.dart';
import '../../../providers/products_provider.dart';
import '../../../models/product_model.dart';
import '../../../models/variant_model.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/utils/image_matcher.dart';

class AddProductScreen extends ConsumerStatefulWidget {
  final String? productId;
  const AddProductScreen({super.key, this.productId});

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameEnCtrl = TextEditingController();
  final _nameMlCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _offerPriceCtrl = TextEditingController();
  final _minQtyCtrl = TextEditingController();

  String _unit = 'piece';
  String _category = '';
  bool _hasVariants = false;
  bool _quickMode = true; // Start in Quick mode for beginners
  List<VariantModel> _variants = [];

  String _imageUrl = '';
  String _imageSource = 'placeholder';
  File? _imageFile;
  bool _loadingImage = false;
  bool _saving = false;
  bool _loaded = false;

  // Stock & expiry tracking
  bool _trackStock = false;
  final _stockQtyCtrl = TextEditingController();
  final _lowStockThresholdCtrl = TextEditingController(text: '5');
  DateTime? _expiryDate;
  final _batchNumberCtrl = TextEditingController();
  final _searchAliasCtrl = TextEditingController();

  // GST fields
  int _gstRate = 0;
  final _hsnCode = TextEditingController();
  bool _priceIncludesGst = true;

  @override
  void dispose() {
    _nameEnCtrl.dispose();
    _nameMlCtrl.dispose();
    _priceCtrl.dispose();
    _offerPriceCtrl.dispose();
    _minQtyCtrl.dispose();
    _stockQtyCtrl.dispose();
    _lowStockThresholdCtrl.dispose();
    _batchNumberCtrl.dispose();
    _searchAliasCtrl.dispose();
    _hsnCode.dispose();
    super.dispose();
  }

  Future<void> _loadExisting(String shopId) async {
    if (_loaded || widget.productId == null) {
      _loaded = true;
      return;
    }
    _loaded = true;
    final p = await ProductRepository.getById(shopId, widget.productId!);
    if (p == null || !mounted) return;
    setState(() {
      _nameEnCtrl.text = p.nameEn;
      _nameMlCtrl.text = p.nameMl;
      _priceCtrl.text = p.price > 0 ? p.price.toString() : '';
      _offerPriceCtrl.text = p.offerPrice > 0 ? p.offerPrice.toString() : '';
      _minQtyCtrl.text = p.minQty > 0 ? p.minQty.toString() : '';
      _unit = p.unit;
      _category = p.category;
      _hasVariants = p.hasVariants;
      _variants = List.from(p.variants);
      _imageUrl = p.imageUrl;
      _imageSource = p.imageSource;
      _trackStock = p.stockQty != null;
      if (p.stockQty != null) _stockQtyCtrl.text = p.stockQty.toString();
      _lowStockThresholdCtrl.text = p.lowStockThreshold.toString();
      _expiryDate = p.expiryDate;
      _batchNumberCtrl.text = p.batchNumber ?? '';
    _searchAliasCtrl.text = p.searchAlias ?? '';
      _gstRate = p.gstRate;
      _hsnCode.text = p.hsnCode ?? '';
      _priceIncludesGst = p.priceIncludesGst;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: source, imageQuality: 85);
    if (xfile == null) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: xfile.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        if (!kIsWeb && Platform.isAndroid)
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: true,
          ),
      ],
    );
    if (cropped == null) return;
    setState(() {
      _imageFile = File(cropped.path);
      _imageSource = 'owner';
    });
  }

  Future<void> _autoMatch() async {
    final name = _nameEnCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _loadingImage = true);
    final url = await ImageMatcher.findForProduct(name);
    setState(() {
      _loadingImage = false;
      if (url != null) {
        _imageUrl = url;
        _imageSource = 'auto';
        _imageFile = null;
      }
    });
  }

  List<String> _getCategories() {
    final shopId = ref.read(activeShopIdProvider).valueOrNull ?? '';
    return ref.read(shopStreamProvider(shopId)).valueOrNull?.categories ?? [];
  }

  void _applyLookup(ProductData data) {
    setState(() {
      if (data.nameEn.isNotEmpty) _nameEnCtrl.text = data.nameEn;
      if (data.imageUrl.isNotEmpty) {
        _imageUrl = data.imageUrl;
        _imageSource = 'barcode';
        _imageFile = null;
      }
      if (data.category.isNotEmpty) _category = data.category;
      _unit = data.unit;
      _loadingImage = false;
    });
    if (data.nameEn.isEmpty && mounted) {
      _showError('Product found but no name available. Enter name manually.');
    }
  }

  Future<void> _lookupBarcode(String barcode) async {
    if (barcode.isEmpty) return;
    setState(() => _loadingImage = true);
    final data = await ProductLookupService.lookupBarcode(barcode, _getCategories());
    if (!mounted) return;
    if (data != null) {
      _applyLookup(data);
    } else {
      setState(() => _loadingImage = false);
      _showError('Barcode not found. Enter details manually.');
    }
  }

  Future<void> _scanBarcode() async {
    if (kIsWeb || !Platform.isAndroid) {
      _showError('Barcode scanning is available on Android only.');
      return;
    }
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (!status.isGranted) {
      _showError('Camera permission required to scan barcodes.');
      if (status.isPermanentlyDenied) openAppSettings();
      return;
    }
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _BarcodeScannerPage()),
    );
    if (barcode == null || !mounted) return;
    setState(() => _loadingImage = true);
    final data = await ProductLookupService.lookupBarcode(barcode, _getCategories());
    if (!mounted) return;
    if (data != null) {
      _applyLookup(data);
    } else {
      setState(() => _loadingImage = false);
      _showError('Product not found in database. Enter details manually.');
    }
  }

  // Scan product photo with AI — identifies product and auto-fills all fields
  Future<void> _scanPhoto() async {
    if (kIsWeb) {
      _showError('Photo scan is available on Android only.');
      return;
    }
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (!status.isGranted) {
      _showError('Camera permission required.');
      if (status.isPermanentlyDenied) openAppSettings();
      return;
    }
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 800,
      imageQuality: 80,
    );
    if (file == null || !mounted) return;

    setState(() => _loadingImage = true);
    final bytes = await file.readAsBytes();
    final base64Image = base64Encode(bytes);
    final data = await ProductLookupService.lookupByPhoto(base64Image, _getCategories());
    if (!mounted) return;
    if (data != null && data.hasData) {
      _applyLookup(data);
    } else {
      setState(() => _loadingImage = false);
      _showError('Could not identify product. Try scanning the barcode instead.');
    }
  }

  Future<void> _save(String shopId, List<String> categories) async {
    if (!_formKey.currentState!.validate()) return;
    if (!_hasVariants) {
      final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;
      if (price <= 0) {
        _showError('Enter a valid price');
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final translations = ref.read(translationsProvider);
      String t(String key) => translations[key] ?? key;
      String finalImageUrl = _imageUrl;
      String finalImageSource = _imageSource;

      final productId = widget.productId ??
          FirebaseFirestore.instance.collection('_').doc().id;

      if (_imageFile != null) {
        finalImageUrl = await StorageService.uploadProductImage(
            shopId, productId, _imageFile!);
        finalImageSource = 'owner';
      }

      final now = DateTime.now();
      final existing = widget.productId != null
          ? await ProductRepository.getById(shopId, productId)
          : null;

      final product = ProductModel(
        productId: productId,
        nameEn: _nameEnCtrl.text.trim(),
        nameMl: _nameMlCtrl.text.trim(),
        category: _category,
        price: double.tryParse(_priceCtrl.text.trim()) ?? 0,
        offerPrice: double.tryParse(_offerPriceCtrl.text.trim()) ?? 0,
        unit: _unit,
        minQty: double.tryParse(_minQtyCtrl.text.trim()) ?? 0,
        imageUrl: finalImageUrl,
        imageSource: finalImageSource,
        hasVariants: _hasVariants,
        variants: _variants,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        orderCount: existing?.orderCount ?? 0,
        stockQty: _trackStock
            ? (int.tryParse(_stockQtyCtrl.text.trim()))
            : null,
        lowStockThreshold:
            int.tryParse(_lowStockThresholdCtrl.text.trim()) ?? 5,
        expiryDate: _expiryDate,
        gstRate: _gstRate,
        hsnCode: _hsnCode.text.trim().isEmpty ? null : _hsnCode.text.trim(),
        priceIncludesGst: _priceIncludesGst,
        batchNumber: _batchNumberCtrl.text.trim().isEmpty ? null : _batchNumberCtrl.text.trim(),
        searchAlias: _searchAliasCtrl.text.trim().isEmpty ? null : _searchAliasCtrl.text.trim(),
      );

      if (widget.productId != null) {
        await ProductRepository.update(shopId, product);
      } else {
        await ProductRepository.add(shopId, product);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('product_saved'))),
        );
        context.pop();
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _clearForm() {
    _nameEnCtrl.clear();
    _nameMlCtrl.clear();
    _priceCtrl.clear();
    _offerPriceCtrl.clear();
    _minQtyCtrl.clear();
    _stockQtyCtrl.clear();
    _batchNumberCtrl.clear();
    _searchAliasCtrl.clear();
    _hsnCode.clear();
    setState(() {
      _imageUrl = '';
      _imageFile = null;
      _imageSource = 'placeholder';
      _trackStock = false;
      _hasVariants = false;
      _variants = [];
      _expiryDate = null;
      _gstRate = 0;
    });
    _formKey.currentState?.reset();
  }

  Future<void> _saveAndAddAnother(String shopId, List<String> categories) async {
    if (!_formKey.currentState!.validate()) return;
    if (!_hasVariants) {
      final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;
      if (price <= 0) { _showError('Enter a valid price'); return; }
    }
    setState(() => _saving = true);
    try {
      final productId = FirebaseFirestore.instance.collection('_').doc().id;
      String finalImageUrl = _imageUrl;
      String finalImageSource = _imageSource;
      if (_imageFile != null) {
        finalImageUrl = await StorageService.uploadProductImage(shopId, productId, _imageFile!);
        finalImageSource = 'owner';
      }
      final now = DateTime.now();
      final product = ProductModel(
        productId: productId,
        nameEn: _nameEnCtrl.text.trim(),
        nameMl: _nameMlCtrl.text.trim(),
        category: _category,
        price: double.tryParse(_priceCtrl.text.trim()) ?? 0,
        offerPrice: double.tryParse(_offerPriceCtrl.text.trim()) ?? 0,
        unit: _unit,
        minQty: double.tryParse(_minQtyCtrl.text.trim()) ?? 0,
        imageUrl: finalImageUrl,
        imageSource: finalImageSource,
        hasVariants: _hasVariants,
        variants: _variants,
        createdAt: now,
        updatedAt: now,
        orderCount: 0,
        stockQty: _trackStock ? (int.tryParse(_stockQtyCtrl.text.trim())) : null,
        lowStockThreshold: int.tryParse(_lowStockThresholdCtrl.text.trim()) ?? 5,
        expiryDate: _expiryDate,
        gstRate: _gstRate,
        hsnCode: _hsnCode.text.trim().isEmpty ? null : _hsnCode.text.trim(),
        priceIncludesGst: _priceIncludesGst,
        batchNumber: _batchNumberCtrl.text.trim().isEmpty ? null : _batchNumberCtrl.text.trim(),
        searchAlias: _searchAliasCtrl.text.trim().isEmpty ? null : _searchAliasCtrl.text.trim(),
      );
      await ProductRepository.add(shopId, product);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product.nameEn} saved! Add next product.'),
            backgroundColor: AppColors.success,
          ),
        );
        _clearForm();
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(String shopId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Product'),
        content: const Text('This product will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await ProductRepository.delete(shopId, widget.productId!);
    if (mounted) context.pop();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
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

        WidgetsBinding.instance.addPostFrameCallback((_) => _loadExisting(shopId));

        final shopVal = ref.watch(shopStreamProvider(shopId)).value;
        final categories = shopVal?.categories ?? [];

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(widget.productId == null ? t('product_add_title') : t('product_edit_title')),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            actions: [
              // Quick / Advanced toggle
              if (widget.productId == null)
                TextButton.icon(
                  icon: Icon(
                    _quickMode ? Icons.tune_outlined : Icons.flash_on_outlined,
                    color: Colors.white70,
                    size: 18,
                  ),
                  label: Text(
                    _quickMode ? 'Advanced' : 'Quick',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  onPressed: () => setState(() => _quickMode = !_quickMode),
                ),
              if (widget.productId != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(shopId),
                ),
            ],
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ImageSection(
                  imageFile: _imageFile,
                  imageUrl: _imageUrl,
                  loading: _loadingImage,
                  onCamera: () => _pickImage(ImageSource.camera),
                  onGallery: () => _pickImage(ImageSource.gallery),
                  onAuto: _autoMatch,
                  onScan: _scanBarcode,
                  onScanPhoto: _scanPhoto,
                  onBarcodeChanged: _lookupBarcode,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: isDesktop(context) ? 320 : double.infinity,
                      child: TextFormField(
                        controller: _nameEnCtrl,
                        decoration: _inputDecoration(t('product_name_en')),
                        validator: (v) =>
                            (v?.trim().isEmpty ?? true) ? t('product_name_required') : null,
                      ),
                    ),
                    SizedBox(
                      width: isDesktop(context) ? 320 : double.infinity,
                      child: TextFormField(
                        controller: _nameMlCtrl,
                        decoration: _inputDecoration(t('product_name_ml')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _searchAliasCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Search Alias / Generic Name (optional)',
                    hintText: 'e.g. Metformin • Ulli • Cotton • Biryani',
                    border: OutlineInputBorder(),
                    isDense: true,
                    helperText:
                        'Staff can find this product by typing this alias in billing',
                  ),
                ),
                const SizedBox(height: 12),
                if (categories.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: _category.isEmpty ? null : _category,
                    decoration: _inputDecoration(t('product_category')),
                    items: categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _category = v ?? ''),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: isDesktop(context) ? 320 : double.infinity,
                      child: DropdownButtonFormField<String>(
                        value: _unit,
                        decoration: _inputDecoration(t('product_unit')),
                        items: kProductUnits
                            .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                            .toList(),
                        onChanged: (v) => setState(() => _unit = v ?? 'piece'),
                      ),
                    ),
                    SizedBox(
                      width: isDesktop(context) ? 320 : double.infinity,
                      child: TextFormField(
                        controller: _minQtyCtrl,
                        decoration: _inputDecoration(t('product_min_qty')),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  value: _hasVariants,
                  title: Text(t('product_has_variants')),
                  subtitle: Text(t('product_has_variants_hint'),
                      style: const TextStyle(fontSize: 12)),
                  activeColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setState(() => _hasVariants = v),
                ),
                if (!_hasVariants) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      SizedBox(
                        width: isDesktop(context) ? 320 : double.infinity,
                        child: TextFormField(
                          controller: _priceCtrl,
                          decoration: _inputDecoration(t('product_price')),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      SizedBox(
                        width: isDesktop(context) ? 320 : double.infinity,
                        child: TextFormField(
                          controller: _offerPriceCtrl,
                          decoration: _inputDecoration(t('product_offer_price')),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                ],
                if (_hasVariants) ...[
                  const SizedBox(height: 8),
                  _VariantEditor(
                    variants: _variants,
                    onChanged: (v) => setState(() => _variants = v),
                  ),
                ],
                if (!_quickMode) ...[
                const SizedBox(height: 16),
                Text('GST & Advanced', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                // GST rate selector
                Row(
                  children: [0, 5, 12, 18, 28].map((rate) {
                    final selected = _gstRate == rate;
                    return GestureDetector(
                      onTap: () => setState(() => _gstRate = rate),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.primary : Colors.white,
                          border: Border.all(color: selected ? AppColors.primary : Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('$rate%',
                            style: TextStyle(
                              color: selected ? Colors.white : AppColors.textSecondary,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                              fontSize: 13,
                            )),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _hsnCode,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'HSN Code (optional)',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                    hintText: 'e.g. 10019010',
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _priceIncludesGst,
                  onChanged: (v) => setState(() => _priceIncludesGst = v),
                  title: const Text('Price includes GST (MRP)'),
                  subtitle: Text(_priceIncludesGst
                      ? 'Tax is included in the price shown'
                      : 'Tax is added on top of price',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  activeColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 16),
                _StockExpirySection(
                  trackStock: _trackStock,
                  stockQtyCtrl: _stockQtyCtrl,
                  lowStockThresholdCtrl: _lowStockThresholdCtrl,
                  expiryDate: _expiryDate,
                  batchNumberCtrl: _batchNumberCtrl,
                  onTrackStockChanged: (v) => setState(() => _trackStock = v),
                  onExpiryDateChanged: (d) => setState(() => _expiryDate = d),
                  inputDecoration: _inputDecoration,
                ),
                ], // end if (!_quickMode)
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saving ? null : () => _save(shopId, categories),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(t('product_save')),
                ),
                // Only show for new products (not when editing)
                if (widget.productId == null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : () => _saveAndAddAnother(shopId, categories),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Save & Add Another'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      );
}

// ─── Stock & Expiry Section ───────────────────────────────────────────────────

class _StockExpirySection extends StatelessWidget {
  final bool trackStock;
  final TextEditingController stockQtyCtrl;
  final TextEditingController lowStockThresholdCtrl;
  final DateTime? expiryDate;
  final TextEditingController batchNumberCtrl;
  final ValueChanged<bool> onTrackStockChanged;
  final ValueChanged<DateTime?> onExpiryDateChanged;
  final InputDecoration Function(String) inputDecoration;

  const _StockExpirySection({
    required this.trackStock,
    required this.stockQtyCtrl,
    required this.lowStockThresholdCtrl,
    required this.expiryDate,
    required this.batchNumberCtrl,
    required this.onTrackStockChanged,
    required this.onExpiryDateChanged,
    required this.inputDecoration,
  });

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: expiryDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 10),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: AppColors.background,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) onExpiryDateChanged(picked);
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 2),
            child: Text(
              'Inventory',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          SwitchListTile(
            value: trackStock,
            title: const Text('Track Stock', style: TextStyle(fontSize: 14)),
            subtitle: const Text(
              'Monitor quantity and get low stock alerts',
              style: TextStyle(fontSize: 11),
            ),
            activeColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            dense: true,
            onChanged: onTrackStockChanged,
          ),
          if (trackStock) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: isDesktop(context) ? 320 : double.infinity,
                  child: TextFormField(
                    controller: stockQtyCtrl,
                    decoration: inputDecoration('Current Stock Qty'),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (trackStock && (v == null || v.trim().isEmpty)) {
                        return 'Enter stock quantity';
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(
                  width: isDesktop(context) ? 320 : double.infinity,
                  child: TextFormField(
                    controller: lowStockThresholdCtrl,
                    decoration: inputDecoration('Alert when below'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          const Divider(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Expiry Date', style: TextStyle(fontSize: 14)),
            subtitle: Text(
              expiryDate != null ? _formatDate(expiryDate!) : 'Not set',
              style: TextStyle(
                fontSize: 12,
                color: expiryDate != null
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (expiryDate != null)
                  GestureDetector(
                    onTap: () => onExpiryDateChanged(null),
                    child: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                  ),
                const SizedBox(width: 4),
                const Icon(Icons.calendar_month_outlined,
                    size: 20, color: AppColors.primary),
              ],
            ),
            onTap: () => _pickDate(context),
          ),
          const Divider(height: 16),
          TextFormField(
            controller: batchNumberCtrl,
            decoration: inputDecoration('Batch / Lot Number (optional)'),
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Image Section ────────────────────────────────────────────────────────────

class _ImageSection extends StatelessWidget {
  final File? imageFile;
  final String imageUrl;
  final bool loading;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onAuto;
  final VoidCallback onScan;
  final VoidCallback onScanPhoto;
  final ValueChanged<String> onBarcodeChanged;

  const _ImageSection({
    required this.imageFile,
    required this.imageUrl,
    required this.loading,
    required this.onCamera,
    required this.onGallery,
    required this.onAuto,
    required this.onScan,
    required this.onScanPhoto,
    required this.onBarcodeChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget preview;
    if (imageFile != null) {
      preview = ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(imageFile!, width: 100, height: 100, fit: BoxFit.cover),
      );
    } else if (imageUrl.isNotEmpty) {
      preview = ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(imageUrl: imageUrl, width: 100, height: 100, fit: BoxFit.cover),
      );
    } else {
      preview = Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.image_outlined, size: 40, color: AppColors.textSecondary),
      );
    }

    return Row(
      children: [
        preview,
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!kIsWeb && Platform.isAndroid) ...[
              OutlinedButton.icon(
                onPressed: loading ? null : onScan,
                icon: loading
                    ? const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.qr_code_scanner, size: 16),
                label: const Text('Scan Barcode'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(130, 36),
                  foregroundColor: AppColors.accent,
                  side: BorderSide(color: AppColors.accent),
                ),
              ),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: loading ? null : onScanPhoto,
                icon: const Icon(Icons.camera_enhance, size: 16),
                label: const Text('Scan Photo (AI)'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(130, 36),
                  foregroundColor: Colors.deepPurple,
                  side: const BorderSide(color: Colors.deepPurple),
                ),
              ),
            ] else
              SizedBox(
                width: 160,
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Barcode',
                    prefixIcon: Icon(Icons.qr_code),
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  ),
                  onSubmitted: onBarcodeChanged,
                ),
              ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: onCamera,
              icon: const Icon(Icons.camera_alt, size: 16),
              label: const Text('Camera'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(130, 36),
                foregroundColor: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: onGallery,
              icon: const Icon(Icons.photo_library, size: 16),
              label: const Text('Gallery'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(130, 36),
                foregroundColor: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: loading ? null : onAuto,
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('Auto-match'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(130, 36),
                foregroundColor: AppColors.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _VariantEditor extends StatelessWidget {
  final List<VariantModel> variants;
  final ValueChanged<List<VariantModel>> onChanged;

  const _VariantEditor({required this.variants, required this.onChanged});

  void _add() {
    onChanged([
      ...variants,
      VariantModel(
        variantId: VariantModel.newId(),
        name: '',
        price: 0,
      ),
    ]);
  }

  void _remove(int i) {
    final updated = List<VariantModel>.from(variants)..removeAt(i);
    onChanged(updated);
  }

  void _update(int i, VariantModel v) {
    final updated = List<VariantModel>.from(variants)..[i] = v;
    onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Variants', style: TextStyle(fontWeight: FontWeight.w600)),
            TextButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
        ...List.generate(variants.length, (i) => _VariantRow(
          variant: variants[i],
          onRemove: () => _remove(i),
          onChanged: (v) => _update(i, v),
        )),
      ],
    );
  }
}

class _VariantRow extends StatefulWidget {
  final VariantModel variant;
  final VoidCallback onRemove;
  final ValueChanged<VariantModel> onChanged;

  const _VariantRow({
    required this.variant,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  State<_VariantRow> createState() => _VariantRowState();
}

class _VariantRowState extends State<_VariantRow> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _offerCtrl;
  late final TextEditingController _stockCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.variant.name);
    _priceCtrl = TextEditingController(
        text: widget.variant.price > 0 ? widget.variant.price.toString() : '');
    _offerCtrl = TextEditingController(
        text: widget.variant.offerPrice > 0 ? widget.variant.offerPrice.toString() : '');
    _stockCtrl = TextEditingController(
        text: widget.variant.stockQty?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _offerCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  void _notify() {
    widget.onChanged(widget.variant.copyWith(
      name: _nameCtrl.text.trim(),
      price: double.tryParse(_priceCtrl.text.trim()) ?? 0,
      offerPrice: double.tryParse(_offerCtrl.text.trim()) ?? 0,
      stockQty: _stockCtrl.text.trim().isEmpty
          ? null
          : int.tryParse(_stockCtrl.text.trim()),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: _nameCtrl,
              onChanged: (_) => _notify(),
              decoration: _dec('Name'),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: TextField(
              controller: _priceCtrl,
              onChanged: (_) => _notify(),
              keyboardType: TextInputType.number,
              decoration: _dec('Price'),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: TextField(
              controller: _offerCtrl,
              onChanged: (_) => _notify(),
              keyboardType: TextInputType.number,
              decoration: _dec('Offer'),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: TextField(
              controller: _stockCtrl,
              onChanged: (_) => _notify(),
              keyboardType: TextInputType.number,
              decoration: _dec('Stock'),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.error),
            onPressed: widget.onRemove,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          ),
        ],
      ),
    );
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        labelStyle: const TextStyle(fontSize: 12),
      );
}

// ─── Barcode Scanner ─────────────────────────────────────────────────────────

class _BarcodeScannerPage extends StatefulWidget {
  const _BarcodeScannerPage();

  @override
  State<_BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<_BarcodeScannerPage> {
  final _controller = MobileScannerController();
  bool _scanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Product Barcode'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_scanned) return;
              final barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final code = barcode.rawValue;
                if (code != null && code.isNotEmpty) {
                  _scanned = true;
                  Navigator.pop(context, code);
                  return;
                }
              }
            },
          ),
          // Scan frame overlay
          Center(
            child: Container(
              width: 260,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.accent, width: 2.5),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          // Corner accents
          Center(
            child: SizedBox(
              width: 260,
              height: 160,
              child: Stack(
                children: [
                  _Corner(top: 0, left: 0),
                  _Corner(top: 0, right: 0),
                  _Corner(bottom: 0, left: 0),
                  _Corner(bottom: 0, right: 0),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  'Point camera at the barcode on the product',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _controller.toggleTorch(),
                  icon: const Icon(Icons.flashlight_on, color: Colors.white, size: 18),
                  label: const Text('Toggle Flash', style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white38)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  final double? top, bottom, left, right;
  const _Corner({this.top, this.bottom, this.left, this.right});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          border: Border(
            top: top != null ? BorderSide(color: AppColors.accent, width: 3) : BorderSide.none,
            bottom: bottom != null ? BorderSide(color: AppColors.accent, width: 3) : BorderSide.none,
            left: left != null ? BorderSide(color: AppColors.accent, width: 3) : BorderSide.none,
            right: right != null ? BorderSide(color: AppColors.accent, width: 3) : BorderSide.none,
          ),
        ),
      ),
    );
  }
}
