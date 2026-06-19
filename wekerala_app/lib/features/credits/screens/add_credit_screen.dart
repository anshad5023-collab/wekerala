import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/credit_model.dart';
import '../../../models/customer_model.dart';
import '../../../providers/credits_provider.dart';
import '../../../providers/shop_provider.dart';

class AddCreditScreen extends ConsumerStatefulWidget {
  const AddCreditScreen({super.key});

  @override
  ConsumerState<AddCreditScreen> createState() => _AddCreditScreenState();
}

class _AddCreditScreenState extends ConsumerState<AddCreditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  DateTime? _dueDate;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  // ─── Date picker ───────────────────────────────────────────────────────────

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  // ─── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save(String shopId) async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountCtrl.text.trim());
    final phone = _phoneCtrl.text.trim();

    // ── Credit limit enforcement ─────────────────────────────────────────────
    // Block if this new udhar would push the customer's outstanding balance over
    // their set credit limit. Warn (but allow) when reaching 80%.
    bool nearLimitWarning = false;
    if (phone.isNotEmpty) {
      try {
        final custSnap = await FirebaseFirestore.instance
            .collection('shops').doc(shopId)
            .collection('customers').doc(phone).get();
        if (custSnap.exists) {
          final d = custSnap.data()!;
          final limit = (d['creditLimit'] as num?)?.toDouble() ?? 0;
          final balance = (d['udharBalance'] as num?)?.toDouble() ?? 0;
          if (limit > 0) {
            final newTotal = balance + amount;
            if (newTotal > limit) {
              if (mounted) {
                _showLimitBlockedDialog(balance, amount, limit);
              }
              return; // hard block
            } else if (newTotal >= limit * 0.8) {
              nearLimitWarning = true;
            }
          }
        }
      } catch (_) {/* if the check fails, don't block a legitimate sale */}
    }

    setState(() => _isSaving = true);

    try {
      final col = FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('credits');
      final creditId = col.doc().id;

      final credit = CreditModel(
        creditId: creditId,
        customerName: _nameCtrl.text.trim(),
        customerPhone: phone,
        amount: amount,
        paidAmount: 0,
        note: _noteCtrl.text.trim(),
        status: 'open',
        createdAt: DateTime.now(),
        dueDate: _dueDate,
      );

      await CreditsRepository.add(shopId, credit);

      // Ensure the customer appears in the customer list even if they've never placed an order
      if (credit.customerPhone.isNotEmpty) {
        await CustomerModel.upsertFromCredit(
          shopId: shopId,
          customerPhone: credit.customerPhone,
          customerName: credit.customerName,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(nearLimitWarning
                ? 'Credit added — customer is near their credit limit ⚠️'
                : 'Credit added successfully'),
            backgroundColor:
                nearLimitWarning ? Colors.orange.shade800 : AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showLimitBlockedDialog(double balance, double amount, double limit) {
    final f = NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.block, color: AppColors.error, size: 40),
        title: const Text('Credit limit reached'),
        content: Text(
          'This customer already owes ${f.format(balance)}.\n'
          'Adding ${f.format(amount)} would exceed their credit limit of '
          '${f.format(limit)}.\n\nCollect a payment first, or raise the limit '
          'from the customer\'s page.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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
        return _buildForm(shopId);
      },
    );
  }

  Widget _buildForm(String shopId) {
    final dueFmt = _dueDate != null
        ? DateFormat('d MMM yyyy').format(_dueDate!)
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Add Udhar Entry',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Section: Customer Info ────────────────────────────────────
              _SectionLabel(label: 'Customer Details'),
              const SizedBox(height: 10),

              // Customer Name
              _buildField(
                controller: _nameCtrl,
                label: 'Customer Name',
                hint: 'e.g. Rajan Pillai',
                prefixIcon: Icons.person_outline_rounded,
                textCapitalization: TextCapitalization.words,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Name is required';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Phone Number
              _buildField(
                controller: _phoneCtrl,
                label: 'Phone Number',
                hint: '9876543210',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Phone is required';
                  final digits = v.trim();
                  if (digits.length != 10) return 'Enter a valid 10-digit number';
                  if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
                    return 'Must start with 6, 7, 8, or 9';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // ── Section: Credit Details ───────────────────────────────────
              _SectionLabel(label: 'Credit Details'),
              const SizedBox(height: 10),

              // Amount
              _buildField(
                controller: _amountCtrl,
                label: 'Amount (₹)',
                hint: '0.00',
                prefixIcon: Icons.currency_rupee_rounded,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                validator: (v) {
                  final val = double.tryParse(v?.trim() ?? '');
                  if (val == null || val <= 0) {
                    return 'Enter a valid amount greater than 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Note
              TextFormField(
                controller: _noteCtrl,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'e.g. Rice, Sugar, Vegetables',
                  hintStyle: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                  prefixIcon: const Icon(Icons.notes_rounded,
                      color: AppColors.textSecondary),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 14),

              // ── Due Date picker ───────────────────────────────────────────
              _SectionLabel(label: 'Due Date (optional)'),
              const SizedBox(height: 10),

              InkWell(
                onTap: _pickDueDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                      color: _dueDate != null
                          ? AppColors.primary
                          : Colors.grey.shade300,
                      width: _dueDate != null ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 20,
                        color: _dueDate != null
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        dueFmt ?? 'Set due date',
                        style: TextStyle(
                          color: _dueDate != null
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontSize: 15,
                          fontWeight: _dueDate != null
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                      ),
                      const Spacer(),
                      if (_dueDate != null)
                        GestureDetector(
                          onTap: () => setState(() => _dueDate = null),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                        )
                      else
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSecondary,
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ── Save Button ───────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : () => _save(shopId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.primary.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Save Credit Entry',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Reusable text field ───────────────────────────────────────────────────

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle:
            const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        prefixIcon: Icon(prefixIcon, color: AppColors.textSecondary),
        counterText: maxLength != null ? '' : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 1.1,
      ),
    );
  }
}
