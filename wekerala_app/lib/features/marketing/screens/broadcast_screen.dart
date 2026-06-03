import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/shop_provider.dart';

// ── Providers ──────────────────────────────────────────────────────────────────

/// Fetches unique customer phone numbers from orders in the last 90 days.
final _recipientsProvider =
    FutureProvider.family<List<String>, String>((ref, shopId) async {
  if (shopId.isEmpty) return [];
  final cutoff = DateTime.now().subtract(const Duration(days: 90));
  final snap = await FirebaseFirestore.instance
      .collection('shops')
      .doc(shopId)
      .collection('orders')
      .where('createdAt', isGreaterThan: Timestamp.fromDate(cutoff))
      .get();

  final phones = <String>{};
  for (final doc in snap.docs) {
    final phone = doc.data()['customerPhone'] as String?;
    if (phone != null && phone.trim().length >= 10) {
      phones.add(phone.trim());
    }
  }
  return phones.toList();
});

// ── Screen ─────────────────────────────────────────────────────────────────────

class BroadcastScreen extends ConsumerStatefulWidget {
  const BroadcastScreen({super.key});

  @override
  ConsumerState<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends ConsumerState<BroadcastScreen> {
  static const _kGreen = Color(0xFF2D6A4F);
  static const _kMaxChars = 4096;

  final _controller = TextEditingController();
  bool _includeAll = true;
  bool _sending = false;

  // ── Template definitions ───────────────────────────────────────────────────
  static const _templates = [
    _Template(
      label: '🎉 Special Offer',
      body:
          'Hello! We have a special offer today at {shopName}. Visit: {url}',
    ),
    _Template(
      label: '📦 New Arrivals',
      body:
          'Hi! New products just arrived at {shopName}. Check them out: {url}',
    ),
    _Template(
      label: '🕐 Store Hours',
      body: 'Our store is open {hours}. Visit us at {url}',
    ),
    _Template(label: '💬 Custom', body: ''),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _buildPreview({
    required String message,
    required String shopName,
    required String url,
  }) {
    return message
        .replaceAll('{shopName}', shopName.isNotEmpty ? shopName : 'Your Shop')
        .replaceAll('{url}', url.isNotEmpty ? url : 'https://wekerala.vercel.app')
        .replaceAll('{hours}', '9 AM – 9 PM');
  }

  Future<void> _sendBroadcast(String shopId) async {
    final message = _controller.text.trim();
    if (message.isEmpty) {
      _showSnackBar('Please enter a message before sending.', isError: true);
      return;
    }
    if (message.length > _kMaxChars) {
      _showSnackBar('Message exceeds $_kMaxChars characters.', isError: true);
      return;
    }

    setState(() => _sending = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('sendBroadcast');
      final result = await callable.call<Map<String, dynamic>>({
        'shopId': shopId,
        'message': message,
      });
      final data = result.data;
      final sent = data['sent'] as int? ?? 0;
      final failed = data['failed'] as int? ?? 0;
      _showSnackBar(
        'Broadcast sent! $sent delivered${failed > 0 ? ', $failed failed' : ''}.',
      );
      _controller.clear();
    } on FirebaseFunctionsException catch (e) {
      _showSnackBar('Error: ${e.message}', isError: true);
    } catch (e) {
      _showSnackBar('Unexpected error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showSnackBar(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final shopAsync = ref.watch(activeShopIdProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('WhatsApp Broadcast'),
        backgroundColor: _kGreen,
        foregroundColor: Colors.white,
      ),
      body: shopAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (shopId) => _Body(
          shopId: shopId ?? '',
          controller: _controller,
          includeAll: _includeAll,
          sending: _sending,
          onIncludeAllChanged: (v) => setState(() => _includeAll = v ?? true),
          onSend: () => _sendBroadcast(shopId ?? ''),
          buildPreview: _buildPreview,
          templates: _templates,
        ),
      ),
    );
  }
}

// ── Body ───────────────────────────────────────────────────────────────────────

class _Body extends ConsumerStatefulWidget {
  final String shopId;
  final TextEditingController controller;
  final bool includeAll;
  final bool sending;
  final ValueChanged<bool?> onIncludeAllChanged;
  final VoidCallback onSend;
  final String Function({
    required String message,
    required String shopName,
    required String url,
  }) buildPreview;
  final List<_Template> templates;

  const _Body({
    required this.shopId,
    required this.controller,
    required this.includeAll,
    required this.sending,
    required this.onIncludeAllChanged,
    required this.onSend,
    required this.buildPreview,
    required this.templates,
  });

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  static const _kGreen = Color(0xFF2D6A4F);
  int _charCount = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    setState(() => _charCount = widget.controller.text.length);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shopStream = widget.shopId.isNotEmpty
        ? ref.watch(shopStreamProvider(widget.shopId))
        : null;

