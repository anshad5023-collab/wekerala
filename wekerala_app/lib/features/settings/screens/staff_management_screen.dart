import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/role_provider.dart';
import '../../../shared/widgets/shimmer_list.dart';

class StaffManagementScreen extends ConsumerStatefulWidget {
  final String shopId;
  const StaffManagementScreen({super.key, required this.shopId});

  @override
  ConsumerState<StaffManagementScreen> createState() =>
      _StaffManagementScreenState();
}

class _StaffManagementScreenState extends ConsumerState<StaffManagementScreen> {
  final _phoneCtrl = TextEditingController();
  String _selectedRole = kRoleCashier;
  bool _adding = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  // ── Firestore helpers ──────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _staffCol =>
      FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.shopId)
          .collection('staff');

  Future<void> _addStaff() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) return;

    setState(() => _adding = true);
    try {
      // Look up the user by phone number in the users collection.
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'User not found. They must first sign in to the Oratas app.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      final uid = snap.docs.first.id;

      await _staffCol.doc(uid).set({
        'phone': phone,
        'role': _selectedRole,
        'addedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _phoneCtrl.clear();
        Navigator.pop(context); // close the bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Staff member added as ${_selectedRole == kRoleCashier ? 'Cashier' : 'Manager'}.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _removeStaff(BuildContext ctx, String uid, String phone) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Remove Staff'),
        content: Text('Remove $phone from staff?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _staffCol.doc(uid).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Staff member removed.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showAddSheet() {
    _phoneCtrl.clear();
    _selectedRole = kRoleCashier;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddStaffSheet(
        phoneCtrl: _phoneCtrl,
        initialRole: _selectedRole,
        adding: _adding,
        onRoleChanged: (r) => setState(() => _selectedRole = r),
        onAdd: _addStaff,
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Staff Management'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSheet,
        backgroundColor: AppColors.accent,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text(
          'Add Staff',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _staffCol.orderBy('addedAt', descending: false).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ShimmerList(itemCount: 5);
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.group_outlined,
                      size: 72, color: AppColors.textSecondary),
                  const SizedBox(height: 16),
                  const Text(
                    'No staff added yet',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap "Add Staff" to give a team member\naccess to this shop.',
                    style: TextStyle(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ).animate().fadeIn(duration: 400.ms),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final doc = docs[i];
              final data = doc.data();
              final phone = data['phone'] as String? ?? 'Unknown';
              final role = data['role'] as String? ?? kRoleCashier;
              final isCashier = role == kRoleCashier;

              return Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.12),
                    child: const Icon(Icons.person, color: AppColors.primary),
                  ),
                  title: Text(
                    phone,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                  ),
                  subtitle: Row(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isCashier
                              ? AppColors.accent.withValues(alpha: 0.15)
                              : AppColors.primaryLight.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isCashier ? 'Cashier' : 'Manager',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isCashier
                                ? AppColors.accent
                                : AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline,
                        color: Colors.red),
                    tooltip: 'Remove staff',
                    onPressed: () => _removeStaff(ctx, doc.id, phone),
                  ),
                ),
              ).animate().fadeIn(duration: 300.ms, delay: Duration(milliseconds: i * 50));
            },
          );
        },
      ),
    );
  }
}

// ─── Add Staff Bottom Sheet ────────────────────────────────────────────────────

class _AddStaffSheet extends StatefulWidget {
  final TextEditingController phoneCtrl;
  final String initialRole;
  final bool adding;
  final ValueChanged<String> onRoleChanged;
  final VoidCallback onAdd;

  const _AddStaffSheet({
    required this.phoneCtrl,
    required this.initialRole,
    required this.adding,
    required this.onRoleChanged,
    required this.onAdd,
  });

  @override
  State<_AddStaffSheet> createState() => _AddStaffSheetState();
}

class _AddStaffSheetState extends State<_AddStaffSheet> {
  late String _role;

  @override
  void initState() {
    super.initState();
    _role = widget.initialRole;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          const Text(
            'Add Staff Member',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            'The person must have signed in to the Oratas app at least once.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),

          // Phone field
          TextField(
            controller: widget.phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Phone Number',
              hintText: 'e.g. 9876543210',
              prefixIcon: const Icon(Icons.phone_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // Role dropdown
          DropdownButtonFormField<String>(
            value: _role,
            decoration: InputDecoration(
              labelText: 'Role',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true,
              fillColor: Colors.white,
            ),
            items: const [
              DropdownMenuItem(
                  value: kRoleCashier, child: Text('Cashier')),
              DropdownMenuItem(
                  value: kRoleManager, child: Text('Manager')),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => _role = v);
              widget.onRoleChanged(v);
            },
          ),
          const SizedBox(height: 8),
          Text(
            _role == kRoleCashier
                ? 'Cashier: access to Billing and Orders only.'
                : 'Manager: access to all tabs including Analytics and Settings.',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),

          // Add button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: widget.adding ? null : widget.onAdd,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: widget.adding
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Add Staff',
                      style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
