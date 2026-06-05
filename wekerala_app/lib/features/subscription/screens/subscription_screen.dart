import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/shop_model.dart';
import '../../../providers/shop_provider.dart';

// ─── Plan definitions ─────────────────────────────────────────────────────────

class _Plan {
  final String id;
  final String label;
  final int price; // offer price
  final int originalPrice; // strike-through price
  final bool isPopular;
  final String tagline;
  final Color color;
  final IconData icon;
  final String waInfo; // "" for Lite
  final List<String> features;
  final List<String> lockedFeatures;

  const _Plan({
    required this.id,
    required this.label,
    required this.price,
    required this.originalPrice,
    this.isPopular = false,
    required this.tagline,
    required this.color,
    required this.icon,
    required this.waInfo,
    required this.features,
    required this.lockedFeatures,
  });

  int annualPrice() => price * 10; // pay 10 months, get 12
}

const _plans = [
  _Plan(
    id: 'lite',
    label: 'Lite',
    price: 349,
    originalPrice: 499,
    tagline: 'Perfect for shops just getting started',
    color: Color(0xFF607D8B),
    icon: Icons.storefront_outlined,
    waInfo: '',
    features: [
      'Billing & POS (unlimited bills)',
      'Up to 1,000 products',
      'Orders & delivery management',
      'Credits / Udhar book',
      'Analytics & reports',
      'Storefront website (PWA)',
      'FCM push notifications (free)',
    ],
    lockedFeatures: [
      'WhatsApp AI auto-reply',
      'WhatsApp broadcasts',
    ],
  ),
  _Plan(
    id: 'standard',
    label: 'Standard',
    price: 799,
    originalPrice: 999,
    isPopular: true,
    tagline: 'WhatsApp automation for growing shops',
    color: Color(0xFF1976D2),
    icon: Icons.chat_outlined,
    waInfo: '200 WhatsApp conversations/month\n30 broadcast sends/month',
    features: [
      'Everything in Lite',
      '200 WhatsApp AI replies/month',
      '30 broadcast sends/month',
      'AI product scan (50/day)',
      'Loyalty program',
    ],
    lockedFeatures: [],
  ),
  _Plan(
    id: 'pro',
    label: 'Pro',
    price: 1999,
    originalPrice: 2499,
    tagline: 'Scale your business with full automation',
    color: Color(0xFF2D6A4F),
    icon: Icons.rocket_launch_outlined,
    waInfo: '600 WhatsApp conversations/month\n100 broadcast sends/month',
    features: [
      'Everything in Standard',
      '600 WhatsApp AI replies/month',
      '100 broadcast sends/month',
      'AI website builder',
      'Up to 5 staff accounts',
      'Priority support',
    ],
    lockedFeatures: [],
  ),
  _Plan(
    id: 'chain',
    label: 'Chain',
    price: 4999,
    originalPrice: 5999,
    tagline: 'Multi-branch management at enterprise scale',
    color: Color(0xFF6A1B9A),
    icon: Icons.account_tree_outlined,
    waInfo: '2,000 WhatsApp conversations/month\n300 broadcast sends/month',
    features: [
      'Everything in Pro',
      '2,000 WhatsApp AI replies/month',
      '300 broadcast sends/month',
      'Unlimited staff accounts',
      'Custom AI training',
      'Dedicated support line',
    ],
    lockedFeatures: [],
  ),
];

_Plan? _planById(String id) {
  try {
    return _plans.firstWhere((p) => p.id == id);
  } catch (_) {
    return null;
  }
}

// ─── Entry widget ─────────────────────────────────────────────────────────────

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

// ─── Main body ────────────────────────────────────────────────────────────────

class _SubscriptionBody extends ConsumerStatefulWidget {
  final String shopId;
  const _SubscriptionBody({required this.shopId});

  @override
  ConsumerState<_SubscriptionBody> createState() => _SubscriptionBodyState();
}