    final shopName =
        shopStream?.whenOrNull(data: (s) => s.shopName) ?? '';
    final slug =
        shopStream?.whenOrNull(data: (s) => s.shopSlug) ?? '';
    final url = slug.isNotEmpty
        ? 'https://wekerala.vercel.app/shops/$slug'
        : (widget.shopId.isNotEmpty
            ? 'https://wekerala.vercel.app/shop?shopId=${widget.shopId}'
            : '');

    final recipientsAsync = widget.shopId.isNotEmpty
        ? ref.watch(_recipientsProvider(widget.shopId))
        : null;

    final previewText = widget.buildPreview(
      message: widget.controller.text,
      shopName: shopName,
      url: url,
    );

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // ── Templates ──────────────────────────────────────────────────────
        _SectionHeader('Message Templates'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.templates.map((t) {
            return ActionChip(
              label: Text(t.label),
              backgroundColor: _kGreen.withValues(alpha: 0.08),
              side: BorderSide(color: _kGreen.withValues(alpha: 0.3)),
              labelStyle: const TextStyle(
                color: _kGreen,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              onPressed: () {
                widget.controller.text = t.body;
                widget.controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: t.body.length),
                );
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 14),

        // ── Message field ─────────────────────────────────────────────────
        TextField(
          controller: widget.controller,
          maxLines: 5,
          maxLength: _BroadcastScreenState._kMaxChars,
          buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
              null, // hide default counter; we show our own below
          decoration: InputDecoration(
            hintText: 'Type your promotional message here...',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kGreen, width: 1.5),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '$_charCount / ${_BroadcastScreenState._kMaxChars}',
            style: TextStyle(
              fontSize: 11,
              color: _charCount > _BroadcastScreenState._kMaxChars
                  ? AppColors.error
                  : AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── Recipients ────────────────────────────────────────────────────
        _SectionHeader('Recipients'),
        const SizedBox(height: 8),
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (recipientsAsync == null)
                const Text('No shop selected.')
              else
                recipientsAsync.when(
                  loading: () => const Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Text('Loading customers...'),
                    ],
                  ),
                  error: (e, _) => Text(
                    'Could not load customers: $e',
                    style: const TextStyle(color: AppColors.error, fontSize: 13),
                  ),
                  data: (phones) => Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _kGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${phones.length} customers found',
                          style: const TextStyle(
                            color: _kGreen,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '(last 90 days)',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: widget.includeAll,
                onChanged: widget.onIncludeAllChanged,
                title: const Text(
                  'Include all customers',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                activeColor: _kGreen,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Preview ───────────────────────────────────────────────────────
        _SectionHeader('Preview'),
        const SizedBox(height: 8),
        _SectionCard(
          child: widget.controller.text.isEmpty
              ? Text(
                  'Your message preview will appear here once you type a message above.',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontStyle: FontStyle.italic),
                )
              : Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCF8C6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.phone_android, size: 12, color: Color(0xFF777777)),
                        const SizedBox(width: 4),
                        const Text('Preview (as customer sees it)',
                            style: TextStyle(fontSize: 10, color: Color(0xFF777777))),
                      ]),
                      const SizedBox(height: 6),
                      _WhatsAppText(previewText),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 28),

        // ── Send button ───────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: widget.sending ? null : widget.onSend,
            icon: widget.sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Icon(Icons.send_rounded, size: 20),
            label: Text(
              widget.sending ? 'Sending...' : 'Send Broadcast',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kGreen,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _kGreen.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ── Shared sub-widgets ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: child,
    );
  }
}

// ── Template data class ────────────────────────────────────────────────────────

class _Template {
  final String label;
  final String body;
  const _Template({required this.label, required this.body});
}

// ── WhatsApp markdown renderer ─────────────────────────────────────────────────
// Renders *bold*, _italic_, ~strikethrough~ exactly as WhatsApp displays them.

class _WhatsAppText extends StatelessWidget {
  final String text;
  const _WhatsAppText(this.text);

  List<InlineSpan> _parse(String input) {
    final spans = <InlineSpan>[];
    // Matches *bold*, _italic_, ~strikethrough~ — non-greedy, no nesting
    final regex = RegExp(r'\*((?:[^*])+)\*|_((?:[^_])+)_|~((?:[^~])+)~');
    int last = 0;
    for (final m in regex.allMatches(input)) {
      if (m.start > last) {
        spans.addAll(_plainLines(input.substring(last, m.start)));
      }
      if (m.group(1) != null) {
        spans.add(TextSpan(
          text: m.group(1),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ));
      } else if (m.group(2) != null) {
        spans.add(TextSpan(
          text: m.group(2),
          style: const TextStyle(fontStyle: FontStyle.italic),
        ));
      } else if (m.group(3) != null) {
        spans.add(TextSpan(
          text: m.group(3),
          style: const TextStyle(decoration: TextDecoration.lineThrough),
        ));
      }
      last = m.end;
    }
    if (last < input.length) spans.addAll(_plainLines(input.substring(last)));
    return spans;
  }

  List<InlineSpan> _plainLines(String text) => [TextSpan(text: text)];

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: _parse(text),
      style: const TextStyle(fontSize: 14, height: 1.5),
    ),
  );
}
