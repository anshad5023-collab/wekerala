import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/gemini_service.dart';
import '../../../models/forecast_model.dart';
import '../../../models/product_model.dart';
import '../../../providers/products_provider.dart';
import '../../../providers/shop_provider.dart';

/// Live forecasts for a shop, keyed by productId. Computed nightly by the
/// `computeForecasts` Cloud Function and stored at shops/{id}/forecasts/{pid}.
final forecastsProvider =
    StreamProvider.family<Map<String, ForecastModel>, String>((ref, shopId) {
  return FirebaseFirestore.instance
      .collection('shops')
      .doc(shopId)
      .collection('forecasts')
      .snapshots()
      .map((snap) {
    final m = <String, ForecastModel>{};
    for (final d in snap.docs) {
      final f = ForecastModel.fromFirestore(d);
      m[f.productId] = f;
    }
    return m;
  });
});

class ReorderScreen extends ConsumerWidget {
  const ReorderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopAsync = ref.watch(activeShopIdProvider);
    return shopAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: Text(e.toString())),
      ),
      data: (shopId) {
        if (shopId == null) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: Text('No active shop found.')),
          );
        }
        return _ReorderBody(shopId: shopId);
      },
    );
  }
}

class _ReorderBody extends ConsumerStatefulWidget {
  final String shopId;
  const _ReorderBody({required this.shopId});

  @override
  ConsumerState<_ReorderBody> createState() => _ReorderBodyState();
}

/// A product paired with its forecast (forecast may be null = no recent sales).
class _Row {
  final ProductModel product;
  final ForecastModel? forecast;
  _Row(this.product, this.forecast);

  bool get tracked => product.stockQty != null;
  double? get daysCover => forecast?.daysCover;
  int get recommendedQty => forecast?.recommendedQty ?? 0;

  /// Urgency: lower = more urgent. Out/over-due first, then soonest run-out.
  double get urgency {
    if (!tracked) return 9e8;
    final c = daysCover;
    if (c == null) {
      // No demand signal — only urgent if already at/below threshold.
      return product.isLowStock ? 100 : 9e7;
    }
    return c;
  }

  bool get needsOrder => recommendedQty > 0 || (tracked && (daysCover ?? 999) <= 7);
}

class _ReorderBodyState extends ConsumerState<_ReorderBody> {
  bool _askingGemini = false;
  String? _suggestion;
  Set<String> _orderedProductIds = {};

  String get _prefsKey {
    final t = DateTime.now();
    return 'reorder_ordered_${widget.shopId}_${t.year}_${t.month}_${t.day}';
  }

  @override
  void initState() {
    super.initState();
    _loadOrderedState();
  }

