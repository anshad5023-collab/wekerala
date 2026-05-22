import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Role constants ───────────────────────────────────────────────────────────

const String kRoleOwner = 'owner';
const String kRoleCashier = 'cashier';
const String kRoleManager = 'manager';

// ─── Local role (persisted via SharedPreferences) ─────────────────────────────

class RoleNotifier extends Notifier<String?> {
  static const _key = 'user_role';

  @override
  String? build() => null;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_key);
  }

  Future<void> setRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, role);
    state = role;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    state = null;
  }
}

final roleProvider = NotifierProvider<RoleNotifier, String?>(RoleNotifier.new);

// ─── Firestore-backed staff role ──────────────────────────────────────────────

/// Returns the staff role string ('cashier' | 'manager') for the current user
/// in the given shop, or null if they are the owner / not a staff member.
final staffRoleProvider =
    FutureProvider.family<String?, String>((ref, shopId) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;
  final doc = await FirebaseFirestore.instance
      .collection('shops')
      .doc(shopId)
      .collection('staff')
      .doc(user.uid)
      .get();
  if (!doc.exists) return null;
  return doc.data()?['role'] as String?;
});

/// True when the current user is a cashier for [shopId].
/// Cashiers see only the Billing and Orders tabs (no Analytics, Udhar, More).
final isCashierProvider = Provider.family<bool, String>((ref, shopId) {
  final role = ref.watch(staffRoleProvider(shopId));
  return role.maybeWhen(data: (r) => r == kRoleCashier, orElse: () => false);
});
