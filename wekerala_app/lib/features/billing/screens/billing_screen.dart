import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/print_service.dart';
import '../../../models/bill_model.dart';
import '../../../models/customer_model.dart';
import '../../../models/product_model.dart';
import '../../../models/variant_model.dart';
import '../../../models/shop_model.dart';
import '../../../providers/billing_provider.dart';
import '../../../providers/customers_provider.dart';
import '../../../providers/credits_provider.dart';
import '../../../models/credit_model.dart';
import '../../../providers/products_provider.dart';
import '../../../providers/shop_provider.dart';
import '../../../shared/widgets/shimmer_list.dart';

// Top-level helper — accessible from both _BillingScreenState and _ProductPanel
Future<VariantModel?> _showVariantPicker(
    BuildContext context, ProductModel product) {
  return showModalBottomSheet<VariantModel>(
    context: context,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              'Select ${product.nameEn} variant',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
          const Divider(height: 1),
          ...product.variants.map((v) => ListTile(
                title: Text(v.name),
                trailing: Text(
                  '₹${(v.offerPrice > 0 ? v.offerPrice : v.price).toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      fontSize: 16),
                ),
                onTap: () => Navigator.pop(ctx, v),
              )),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Main screen
// ---------------------------------------------------------------------------

class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key});

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _discountCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _searchQuery = '';
  bool _saving = false;
  double? _splitCashAmount;
  double? _splitUpiAmount;
  int _redeemedLoyaltyPoints = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
      _loadActiveFlashSale();
    });
  }

  Future<void> _loadActiveFlashSale() async {
    final shopIdAsync = ref.read(activeShopIdProvider);
    final shopId = shopIdAsync.value;
    if (shopId == null) return;
    final flashSale = await ref.read(activeFlashSaleProvider(shopId).future);
    if (flashSale == null || !mounted) return;
    final pct = (flashSale['discountPercent'] as num?)?.toDouble() ?? 0;
    final name = flashSale['name'] as String? ?? 'Flash Sale';
    final category = flashSale['applicableCategory'] as String? ?? '';
    if (pct > 0) {
      ref.read(billingProvider.notifier).applyFlashSale(pct, name, category);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _discountCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  Future<String?> _resolveShopId() async {
    final shopIdAsync = ref.read(activeShopIdProvider);
    return shopIdAsync.value;
  }

  void _onDiscountChanged(String value) {
    final amount = double.tryParse(value) ?? 0;
    final total = ref.read(billingProvider).subtotal;
    if (amount > total && total > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Discount cannot exceed the bill total.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _discountCtrl.text = total.toStringAsFixed(2);
      ref.read(billingProvider.notifier).setDiscount(total);
      return;
    }
    ref.read(billingProvider.notifier).setDiscount(amount);
  }

  // ── payment flow ──────────────────────────────────────────────────────────

  Future<void> _onPaymentTap(String method, {double? cashAmt, double? upiAmt}) async {
    if (_saving) return;
    if (method == 'split') {
      if (mounted) setState(() { _splitCashAmount = cashAmt; _splitUpiAmount = upiAmt; });
    }
    final billingState = ref.read(billingProvider);
    if (billingState.cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty. Add products first.')),
      );
      return;
    }

    final shopId = await _resolveShopId();
    if (shopId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not determine active shop.')),
        );
      }
      return;
    }

    // UPI: show QR code first so the owner can present it to the customer
    if (method == 'upi') {
      final shopAsync = ref.read(shopStreamProvider(shopId));
      final shop = shopAsync.value;
      final upiId = shop?.upiId ?? '';
      if (upiId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('UPI ID not configured. Add it in Shop Settings.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      final total = ref.read(billingProvider).total;
      if (!mounted) return;
      final qrConfirmed = await _showUpiQrDialog(
        context,
        upiId: upiId,
        shopName: shop?.shopName ?? '',
        amount: total,
      );
      if (!qrConfirmed || !mounted) return;
    }

    String customerName = '';
    String customerPhone = '';
    // Pre-fill note from KOT table reference (or any other pre-note)
    String billNote = ref.read(billingProvider).preNote;

    if (!mounted) return;
    // For udhar, name + phone are required; otherwise optional.
    final confirmed = await _showCustomerDialog(
      context,
      requireFields: method == 'udhar',
      initialNote: billNote,
      shopId: shopId,
      onSubmit: (name, phone, note, loyaltyPointsRedeemed) {
        customerName = name;
        customerPhone = phone;
        billNote = note;
        _redeemedLoyaltyPoints = loyaltyPointsRedeemed;
        // Apply loyalty redemption as additional discount
        if (loyaltyPointsRedeemed > 0) {
          final shop = ref.read(shopStreamProvider(shopId)).valueOrNull;
          final vpp = (shop?.loyaltySettings['valuePerPoint'] as num?)?.toDouble() ?? 0.5;
          final loyaltyDiscount = loyaltyPointsRedeemed * vpp;
          final existing = double.tryParse(_discountCtrl.text) ?? 0;
          final combined = existing + loyaltyDiscount;
          _discountCtrl.text = combined.toStringAsFixed(2);
          ref.read(billingProvider.notifier).setDiscount(combined);
        }
      },
    );

    if (!confirmed || !mounted) return;

    // Fetch shop name and GSTIN for receipt
    final shopAsync = ref.read(shopStreamProvider(shopId));
    final shop = shopAsync.value;
    final shopName = shop?.shopName ?? 'Our Shop';
    final gstin = shop?.gstin ?? '';
    final autoSend = shop?.autoSendWhatsappReceipt ?? false;

    setState(() => _saving = true);
    try {
      final bill = await ref.read(billingProvider.notifier).saveBill(
            shopId: shopId,
            paymentMethod: method,
            customerName: customerName,
            customerPhone: customerPhone,
            gstinSnapshot: gstin,
            cashAmount: method == 'split' ? _splitCashAmount : null,
            upiAmount: method == 'split' ? _splitUpiAmount : null,
            billNote: billNote.isNotEmpty ? billNote : null,
          );

      if (!mounted) return;

      HapticFeedback.mediumImpact();
      await showBillSavedOverlay(context);
      if (!mounted) return;

      // Show success snackbar with bill number immediately after saving.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                'Bill #${bill.billId.substring(0, 6).toUpperCase()} saved!',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
      );

      await _showReceiptSheet(
        context,
        bill: bill,
        shopName: shopName,
        shopAddress: shop?.address ?? '',
        autoSendWhatsapp: autoSend,
        shop: shop,
      );

      if (!mounted) return;
      // Deduct redeemed loyalty points from customer's balance
      if (_redeemedLoyaltyPoints > 0 && customerPhone.isNotEmpty) {
        FirebaseFirestore.instance
            .collection('shops').doc(shopId)
            .collection('customers').doc(customerPhone)
            .update({'loyaltyPoints': FieldValue.increment(-_redeemedLoyaltyPoints)})
            .ignore();
        _redeemedLoyaltyPoints = 0;
      }
      ref.read(billingProvider.notifier).clearCart();
      _discountCtrl.clear();

      // WhatsApp upsell: show once after 3rd bill if shop is on trial
      if (mounted && (shop?.subscriptionStatus == 'trial')) {
        final prefs = await SharedPreferences.getInstance();
        final count = (prefs.getInt('bill_count_$shopId') ?? 0) + 1;
        await prefs.setInt('bill_count_$shopId', count);
        final shown = prefs.getBool('upsell_shown_$shopId') ?? false;
        if (count == 3 && !shown && mounted) {
          await prefs.setBool('upsell_shown_$shopId', true);
          if (mounted) await _showWhatsAppUpsell(context);
        }
      }

      if (!mounted) return;
      context.pop();
    } catch (e, st) {
      debugPrint('saveBill error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save bill. Please try again.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── dialogs / sheets ──────────────────────────────────────────────────────

  Future<void> _showWhatsAppUpsell(BuildContext ctx) async {
    await showDialog<void>(
      context: ctx,
      builder: (dctx) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.chat_outlined, color: Color(0xFF25D366), size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Send Receipts on WhatsApp!',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You\'ve made 3 bills! 🎉\n\nUpgrade to send automatic WhatsApp receipts to every customer after every sale.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            SizedBox(height: 12),
            _UpsellItem(text: 'Auto WhatsApp receipt after every bill'),
            _UpsellItem(text: 'Win-back messages for inactive customers'),
            _UpsellItem(text: 'Online store for your shop'),
            SizedBox(height: 8),
            Text(
              'From ₹349/month — billing is always FREE.',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.primary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: const Text('Later',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(dctx);
              context.push('/subscription');
            },
            child: const Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }

  Future<bool> _showCustomerDialog(
    BuildContext context, {
    required bool requireFields,
    required void Function(String name, String phone, String note, int loyaltyPointsRedeemed) onSubmit,
    String? shopId,
    String initialNote = '',
  }) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final noteCtrl = TextEditingController(text: initialNote);
    final formKey = GlobalKey<FormState>();

    // Read existing customers for autocomplete suggestions (may be empty if
    // shopId is unknown or stream not yet loaded — degrades gracefully).
    final customers = shopId != null
        ? (ref.read(customersStreamProvider(shopId)).valueOrNull ?? <CustomerModel>[])
        : <CustomerModel>[];
    // Build phone → outstanding udhar map so we can warn before adding more credit.
    final credits = shopId != null
        ? (ref.read(allCreditsStreamProvider(shopId)).valueOrNull ?? <CreditModel>[])
        : <CreditModel>[];
    final Map<String, double> udharByPhone = {};
    for (final c in credits) {
      if (c.status != 'paid') {
        udharByPhone[c.customerPhone] =
            (udharByPhone[c.customerPhone] ?? 0) + c.outstanding;
      }
    }

    // Loyalty settings from the shop document
    final shop = shopId != null ? ref.read(shopStreamProvider(shopId)).valueOrNull : null;
    final loyaltySettings = shop?.loyaltySettings ?? {};
    final loyaltyEnabled = loyaltySettings['enabled'] == true;
    final minRedeem = (loyaltySettings['minRedeem'] as num?)?.toInt() ?? 100;
    final valuePerPoint = (loyaltySettings['valuePerPoint'] as num?)?.toDouble() ?? 0.5;

    // Dialog-local state managed by StatefulBuilder
    int dialogLoyaltyPoints = 0;
    bool redeemLoyalty = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlgState) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text(
          requireFields ? 'Udhar Customer Details' : 'Customer (Optional)',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (requireFields)
                const Text(
                  'Name and phone are required for Udhar.',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
              const SizedBox(height: 12),
              // ── Customer name with autocomplete ─────────────────────────
              Autocomplete<CustomerModel>(
                optionsBuilder: (textEditingValue) {
                  if (textEditingValue.text.isEmpty) return const [];
                  return customers.where((c) => c.name
                      .toLowerCase()
                      .contains(textEditingValue.text.toLowerCase()));
                },
                displayStringForOption: (c) => c.name,
                fieldViewBuilder: (context, autoCtrl, focusNode, onFieldSubmitted) {
                  // Keep the external nameCtrl in sync so onSubmit captures it.
                  autoCtrl.addListener(() {
                    nameCtrl.text = autoCtrl.text;
                  });
                  return TextFormField(
                    controller: autoCtrl,
                    focusNode: focusNode,
                    decoration: _inputDecoration('Customer Name'),
                    textCapitalization: TextCapitalization.words,
                    validator: requireFields
                        ? (v) => (v == null || v.trim().isEmpty)
                            ? 'Name is required'
                            : null
                        : null,
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(10),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final customer = options.elementAt(index);
                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor: AppColors.primary
                                    .withValues(alpha: 0.1),
                                child: Text(
                                  customer.name
                                      .substring(0, 1)
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              title: Text(customer.name,
                                  style: const TextStyle(fontSize: 14)),
                              subtitle: Text(customer.phone,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                              trailing: Text(
                                '₹${customer.totalSpent.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12),
                              ),
                              onTap: () {
                                onSelected(customer);
                                phoneCtrl.text = customer.phone;
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
                onSelected: (customer) {
                  nameCtrl.text = customer.name;
                  phoneCtrl.text = customer.phone;
                  setDlgState(() {
                    dialogLoyaltyPoints = customer.loyaltyPoints;
                    redeemLoyalty = false;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneCtrl,
                decoration: _inputDecoration('Phone Number'),
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 10,
                validator: requireFields
                    ? (v) => (v == null || v.trim().length < 10)
                        ? 'Valid 10-digit phone required'
                        : null
                    : null,
                onChanged: (val) {
                  // Sync loyalty points when phone matches a known customer
                  final match = customers.firstWhere(
                    (c) => c.phone == val,
                    orElse: () => CustomerModel(
                      customerId: '', name: '', phone: val,
                      totalOrders: 0, totalSpent: 0,
                      lastOrderDate: DateTime.now(),
                      firstOrderDate: DateTime.now(),
                    ),
                  );
                  setDlgState(() {
                    dialogLoyaltyPoints = match.loyaltyPoints;
                    redeemLoyalty = false;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: noteCtrl,
                decoration: _inputDecoration(
                    'Note / Prescription No. (optional)'),
              ),
              // Loyalty redemption toggle (shown when loyalty is enabled and customer has enough points)
              if (loyaltyEnabled && dialogLoyaltyPoints >= minRedeem) ...[
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: redeemLoyalty,
                  onChanged: (v) => setDlgState(() => redeemLoyalty = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Redeem $dialogLoyaltyPoints pts  →  ₹${(dialogLoyaltyPoints * valuePerPoint).toStringAsFixed(0)} off',
                    style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (formKey.currentState?.validate() ?? true) {
                final redeemedPoints = (loyaltyEnabled && redeemLoyalty) ? dialogLoyaltyPoints : 0;
                onSubmit(nameCtrl.text.trim(), phoneCtrl.text.trim(), noteCtrl.text.trim(), redeemedPoints);
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      )),
    );

    return result ?? false;
  }

  Future<void> _showReceiptSheet(
    BuildContext context, {
    required BillModel bill,
    required String shopName,
    String shopAddress = '',
    bool autoSendWhatsapp = false,
    ShopModel? shop,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReceiptSheet(
        bill: bill,
        shopName: shopName,
        shopAddress: shopAddress,
        autoSendWhatsapp: autoSendWhatsapp,
        shop: shop,
      ),
    );
  }

  Future<bool> _showUpiQrDialog(
    BuildContext context, {
    required String upiId,
    required String shopName,
    required double amount,
  }) async {
    // UPI deep link format
    final upiString =
        'upi://pay?pa=${Uri.encodeComponent(upiId)}&pn=${Uri.encodeComponent(shopName)}&am=${amount.toStringAsFixed(2)}&tn=Payment&cu=INR';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        title: const Row(
          children: [
            Icon(Icons.qr_code_2, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Scan to Pay', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: QrImageView(
                data: upiString,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.currency_rupee,
                      color: AppColors.primary, size: 20),
                  Text(
                    amount.toStringAsFixed(2),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'UPI: $upiId',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 4),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Payment Received ✓'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final billingState = ref.watch(billingProvider);
    final shopIdAsync = ref.watch(activeShopIdProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 700;

    // Auto-apply active flash sale discount
    final shopId = shopIdAsync.valueOrNull;
    if (shopId != null) {
      ref.listen(activeFlashSaleProvider(shopId), (prev, next) {
        final sale = next.valueOrNull;
        final notifier = ref.read(billingProvider.notifier);
        if (sale != null) {
          final pct = (sale['discountPercent'] as num?)?.toDouble() ?? 0;
          final name = (sale['name'] as String?) ?? 'Flash Sale';
          final category = (sale['applicableCategory'] as String?) ?? '';
          notifier.setFlashSale(pct, name, category: category);
        } else {
          notifier.clearFlashSale();
        }
      });
    }

    final shopType = shopId != null
        ? (ref.watch(shopStreamProvider(shopId)).valueOrNull?.shopType ?? '')
        : '';

    final cartPanel = _CartPanel(
      discountCtrl: _discountCtrl,
      onDiscountChanged: _onDiscountChanged,
      onUdhar: () => _onPaymentTap('udhar'),
      shopType: shopType,
    );

    final productPanel = shopIdAsync.when(
      data: (shopId) => shopId == null
          ? const Center(child: Text('No active shop found.'))
          : _ProductPanel(
              shopId: shopId,
              searchCtrl: _searchCtrl,
              searchFocus: _searchFocus,
              searchQuery: _searchQuery,
              onSearchChanged: (q) => setState(() => _searchQuery = q),
              crossAxisCount: isDesktop ? 3 : 2,
            ),
      loading: () => const ShimmerList(itemCount: 6),
      error: (e, _) => Center(child: Text('Error: $e')),
    );

    final paymentBar = _PaymentBar(onTap: _onPaymentTap);

    // Flash sale banner (shown when a sale is active)
    final flashBanner = billingState.flashSalePercent > 0
        ? Container(
            width: double.infinity,
            color: const Color(0xFFFC8019),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.local_fire_department,
                    color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  '🔥 ${billingState.flashSaleName}: ${billingState.flashSalePercent.toInt()}% OFF${billingState.flashSaleCategory.isNotEmpty ? " on ${billingState.flashSaleCategory}" : ""} applied!',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                ),
              ],
            ),
          )
        : const SizedBox.shrink();

    final Widget body;
    if (isDesktop) {
      // Desktop: products on left, cart + payment on right
      body = Row(
        children: [
          Expanded(flex: 55, child: productPanel),
          const VerticalDivider(
              width: 1, thickness: 1, color: Color(0xFFE5EBE8)),
          Expanded(
            flex: 45,
            child: Column(
              children: [
                Expanded(child: cartPanel),
                paymentBar,
              ],
            ),
          ),
        ],
      );
    } else {
      // Mobile: cart on top, products below, payment bar at bottom
      body = Column(
        children: [
          flashBanner,
          Flexible(flex: 40, child: cartPanel),
          const Divider(height: 1, thickness: 1, color: AppColors.surface),
          Flexible(flex: 60, child: productPanel),
          paymentBar,
        ],
      );
    }

    // Keyboard shortcuts for desktop/Windows POS
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f2): () =>
            _searchFocus.requestFocus(),
        const SingleActivator(LogicalKeyboardKey.f10): () async {
          final items = ref.read(billingProvider).cartItems;
          if (items.isNotEmpty && !_saving) await _onPaymentTap('cash');
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          _searchFocus.unfocus();
          _searchCtrl.clear();
          setState(() => _searchQuery = '');
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Quick Billing'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Bill History',
            onPressed: () => context.push('/bill-history'),
          ),
          IconButton(
            icon: const Icon(Icons.calculate_outlined),
            tooltip: 'Cash Counter',
            onPressed: () => context.push('/cash-counter'),
          ),
          if (billingState.cartItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear cart',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppColors.background,
                    title: const Text(
                      'Clear Cart?',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold),
                    ),
                    content: const Text(
                      'All items will be removed from the cart.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel',
                            style:
                                TextStyle(color: AppColors.textSecondary)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  ref.read(billingProvider.notifier).clearCart();
                  _discountCtrl.clear();
                }
              },
            ),
        ],
      ),
      body: body,
    )));
  }
}

// ---------------------------------------------------------------------------
// Cart panel
// ---------------------------------------------------------------------------

class _CartPanel extends ConsumerWidget {
  final TextEditingController discountCtrl;
  final ValueChanged<String> onDiscountChanged;
  final VoidCallback onUdhar;
  final String shopType;

  const _CartPanel({
    required this.discountCtrl,
    required this.onDiscountChanged,
    required this.onUdhar,
    this.shopType = '',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(billingProvider);
    final notifier = ref.read(billingProvider.notifier);

    return Column(
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Row(
            children: [
              Text(
                'CART',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppColors.textSecondary,
                ),
              ),
              if (state.cartItems.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${state.cartItems.length}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Cart list
        Expanded(
          child: state.cartItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shopping_cart_outlined,
                          size: 36, color: AppColors.textSecondary),
                      const SizedBox(height: 8),
                      const Text(
                        'Tap products below to add',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  itemCount: state.cartItems.length,
                  itemBuilder: (context, index) {
                    final item = state.cartItems[index];
                    return _CartItemRow(
                      item: item,
                      shopType: shopType,
                      onIncrement: () => notifier.updateQty(
                          item.productId, item.qty + item.qtyStep),
                      onDecrement: () => notifier.decrementItem(item.productId),
                      onDelete: () => notifier.removeItem(item.productId),
                      onSetQty: (qty) => notifier.updateQty(item.productId, qty),
                      onSetModifiers: (mods) =>
                          notifier.setItemModifiers(item.productId, mods),
                    ).animate().fadeIn(duration: 200.ms);
                  },
                ),
        ),

        // Discount row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              const Text('Discount:  ₹',
                  style: TextStyle(color: AppColors.textSecondary)),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: discountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  onChanged: onDiscountChanged,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    border: OutlineInputBorder(),
                    hintText: '0',
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),

        // GST breakdown section
        if (state.gstBreakdown.isNotEmpty) ...[
          const Divider(height: 1, thickness: 1, color: AppColors.surface),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...state.gstBreakdown.entries.map((e) {
                  final rate = e.key;
                  final data = e.value;
                  return Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Taxable @$rate%',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary),
                          ),
                          Text(
                            '₹${data['taxableAmount']!.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '  CGST ${rate / 2}%',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary),
                          ),
                          Text(
                            '₹${data['cgst']!.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '  SGST ${rate / 2}%',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary),
                          ),
                          Text(
                            '₹${data['sgst']!.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  );
                }),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Tax',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '₹${state.totalTax.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

        // Total + Udhar row
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(
              top: BorderSide(color: Color(0xFFE5EBE8), width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '₹${state.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              // Udhar quick-action button — desktop only (mobile has payment bar)
              if (MediaQuery.of(context).size.width >= 700) ...[
                const SizedBox(height: 8),
                _UdharButton(enabled: state.cartItems.isNotEmpty, onTap: onUdhar),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Cart item row
// ---------------------------------------------------------------------------

/// Preset modifier chips by shop type — shown in the modifier bottom sheet.
const _kModifierPresets = <String, List<String>>{
  'Hotel / Restaurant': [
    'Extra spicy', 'Less spicy', 'No spice',
    'Extra gravy', 'No onion', 'No garlic',
    'Half portion', 'Extra portion',
  ],
  'Bakery': [
    'Less sweet', 'Extra sweet', 'No sugar',
    'Eggless', 'Extra cream', 'No cream',
    'Warm', 'Well done',
  ],
  'Café': [
    'Extra shot', 'Less sugar', 'No sugar',
    'Oat milk', 'Cold', 'No ice',
    'Extra hot',
  ],
};

class _CartItemRow extends StatelessWidget {
  final BillItemModel item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onDelete;
  final ValueChanged<double>? onSetQty;
  final ValueChanged<List<String>>? onSetModifiers;
  final String shopType;

  const _CartItemRow({
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    required this.onDelete,
    this.onSetQty,
    this.onSetModifiers,
    this.shopType = '',
  });

  String get _qtyLabel {
    if (item.qty % 1 == 0) return item.qty.toInt().toString();
    return item.qty.toStringAsFixed(item.isWeightBased ? 2 : 1);
  }

  String get _priceLabel {
    final suffix = item.isWeightBased ? '/ ${item.unit}' : '/ unit';
    return '₹${item.price.toStringAsFixed(2)} $suffix';
  }

  Future<void> _showQtyDialog(BuildContext ctx) async {
    final ctrl = TextEditingController(text: _qtyLabel);
    final val = await showDialog<double>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text(item.productName, style: const TextStyle(fontSize: 14)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}'))
          ],
          decoration: InputDecoration(
            suffixText: item.unit,
            hintText: 'Enter quantity',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, double.tryParse(ctrl.text.trim())),
            child: const Text('Set'),
          ),
        ],
      ),
    );
    if (val != null && val > 0 && onSetQty != null) onSetQty!(val);
  }

  Future<void> _showModifierSheet(BuildContext ctx) async {
    final presets = _kModifierPresets[shopType] ?? [];
    final current = List<String>.from(item.modifiers);
    final customCtrl = TextEditingController();

    await showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (_, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 16,
            top: 20,
            left: 16,
            right: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add-ons for ${item.productName}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 12),
              if (presets.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: presets.map((p) {
                    final selected = current.contains(p);
                    return FilterChip(
                      label: Text(p, style: const TextStyle(fontSize: 12)),
                      selected: selected,
                      onSelected: (v) => setSheetState(() {
                        if (v) {
                          current.add(p);
                        } else {
                          current.remove(p);
                        }
                      }),
                      selectedColor: AppColors.primary.withValues(alpha: 0.15),
                      checkmarkColor: AppColors.primary,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                const Divider(),
              ],
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: customCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Custom instruction…',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      final v = customCtrl.text.trim();
                      if (v.isNotEmpty) {
                        setSheetState(() {
                          current.add(v);
                          customCtrl.clear();
                        });
                      }
                    },
                    child: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (current.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  children: current.map((m) => Chip(
                    label: Text(m, style: const TextStyle(fontSize: 11)),
                    onDeleted: () => setSheetState(() => current.remove(m)),
                    deleteIconColor: AppColors.error,
                    padding: EdgeInsets.zero,
                  )).toList(),
                ),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(sheetCtx);
                    if (onSetModifiers != null) onSetModifiers!(List.from(current));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasModifiers = item.modifiers.isNotEmpty;
    final hasBatch = item.batchNumber != null && item.batchNumber!.isNotEmpty;
    final hasNote = item.itemNote != null && item.itemNote!.isNotEmpty;
    final showModifierBtn = _kModifierPresets.containsKey(shopType) || onSetModifiers != null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE5EBE8), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // Product name + unit price
                Expanded(
                  child: GestureDetector(
                    onLongPress: showModifierBtn
                        ? () => _showModifierSheet(context)
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                item.productName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (showModifierBtn) ...[
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => _showModifierSheet(context),
                                child: Icon(
                                  Icons.tune_rounded,
                                  size: 14,
                                  color: hasModifiers
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          _priceLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        // Batch number badge for pharmacy
                        if (hasBatch)
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Batch: ${item.batchNumber}',
                              style: const TextStyle(
                                  fontSize: 9, color: Color(0xFF0369A1)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Qty stepper — tap qty to type, +/- by qtyStep
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _QtyButton(icon: Icons.remove, onTap: onDecrement),
                    GestureDetector(
                      onTap: onSetQty == null
                          ? null
                          : () => _showQtyDialog(context),
                      child: SizedBox(
                        width: 42,
                        child: Center(
                          child: Text(
                            item.isWeightBased
                                ? '${_qtyLabel} ${item.unit}'
                                : _qtyLabel,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                    _QtyButton(icon: Icons.add, onTap: onIncrement),
                  ],
                ),
                const SizedBox(width: 8),
                // Subtotal
                SizedBox(
                  width: 60,
                  child: Text(
                    '₹${item.subtotal.toStringAsFixed(2)}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                // Delete
                GestureDetector(
                  onTap: onDelete,
                  child: const SizedBox(
                    width: 32,
                    height: 40,
                    child: Icon(Icons.close, size: 16, color: AppColors.error),
                  ),
                ),
              ],
            ),
            // Modifier chips row
            if (hasModifiers)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: item.modifiers.map((m) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          width: 0.5),
                    ),
                    child: Text(
                      m,
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.primary),
                    ),
                  )).toList(),
                ),
              ),
            // Item note
            if (hasNote)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '📝 ${item.itemNote}',
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textSecondary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 40×40 quantity stepper button — meets minimum touch-target spec.
class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Product panel
// ---------------------------------------------------------------------------

class _ProductPanel extends ConsumerStatefulWidget {
  final String shopId;
  final TextEditingController searchCtrl;
  final FocusNode searchFocus;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final int crossAxisCount;

  const _ProductPanel({
    required this.shopId,
    required this.searchCtrl,
    required this.searchFocus,
    required this.searchQuery,
    required this.onSearchChanged,
    this.crossAxisCount = 2,
  });

  @override
  ConsumerState<_ProductPanel> createState() => _ProductPanelState();
}

class _ProductPanelState extends ConsumerState<_ProductPanel> {
  String _selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    final shopId = widget.shopId;
    final searchQuery = widget.searchQuery;
    final productsAsync = ref.watch(productsStreamProvider(shopId));
    final shopAsync = ref.watch(shopStreamProvider(shopId));
    final categories = ['All', ...?shopAsync.value?.categories];
    final cartItems = ref.watch(billingProvider).cartItems;
    final inCartIds = {for (final i in cartItems) i.productId};

    return Column(
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'PRODUCTS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),

        // Search box
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          child: TextField(
            controller: widget.searchCtrl,
            focusNode: widget.searchFocus,
            onChanged: widget.onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search products...',
              prefixIcon:
                  const Icon(Icons.search, color: AppColors.textSecondary),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (searchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear,
                          color: AppColors.textSecondary),
                      onPressed: () {
                        widget.searchCtrl.clear();
                        widget.onSearchChanged('');
                      },
                    ),
                  if (!kIsWeb && Platform.isAndroid)
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner,
                          color: AppColors.textSecondary),
                      tooltip: 'Scan barcode',
                      onPressed: () async {
                        final barcode = await Navigator.push<String>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const _BillingBarcodeScanner(),
                          ),
                        );
                        if (barcode != null && barcode.isNotEmpty) {
                          // Use helper: in-memory first, then Firestore fallback
                          final product = await _lookupByBarcode(shopId, barcode, ref);
                          if (!context.mounted) return;
                          if (product != null && !product.isOutOfStock) {
                            ref
                                .read(billingProvider.notifier)
                                .addItem(product);
                          } else if (product != null && product.isOutOfStock) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    '${product.nameEn} is out of stock.'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Barcode $barcode not in catalog — add the product first'),
                                action: SnackBarAction(
                                  label: 'Add Product',
                                  onPressed: () => context.push('/products/add'),
                                ),
                                duration: const Duration(seconds: 6),
                              ),
                            );
                          }
                        }
                      },
                    )
                  else if (!kIsWeb && Platform.isWindows)
                    // Desktop fallback: USB barcode scanners act as keyboards
                    // and submit with Enter — this field captures that input.
                    _DesktopBarcodeField(
                      shopId: shopId,
                      onProductFound: (product) =>
                          ref.read(billingProvider.notifier).addItem(product),
                      onNotFound: (barcode) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            action: SnackBarAction(
                              label: 'Add Product',
                              onPressed: () => context.push('/products/add'),
                            ),
                            duration: const Duration(seconds: 6),
                            content: Text(
                                'No product found for barcode: $barcode'),
                          ),
                        );
                      },
                    ),
                ],
              ),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ),

        // Category filter chips
        if (categories.length > 2)
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final cat = categories[i];
                final sel = cat == _selectedCategory;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel
                          ? AppColors.primary
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: sel
                            ? AppColors.primary
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Text(cat,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: sel
                              ? FontWeight.w700
                              : FontWeight.normal,
                          color: sel
                              ? Colors.white
                              : AppColors.textSecondary,
                        )),
                  ),
                );
              },
            ),
          ),
        if (categories.length > 2) const SizedBox(height: 6),

        // Product list
        Expanded(
          child: productsAsync.when(
            data: (products) {
              final sq = searchQuery.toLowerCase();
              final visible = products
                  .where((p) =>
                      !p.isHidden &&
                      !p.isOutOfStock &&
                      (_selectedCategory == 'All' || p.category == _selectedCategory) &&
                      (searchQuery.isEmpty ||
                          p.nameEn.toLowerCase().contains(sq) ||
                          p.nameMl.toLowerCase().contains(sq) ||
                          (p.searchAlias != null &&
                              p.searchAlias!.toLowerCase().contains(sq)) ||
                          (p.barcode != null && p.barcode!.contains(searchQuery))))
                  .toList()
                // Sort by orderCount desc so most-billed products appear first
                ..sort((a, b) => b.orderCount.compareTo(a.orderCount));

              if (visible.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.inventory_2_outlined,
                          size: 48, color: AppColors.textSecondary),
                      const SizedBox(height: 12),
                      Text(
                        products.isEmpty
                            ? 'No products in catalog yet'
                            : 'No products found.',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      if (products.isEmpty) ...[
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => context.push('/products/add'),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add First Product'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white),
                        ),
                      ],
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: visible.length,
                itemBuilder: (context, index) {
                  final product = visible[index];
                  final inCart = inCartIds.contains(product.productId);
                  return _ProductButton(
                    product: product,
                    inCart: inCart,
                    onTap: () async {
                      if (product.hasVariants && product.variants.isNotEmpty) {
                        final variant = await _showVariantPicker(context, product);
                        if (variant != null && context.mounted) {
                          ref.read(billingProvider.notifier)
                              .addItem(product, variant: variant);
                        }
                      } else {
                        ref.read(billingProvider.notifier).addItem(product);
                      }
                    },
                  );
                },
              );
            },
            loading: () => const ShimmerList(itemCount: 8, itemHeight: 60),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Product button
// ---------------------------------------------------------------------------

class _ProductButton extends StatelessWidget {
  final ProductModel product;
  final bool inCart;
  final VoidCallback onTap;

  const _ProductButton({
    required this.product,
    required this.inCart,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectivePrice =
        product.offerPrice > 0 ? product.offerPrice : product.price;
    final hasOffer = product.offerPrice > 0 && product.offerPrice < product.price;

    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: inCart ? AppColors.success.withValues(alpha: 0.06) : Colors.white,
          border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Thumbnail
            _BillingProductThumb(url: product.imageUrl, inCart: inCart),
            const SizedBox(width: 12),
            // Name + category
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.nameEn,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: inCart ? AppColors.success : AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (product.category.isNotEmpty)
                    Text(
                      product.category,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
            // Price
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '₹${effectivePrice.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: inCart ? AppColors.success : AppColors.primary,
                  ),
                ),
                if (hasOffer)
                  Text(
                    '₹${product.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                      decoration: TextDecoration.lineThrough,
                    ),
                  )
                else
                  Text(
                    '/ ${product.unit}',
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textSecondary),
                  ),
              ],
            ),
            const SizedBox(width: 8),
            // Add / check icon
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: inCart
                    ? AppColors.success.withValues(alpha: 0.12)
                    : AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                inCart ? Icons.check_rounded : Icons.add_rounded,
                color: inCart ? AppColors.success : AppColors.primary,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Billing product thumbnail
