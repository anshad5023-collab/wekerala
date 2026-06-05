import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/shop_provider.dart';

class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopAsync = ref.watch(activeShopIdProvider);
    return shopAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text(e.toString()))),
      data: (shopId) {
        if (shopId == null || shopId.isEmpty) {
          return const Scaffold(body: Center(child: Text('Shop not found')));
        }
        return _SubscriptionBody(shopId: shopId);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SubscriptionBody extends ConsumerStatefulWidget {
  final String shopId;
  const _SubscriptionBody({required this.shopId});

  @override
  ConsumerState<_SubscriptionBody> createState() => _SubscriptionBodyState();
}

class _SubscriptionBodyState extends ConsumerState<_SubscriptionBody> {
  bool _submitting = false;

  String get _upiId => dotenv.get('SHOPLINK_UPI_ID', fallback: '');
  String get _supportWhatsApp => dotenv.get('SUPPORT_WHATSAPP', fallback: '');
  String get _razorpayKeyId => dotenv.get('RAZORPAY_KEY_ID', fallback: '');

  // Opens the UPI payment intent
  Future<void> _payViaUpi() async {
    if (_upiId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('UPI ID not configured — contact support')),
      );
      return;
    }
    final uri = Uri.parse(
      'upi://pay?pa=$_upiId&pn=Oratas&am=99&cu=INR&tn=Oratas+Monthly+Subscription',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      // Fallback: copy UPI ID to clipboard
      await Clipboard.setData(ClipboardData(text: _upiId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('UPI ID copied: $_upiId — open any UPI app to pay ₹99')),
        );
      }
    }
  }

  // Pay via Razorpay (automated — webhook auto-activates subscription)
  Future<void> _payViaRazorpay() async {
    setState(() => _submitting = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('createRazorpayOrder');
      final result = await callable.call<Map<Object?, Object?>>({'shopId': widget.shopId});
      final data = Map<String, dynamic>.from(result.data);
      final orderId = data['orderId'] as String? ?? '';
      final keyId = data['keyId'] as String? ?? _razorpayKeyId;
      if (orderId.isEmpty || keyId.isEmpty) {
        throw Exception('Could not create payment order');
      }
      // Open Razorpay checkout URL in browser
      final url = Uri.parse(
        'https://api.razorpay.com/v1/checkout/embedded?key_id=$keyId&order_id=$orderId',
      );
      await launchUrl(url, mode: LaunchMode.externalApplication);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Complete payment in browser. Your subscription activates automatically!'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Payment setup failed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // Records "I've paid" in Firestore and opens WhatsApp
  Future<void> _confirmPayment() async {
    setState(() => _submitting = true);
    try {
      final now = DateTime.now();
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.shopId)
          .update({
        'subscriptionStatus': 'payment_pending',
        'paymentPendingAt': Timestamp.fromDate(now),
      });

      // Open WhatsApp with pre-filled message to admin
      if (_supportWhatsApp.isNotEmpty) {
        final msg = Uri.encodeComponent(
          'Hi, I have paid ₹99 for Oratas subscription.\n'
          'Shop ID: ${widget.shopId}\n'
          'Please activate my subscription.',
        );
        final wa = Uri.parse('https://wa.me/$_supportWhatsApp?text=$msg');
        await launchUrl(wa, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopAsync = ref.watch(shopStreamProvider(widget.shopId));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Subscription'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: shopAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (shop) {
          final now = DateTime.now();
          final daysLeft = shop.trialEndDate.difference(now).inDays;
          final status = shop.subscriptionStatus; // trial | active | payment_pending | expired

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _StatusCard(status: status, daysLeft: daysLeft),
              const SizedBox(height: 24),

              if (status == 'active') ...[
                _ActiveDetails(shop: shop),
              ] else if (status == 'payment_pending') ...[
                _PendingCard(shopId: widget.shopId),
              ] else ...[
                // Plan card
                _PlanCard(),
                const SizedBox(height: 16),
                _HowToPayCard(),
                const SizedBox(height: 20),
                // Razorpay (auto-activate) — shown when key is configured
                if (_razorpayKeyId.isNotEmpty) ...[
                  ElevatedButton.icon(
                    icon: const Icon(Icons.credit_card_outlined, size: 20),
                    label: Text(
                      _submitting ? 'Loading...' : 'Pay ₹99/month (Card / UPI / NetBanking)',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    onPressed: _submitting ? null : _payViaRazorpay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D6A4F),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Row(children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text('or pay manually', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ),
                    Expanded(child: Divider()),
                  ]),
                  const SizedBox(height: 10),
                ],
                // Manual UPI button
                ElevatedButton.icon(
                  icon: const Icon(Icons.currency_rupee, size: 20),
                  label: const Text('Pay ₹99 via UPI (Manual)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  onPressed: _payViaUpi,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
                const SizedBox(height: 12),
                // After paying, user taps this
                OutlinedButton.icon(
                  icon: _submitting
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check_circle_outline, size: 20),
                  label: const Text('I\'ve paid — confirm my subscription',
                      style: TextStyle(fontSize: 14)),
                  onPressed: _submitting ? null : _confirmPayment,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(48),
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 24),
                _UpiIdTile(upiId: _upiId),
              ],
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}

// ── Status card ────────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final String status;
  final int daysLeft;
  const _StatusCard({required this.status, required this.daysLeft});

  @override
  Widget build(BuildContext context) {
    final (icon, label, desc, colors) = switch (status) {
      'active'          => (Icons.verified_rounded,   'Active',          'All features unlocked',
                            [const Color(0xFF2D6A4F), const Color(0xFF1B4332)]),
      'payment_pending' => (Icons.hourglass_top,      'Pending',         'Payment received — activating soon',
                            [Colors.orange.shade600,   Colors.orange.shade800]),
      'expired'         => (Icons.cancel_rounded,     'Expired',         'Renew to continue using Oratas',
                            [Colors.red.shade400,      Colors.red.shade700]),
      _                 => (Icons.access_time_rounded, 'Free Trial',     '$daysLeft days remaining',
                            [Colors.blue.shade400,     Colors.blue.shade700]),
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors,
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Icon(icon, color: Colors.white, size: 36),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(desc,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ]),
      ]),
    );
  }
}

// ── Plan card ─────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const features = [
      ('Unlimited orders & billing',    Icons.receipt_long_outlined),
      ('Up to 500 products',            Icons.inventory_2_outlined),
      ('Customer shop link (PWA)',       Icons.link_rounded),
      ('Udhar / credit book',           Icons.people_outline),
      ('WhatsApp order notifications',  Icons.chat_outlined),
      ('WhatsApp support',              Icons.support_agent_outlined),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Oratas Monthly Plan',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const Text('₹99',
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold,
                  color: AppColors.primary)),
          const Text(' / month',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Best value',
                style: TextStyle(color: AppColors.success, fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
        ]),
        const Divider(height: 20),
        ...features.map((f) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Icon(f.$2, color: AppColors.success, size: 18),
            const SizedBox(width: 10),
            Text(f.$1, style: const TextStyle(fontSize: 13)),
          ]),
        )),
      ]),
    );
  }
}

