import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

enum AuthStatus {
  initial,
  loading,
  otpSent,
  authenticated,
  unauthenticated,
  error,
}

class AuthState {
  final AuthStatus status;
  final String? verificationId;
  final String? phoneNumber;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.verificationId,
    this.phoneNumber,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? verificationId,
    String? phoneNumber,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      verificationId: verificationId ?? this.verificationId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  @override
  AuthState build() {
    final user = _auth.currentUser;
    if (user != null) {
      return const AuthState(status: AuthStatus.authenticated);
    }
    return const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> sendOtp(String phoneNumber) async {
    state = state.copyWith(status: AuthStatus.loading, phoneNumber: phoneNumber);

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: '+91$phoneNumber',
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          state = state.copyWith(
            status: AuthStatus.error,
            errorMessage: _mapAuthError(e.code),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          state = state.copyWith(
            status: AuthStatus.otpSent,
            verificationId: verificationId,
          );
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } catch (e, st) {
      debugPrint('sendOtp error: $e\n$st');
      String msg;
      if (e is FirebaseAuthException) {
        msg = _mapAuthError(e.code);
      } else if (e is PlatformException) {
        msg = _mapAuthError(e.code);
      } else {
        msg = 'Auth error: ${e.toString()}';
      }
      state = state.copyWith(status: AuthStatus.error, errorMessage: msg);
    }
  }

  Future<bool> verifyOtp(String smsCode) async {
    final verificationId = state.verificationId;
    if (verificationId == null) return false;

    state = state.copyWith(status: AuthStatus.loading);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      await _signInWithCredential(credential);
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _mapAuthError(e.code),
      );
      return false;
    } catch (e, st) {
      debugPrint('verifyOtp error: $e\n$st');
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e is PlatformException ? _mapAuthError(e.code) : 'Auth error: ${e.toString()}',
      );
      return false;
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    final userCred = await _auth.signInWithCredential(credential);
    final user = userCred.user;
    if (user == null) return;
    await _upsertUserDoc(user);
    // Persist current language to Firestore so reinstall can restore it
    try {
      final prefs = await SharedPreferences.getInstance();
      final lang = prefs.getString('language') ?? 'en';
      await _db.collection('users').doc(user.uid).set(
        {'language': lang},
        SetOptions(merge: true),
      );
    } catch (_) {}
    state = state.copyWith(status: AuthStatus.authenticated);
  }

  Future<void> _upsertUserDoc(User user) async {
    final ref = _db.collection('users').doc(user.uid);
    final doc = await ref.get();
    if (!doc.exists) {
      // Fresh user — create full document
      final newUser = UserModel(
        userId: user.uid,
        phone: user.phoneNumber ?? '',
        name: '',
        language: 'en',
        createdAt: DateTime.now(),
        shopIds: [],
        activeShopId: '',
      );
      await ref.set(newUser.toFirestore());
    } else {
      // Existing user — ensure required fields are present (repair incomplete docs)
      final data = doc.data() ?? {};
      final updates = <String, dynamic>{};
      if (!data.containsKey('shopIds')) updates['shopIds'] = [];
      if (!data.containsKey('phone') || (data['phone'] as String).isEmpty) {
        updates['phone'] = user.phoneNumber ?? '';
      }
      if (updates.isNotEmpty) {
        await ref.set(updates, SetOptions(merge: true));
      }
    }
  }

  Future<bool> hasShops() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    // Fast path: check users doc shopIds
    final doc = await _db.collection('users').doc(user.uid).get();
    if (doc.exists) {
      final shopIds = (doc.data()?['shopIds'] as List?)?.cast<String>() ?? [];
      if (shopIds.isNotEmpty) return true;
    }

    // Fallback: query shops collection directly.
    // Handles reinstall + cases where shopIds was never written (old bug).
    final shopsSnap = await _db
        .collection('shops')
        .where('ownerId', isEqualTo: user.uid)
        .limit(1)
        .get();
    if (shopsSnap.docs.isEmpty) return false;

    // Repair the users doc so future calls use the fast path
    final shopId = shopsSnap.docs.first.id;
    await _db.collection('users').doc(user.uid).set({
      'shopIds': FieldValue.arrayUnion([shopId]),
      'activeShopId': shopId,
    }, SetOptions(merge: true));
    return true;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void resetError() {
    state = state.copyWith(status: AuthStatus.otpSent);
  }

  String _mapAuthError(String code) {
    switch (code) {
      case 'invalid-verification-code':
      case 'invalid-verification-id':
        return 'Wrong OTP. Please check and try again.';
      case 'session-expired':
        return 'OTP expired. Please request a new one.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes and try again.';
      case 'network-request-failed':
        return 'No internet. Switch to mobile data (4G) and try again.';
      case 'invalid-phone-number':
        return 'Invalid phone number. Please enter a valid 10-digit number.';
      case 'quota-exceeded':
        return 'SMS limit reached. Please try again tomorrow.';
      case 'app-not-authorized':
        return 'App not authorized for OTP. Please contact support.';
      case 'missing-phone-number':
        return 'Please enter a phone number.';
      default:
        return 'Error ($code). Please try again or contact support.';
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});
