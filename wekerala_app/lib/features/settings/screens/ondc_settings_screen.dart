import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/shop_provider.dart';

class OndcSettingsScreen extends ConsumerStatefulWidget {
  const OndcSettingsScreen({super.key});

  @override
  ConsumerState<OndcSettingsScreen> createState() => _OndcSettingsScreenState();
}

class _OndcSettingsScreenState extends ConsumerState<OndcSettingsScreen> {
  final _sellerIdController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _sellerIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shopAsync = ref.watch(activeShopIdProvider);
    final shopId = shopAsync.valueOrNull ?? '';
    final shopAsync2 = ref.watch(shopStreamProvider(shopId));
    final shop = shopAsync2.valueOrNull;

    // Pre-fill seller ID field if it exists and field is still empty
    if (shop != null &&
        _sellerIdController.text.isEmpty &&
        (shop.ondcSellerId?.isNotEmpty == true)) {
      _sellerIdController.text = shop.ondcSellerId!;
    }

    final isConnected = shop?.ondcSellerId?.isNotEmpty == true;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('ONDC Integration'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── What is ONDC banner ──────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.store_outlined, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'What is ONDC?',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ]),
                SizedBox(height: 8),
                Text(
                  'ONDC is India\'s open commerce network backed by the Government of India. '
                  'List your shop on ONDC and receive orders from Swiggy, Meesho, Juspay, '
                  'and 20+ buyer apps — all managed in one place.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '400+ cities  |  Zero listing fee  |  3-12% commission vs Amazon\'s 15-35%',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Status card ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ONDC Status',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: isConnected ? Colors.green : Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isConnected
                          ? 'Active — Receiving ONDC Orders'
                          : 'Not Connected',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isConnected
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
                if (isConnected) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Seller ID: ${shop!.ondcSellerId}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Webhook: https://us-central1-shoplink-prod.cloudfunctions.net/ondcWebhook',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── How to connect ──────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How to Connect',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                SizedBox(height: 12),
                _StepTile(
                  number: '1',
                  text: 'Register on eSamudaay or Mystore as an ONDC seller',
                ),
                _StepTile(
                  number: '2',
                  text: 'Get your Seller ID (Provider ID) from the platform',
                ),
                _StepTile(number: '3', text: 'Enter your Seller ID below'),
                _StepTile(
                  number: '4',
                  text:
                      'Set your Webhook URL in eSamudaay to the URL shown below',
                ),
                _StepTile(
                  number: '5',
                  text:
                      'Your products sync automatically and ONDC orders appear here',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Seller ID input ─────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your ONDC Seller ID',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Enter the Provider ID from your eSamudaay / Mystore account',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _sellerIdController,
                  decoration: InputDecoration(
                    hintText: 'e.g., provider.wekerala.myshop.001',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        _isSaving ? null : () => _saveSellerId(shopId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Save Seller ID',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Webhook URL copy card ────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.link_outlined,
                      color: Colors.blue.shade700, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Your Webhook URL',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                const Text(
                  'Copy this URL and paste it as your webhook in eSamudaay:',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'https://us-central1-shoplink-prod.cloudfunctions.net/ondcWebhook',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue.shade700,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_outlined, size: 18),
                      onPressed: () {
                        Clipboard.setData(const ClipboardData(
                          text:
                              'https://us-central1-shoplink-prod.cloudfunctions.net/ondcWebhook',
                        ));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Webhook URL copied!')),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _saveSellerId(String shopId) async {
    if (shopId.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .update({'ondcSellerId': _sellerIdController.text.trim()});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ONDC Seller ID saved!'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

// ── Step tile widget ───────────────────────────────────────────────────────────

class _StepTile extends StatelessWidget {
  final String number;
  final String text;
  const _StepTile({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
