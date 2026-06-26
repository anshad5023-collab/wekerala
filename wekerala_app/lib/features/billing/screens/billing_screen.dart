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
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/print_service.dart';
import '../../../core/services/scan_feedback.dart';
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 14),
              child: Text(
                'Select ${product.nameEn} variant',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            // Tap-friendly grid of variant chips — faster than a long list for
            // size/colour selection at the counter.
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: product.variants.map((v) {
                final price = v.offerPrice > 0 ? v.offerPrice : v.price;
                return InkWell(
                  onTap: () => Navigator.pop(ctx, v),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 92),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.35)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(v.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text('₹${price.toStringAsFixed(0)}',
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
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

    // Credit-limit enforcement: block a new udhar that would push this
    // customer over their set limit.
    if (method == 'udhar' && customerPhone.isNotEmpty) {
      final blocked = await _checkCreditLimitBlocked(
          shopId, customerPhone, ref.read(billingProvider).total);
      if (blocked || !mounted) return;
    }

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

  /// Returns true (and shows a blocking dialog) if adding [addAmount] of udhar
  /// would push this customer over their credit limit. 0 limit = no limit.
  Future<bool> _checkCreditLimitBlocked(
      String shopId, String phone, double addAmount) async {
    final customers =
        ref.read(customersStreamProvider(shopId)).valueOrNull ?? const [];
    double limit = 0;
    for (final c in customers) {
      if (c.phone == phone) {
        limit = c.creditLimit;
        break;
      }
    }
    if (limit <= 0) return false; // no limit set

    final credits =
        ref.read(allCreditsStreamProvider(shopId)).valueOrNull ?? const [];
    double outstanding = 0;
    for (final c in credits) {
      if (c.customerPhone == phone && c.status != 'paid') {
        outstanding += c.outstanding;
      }
    }

    if (outstanding + addAmount <= limit) return false; // within limit

    if (mounted) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.block, color: AppColors.error, size: 40),
          title: const Text('Credit limit reached'),
          content: Text(
            'This customer already owes ₹${outstanding.toStringAsFixed(0)}.\n'
            'This ₹${addAmount.toStringAsFixed(0)} udhar would exceed their '
            'limit of ₹${limit.toStringAsFixed(0)}.\n\n'
            'Collect a payment, raise the limit on the customer\'s page, or '
            'take this bill as Cash/UPI instead.',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK')),
          ],
        ),
      );
    }
    return true;
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

  // ── park / hold bills ───────────────────────────────────────────────────

  Future<String?> _askParkLabel(BuildContext context) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        title: const Text('Hold this bill',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: _inputDecoration('Name / table (optional)'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Hold'),
          ),
        ],
      ),
    );
  }

  void _parkCurrent(String label) {
    ref.read(billingProvider.notifier).parkCurrentBill(label);
    _discountCtrl.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(label.isEmpty ? 'Bill held' : 'Held: $label'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.accent,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _resumeParked(String id) {
    ref.read(billingProvider.notifier).resumeParkedBill(id);
    final d = ref.read(billingProvider).discountAmount;
    _discountCtrl.text = d > 0 ? d.toStringAsFixed(2) : '';
  }

  Future<void> _showParkedBills(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => Consumer(
        builder: (ctx, ref2, _) {
          final state = ref2.watch(billingProvider);
          final parked = state.parkedBills;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bookmark_outline,
                          color: AppColors.primary),
                      const SizedBox(width: 8),
                      const Text('Parked Bills',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: state.cartItems.isEmpty
                          ? null
                          : () async {
                              final label = await _askParkLabel(sheetCtx);
                              if (label == null) return; // cancelled
                              _parkCurrent(label);
                              if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                            },
                      icon: const Icon(Icons.pause_circle_outline, size: 18),
                      label: const Text('Hold current bill'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.accent,
                        side: BorderSide(
                            color: AppColors.accent.withValues(alpha: 0.6)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  if (parked.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('No held bills yet.',
                            style: TextStyle(color: AppColors.textSecondary)),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: parked.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final p = parked[i];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.receipt_long_outlined,
                                color: AppColors.primary),
                            title: Text(p.label.isEmpty ? 'Bill ${i + 1}' : p.label,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(
                                '${p.items.length} items  •  ₹${p.total.toStringAsFixed(0)}'),
                            onTap: () {
                              _resumeParked(p.id);
                              Navigator.pop(sheetCtx);
                            },
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: AppColors.error),
                              onPressed: () => ref2
                                  .read(billingProvider.notifier)
                                  .deleteParkedBill(p.id),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── quick item (no-catalog billing) ──────────────────────────────────────

  Future<void> _showQuickItemDialog() async {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final priceFocus = FocusNode();

    void add({required bool keepOpen, required BuildContext ctx}) {
      final price = double.tryParse(priceCtrl.text.trim()) ?? 0;
      final qty = double.tryParse(qtyCtrl.text.trim()) ?? 1;
      if (price <= 0) return;
      ref.read(billingProvider.notifier).addCustomItem(
            name: nameCtrl.text.trim(),
            price: price,
            qty: qty <= 0 ? 1 : qty,
          );
      HapticFeedback.lightImpact();
      if (keepOpen) {
        nameCtrl.clear();
        priceCtrl.clear();
        qtyCtrl.text = '1';
        priceFocus.requestFocus();
      } else {
        Navigator.pop(ctx);
      }
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        title: const Text('Quick item',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add a priced line without a catalog product.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: _inputDecoration('Name (optional)'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: priceCtrl,
                    focusNode: priceFocus,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))
                    ],
                    decoration: _inputDecoration('Price ₹'),
                    onSubmitted: (_) => add(keepOpen: true, ctx: ctx),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: qtyCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}'))
                    ],
                    decoration: _inputDecoration('Qty'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => add(keepOpen: true, ctx: ctx),
            child: const Text('Add & next'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white),
            onPressed: () => add(keepOpen: false, ctx: ctx),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // ── price check (scan to see price, don't add) ───────────────────────────

  Future<void> _showPriceCheck() async {
    final shopId = await _resolveShopId();
    if (shopId == null || !mounted) return;
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _BillingBarcodeScanner()),
    );
    if (barcode == null || barcode.isEmpty || !mounted) return;
    final product = await _lookupByBarcode(shopId, barcode, ref);
    if (!mounted) return;
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Barcode $barcode not in catalog'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final price = product.offerPrice > 0 ? product.offerPrice : product.price;
    final hasOffer = product.offerPrice > 0 && product.offerPrice < product.price;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text(product.nameEn,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('₹${price.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary)),
                const SizedBox(width: 8),
                if (hasOffer)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text('₹${product.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.textSecondary,
                            decoration: TextDecoration.lineThrough)),
                  ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6, left: 2),
                  child: Text('/ ${product.unit}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              product.isOutOfStock
                  ? 'Out of stock'
                  : product.stockQty != null
                      ? 'In stock: ${product.stockQty} ${product.unit}'
                      : 'In stock',
              style: TextStyle(
                  fontSize: 13,
                  color: product.isOutOfStock
                      ? AppColors.error
                      : AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          if (!product.isOutOfStock)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white),
              icon: const Icon(Icons.add_shopping_cart, size: 18),
              label: const Text('Add to bill'),
              onPressed: () {
                ref.read(billingProvider.notifier).addItem(product);
                Navigator.pop(ctx);
              },
            ),
        ],
      ),
    );
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
          // Continuous "scan gun" mode — keep the camera open and add every
          // barcode straight to the bill. Android only (uses the device camera).
          if (!kIsWeb && Platform.isAndroid && shopId != null)
            IconButton(
              icon: const Icon(Icons.barcode_reader),
              tooltip: 'Scan to Bill',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _ContinuousScanBilling(shopId: shopId),
                ),
              ),
            ),
          // Parked / held bills — badge shows how many are waiting.
          IconButton(
            icon: Badge(
              isLabelVisible: billingState.parkedBills.isNotEmpty,
              label: Text('${billingState.parkedBills.length}'),
              child: const Icon(Icons.bookmark_border),
            ),
            tooltip: 'Held bills',
            onPressed: () => _showParkedBills(context),
          ),
          // Everything else lives in a "More" menu so the bar never overflows.
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              switch (v) {
                case 'voice':
                  if (shopId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _VoiceBillingScreen(shopId: shopId),
                      ),
                    );
                  }
                  break;
                case 'price':
                  _showPriceCheck();
                  break;
                case 'quick':
                  _showQuickItemDialog();
                  break;
                case 'history':
                  context.push('/bill-history');
                  break;
                case 'cash':
                  context.push('/cash-counter');
                  break;
              }
            },
            itemBuilder: (ctx) => [
              if (!kIsWeb && Platform.isAndroid && shopId != null)
                const PopupMenuItem(
                  value: 'voice',
                  child: ListTile(
                      leading: Icon(Icons.mic_none),
                      title: Text('Voice billing')),
                ),
              if (!kIsWeb && Platform.isAndroid && shopId != null)
                const PopupMenuItem(
                  value: 'price',
                  child: ListTile(
                      leading: Icon(Icons.sell_outlined),
                      title: Text('Price check')),
                ),
              const PopupMenuItem(
                value: 'quick',
                child: ListTile(
                    leading: Icon(Icons.dialpad),
                    title: Text('Quick item')),
              ),
              const PopupMenuItem(
                value: 'history',
                child: ListTile(
                    leading: Icon(Icons.receipt_long_outlined),
                    title: Text('Bill history')),
              ),
              const PopupMenuItem(
                value: 'cash',
                child: ListTile(
                    leading: Icon(Icons.calculate_outlined),
                    title: Text('Cash counter')),
              ),
            ],
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

    // Apply a percentage discount by converting it to a flat ₹ amount on the
    // current subtotal (keeps the ₹ field as the single source of truth).
    Future<void> applyDiscountPercent() async {
      final pctCtrl = TextEditingController();
      final pct = await showDialog<double>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Discount %', style: TextStyle(fontSize: 15)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                children: [5, 10, 15, 20].map((p) {
                  return ActionChip(
                    label: Text('$p%'),
                    onPressed: () => Navigator.pop(context, p.toDouble()),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pctCtrl,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))
                ],
                decoration: const InputDecoration(
                    suffixText: '%', hintText: 'Custom %'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, double.tryParse(pctCtrl.text.trim())),
              child: const Text('Apply'),
            ),
          ],
        ),
      );
      if (pct == null || pct <= 0) return;
      final amount = (state.subtotal * pct / 100);
      discountCtrl.text = amount.toStringAsFixed(2);
      onDiscountChanged(discountCtrl.text);
    }

    // Remove an item but offer a 4-second "Undo" — so an accidental delete is
    // never final (the owner specifically asked to be able to cancel an item).
    void removeWithUndo(int index, BillItemModel item) {
      notifier.removeItem(item.productId);
      HapticFeedback.lightImpact();
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Removed ${item.productName}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Undo',
            textColor: Colors.white,
            onPressed: () => notifier.restoreCartItem(item, index),
          ),
        ),
      );
    }

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
                    return Dismissible(
                      key: ValueKey(item.productId),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.delete_outline,
                            color: Colors.white),
                      ),
                      onDismissed: (_) => removeWithUndo(index, item),
                      child: _CartItemRow(
                        item: item,
                        shopType: shopType,
                        onIncrement: () => notifier.updateQty(
                            item.productId, item.qty + item.qtyStep),
                        onDecrement: () =>
                            notifier.decrementItem(item.productId),
                        onDelete: () => removeWithUndo(index, item),
                        onSetQty: (qty) =>
                            notifier.updateQty(item.productId, qty),
                        onSetPrice: (p) =>
                            notifier.setItemPrice(item.productId, p),
                        onSetModifiers: (mods) =>
                            notifier.setItemModifiers(item.productId, mods),
                      ).animate().fadeIn(duration: 200.ms),
                    );
                  },
                ),
        ),

        // Discount row — flat ₹ field, a % quick-apply, and a round-off toggle.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              const Text('Discount:  ₹',
                  style: TextStyle(color: AppColors.textSecondary)),
              SizedBox(
                width: 70,
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
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed:
                    state.cartItems.isEmpty ? null : applyDiscountPercent,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(40, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  foregroundColor: AppColors.primary,
                ),
                child: const Text('%'),
              ),
              const Spacer(),
              // Round-off toggle
              GestureDetector(
                onTap: () => notifier.setRoundOff(!state.roundOffEnabled),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Round',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    Transform.scale(
                      scale: 0.75,
                      child: Switch(
                        value: state.roundOffEnabled,
                        activeColor: AppColors.primary,
                        onChanged: (v) => notifier.setRoundOff(v),
                      ),
                    ),
                  ],
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
              // Round-off line (only when it actually changes the total)
              if (state.roundOffEnabled && state.roundOffAmount.abs() >= 0.01)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Round off',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                      Text(
                        '${state.roundOffAmount >= 0 ? '+' : '-'}₹${state.roundOffAmount.abs().toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
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
  final ValueChanged<double>? onSetPrice;
  final ValueChanged<List<String>>? onSetModifiers;
  final String shopType;

  const _CartItemRow({
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    required this.onDelete,
    this.onSetQty,
    this.onSetPrice,
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

  Future<void> _showPriceDialog(BuildContext ctx) async {
    final ctrl = TextEditingController(text: item.price.toStringAsFixed(2));
    final val = await showDialog<double>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text('Price — ${item.productName}',
            style: const TextStyle(fontSize: 14)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Set a negotiated unit price for this item.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))
              ],
              decoration: InputDecoration(
                prefixText: '₹ ',
                suffixText: '/ ${item.unit}',
                hintText: 'Unit price',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, double.tryParse(ctrl.text.trim())),
            child: const Text('Set'),
          ),
        ],
      ),
    );
    if (val != null && val >= 0 && onSetPrice != null) onSetPrice!(val);
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
                        GestureDetector(
                          onTap: onSetPrice == null
                              ? null
                              : () => _showPriceDialog(context),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _priceLabel,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              if (onSetPrice != null) ...[
                                const SizedBox(width: 3),
                                const Icon(Icons.edit,
                                    size: 11, color: AppColors.textSecondary),
                              ],
                            ],
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
                                ? '$_qtyLabel ${item.unit}'
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

  // Non-blocking nudge when the cart qty exceeds what's on hand. We still let
  // the sale through (the owner may have stock the app doesn't know about) but
  // they get told, so inventory doesn't silently drift negative.
  void _warnIfOversold(BuildContext context, ProductModel product) {
    final stock = product.stockQty;
    if (stock == null) return; // services / untracked items
    final cartQty = ref
        .read(billingProvider)
        .cartItems
        .where((i) => i.productId == product.productId)
        .fold<double>(0, (a, i) => a + i.qty);
    if (cartQty > stock) {
      final qtyStr = cartQty % 1 == 0 ? cartQty.toInt().toString() : cartQty.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Only $stock ${product.unit} of ${product.nameEn} left — cart now has $qtyStr'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Shared add logic — used by the product list AND the quick-add row.
  Future<void> _addProduct(BuildContext context, ProductModel product) async {
    if (product.hasVariants && product.variants.isNotEmpty) {
      final variant = await _showVariantPicker(context, product);
      if (variant != null && context.mounted) {
        ref.read(billingProvider.notifier).addItem(product, variant: variant);
      }
    } else {
      ref.read(billingProvider.notifier).addItem(product);
      _warnIfOversold(context, product);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopId = widget.shopId;
    final searchQuery = widget.searchQuery;
    final productsAsync = ref.watch(productsStreamProvider(shopId));
    final shopAsync = ref.watch(shopStreamProvider(shopId));
    final categories = ['All', ...?shopAsync.value?.categories];
    final cartItems = ref.watch(billingProvider).cartItems;
    final inCartIds = {for (final i in cartItems) i.productId};

    // Bestsellers for the quick-add row (hidden while searching to cut clutter).
    final allProducts = productsAsync.valueOrNull ?? const <ProductModel>[];
    final quickItems = (allProducts
            .where((p) => !p.isHidden && !p.isOutOfStock && p.orderCount > 0)
            .toList()
          ..sort((a, b) => b.orderCount.compareTo(a.orderCount)))
        .take(10)
        .toList();

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
                      onProductFound: (product) {
                        ref.read(billingProvider.notifier).addItem(product);
                        ScanFeedback.success();
                      },
                      onNotFound: (barcode) {
                        ScanFeedback.error();
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

        // Quick-add row — tap the shop's bestsellers without searching/scrolling.
        if (searchQuery.isEmpty && quickItems.isNotEmpty) ...[
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: quickItems.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final p = quickItems[i];
                final price = p.offerPrice > 0 ? p.offerPrice : p.price;
                return ActionChip(
                  avatar: const Icon(Icons.bolt,
                      size: 16, color: AppColors.primary),
                  label: Text('${p.nameEn}  ₹${price.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 12)),
                  onPressed: () => _addProduct(context, p),
                  backgroundColor: AppColors.primary.withValues(alpha: 0.06),
                  side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.25)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              },
            ),
          ),
          const SizedBox(height: 6),
        ],

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
                    onTap: () => _addProduct(context, product),
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

  bool _syncingSplit = false;

  // Format an amount without trailing ".0" for whole numbers.
  String _fmtAmt(double v) {
    if (v <= 0) return '0';
    return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  }

  // User typed in the Cash field → auto-fill UPI with the remainder.
  void _syncFromCash(double total) {
    if (_syncingSplit) return;
    _syncingSplit = true;
    final cash = double.tryParse(_cashSplitCtrl.text) ?? 0;
    final remaining = total - cash;
    _upiSplitCtrl.text = _fmtAmt(remaining < 0 ? 0 : remaining);
    _syncingSplit = false;
    setState(() {});
  }

  // User typed in the UPI field → auto-fill Cash with the remainder.
  void _syncFromUpi(double total) {
    if (_syncingSplit) return;
    _syncingSplit = true;
    final upi = double.tryParse(_upiSplitCtrl.text) ?? 0;
    final remaining = total - upi;
    _cashSplitCtrl.text = _fmtAmt(remaining < 0 ? 0 : remaining);
    _syncingSplit = false;
    setState(() {});
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
            // Helper: shows the goal + live confirmation that the two add up.
            Builder(builder: (_) {
              final total = billingState.total;
              final cash = double.tryParse(_cashSplitCtrl.text) ?? 0;
              final upi = double.tryParse(_upiSplitCtrl.text) ?? 0;
              final sum = cash + upi;
              final matches = (sum - total).abs() < 0.01;
              final hasInput = _cashSplitCtrl.text.isNotEmpty || _upiSplitCtrl.text.isNotEmpty;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text('Total to split: ₹${total.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                    const Spacer(),
                    if (hasInput)
                      Text(
                        matches
                            ? '₹${_fmtAmt(cash)} + ₹${_fmtAmt(upi)} ✓'
                            : 'Off by ₹${(total - sum).abs().toStringAsFixed(0)}',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: matches ? AppColors.success : AppColors.error),
                      ),
                  ],
                ),
              );
            }),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cashSplitCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => _syncFromCash(billingState.total),
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
                    onChanged: (_) => _syncFromUpi(billingState.total),
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
      if (item.modifiers.isNotEmpty) {
        buf.writeln('  + ${item.modifiers.join(', ')}');
      }
      if (item.itemNote != null && item.itemNote!.isNotEmpty) {
        buf.writeln('  📝 ${item.itemNote}');
      }
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
    // Round-off line so the printed/sent bill reconciles when the owner
    // rounded the total to a clean rupee amount.
    final roundOff = bill.roundOff;
    if (roundOff.abs() >= 0.01) {
      buf.writeln(
          'Round off: ${roundOff >= 0 ? '+' : '-'}₹${roundOff.abs().toStringAsFixed(2)}');
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                  if (item.modifiers.isNotEmpty)
                    Text('  + ${item.modifiers.join(', ')}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                  if (item.itemNote != null && item.itemNote!.isNotEmpty)
                    Text('  📝 ${item.itemNote}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
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

          // Round-off (only shown when it changed the total)
          if (bill.roundOff.abs() >= 0.01)
            _SummaryRow(
              label: 'Round off',
              value:
                  '${bill.roundOff >= 0 ? '+' : '-'}₹${bill.roundOff.abs().toStringAsFixed(2)}',
            ),

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

// ---------------------------------------------------------------------------
// Voice billing — say items, they get matched to the catalog and added
// ---------------------------------------------------------------------------
// e.g. "2 kg rice, one Maggi, three soap" → adds those lines. Quantities can be
// digits or words (English + common Malayalam numerals). Best-effort matching
// against product names; anything it can't match is listed so the owner can
// add it by hand.

class _VoiceMatch {
  final ProductModel product;
  final double qty;
  _VoiceMatch(this.product, this.qty);
}

class _VoiceLine {
  final _VoiceMatch? match;
  final String phrase;
  _VoiceLine(this.match, this.phrase);
}

const _kNumberWords = <String, double>{
  'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, 'six': 6,
  'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10, 'a': 1, 'an': 1, 'half': 0.5,
  // common Malayalam numerals (transliterated)
  'onnu': 1, 'rendu': 2, 'randu': 2, 'moonu': 3, 'munnu': 3, 'naalu': 4,
  'anchu': 5, 'aaru': 6, 'ezhu': 7, 'ettu': 8, 'onpathu': 9, 'pathu': 10,
};

const _kUnitWords = <String>{
  'kg', 'kgs', 'kilo', 'kilos', 'gram', 'grams', 'g', 'gm', 'packet',
  'packets', 'piece', 'pieces', 'pcs', 'nos', 'litre', 'liter',
  'litres', 'liters', 'l', 'ml', 'dozen', 'box', 'boxes', 'bottle', 'bottles',
};

List<_VoiceLine> _parseVoiceTranscript(
    String transcript, List<ProductModel> products) {
  final lines = <_VoiceLine>[];
  final phrases = transcript.toLowerCase().split(RegExp(r',|\band\b|\bplus\b|\n'));
  for (final raw in phrases) {
    final phrase = raw.trim();
    if (phrase.isEmpty) continue;
    var words = phrase.split(RegExp(r'\s+'));
    double qty = 1;
    if (words.isNotEmpty) {
      final first = words.first;
      final asNum = double.tryParse(first);
      if (asNum != null && asNum > 0) {
        qty = asNum;
        words = words.sublist(1);
      } else if (_kNumberWords.containsKey(first)) {
        qty = _kNumberWords[first]!;
        words = words.sublist(1);
      }
    }
    final nameWords = words
        .where((w) => !_kUnitWords.contains(w) && !_kNumberWords.containsKey(w))
        .toList();
    final query = nameWords.join(' ').trim();
    if (query.isEmpty) {
      lines.add(_VoiceLine(null, phrase));
      continue;
    }
    ProductModel? best;
    int bestScore = 0;
    for (final p in products) {
      if (p.isHidden || p.isOutOfStock) continue;
      final en = p.nameEn.toLowerCase();
      final ml = p.nameMl.toLowerCase();
      var score = 0;
      if (en == query || ml == query) {
        score = 1000 + p.orderCount;
      } else if (en.contains(query) ||
          query.contains(en) ||
          (ml.isNotEmpty && (ml.contains(query) || query.contains(ml)))) {
        score = 500 + p.orderCount;
      } else {
        final overlap = nameWords.where((w) => w.length > 2 && en.contains(w)).length;
        if (overlap > 0) score = overlap * 10 + p.orderCount;
      }
      if (score > bestScore) {
        bestScore = score;
        best = p;
      }
    }
    lines.add(best != null
        ? _VoiceLine(_VoiceMatch(best, qty), phrase)
        : _VoiceLine(null, phrase));
  }
  return lines;
}

class _VoiceBillingScreen extends ConsumerStatefulWidget {
  final String shopId;
  const _VoiceBillingScreen({required this.shopId});

  @override
  ConsumerState<_VoiceBillingScreen> createState() =>
      _VoiceBillingScreenState();
}

class _VoiceBillingScreenState extends ConsumerState<_VoiceBillingScreen> {
  final SpeechToText _speech = SpeechToText();
  bool _available = false;
  bool _listening = false;
  bool _consumed = false; // guards against double-processing one utterance
  String _transcript = '';
  final List<String> _added = [];
  final List<String> _unmatched = [];
  String _error = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _available = await _speech.initialize(
        onStatus: (s) {
          if ((s == 'done' || s == 'notListening') && mounted) {
            setState(() => _listening = false);
          }
        },
        onError: (e) {
          if (mounted) {
            setState(() {
              _error = e.errorMsg;
              _listening = false;
            });
          }
        },
      );
    } catch (e) {
      _available = false;
      _error = e.toString();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (!_available) {
      await _init();
      if (!_available) return;
    }
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      _process(_transcript);
      return;
    }
    setState(() {
      _transcript = '';
      _added.clear();
      _unmatched.clear();
      _error = '';
      _listening = true;
      _consumed = false;
    });
    await _speech.listen(
      onResult: (r) {
        if (!mounted) return;
        setState(() => _transcript = r.recognizedWords);
        if (r.finalResult) {
          _process(r.recognizedWords);
          setState(() => _listening = false);
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 4),
    );
  }

  void _process(String transcript) {
    if (_consumed || transcript.trim().isEmpty) return;
    _consumed = true;
    final products =
        ref.read(productsStreamProvider(widget.shopId)).valueOrNull ??
            const <ProductModel>[];
    final results = _parseVoiceTranscript(transcript, products);
    final notifier = ref.read(billingProvider.notifier);
    for (final r in results) {
      final m = r.match;
      if (m != null) {
        notifier.addProductQuantity(m.product, m.qty);
        final qs =
            m.qty % 1 == 0 ? m.qty.toInt().toString() : m.qty.toStringAsFixed(2);
        _added.add('$qs × ${m.product.nameEn}');
      } else {
        _unmatched.add(r.phrase);
      }
    }
    HapticFeedback.mediumImpact();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = ref.watch(billingProvider).cartItems.length;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Voice Billing'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _listening
                  ? 'Listening… say items like "2 kg rice, one Maggi"'
                  : 'Tap the mic and say your items.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            if (_transcript.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text('"$_transcript"',
                    style: const TextStyle(
                        fontSize: 16, fontStyle: FontStyle.italic)),
              ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  for (final a in _added)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.check_circle,
                          color: AppColors.success, size: 20),
                      title: Text(a),
                    ),
                  for (final u in _unmatched)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.help_outline,
                          color: Colors.orange, size: 20),
                      title: Text('Not found: "$u"',
                          style: const TextStyle(color: Colors.orange)),
                    ),
                  if (_error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _available
                            ? 'Error: $_error'
                            : 'Voice not available on this device/permission. $_error',
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                ],
              ),
            ),
            // Mic button
            Center(
              child: GestureDetector(
                onTap: _toggle,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _listening ? AppColors.error : AppColors.primary,
                    boxShadow: [
                      BoxShadow(
                        color: (_listening ? AppColors.error : AppColors.primary)
                            .withValues(alpha: 0.4),
                        blurRadius: _listening ? 24 : 10,
                        spreadRadius: _listening ? 4 : 0,
                      ),
                    ],
                  ),
                  child: Icon(_listening ? Icons.stop : Icons.mic,
                      color: Colors.white, size: 40),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.check),
                label: Text('Done${cartCount > 0 ? '  ($cartCount in cart)' : ''}'),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Continuous scan-to-bill ("scan gun" mode)