class _SubscriptionBodyState extends ConsumerState<_SubscriptionBody> {
  bool _submitting = false;
  _Plan? _selectedPlan;
  Map<String, dynamic> _usage = {};
  bool _showAllPlans = false;
  bool _isAnnual = false;

  int _currentAmount(_Plan plan) => _isAnnual ? plan.annualPrice() : plan.price;

  String get _upiId => dotenv.get('SHOPLINK_UPI_ID', fallback: '');
  String get _supportWhatsApp {
    final raw = dotenv.get('SUPPORT_WHATSAPP', fallback: '').replaceAll(RegExp(r'\D'), '');
    if (raw.isEmpty) return '';
    return raw.startsWith('91') ? raw : '91$raw';
  }
  String get _razorpayKeyId => dotenv.get('RAZORPAY_KEY_ID', fallback: '');

  @override
  void initState() {
    super.initState();
    _loadUsage();
  }

  Future<void> _loadUsage() async {
    final month = DateTime.now().toIso8601String().substring(0, 7);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.shopId)
          .collection('usage')
          .doc(month)
          .get();
      if (mounted) setState(() => _usage = doc.data() ?? {});
    } catch (_) {}
  }

  Future<void> _payViaUpi(_Plan plan) async {
    if (_upiId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('UPI ID not configured — contact support')),
      );
      return;
    }
    final amount = _currentAmount(plan);
    final label = _isAnnual ? '${plan.label} Annual' : plan.label;
    final uri = Uri.parse(
      'upi://pay?pa=$_upiId&pn=Oratas&am=$amount&cu=INR'
      '&tn=Oratas+$label+Plan',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await Clipboard.setData(ClipboardData(text: _upiId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('UPI ID copied: $_upiId — pay ₹$amount in any UPI app')),
        );
      }
    }
  }

  Future<void> _payViaRazorpay(_Plan plan) async {
    setState(() => _submitting = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('createRazorpayOrder');
      final result = await callable.call<Map<Object?, Object?>>({
        'shopId': widget.shopId,
        'plan': plan.id,
        'amount': _currentAmount(plan),
        'isAnnual': _isAnnual,
      });
      final data = Map<String, dynamic>.from(result.data);
      final orderId = data['orderId'] as String? ?? '';
      final keyId = data['keyId'] as String? ?? _razorpayKeyId;
      if (orderId.isEmpty || keyId.isEmpty) throw Exception('Could not create payment order');
      final url = Uri.parse(
        'https://api.razorpay.com/v1/checkout/embedded?key_id=$keyId&order_id=$orderId',
      );
      await launchUrl(url, mode: LaunchMode.externalApplication);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Complete payment in browser — subscription activates automatically!'),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _confirmManualPayment(_Plan plan) async {
    setState(() => _submitting = true);
    try {
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.shopId)
          .update({
        'subscriptionStatus': 'payment_pending',
        'paymentPendingAt': Timestamp.fromDate(DateTime.now()),
        'planRequested': plan.id,
        'isAnnual': _isAnnual,
      });
      final amount = _currentAmount(plan);
      final billingCycle = _isAnnual ? 'annual' : 'monthly';
      if (_supportWhatsApp.isNotEmpty) {
        final msg = Uri.encodeComponent(
          'Hi, I have paid ₹$amount for Oratas ${plan.label} plan ($billingCycle).\n'
          'Shop ID: ${widget.shopId}\n'
          'Please activate my subscription.',
        );
        final wa = Uri.parse('https://wa.me/$_supportWhatsApp?text=$msg');
        await launchUrl(wa, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
          final status = shop.subscriptionStatus;
          final currentPlan = _planById(shop.plan);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Trial urgency banner
              if (status == 'trial' && daysLeft <= 5 && daysLeft >= 0) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    const Text('⏰', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          daysLeft == 0 ? 'Trial ends today!' : '$daysLeft day${daysLeft == 1 ? '' : 's'} left in your trial',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const Text('Lock in the launch offer before prices go up.',
                            style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ]),
                    ),
                  ]),
                ),
              ],
              _StatusCard(status: status, daysLeft: daysLeft, plan: currentPlan),
              const SizedBox(height: 20),

              if (status == 'payment_pending') ...[
                _PendingCard(shopId: widget.shopId, supportWa: _supportWhatsApp),
              ] else if (status == 'active') ...[
                if (currentPlan != null) _CurrentPlanCard(plan: currentPlan),
                const SizedBox(height: 16),
                _UsageCard(plan: currentPlan, usage: _usage),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: () => setState(() => _showAllPlans = !_showAllPlans),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(_showAllPlans ? 'Hide plans' : 'Upgrade / Change plan'),
                ),
                if (_showAllPlans) ...[
                  const SizedBox(height: 16),
                  _BillingToggle(
                    isAnnual: _isAnnual,
                    onToggle: (v) => setState(() => _isAnnual = v),
                  ),
                  const SizedBox(height: 12),
                  _PlanSelector(
                    currentPlanId: shop.plan,
                    selected: _selectedPlan,
                    isAnnual: _isAnnual,
                    onSelect: (p) => setState(() => _selectedPlan = p),
                  ),
                  if (_selectedPlan != null && _selectedPlan!.id != shop.plan) ...[
                    const SizedBox(height: 16),
                    _PaymentSection(
                      plan: _selectedPlan!,
                      isAnnual: _isAnnual,
                      amount: _currentAmount(_selectedPlan!),
                      submitting: _submitting,
                      showRazorpay: _razorpayKeyId.isNotEmpty,
                      upiId: _upiId,
                      onRazorpay: () => _payViaRazorpay(_selectedPlan!),
                      onUpi: () => _payViaUpi(_selectedPlan!),
                      onConfirm: () => _confirmManualPayment(_selectedPlan!),
                    ),
                  ],
                ],
              ] else ...[
                // Trial or expired — show plan selection immediately
                _BillingToggle(
                  isAnnual: _isAnnual,
                  onToggle: (v) => setState(() => _isAnnual = v),
                ),
                const SizedBox(height: 12),
                _PlanSelector(
                  currentPlanId: shop.plan,
                  selected: _selectedPlan,
                  isAnnual: _isAnnual,
                  onSelect: (p) => setState(() => _selectedPlan = p),
                ),
                const SizedBox(height: 20),
                if (_selectedPlan != null) ...[
                  _PaymentSection(
                    plan: _selectedPlan!,
                    isAnnual: _isAnnual,
                    amount: _currentAmount(_selectedPlan!),
                    submitting: _submitting,
                    showRazorpay: _razorpayKeyId.isNotEmpty,
                    upiId: _upiId,
                    onRazorpay: () => _payViaRazorpay(_selectedPlan!),
                    onUpi: () => _payViaUpi(_selectedPlan!),
                    onConfirm: () => _confirmManualPayment(_selectedPlan!),
                  ),
                ] else ...[
                  _SelectPlanHint(),
                ],
              ],
              const SizedBox(height: 24),
              _TrustBadges(),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}

