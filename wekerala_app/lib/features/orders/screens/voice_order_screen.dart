import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/order_model.dart';
import '../../../models/product_model.dart';
import '../voice_command_parser.dart';

// ---------------------------------------------------------------------------
// Data class for a single parsed/manually-entered item
// ---------------------------------------------------------------------------
class _VoiceItem {
  String name;
  double qty;
  String unit;
  String productId;
  double price;

  _VoiceItem({
    required this.name,
    required this.qty,
    required this.unit,
    this.productId = '',
    this.price = 0,
  });
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class VoiceOrderScreen extends ConsumerStatefulWidget {
  const VoiceOrderScreen({super.key});

  @override
  ConsumerState<VoiceOrderScreen> createState() => _VoiceOrderScreenState();
}

class _VoiceOrderScreenState extends ConsumerState<VoiceOrderScreen> {
  // -- Speech --
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
  String _transcription = '';

  // -- Parsed items --
  List<_VoiceItem> _parsedItems = [];

  // -- Item-level controllers (rebuilt when list changes) --
  List<TextEditingController> _nameCtls = [];
  List<TextEditingController> _qtyCtls = [];

  // -- Customer form --
  final _formKey = GlobalKey<FormState>();
  final _customerNameCtl = TextEditingController();
  final _customerPhoneCtl = TextEditingController();
  final _customerLocationCtl = TextEditingController();

  // -- Loading state --
  bool _isCreating = false;

  // -- Product catalog for matching --
  List<ProductModel> _products = [];