// ---------------------------------------------------------------------------

class _BillingProductThumb extends StatelessWidget {
  final String url;
  final bool inCart;
  const _BillingProductThumb({required this.url, required this.inCart});

  @override
  Widget build(BuildContext context) {
    final border = Border.all(
      color: inCart
          ? AppColors.success.withValues(alpha: 0.5)
          : Colors.grey.shade200,
    );
    if (url.isEmpty) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: border,
        ),
        child: const Icon(Icons.image_outlined,
            size: 20, color: AppColors.textSecondary),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: CachedNetworkImage(
        imageUrl: url,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        placeholder: (_, __) =>
            Container(width: 44, height: 44, color: AppColors.surface),
        errorWidget: (_, __, ___) => Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(6),
            border: border,
          ),
          child: const Icon(Icons.broken_image_outlined,
              size: 20, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Udhar button
// ---------------------------------------------------------------------------

class _UdharButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;
  const _UdharButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: enabled ? onTap : null,
        icon: const Icon(Icons.account_balance_wallet_outlined, size: 16),
        label: const Text('Save as Udhar (Credit)'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent,
          side: BorderSide(
            color: enabled
                ? AppColors.accent.withValues(alpha: 0.6)
                : Colors.grey.shade300,
          ),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Payment bar
// ---------------------------------------------------------------------------

class _PaymentBar extends ConsumerStatefulWidget {
  final void Function(String method, {double? cashAmt, double? upiAmt}) onTap;

  const _PaymentBar({required this.onTap});

  @override
  ConsumerState<_PaymentBar> createState() => _PaymentBarState();
}

class _PaymentBarState extends ConsumerState<_PaymentBar> {
  String? _selectedMethod;
  bool _splitMode = false;
  final _cashSplitCtrl = TextEditingController();
  final _upiSplitCtrl = TextEditingController();
  final _tenderedCtrl = TextEditingController(); // cash change calculator

  @override
  void dispose() {
    _cashSplitCtrl.dispose();
    _upiSplitCtrl.dispose();
    _tenderedCtrl.dispose();
    super.dispose();
  }

  void _onSplitConfirm(double total) {
    final cash = double.tryParse(_cashSplitCtrl.text) ?? 0;
    final upi = double.tryParse(_upiSplitCtrl.text) ?? 0;
    if ((cash + upi - total).abs() > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Cash (₹${cash.toStringAsFixed(0)}) + UPI (₹${upi.toStringAsFixed(0)}) must equal ₹${total.toStringAsFixed(0)}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() { _splitMode = false; _selectedMethod = 'split'; });
    widget.onTap('split', cashAmt: cash, upiAmt: upi);
  }

  @override
  Widget build(BuildContext context) {
    final shopIdAsync = ref.watch(activeShopIdProvider);
    final billingState = ref.watch(billingProvider);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: Color(0xFFE5EBE8), width: 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Section header
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'PAYMENT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _PayButton(
                  label: 'Cash',
                  icon: Icons.payments_outlined,
                  color: AppColors.success,
                  onTap: () {
                    setState(() => _selectedMethod = 'cash');
                    widget.onTap('cash');
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PayButton(
                  label: 'UPI',
                  icon: Icons.qr_code_scanner_outlined,
                  color: const Color(0xFF1565C0),
                  onTap: () {
                    setState(() => _selectedMethod = 'upi');
                    widget.onTap('upi');
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PayButton(
                  label: 'Udhar',
                  icon: Icons.account_balance_wallet_outlined,
                  color: AppColors.accent,
                  onTap: () {
                    setState(() { _selectedMethod = 'udhar'; _splitMode = false; });
                    widget.onTap('udhar');
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PayButton(
                  label: 'Split',
                  icon: Icons.call_split_outlined,
                  color: Colors.purple,
                  isSelected: _splitMode,
                  onTap: () => setState(() { _splitMode = !_splitMode; _selectedMethod = null; }),
                ),
              ),
            ],
          ),
          // Split payment fields
          if (_splitMode) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cashSplitCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Cash ₹',
                      isDense: true,
                      border: const OutlineInputBorder(),
                      prefixIcon: Icon(Icons.payments_outlined, color: AppColors.success, size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _upiSplitCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'UPI ₹',
                      isDense: true,
                      border: const OutlineInputBorder(),
                      prefixIcon: Icon(Icons.qr_code_scanner_outlined, color: Color(0xFF1565C0), size: 18),
                    ),
                    onSubmitted: (_) => _onSplitConfirm(billingState.total),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _onSplitConfirm(billingState.total),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('OK', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
          // Cash change calculator — shows when Cash is selected
          if (_selectedMethod == 'cash') ...[
            const SizedBox(height: 10),
            StatefulBuilder(
              builder: (ctx, setS) {
                final tendered = double.tryParse(_tenderedCtrl.text) ?? 0;
                final change = tendered - billingState.total;
                return Column(
                  children: [
                    TextField(
                      controller: _tenderedCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setS(() {}),
                      decoration: InputDecoration(
                        labelText: 'Customer gave',
                        isDense: true,
                        prefixText: '₹ ',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.payments_outlined,
                            color: AppColors.success, size: 18),
                      ),
                    ),
                    if (tendered > 0 && change >= 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(children: [
                          const Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
                          const SizedBox(width: 8),
                          Text('Change: ${change.toStringAsFixed(0)}',
                              style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w800, fontSize: 18)),
                        ]),
                      ),
                    ],
                    if (tendered > 0 && change < 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Short by ${(-change).toStringAsFixed(0)}',
                            style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w700, fontSize: 16)),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
          // Show UPI QR card when UPI is selected
          if (_selectedMethod == 'upi')
            shopIdAsync.when(
              data: (shopId) {
                if (shopId == null) return const SizedBox.shrink();
                final shopAsync = ref.watch(shopStreamProvider(shopId));
                return shopAsync.when(
                  data: (shop) {
                    if (shop.upiId.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _UpiQrCard(
                        upiId: shop.upiId,
                        shopName: shop.shopName,
                        amount: billingState.total,
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}

class _PayButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isSelected;

  const _PayButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  State<_PayButton> createState() => _PayButtonState();
}

class _PayButtonState extends State<_PayButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        setState(() => _scale = 0.95);
      },
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: widget.isSelected ? Colors.white : widget.color,
            borderRadius: BorderRadius.circular(26),
            border: widget.isSelected
                ? Border.all(color: widget.color, width: 2)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon,
                  color: widget.isSelected ? widget.color : Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.isSelected ? widget.color : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Receipt bottom sheet
// ---------------------------------------------------------------------------

class _ReceiptSheet extends StatefulWidget {
  final BillModel bill;
  final String shopName;
  final String shopAddress;
  final bool autoSendWhatsapp;
  final ShopModel? shop;

  const _ReceiptSheet({
    required this.bill,
    required this.shopName,
    this.shopAddress = '',
    this.autoSendWhatsapp = false,
    this.shop,
  });

  @override
  State<_ReceiptSheet> createState() => _ReceiptSheetState();
}

class _ReceiptSheetState extends State<_ReceiptSheet> {
  bool _printing = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoSendWhatsapp) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _openWhatsApp();
      });
    }
  }

  /// Opens WhatsApp directly with the bill receipt pre-filled.
  /// Shows a warning if the customer has no phone number.
  Future<void> _openWhatsApp() async {
    final phone = widget.bill.customerPhone.replaceAll(RegExp(r'\D'), '');
    final text = _buildReceiptText();
    if (phone.length >= 10) {
      final e164 = phone.startsWith('91') && phone.length == 12
          ? phone
          : '91${phone.substring(phone.length - 10)}';
      final uri = Uri.parse(
        'https://wa.me/$e164?text=${Uri.encodeComponent(text)}',
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    // No customer phone — show warning and fall back to share sheet
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'No customer phone number — sharing via general share sheet instead.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
    }
    Share.share(text);
  }

  String _buildReceiptText() {
    final bill = widget.bill;
    final shopName = widget.shopName;
    final shopAddress = widget.shopAddress;
    final buf = StringBuffer();
    buf.writeln('*$shopName*');
    if (shopAddress.isNotEmpty) buf.writeln(shopAddress);
    if (bill.gstinSnapshot != null && bill.gstinSnapshot!.isNotEmpty) {
      buf.writeln('GSTIN: ${bill.gstinSnapshot}');
    }
    buf.writeln('──────────────────');
    final dateStr =
        '${bill.createdAt.day.toString().padLeft(2, '0')}/${bill.createdAt.month.toString().padLeft(2, '0')}/${bill.createdAt.year}';
    buf.writeln(
        'Bill No: ${bill.billId.substring(0, 6).toUpperCase()}  $dateStr');
    buf.writeln('──────────────────');
    for (final item in bill.items) {
      final qtyStr = item.qty % 1 == 0
          ? item.qty.toInt().toString()
          : item.qty.toStringAsFixed(1);
      final hsnPart =
          (item.hsnCode != null && item.hsnCode!.isNotEmpty)
              ? '  HSN:${item.hsnCode}'
              : '';
      buf.writeln(
          '${item.productName}$hsnPart  ${qtyStr}x₹${item.price.toStringAsFixed(2)}  ₹${item.subtotal.toStringAsFixed(2)}');
    }
    buf.writeln('──────────────────');
    buf.writeln(
        'Subtotal: ₹${bill.totalAmount.toStringAsFixed(2)}');
    if (bill.discountAmount > 0) {
      buf.writeln(
          'Discount: -₹${bill.discountAmount.toStringAsFixed(2)}');
    }
    if (bill.totalTax > 0) {
      for (final e in bill.gstBreakdown.entries) {
        final rate = int.tryParse(e.key) ?? 0;
        final data = e.value;
        buf.writeln(
            '  CGST ${rate / 2}%: ₹${data['cgst']!.toStringAsFixed(2)}');
        buf.writeln(
            '  SGST ${rate / 2}%: ₹${data['sgst']!.toStringAsFixed(2)}');
      }
      buf.writeln(
          'Total Tax: ₹${bill.totalTax.toStringAsFixed(2)}');
    }
    buf.writeln('──────────────────');
    buf.writeln(
        'TOTAL: ₹${bill.finalAmount.toStringAsFixed(2)}');
    buf.writeln(
        'Payment: ${_paymentLabel(bill.paymentMethod)}');
    if (bill.customerName.isNotEmpty) {
      buf.writeln('Customer: ${bill.customerName}');
    }
    buf.writeln('──────────────────');
    buf.writeln('നന്ദി! വീണ്ടും വരൂ 🙏');
    return buf.toString().trim();
  }

  String _paymentLabel(String method) {
    switch (method) {
      case 'upi':
        return 'UPI';
      case 'udhar':
        return 'Udhar (Credit)';
      case 'split':
        return 'Split (Cash + UPI)';
      default:
        return 'Cash';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bill = widget.bill;
    final receiptText = _buildReceiptText();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Row(
            children: [
              const Icon(Icons.receipt_long_outlined,
                  color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bill Receipt',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    if (bill.gstinSnapshot != null &&
                        bill.gstinSnapshot!.isNotEmpty)
                      Text(
                        'GSTIN: ${bill.gstinSnapshot}',
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11),
                      ),
                  ],
                ),
              ),
              Text(
                '#${bill.billId.substring(0, 6).toUpperCase()}',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(color: AppColors.surface, thickness: 1.5),

          // Items
          ...bill.items.map((item) {
            final qtyStr = item.qty % 1 == 0
                ? item.qty.toInt().toString()
                : item.qty.toStringAsFixed(1);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.productName}  x$qtyStr',
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary),
                    ),
                  ),
                  Text(
                    '₹${item.subtotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          }),

          const Divider(color: AppColors.surface, thickness: 1.5),

          // Discount
          if (bill.discountAmount > 0) ...[
            _SummaryRow(
              label: 'Discount',
              value: '-₹${bill.discountAmount.toStringAsFixed(2)}',
              valueColor: AppColors.success,
            ),
            const SizedBox(height: 4),
          ],

          // GST breakdown
          if (bill.totalTax > 0) ...[
            ...bill.gstBreakdown.entries.expand((e) {
              final rate = int.tryParse(e.key) ?? 0;
              final data = e.value;
              return [
                _SummaryRow(
                  label: 'CGST ${rate / 2}%',
                  value: '₹${data['cgst']!.toStringAsFixed(2)}',
                ),
                const SizedBox(height: 2),
                _SummaryRow(
                  label: 'SGST ${rate / 2}%',
                  value: '₹${data['sgst']!.toStringAsFixed(2)}',
                ),
                const SizedBox(height: 2),
              ];
            }),
            _SummaryRow(
              label: 'Total Tax',
              value: '₹${bill.totalTax.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 4),
          ],

          // Total
          _SummaryRow(
            label: 'Total',
            value: '₹${bill.finalAmount.toStringAsFixed(2)}',
            bold: true,
          ),
          const SizedBox(height: 4),

          // Payment method
          _SummaryRow(
            label: 'Payment',
            value: _paymentLabel(bill.paymentMethod),
          ),

          // Customer
          if (bill.customerName.isNotEmpty) ...[
            const SizedBox(height: 4),
            _SummaryRow(
              label: 'Customer',
              value: bill.customerName +
                  (bill.customerPhone.isNotEmpty
                      ? '  ${bill.customerPhone}'
                      : ''),
            ),
          ],

          const SizedBox(height: 20),

          // Share button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366), // WhatsApp green
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.share_outlined),
              label: const Text(
                'Share on WhatsApp',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
              onPressed: () async => _openWhatsApp(),
            ),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2),

          const SizedBox(height: 10),

          // Print button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: _printing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary),
                    )
                  : const Icon(Icons.print_outlined, color: AppColors.primary),
              label: Text(
                _printing ? 'Printing...' : 'Print Receipt',
                style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
              onPressed: _printing
                  ? null
                  : () async {
                      if (widget.shop == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Shop data unavailable. Please try again.'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }
                      setState(() => _printing = true);
                      try {
                        await PrintService.printBill(bill, widget.shop!);
                        if (mounted) {
                          // ignore: use_build_context_synchronously
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Printed successfully'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          // ignore: use_build_context_synchronously
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Print failed: $e'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _printing = false);
                      }
                    },
            ),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2),

          const SizedBox(height: 10),

          // Close button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Close',
                style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    ).animate().slideY(begin: 0.3, duration: 350.ms, curve: Curves.easeOut);
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: bold ? 15 : 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppColors.textPrimary,
            fontSize: bold ? 18 : 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// Barcode lookup helper
// ---------------------------------------------------------------------------
// 1. Checks in-memory productsStreamProvider list (instant, covers 300 newest).
// 2. If not found, falls back to a direct Firestore query so products added
//    earlier (beyond the 300-limit) are still matched.
// 3. Normalises leading-zero mismatch (EAN-13 scanners may include/omit leading 0).
Future<ProductModel?> _lookupByBarcode(
    String shopId, String barcode, WidgetRef ref) async {
  final trimmed = barcode.trim();
  if (trimmed.isEmpty) return null;

  // Fast path — in-memory search
  ProductModel? found = ref.read(
      productByBarcodeProvider((shopId: shopId, barcode: trimmed)));
  if (found != null) return found;

  // Leading-zero normalisation
  final alt = trimmed.startsWith('0') ? trimmed.substring(1) : '0$trimmed';
  found = ref.read(
      productByBarcodeProvider((shopId: shopId, barcode: alt)));
  if (found != null) return found;

  // Firestore fallback — queries ALL products, not just the cached 300
  try {
    final col = FirebaseFirestore.instance
        .collection('shops').doc(shopId).collection('products');

    final snap = await col.where('barcode', isEqualTo: trimmed).limit(1).get();
    if (snap.docs.isNotEmpty) return ProductModel.fromFirestore(snap.docs.first);

    final snapAlt = await col.where('barcode', isEqualTo: alt).limit(1).get();
    if (snapAlt.docs.isNotEmpty) return ProductModel.fromFirestore(snapAlt.docs.first);
  } catch (_) {}

  return null;
}

// Desktop barcode text-entry field (Windows — USB scanners send Enter on scan)
// ---------------------------------------------------------------------------

class _DesktopBarcodeField extends ConsumerStatefulWidget {
  final String shopId;
  final void Function(ProductModel product) onProductFound;
  final void Function(String barcode) onNotFound;

  const _DesktopBarcodeField({
    required this.shopId,
    required this.onProductFound,
    required this.onNotFound,
  });

  @override
  ConsumerState<_DesktopBarcodeField> createState() =>
      _DesktopBarcodeFieldState();
}

class _DesktopBarcodeFieldState extends ConsumerState<_DesktopBarcodeField> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _onSubmitted(String barcode) async {
    if (barcode.trim().isEmpty) return;
    _ctrl.clear(); // clear immediately so next scan can start
    final product = await _lookupByBarcode(widget.shopId, barcode, ref);
    if (!mounted) return;
    if (product != null) {
      widget.onProductFound(product);
    } else {
      widget.onNotFound(barcode.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: TextField(
        controller: _ctrl,
        decoration: const InputDecoration(
          labelText: 'Scan / Enter Barcode',
          prefixIcon: Icon(Icons.qr_code,
              size: 18, color: AppColors.textSecondary),
          border: OutlineInputBorder(),
          isDense: true,
          contentPadding:
              EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        ),
        onSubmitted: _onSubmitted,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Barcode scanner page (used by _ProductPanel)
// ---------------------------------------------------------------------------

class _BillingBarcodeScanner extends StatelessWidget {
  const _BillingBarcodeScanner();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: MobileScanner(
        onDetect: (capture) {
          final barcode = capture.barcodes.firstOrNull?.rawValue;
          if (barcode != null) Navigator.pop(context, barcode);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Upsell feature list item
// ---------------------------------------------------------------------------

class _UpsellItem extends StatelessWidget {
  final String text;
  const _UpsellItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline,
              size: 15, color: AppColors.success),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Input decoration helper (file-level)
// ---------------------------------------------------------------------------

InputDecoration _inputDecoration(String label) => InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );

// ---------------------------------------------------------------------------
// UPI QR card — shown inline when UPI payment method is selected
// ---------------------------------------------------------------------------

class _UpiQrCard extends StatelessWidget {
  final String upiId;
  final String shopName;
  final double amount;

  const _UpiQrCard({
    required this.upiId,
    required this.shopName,
    required this.amount,
  });

  String get _upiString =>
      'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(shopName)}&am=${amount.toStringAsFixed(2)}&cu=INR';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade50,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.qr_code_2_rounded,
                  color: Colors.green.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Scan to Pay ₹${amount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Colors.green.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          QrImageView(
            data: _upiString,
            version: QrVersions.auto,
            size: 180,
            backgroundColor: Colors.white,
          ),
          const SizedBox(height: 8),
          Text(
            upiId,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ask customer to scan with any UPI app',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