// ─── Status card ──────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final String status;
  final int daysLeft;
  final _Plan? plan;
  const _StatusCard({required this.status, required this.daysLeft, this.plan});

  @override
  Widget build(BuildContext context) {
    final (icon, label, desc, colors) = switch (status) {
      'active' => (
          Icons.verified_rounded,
          'Active — ${plan?.label ?? 'Plan'}',
          '₹${plan?.price ?? 0}/month • All features unlocked',
          [const Color(0xFF2D6A4F), const Color(0xFF1B4332)],
        ),
      'payment_pending' => (
          Icons.hourglass_top,
          'Payment Pending',
          'Verifying your payment — activating soon',
          [Colors.orange.shade600, Colors.orange.shade800],
        ),
      'expired' => (
          Icons.cancel_rounded,
          'Expired',
          'Renew your plan to continue',
          [Colors.red.shade400, Colors.red.shade700],
        ),
      _ => (
          Icons.access_time_rounded,
          'Free Trial',
          daysLeft > 0 ? '$daysLeft days remaining — pick a plan below' : 'Trial ended',
          [Colors.blue.shade400, Colors.blue.shade700],
        ),
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Icon(icon, color: Colors.white, size: 36),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(desc, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ]),
        ),
      ]),
    );
  }
}

// ─── Current plan card (active shops) ────────────────────────────────────────