  static const _units = [
    'piece', 'kg', 'gram', 'litre', 'ml', 'dozen', 'packet', 'box', 'pcs',
  ];

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final shopId = userDoc.data()?['activeShopId'] as String?;
      if (shopId == null || shopId.isEmpty) return;
      final snap = await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('products')
          .get();
      if (mounted) {
        setState(() {
          _products = snap.docs.map(ProductModel.fromFirestore).toList();
        });
      }
    } catch (_) {}
  }

  // Fuzzy-match a spoken word against the product catalog.
  // Returns the best matching product or null if no reasonable match.
  ProductModel? _matchProduct(String spokenName) {
    if (_products.isEmpty || spokenName.isEmpty) return null;
    final query = spokenName.toLowerCase().trim();

    // Exact match first
    for (final p in _products) {
      if (p.nameEn.toLowerCase() == query ||
          p.nameMl.toLowerCase() == query) {
        return p;
      }
    }

    // Contains match (spoken word is contained in product name or vice versa)
    ProductModel? best;
    int bestScore = 0;
    for (final p in _products) {
      final name = p.nameEn.toLowerCase();
      final nameMl = p.nameMl.toLowerCase();
      int score = 0;
      if (name.contains(query) || query.contains(name)) {
        score = name.length; // longer match = better
      } else if (nameMl.isNotEmpty &&
          (nameMl.contains(query) || query.contains(nameMl))) {
        score = nameMl.length;
      } else {
        // Word overlap score
        final queryWords = query.split(' ');
        final nameWords = name.split(' ');
        for (final qw in queryWords) {
          if (qw.length >= 3 && nameWords.any((nw) => nw.contains(qw) || qw.contains(nw))) {
            score += qw.length;
          }
        }
      }
      if (score > bestScore) {
        bestScore = score;
        best = p;
      }
    }
    // Only return if score is meaningful (avoid random matches)
    return bestScore >= 3 ? best : null;
  }

  @override
  void dispose() {
    _speech.stop();
    _customerNameCtl.dispose();
    _customerPhoneCtl.dispose();
    _customerLocationCtl.dispose();
    for (final c in _nameCtls) {
      c.dispose();
    }
    for (final c in _qtyCtls) {
      c.dispose();
    }
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Speech helpers
  // -------------------------------------------------------------------------
  Future<void> _initSpeech() async {
    await _speech.initialize(
      onError: (error) {
        if (mounted) setState(() => _isListening = false);
      },
    );
  }

  Future<void> _toggleListening() async {
    if (!_isListening) {
      final available = await _speech.initialize();
      if (available) {
        setState(() {
          _isListening = true;
          _transcription = '';
        });
        await _speech.listen(
          onResult: (result) {
            if (!mounted) return;
            setState(() {
              _transcription = result.recognizedWords;
              if (result.finalResult) {
                _parseTranscription(_transcription);
                _isListening = false;
              }
            });
          },
          localeId: 'ml_IN',
          listenFor: const Duration(seconds: 30),
        );
      }
    } else {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
    }
  }

  // -------------------------------------------------------------------------
  // Parser
  // -------------------------------------------------------------------------
  void _parseTranscription(String text) {
    // Malayalam-first parsing lives in the pure, unit-tested parseVoiceOrder
    // (handles Malayalam script, Manglish, fractions and English). We just map
    // its result into the screen's editable _VoiceItem rows.
    final parsed = parseVoiceOrder(text)
        .map((p) => _VoiceItem(name: p.name, qty: p.qty, unit: p.unit))
        .toList();
    _applyParsedItems(parsed);
  }

  // Syncs controllers whenever _parsedItems changes, with product matching
  void _applyParsedItems(List<_VoiceItem> items) {
    for (final c in _nameCtls) {
      c.dispose();
    }
    for (final c in _qtyCtls) {
      c.dispose();
    }

    // Try to match each item against the product catalog
    final matched = items.map((item) {
      final product = _matchProduct(item.name);
      if (product != null) {
        return _VoiceItem(
          name: product.nameEn,
          qty: item.qty,
          unit: product.unit.isNotEmpty ? product.unit : item.unit,
          productId: product.productId,
          price: product.offerPrice > 0 ? product.offerPrice : product.price,
        );
      }
      return item;
    }).toList();

    _nameCtls = matched.map((e) => TextEditingController(text: e.name)).toList();
    _qtyCtls = matched
        .map((e) => TextEditingController(
            text: e.qty == e.qty.truncateToDouble()
                ? e.qty.toInt().toString()
                : e.qty.toString()))
        .toList();

    setState(() => _parsedItems = matched);
  }

  void _addManualItem() {
    final newItem = _VoiceItem(name: '', qty: 1, unit: 'piece');
    final newItems = [..._parsedItems, newItem];
    _nameCtls.add(TextEditingController());
    _qtyCtls.add(TextEditingController(text: '1'));
    setState(() => _parsedItems = newItems);
  }

  void _removeItem(int index) {
    _nameCtls[index].dispose();
    _qtyCtls[index].dispose();
    _nameCtls.removeAt(index);
    _qtyCtls.removeAt(index);
    setState(() => _parsedItems.removeAt(index));
  }

  // -------------------------------------------------------------------------
  // Create order
  // -------------------------------------------------------------------------
  Future<void> _createOrder() async {
    if (!_formKey.currentState!.validate()) return;
    if (_parsedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item')),
      );
      return;
    }

    // Sync text-field edits back into _parsedItems
    for (int i = 0; i < _parsedItems.length; i++) {
      _parsedItems[i].name = _nameCtls[i].text.trim();
      _parsedItems[i].qty = double.tryParse(_qtyCtls[i].text) ?? 1;
    }

    setState(() => _isCreating = true);

    try {
      // Fetch active shopId
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final shopId = userDoc.data()?['activeShopId'] as String?;
      if (shopId == null || shopId.isEmpty) {
        throw Exception('No active shop found');
      }

      final db = FirebaseFirestore.instance;
      final ordersRef = db.collection('shops').doc(shopId).collection('orders');
      final orderId = ordersRef.doc().id;

      final now = DateTime.now();
      // Derive order number from the collision-free Firestore doc ID
      final orderNumber = (orderId.hashCode.abs() % 90000) + 10000;

      final items = _parsedItems
          .where((e) => e.name.isNotEmpty)
          .map((e) => OrderItemModel(
                productId: e.productId,
                productName: e.name,
                qty: e.qty,
                unit: e.unit,
                price: e.price,
                subtotal: e.price * e.qty,
              ))
          .toList();

      final totalAmount = items.fold<double>(0, (acc, i) => acc + i.subtotal);

      final order = OrderModel(
        orderId: orderId,
        shopId: shopId,
        orderNumber: orderNumber,
        status: 'new',
        customerName: _customerNameCtl.text.trim(),
        customerPhone: _customerPhoneCtl.text.trim(),
        customerLocation: _customerLocationCtl.text.trim(),
        deliveryType: 'delivery',
        items: items,
        totalAmount: totalAmount,
        paymentMethod: 'cash',
        createdAt: now,
        updatedAt: now,
      );

      await ordersRef.doc(orderId).set(order.toFirestore());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order #$orderNumber created!'),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    // speech_to_text works on Android and Windows; block only web and iOS.
    final bool speechSupported =
        !kIsWeb && (Platform.isAndroid || Platform.isWindows);
    if (!speechSupported) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Voice Order'),
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
        ),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.mic_off, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Voice ordering is not available\non this platform.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Voice Order'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _MicSection(
                isListening: _isListening,
                onToggle: _toggleListening,
              ),
              const SizedBox(height: 20),
              _TranscriptionCard(
                transcription: _transcription,
                isListening: _isListening,
              ),
              const SizedBox(height: 20),
              _ItemsSection(
                items: _parsedItems,
                nameCtls: _nameCtls,
                qtyCtls: _qtyCtls,
                units: _units,
                onAdd: _addManualItem,
                onRemove: _removeItem,
                onUnitChanged: (index, unit) {
                  setState(() => _parsedItems[index].unit = unit);
                },
              ),
              const SizedBox(height: 20),
              _CustomerSection(
                nameCtl: _customerNameCtl,
                phoneCtl: _customerPhoneCtl,
                locationCtl: _customerLocationCtl,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isCreating ? null : _createOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.primary.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isCreating
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text(
                          'Create Order',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mic button section
// ---------------------------------------------------------------------------
class _MicSection extends StatelessWidget {
  final bool isListening;
  final VoidCallback onToggle;

  const _MicSection({required this.isListening, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onToggle,
          child: isListening
              ? Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mic, color: Colors.white, size: 44),
                )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(begin: 1.0, end: 1.15, duration: 600.ms)
              : Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.mic_none, color: Colors.white, size: 44),
                ),
        ),
        const SizedBox(height: 10),
        Text(
          isListening ? 'Listening...' : 'Tap to speak',
          style: TextStyle(
            color: isListening ? Colors.red : AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Transcription card
// ---------------------------------------------------------------------------
class _TranscriptionCard extends StatelessWidget {
  final String transcription;
  final bool isListening;

  const _TranscriptionCard(
      {required this.transcription, required this.isListening});

  @override
  Widget build(BuildContext context) {
    final text = transcription.isNotEmpty
        ? transcription
        : "Speak the order... e.g. '2 kg rice, 1 sugar, Kadamakkudy'";

    return Card(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isListening ? Colors.red.shade200 : Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.record_voice_over,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                const Text(
                  'Transcription',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isListening) ...[
                  const Spacer(),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .fadeIn(duration: 500.ms),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: transcription.isNotEmpty
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontStyle: transcription.isEmpty ? FontStyle.italic : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Items section
// ---------------------------------------------------------------------------
class _ItemsSection extends StatelessWidget {
  final List<_VoiceItem> items;
  final List<TextEditingController> nameCtls;
  final List<TextEditingController> qtyCtls;
  final List<String> units;
  final VoidCallback onAdd;
  final void Function(int) onRemove;
  final void Function(int, String) onUnitChanged;

  const _ItemsSection({
    required this.items,
    required this.nameCtls,
    required this.qtyCtls,
    required this.units,
    required this.onAdd,
    required this.onRemove,
    required this.onUnitChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Items',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add item'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
        ),
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Text(
              'No items yet. Speak or tap "Add item".',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          )
        else ...[
          ...List.generate(items.length, (i) {
            return _ItemRow(
              nameCtl: nameCtls[i],
              qtyCtl: qtyCtls[i],
              unit: items[i].unit,
              units: units,
              price: items[i].price,
              onRemove: () => onRemove(i),
              onUnitChanged: (u) => onUnitChanged(i, u),
            );
          }),
          // Running subtotal — lets owner verify total before saving
          if (items.any((e) => e.price > 0)) ...[
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text('Estimated Total: ',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(
                  '₹${items.fold<double>(0, (s, e) => s + e.price * e.qty).toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.primary),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  final TextEditingController nameCtl;
  final TextEditingController qtyCtl;
  final String unit;
  final List<String> units;
  final VoidCallback onRemove;
  final void Function(String) onUnitChanged;
  final double price;

  const _ItemRow({
    required this.nameCtl,
    required this.qtyCtl,
    required this.unit,
    required this.units,
    required this.onRemove,
    required this.onUnitChanged,
    this.price = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Item name
          Expanded(
            flex: 4,
            child: TextFormField(
              controller: nameCtl,
              decoration: const InputDecoration(
                hintText: 'Item name',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
          // Qty
          SizedBox(
            width: 48,
            child: TextFormField(
              controller: qtyCtl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              decoration: const InputDecoration(
                hintText: 'Qty',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 6),
          // Unit dropdown
          DropdownButton<String>(
            value: units.contains(unit) ? unit : units.first,
            isDense: true,
            underline: const SizedBox(),
            items: units
                .map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 12))))
                .toList(),
            onChanged: (v) {
              if (v != null) onUnitChanged(v);
            },
          ),
          const SizedBox(width: 4),
          if (price > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                '₹${price.toStringAsFixed(price == price.truncateToDouble() ? 0 : 2)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          // Delete
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            splashRadius: 18,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Customer info section
// ---------------------------------------------------------------------------
class _CustomerSection extends StatelessWidget {
  final TextEditingController nameCtl;
  final TextEditingController phoneCtl;
  final TextEditingController locationCtl;

  const _CustomerSection({
    required this.nameCtl,
    required this.phoneCtl,
    required this.locationCtl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Customer Info',
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
        ),
        const SizedBox(height: 10),
        _field(
          controller: nameCtl,
          label: 'Customer Name',
          icon: Icons.person_outline,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Name is required' : null,
        ),
        const SizedBox(height: 10),
        _field(
          controller: phoneCtl,
          label: 'Phone Number',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Phone is required';
            if (v.trim().length < 10) return 'Enter a valid phone number';
            return null;
          },
        ),
        const SizedBox(height: 10),
        _field(
          controller: locationCtl,
          label: 'Delivery Location / Address',
          icon: Icons.location_on_outlined,
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }
}