// ---------------------------------------------------------------------------
// The owner keeps the camera open and waves the phone across each product's
// barcode — every detected barcode is looked up and added straight to the
// shared cart, with a beep + vibrate so they never have to look at the screen.
// Re-presenting the same item adds +1 (a short per-barcode debounce stops a
// single scan from being counted dozens of times while it sits in view).
class _ContinuousScanBilling extends ConsumerStatefulWidget {
  final String shopId;
  const _ContinuousScanBilling({required this.shopId});

  @override
  ConsumerState<_ContinuousScanBilling> createState() =>
      _ContinuousScanBillingState();
}

class _RecentScan {
  final String productId;
  final String name;
  final double price;
  _RecentScan(this.productId, this.name, this.price);
}

class _ContinuousScanBillingState
    extends ConsumerState<_ContinuousScanBilling> {
  final MobileScannerController _scanner = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  // Per-barcode debounce: ignore the same code if seen again within this window,
  // so holding an item in view = +1, not +30.
  static const _debounce = Duration(milliseconds: 1200);
  String? _lastCode;
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);

  final List<_RecentScan> _recent = []; // newest first — drives the undo stack
  int _unknownCount = 0;
  bool _flashOn = false;
  bool _busy = false; // a lookup is in flight

  // Visual feedback: 'ok' (green), 'bad' (red), or null (none).
  String? _feedback;
  String _banner = 'Point at a barcode';

  @override
  void initState() {
    super.initState();
    ScanFeedback.preload(); // warm up the beep so the first scan is instant
  }

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.length < 4) return;

    final now = DateTime.now();
    if (code == _lastCode && now.difference(_lastAt) < _debounce) return;
    _lastCode = code;
    _lastAt = now;

    _busy = true;
    try {
      final product = await _lookupByBarcode(widget.shopId, code, ref);
      if (!mounted) return;
      if (product != null && !product.isOutOfStock) {
        ref.read(billingProvider.notifier).addItem(product);
        final price =
            product.offerPrice > 0 ? product.offerPrice : product.price;
        _recent.insert(0, _RecentScan(product.productId, product.nameEn, price));
        ScanFeedback.success(); // crisp POS beep + haptic
        setState(() {
          _feedback = 'ok';
          _banner = '✓ ${product.nameEn}  ₹${price.toStringAsFixed(0)}';
        });
      } else if (product != null && product.isOutOfStock) {
        ScanFeedback.error(); // low buzz + strong haptic
        setState(() {
          _feedback = 'bad';
          _banner = '${product.nameEn} — OUT OF STOCK';
        });
      } else {
        // Unknown barcode at the counter — don't dead-end. Offer a one-screen
        // quick add (name + price) with the barcode pre-filled, create the
        // product in this shop, and drop it straight into the bill.
        await _quickAddUnknown(code);
      }
    } finally {
      _busy = false;
      // Clear the colour flash shortly after.
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) setState(() => _feedback = null);
      });
    }
  }

  /// Quick-add an unrecognised barcode without leaving the scan screen.
  Future<void> _quickAddUnknown(String code) async {
    _unknownCount++;
    ScanFeedback.error(); // low buzz — not recognised
    setState(() {
      _feedback = 'bad';
      _banner = 'Unknown barcode — quick add it';
    });
    // Pause scanning while the sheet is open so it doesn't re-fire.
    await _scanner.stop().catchError((_) {});
    final product = await _showQuickAddSheet(code);
    if (mounted && product != null) {
      ref.read(billingProvider.notifier).addItem(product);
      final price = product.offerPrice > 0 ? product.offerPrice : product.price;
      _recent.insert(0, _RecentScan(product.productId, product.nameEn, price));
      ScanFeedback.success();
      setState(() {
        _feedback = 'ok';
        _banner = '✓ ${product.nameEn}  ₹${price.toStringAsFixed(0)}';
      });
    }
    await _scanner.start().catchError((_) {});
  }

  Future<ProductModel?> _showQuickAddSheet(String code) async {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    bool busy = false;
    return showModalBottomSheet<ProductModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('New product',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text('Barcode: $code',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: _inputDecoration('Product name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: priceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))
                ],
                decoration: _inputDecoration('Price ₹'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white),
                      onPressed: busy
                          ? null
                          : () async {
                              final name = nameCtrl.text.trim();
                              final price =
                                  double.tryParse(priceCtrl.text.trim()) ?? 0;
                              if (name.isEmpty || price <= 0) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Enter a name and a price.')),
                                );
                                return;
                              }
                              setSheet(() => busy = true);
                              final now = DateTime.now();
                              final productId = FirebaseFirestore.instance
                                  .collection('_')
                                  .doc()
                                  .id;
                              final product = ProductModel(
                                productId: productId,
                                nameEn: name,
                                category: '',
                                price: price,
                                unit: 'piece',
                                barcode: code,
                                createdAt: now,
                                updatedAt: now,
                              );
                              try {
                                await ProductRepository.add(
                                    widget.shopId, product);
                                if (ctx.mounted) Navigator.pop(ctx, product);
                              } catch (e) {
                                setSheet(() => busy = false);
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(content: Text('Could not save: $e')),
                                  );
                                }
                              }
                            },
                      child: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Add & bill'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _undoLast() {
    if (_recent.isEmpty) return;
    final last = _recent.removeAt(0);
    ref.read(billingProvider.notifier).decrementItem(last.productId);
    HapticFeedback.lightImpact();
    setState(() => _banner = 'Removed ${last.name}');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(billingProvider);
    final itemCount = state.cartItems.fold<double>(0, (a, i) => a + i.qty);

    final flashColor = _feedback == 'ok'
        ? AppColors.success.withValues(alpha: 0.30)
        : _feedback == 'bad'
            ? AppColors.error.withValues(alpha: 0.30)
            : Colors.transparent;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan to Bill'),
        actions: [
          IconButton(
            tooltip: _flashOn ? 'Flash off' : 'Flash on',
            icon: Icon(_flashOn ? Icons.flash_on : Icons.flash_off),
            onPressed: () async {
              await _scanner.toggleTorch().catchError((_) {});
              setState(() => _flashOn = !_flashOn);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(controller: _scanner, onDetect: _onDetect),
                // Colour flash on each scan
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  color: flashColor,
                ),
                // Scan frame
                Center(
                  child: Container(
                    width: 260,
                    height: 130,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primary, width: 3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                // Status banner
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _banner,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                if (_unknownCount > 0)
                  Positioned(
                    top: 70,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('$_unknownCount unknown',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                // Hint
                const Positioned(
                  bottom: 10,
                  left: 16,
                  right: 16,
                  child: Text(
                    'Move slowly across each barcode. Same item again = +1.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          // Running total + actions
          SafeArea(
            top: false,
            child: Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        '${itemCount.toStringAsFixed(itemCount % 1 == 0 ? 0 : 2)} items',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary),
                      ),
                      const Spacer(),
                      Text(
                        '₹${state.total.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                            color: AppColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _recent.isEmpty ? null : _undoLast,
                          icon: const Icon(Icons.undo, size: 18),
                          label: const Text('Undo last'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            foregroundColor: AppColors.error,
                            side: BorderSide(
                                color: _recent.isEmpty
                                    ? Colors.grey.shade300
                                    : AppColors.error),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.check),
                          label: const Text('Done'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