class _CurrentPlanCard extends StatelessWidget {
  final _Plan plan;
  const _CurrentPlanCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: plan.color.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(plan.icon, color: plan.color, size: 22),
          const SizedBox(width: 8),
          Text('${plan.label} Plan',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15, color: plan.color)),
          const Spacer(),
          Text('₹${plan.price}/month',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ]),
        if (plan.waInfo.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Icon(Icons.chat_outlined, size: 14, color: Color(0xFF2D6A4F)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(plan.waInfo,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF2D6A4F))),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

// ─── Usage tracking card ──────────────────────────────────────────────────────

class _UsageCard extends StatelessWidget {
  final _Plan? plan;
  final Map<String, dynamic> usage;
  const _UsageCard({required this.plan, required this.usage});

  @override
  Widget build(BuildContext context) {
    if (plan == null || plan!.id == 'lite') return const SizedBox.shrink();

    final waLimit = plan!.id == 'standard'
        ? 200
        : plan!.id == 'pro'
            ? 600
            : 2000;
    final broadcastLimit = plan!.id == 'standard'
        ? 30
        : plan!.id == 'pro'
            ? 100
            : 300;

    final waUsed = (usage['waUtilityCount'] as num?)?.toInt() ?? 0;
    final broadcastUsed = (usage['waMarketingCount'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('This Month\'s Usage',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 12),
        _UsageMeter(
            label: 'WhatsApp AI replies',
            used: waUsed,
            limit: waLimit,
            overageRate: '₹0.32'),
        const SizedBox(height: 10),
        _UsageMeter(
            label: 'Broadcasts sent',
            used: broadcastUsed,
            limit: broadcastLimit,
            overageRate: '₹0.80'),
        const SizedBox(height: 8),
        Text(
          'Overage charged automatically at month end.',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
      ]),
    );
  }
}

class _UsageMeter extends StatelessWidget {
  final String label;
  final int used;
  final int limit;
  final String overageRate;
  const _UsageMeter(
      {required this.label,
      required this.used,
      required this.limit,
      required this.overageRate});

  @override
  Widget build(BuildContext context) {
    final ratio = limit > 0 ? (used / limit).clamp(0.0, 1.0) : 0.0;
    final overage = used > limit ? used - limit : 0;
    final color = ratio >= 1.0
        ? AppColors.error
        : ratio >= 0.8
            ? Colors.orange
            : AppColors.success;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        Text('$used / $limit',
            style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 13)),
      ]),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: ratio,
          color: color,
          backgroundColor: Colors.grey.shade200,
          minHeight: 8,
        ),
      ),
      if (overage > 0) ...[
        const SizedBox(height: 3),
        Text('Overage: $overage × $overageRate = ₹${(overage * double.parse(overageRate.substring(1))).toStringAsFixed(0)}',
            style: const TextStyle(color: AppColors.error, fontSize: 11)),
      ],
    ]);
  }
}

// ─── Plan selector grid ───────────────────────────────────────────────────────

class _PlanSelector extends StatelessWidget {
  final String currentPlanId;
  final _Plan? selected;
  final bool isAnnual;
  final ValueChanged<_Plan> onSelect;
  const _PlanSelector({
    required this.currentPlanId,
    required this.selected,
    required this.isAnnual,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const Align(
        alignment: Alignment.centerLeft,
        child: Text('Choose a Plan',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ),
      const SizedBox(height: 12),
      ..._plans.map((plan) {
        final isCurrent = plan.id == currentPlanId;
        final isSelected = selected?.id == plan.id;
        return _PlanCard(
          plan: plan,
          isCurrent: isCurrent,
          isSelected: isSelected,
          isAnnual: isAnnual,
          onTap: () => onSelect(plan),
        );
      }),
    ]);
  }
}