  Future<void> _loadOrderedState() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_prefsKey) ?? [];
    if (mounted) setState(() => _orderedProductIds = stored.toSet());
  }

  Future<void> _markOrdered(String productId) async {
    setState(() => _orderedProductIds.add(productId));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _orderedProductIds.toList());
  }

  Future<void> _askGemini(List<_Row> rows) async {
    setState(() {
      _askingGemini = true;
      _suggestion = null;
    });
    final ctx = rows.take(40).map((r) => {
          'name': r.product.nameEn,
          'stock': r.product.stockQty ?? 0,
          'dailyDemand': r.forecast?.dailyDemand ?? 0,
          'daysCover': r.daysCover?.round() ?? 'n/a',
          'recommendedOrder': r.recommendedQty,
          'unit': r.product.unit,
        }).toList();
    final result = await GeminiService.getReorderSuggestions(ctx);
    if (mounted) {
      setState(() {
        _suggestion = result;
        _askingGemini = false;
      });
    }
  }

  void _copyToWhatsApp(List<_Row> rows) {
    final toOrder = rows.where((r) => r.recommendedQty > 0).toList();
    if (toOrder.isEmpty) return;
    final buf = StringBuffer()
      ..writeln('📦 *Reorder List*')
      ..writeln('─────────────────');
    for (final r in toOrder) {
      buf.writeln('• ${r.product.nameEn}: ${r.recommendedQty} ${r.product.unit}');
    }
    buf
      ..writeln('─────────────────')
      ..writeln('Please arrange ASAP. Thank you!');
    final text = buf.toString().trim();
    Clipboard.setData(ClipboardData(text: text));
    launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}'),
        mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsStreamProvider(widget.shopId));
    final forecastsAsync = ref.watch(forecastsProvider(widget.shopId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Smart Reorder 🤖',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: productsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (products) {
          final forecasts = forecastsAsync.valueOrNull ?? const {};
          final rows = products
              .map((p) => _Row(p, forecasts[p.productId]))
              .where((r) => r.tracked) // only stock-tracked products
              .toList()
            ..sort((a, b) => a.urgency.compareTo(b.urgency));

          final needCount = rows.where((r) => r.needsOrder).length;
          // Freshness from any forecast doc.
          final updatedAt = forecasts.values.isEmpty
              ? null
              : forecasts.values
                  .map((f) => f.updatedAt)
                  .reduce((a, b) => a.isAfter(b) ? a : b);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              _summaryBanner(needCount, rows.length, updatedAt),
              const SizedBox(height: 10),
              _targetDaysControl(),
              const SizedBox(height: 12),
              if (needCount > 0)
                OutlinedButton.icon(
                  onPressed: () => _copyToWhatsApp(rows),
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy reorder list to WhatsApp'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    minimumSize: const Size(double.infinity, 46),
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _askingGemini ? null : () => _askGemini(rows),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: _askingGemini
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.auto_awesome),
                label: Text(
                    _askingGemini ? 'Asking Gemini AI...' : 'Ask Gemini to explain',
                    style:
                        const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              if (_suggestion != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25)),
                  ),
                  child: Text(_suggestion!,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                          height: 1.6)),
                ).animate().fadeIn(duration: 300.ms),
              ],
              const SizedBox(height: 18),
              const Text('INVENTORY FORECAST',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'No stock-tracked products yet.\n'
                      'Turn on stock tracking for products to get forecasts.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                ...rows.asMap().entries.map((e) => _ProductRow(
                      row: e.value,
                      isOrdered: _orderedProductIds.contains(e.value.product.productId),
                      onMarkOrdered: () => _markOrdered(e.value.product.productId),
                    ).animate().fadeIn(
                        duration: 220.ms,
                        delay: Duration(milliseconds: 30 + e.key * 25))),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryBanner(int needCount, int total, DateTime? updatedAt) {
    final fresh = updatedAt != null
        ? 'Updated ${_ago(updatedAt)}'
        : 'Forecast updates nightly';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: needCount > 0 ? Colors.red.shade50 : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: needCount > 0
                ? Colors.red.shade200
                : AppColors.textSecondary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(needCount > 0 ? Icons.trending_down : Icons.check_circle_outline,
              color: needCount > 0 ? Colors.red : AppColors.success, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  needCount > 0
                      ? '$needCount product${needCount == 1 ? '' : 's'} to reorder soon'
                      : 'Stock levels look healthy',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color:
                          needCount > 0 ? Colors.red.shade700 : AppColors.success),
                ),
                Text('$total tracked  •  $fresh',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _targetDaysControl() {
    final shop = ref.watch(shopStreamProvider(widget.shopId)).valueOrNull;
    final target = shop?.targetDaysCover ?? 0;
    final label = target > 0
        ? 'Keep $target days of stock'
        : 'Set stock target (using 14 days)';
    return InkWell(
      onTap: () => _editTargetDays(target),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.flag_outlined, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary)),
            ),
            const Icon(Icons.edit, size: 15, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Future<void> _editTargetDays(int current) async {
    final ctrl =
        TextEditingController(text: current > 0 ? current.toString() : '14');
    final value = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Stock target'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'How many days of stock should the shop keep on hand? '
                'This drives the suggested order quantities.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Days of cover',
                suffixText: 'days',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, int.tryParse(ctrl.text.trim()) ?? 0),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (value == null || value <= 0) return;
    await FirebaseFirestore.instance
        .collection('shops')
        .doc(widget.shopId)
        .update({'targetDaysCover': value});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Stock target set to $value days. '
            'New order suggestions apply after tonight\'s update.'),
        backgroundColor: AppColors.success,
      ));
    }
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return DateFormat('d MMM').format(t);
  }
}

class _ProductRow extends StatelessWidget {
  final _Row row;
  final bool isOrdered;
  final VoidCallback onMarkOrdered;

  const _ProductRow({
    required this.row,
    required this.isOrdered,
    required this.onMarkOrdered,
  });

  @override
  Widget build(BuildContext context) {
    final p = row.product;
    final f = row.forecast;
    final stock = p.stockQty ?? 0;
    final cover = row.daysCover;
    final orderQty = row.recommendedQty;
    final urgent = (cover != null && cover <= 7) || stock <= 0;

    // Run-out text
    String coverText;
    Color coverColor;
    if (f == null || !f.hasDemand) {
      coverText = 'No recent sales';
      coverColor = AppColors.textSecondary;
    } else if (cover == null) {
      coverText = 'In stock';
      coverColor = AppColors.success;
    } else if (cover <= 0) {
      coverText = 'Out of stock';
      coverColor = Colors.red;
    } else {
      coverText = 'Runs out in ~${cover.round()} day${cover.round() == 1 ? '' : 's'}';
      coverColor = cover <= 7 ? Colors.red : (cover <= 14 ? const Color(0xFFF57C00) : AppColors.success);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOrdered
              ? Colors.green.shade200
              : urgent
                  ? Colors.red.shade200
                  : AppColors.textSecondary.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 4),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOrdered
                    ? Colors.green
                    : urgent
                        ? Colors.red
                        : AppColors.success,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.nameEn,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(coverText,
                    style: TextStyle(
                        fontSize: 12,
                        color: coverColor,
                        fontWeight: FontWeight.w500)),
                if (f != null && f.hasDemand)
                  Text(
                      '~${f.dailyDemand.toStringAsFixed(f.dailyDemand < 1 ? 2 : 1)}/day'
                      '  •  ${f.confidence} confidence',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                if (orderQty > 0 && !isOrdered) ...[
                  const SizedBox(height: 4),
                  Text('Order: $orderQty ${p.unit}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                  TextButton(
                    onPressed: onMarkOrdered,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.green.shade700,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Mark Ordered',
                        style: TextStyle(fontSize: 12)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isOrdered
                      ? Colors.green.shade50
                      : urgent
                          ? Colors.red.shade50
                          : AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$stock ${p.unit}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isOrdered
                            ? Colors.green.shade700
                            : urgent
                                ? Colors.red.shade700
                                : AppColors.primary)),
              ),
              if (isOrdered)
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.check_circle, color: Colors.green, size: 16),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