// ── How to pay card ───────────────────────────────────────────────────────────

class _HowToPayCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const steps = [
      'Tap "Pay ₹99 via UPI" — Google Pay / PhonePe / BHIM will open',
      'Complete the ₹99 payment to Oratas',
      'Come back here and tap "I\'ve paid" — we\'ll activate within 2 hours',
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.info_outline, size: 16, color: Colors.amber),
          SizedBox(width: 6),
          Text('How to pay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ]),
        const SizedBox(height: 10),
        ...steps.asMap().entries.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 20, height: 20,
              decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
              child: Center(child: Text('${e.key + 1}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(e.value,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
          ]),
        )),
      ]),
    );
  }
}

// ── UPI ID tile (copyable) ────────────────────────────────────────────────────

class _UpiIdTile extends StatelessWidget {
  final String upiId;
  const _UpiIdTile({required this.upiId});

  @override
  Widget build(BuildContext context) {
    if (upiId.isEmpty) return const SizedBox.shrink();
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: upiId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('UPI ID copied to clipboard')),
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          const Icon(Icons.account_balance_wallet_outlined, size: 18,
              color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(child: Text('UPI: $upiId',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
          const Icon(Icons.copy, size: 16, color: AppColors.textSecondary),
        ]),
      ),
    );
  }
}

// ── Pending card ──────────────────────────────────────────────────────────────

class _PendingCard extends StatelessWidget {
  final String shopId;
  const _PendingCard({required this.shopId});

  @override
  Widget build(BuildContext context) {
    final supportWa = dotenv.get('SUPPORT_WHATSAPP', fallback: '');
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(children: [
        const Icon(Icons.hourglass_top, size: 48, color: Colors.orange),
        const SizedBox(height: 12),
        const Text('Payment received!',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 6),
        const Text('We\'re verifying your payment.\nYou\'ll be activated within 2 hours.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        if (supportWa.isNotEmpty) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.chat, size: 18),
            label: const Text('Message us on WhatsApp'),
            onPressed: () async {
              final msg = Uri.encodeComponent(
                'Hi, I\'ve paid for Oratas. Shop ID: $shopId. Please activate.',
              );
              final wa = Uri.parse('https://wa.me/$supportWa?text=$msg');
              await launchUrl(wa, mode: LaunchMode.externalApplication);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF25D366),
              side: const BorderSide(color: Color(0xFF25D366)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ]),
    );
  }
}

// ── Active details ────────────────────────────────────────────────────────────

class _ActiveDetails extends StatelessWidget {
  final dynamic shop;
  const _ActiveDetails({required this.shop});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Your subscription is active',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 10),
        _Row('Next renewal', _fmt(shop.trialEndDate)),
        if (shop.lastPaymentDate != null)
          _Row('Last payment', _fmt(shop.lastPaymentDate!)),
      ]),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';

  static const _months = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec',
  ];
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ]),
    );
  }
}