class _PlanCard extends StatelessWidget {
  final _Plan plan;
  final bool isCurrent;
  final bool isSelected;
  final bool isAnnual;
  final VoidCallback onTap;
  const _PlanCard({
    required this.plan,
    required this.isCurrent,
    required this.isSelected,
    required this.isAnnual,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayPrice = isAnnual ? plan.annualPrice() : plan.price;
    final displayOriginal = isAnnual ? plan.originalPrice * 10 : plan.originalPrice;
    final priceLabel = isAnnual ? '/year' : '/month';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? plan.color.withValues(alpha: 0.06)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? plan.color
                : plan.isPopular
                    ? plan.color.withValues(alpha: 0.4)
                    : Colors.grey.shade200,
            width: isSelected || plan.isPopular ? 2 : 1,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Popular badge (above card header)
          if (plan.isPopular) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: plan.color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.star_rounded, size: 13, color: Colors.white),
                SizedBox(width: 4),
                Text('Most Popular',
                    style: TextStyle(
                        color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ]),
            ),
          ],
          Row(children: [
            Icon(plan.icon, color: plan.color, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(plan.label,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16, color: plan.color)),
                Text(plan.tagline,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ]),
            ),
            if (isCurrent) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Current',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.success,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ]),
          const SizedBox(height: 10),
          // Price row with strike-through
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('₹$displayPrice',
                style: TextStyle(
                    fontSize: 26, fontWeight: FontWeight.bold, color: plan.color)),
            const SizedBox(width: 4),
            Text(priceLabel,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(width: 10),
            Text('₹$displayOriginal',
                style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    decoration: TextDecoration.lineThrough)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE0B2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Save ₹${displayOriginal - displayPrice}',
                style: const TextStyle(
                    fontSize: 10, color: Color(0xFFE65100), fontWeight: FontWeight.bold),
              ),
            ),
          ]),
          if (isAnnual) ...[
            const SizedBox(height: 2),
            Text(
              '₹${plan.price}/month × 10 months — 2 months FREE',
              style: TextStyle(fontSize: 11, color: Colors.green.shade700),
            ),
          ],
          if (plan.waInfo.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Icon(Icons.chat_outlined, size: 13, color: Color(0xFF2D6A4F)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(plan.waInfo,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF2D6A4F))),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 10),
          ...plan.features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.check_circle_outline,
                      size: 15, color: AppColors.success),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(f,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textPrimary))),
                ]),
              )),
          if (plan.lockedFeatures.isNotEmpty) ...[
            const SizedBox(height: 2),
            ...plan.lockedFeatures.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.lock_outline, size: 15, color: Colors.grey.shade400),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(f,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade400))),
                  ]),
                )),
          ],
        ]),
      ),
    );
  }
}

// ─── Payment section ──────────────────────────────────────────────────────────

class _PaymentSection extends StatelessWidget {
  final _Plan plan;
  final bool isAnnual;
  final int amount;
  final bool submitting;
  final bool showRazorpay;
  final String upiId;
  final VoidCallback onRazorpay;
  final VoidCallback onUpi;
  final VoidCallback onConfirm;

