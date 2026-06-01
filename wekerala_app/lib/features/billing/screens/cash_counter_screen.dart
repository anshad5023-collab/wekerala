import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/billing_provider.dart';
import '../../../providers/shop_provider.dart';

// Denomination → count → total
const _denoms = [500, 200, 100, 50, 20, 10, 5, 2, 1];

class CashCounterScreen extends ConsumerStatefulWidget {
  const CashCounterScreen({super.key});

  @override
  ConsumerState<CashCounterScreen> createState() => _CashCounterScreenState();
}

class _CashCounterScreenState extends ConsumerState<CashCounterScreen> {
  final Map<int, TextEditingController> _controllers = {
    for (final d in _denoms) d: TextEditingController(),
  };

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _handCount => _denoms.fold(0.0, (sum, d) {
        final n = int.tryParse(_controllers[d]!.text) ?? 0;
        return sum + d * n;
      });

  @override
  Widget build(BuildContext context) {
    final shopIdAsync = ref.watch(activeShopIdProvider);
    final shopId = shopIdAsync.valueOrNull ?? '';
    final summary = ref.watch(dailySalesSummaryProvider(shopId));
    final systemCash = summary['cashTotal'] ?? 0.0;
    final handCount = _handCount;
    final variance = handCount - systemCash;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Cash Counter'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // System vs hand totals
                _TotalsCard(
                  systemCash: systemCash,
                  handCount: handCount,
                  variance: variance,
                ),
                const SizedBox(height: 20),

                const Text(
                  'COUNT NOTES & COINS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: _denoms.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final d = entry.value;
                      final isLast = idx == _denoms.length - 1;
                      return _DenomRow(
                        denom: d,
                        controller: _controllers[d]!,
                        isLast: isLast,
                        onChanged: () => setState(() {}),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Bottom reset button
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            color: Colors.white,
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.textSecondary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  for (final c in _controllers.values) {
                    c.clear();
                  }
                  setState(() {});
                },
                child: const Text(
                  'Reset',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  final double systemCash;
  final double handCount;
  final double variance;

  const _TotalsCard({
    required this.systemCash,
    required this.handCount,
    required this.variance,
  });

  @override
  Widget build(BuildContext context) {
    final isShort = variance < 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _StatBox(label: 'System Cash', value: '₹${systemCash.toStringAsFixed(2)}'),
              const SizedBox(width: 12),
              _StatBox(label: 'Hand Count', value: '₹${handCount.toStringAsFixed(2)}'),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  variance == 0
                      ? Icons.check_circle_outline
                      : isShort
                          ? Icons.arrow_downward
                          : Icons.arrow_upward,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  variance == 0
                      ? 'Balanced ✓'
                      : '${isShort ? 'Short' : 'Over'} by ₹${variance.abs().toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  const _StatBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 11)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18)),
        ],
      ),
    );
  }
}

class _DenomRow extends StatelessWidget {
  final int denom;
  final TextEditingController controller;
  final bool isLast;
  final VoidCallback onChanged;

  const _DenomRow({
    required this.denom,
    required this.controller,
    required this.isLast,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final count = int.tryParse(controller.text) ?? 0;
    final total = denom * count;

    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0xFFF0F0F0)),
              ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Denomination label
          SizedBox(
            width: 60,
            child: Text(
              '₹$denom',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          const Text('×',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
          const SizedBox(width: 12),
          // Count input
          SizedBox(
            width: 70,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '0',
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.surface),
                ),
                filled: true,
                fillColor: AppColors.surface,
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
          const Spacer(),
          // Running total
          Text(
            total > 0 ? '₹$total' : '—',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: total > 0 ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