  const _PaymentSection({
    required this.plan,
    required this.isAnnual,
    required this.amount,
    required this.submitting,
    required this.showRazorpay,
    required this.upiId,
    required this.onRazorpay,
    required this.onUpi,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final cycleLabel = isAnnual ? 'year (2 months free!)' : 'month';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.shade200),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.info_outline, size: 16, color: Colors.amber),
            const SizedBox(width: 6),
            Expanded(
              child: Text('${plan.label} plan — ₹$amount/$cycleLabel',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ]),
          const SizedBox(height: 8),
          const Text(
            '1. Tap the pay button below\n'
            '2. Complete payment in your UPI app\n'
            '3. Tap "I\'ve paid" — we\'ll activate within 2 hours',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      if (showRazorpay) ...[
        ElevatedButton.icon(
          icon: const Icon(Icons.credit_card_outlined, size: 20),
          label: Text(
            submitting ? 'Loading...' : 'Pay ₹$amount (Card / UPI / NetBanking)',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          onPressed: submitting ? null : onRazorpay,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2D6A4F),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
        ),
        const SizedBox(height: 10),
        const Row(children: [
          Expanded(child: Divider()),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child:
                Text('or pay manually', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ),
          Expanded(child: Divider()),
        ]),
        const SizedBox(height: 10),
      ],
      ElevatedButton.icon(
        icon: const Icon(Icons.currency_rupee, size: 20),
        label: Text('Pay ₹$amount via UPI',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        onPressed: onUpi,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        icon: submitting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.check_circle_outline, size: 20),
        label: const Text('I\'ve paid — notify us to activate',
            style: TextStyle(fontSize: 14)),
        onPressed: submitting ? null : onConfirm,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      const SizedBox(height: 8),
      if (upiId.isNotEmpty)
        InkWell(
          onTap: () {
            Clipboard.setData(ClipboardData(text: upiId));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('UPI ID copied')),
            );
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Icon(Icons.account_balance_wallet_outlined,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('UPI: $upiId',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
              const Icon(Icons.copy, size: 14, color: AppColors.textSecondary),
            ]),
          ),
        ),
    ]);
  }
}

// ─── Billing toggle (monthly / annual) ───────────────────────────────────────

class _BillingToggle extends StatelessWidget {
  final bool isAnnual;
  final ValueChanged<bool> onToggle;
  const _BillingToggle({required this.isAnnual, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(children: [
        Expanded(
          child: GestureDetector(
            onTap: () => onToggle(false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: !isAnnual ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(26),
                boxShadow: !isAnnual
                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6)]
                    : [],
              ),
              child: Center(
                child: Text('Monthly',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: !isAnnual ? AppColors.primary : AppColors.textSecondary)),
              ),
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => onToggle(true),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isAnnual ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(26),
                boxShadow: isAnnual
                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6)]
                    : [],
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('Annual',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isAnnual ? AppColors.primary : AppColors.textSecondary)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade600,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('2 FREE',
                      style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─── Trust badges ─────────────────────────────────────────────────────────────

class _TrustBadges extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(children: [
        const Text('Why Kerala shops choose weKerala',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _TrustBadge(icon: Icons.replay_rounded, label: '7-Day\nRefund'),
          _TrustBadge(icon: Icons.cancel_outlined, label: 'Cancel\nAnytime'),
          _TrustBadge(icon: Icons.store_outlined, label: '50+ Kerala\nShops'),
          _TrustBadge(icon: Icons.support_agent_outlined, label: 'WhatsApp\nSupport'),
        ]),
      ]),
    );
  }
}

class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TrustBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Icon(icon, size: 26, color: AppColors.primary),
      const SizedBox(height: 4),
      Text(label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, height: 1.3)),
    ]);
  }
}

// ─── Select plan hint ─────────────────────────────────────────────────────────

class _SelectPlanHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: const Row(children: [
        Icon(Icons.touch_app_outlined, color: AppColors.primary),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'Tap a plan above to see pricing and activate your subscription.',
            style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
        ),
      ]),
    );
  }
}

// ─── Pending card ─────────────────────────────────────────────────────────────

class _PendingCard extends StatelessWidget {
  final String shopId;
  final String supportWa;
  const _PendingCard({required this.shopId, required this.supportWa});

  @override
  Widget build(BuildContext context) {
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
        const Text(
          'We\'re verifying your payment.\nYou\'ll be activated within 2 hours.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        if (supportWa.isNotEmpty) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.chat, size: 18),
            label: const Text('Message us on WhatsApp'),
            onPressed: () async {
              final msg = Uri.encodeComponent(
                  'Hi, I\'ve paid for Oratas. Shop ID: $shopId. Please activate.');
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
