import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

enum GoogleAuthStatus { idle, loading, success, error }

class GoogleAuthState {
  final GoogleAuthStatus status;
  final String? errorMessage;

  const GoogleAuthState({this.status = GoogleAuthStatus.idle, this.errorMessage});

  GoogleAuthState copyWith({GoogleAuthStatus? status, String? errorMessage}) {
    return GoogleAuthState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class GoogleAuthNotifier extends Notifier<GoogleAuthState> {
  // Web/server client ID from google-services.json (client_type: 3)
  // Required so Firebase can validate the ID token on the server side
  final _googleSignIn = GoogleSignIn(
    serverClientId:
        '482080959600-n74sm12dgosqonfmofrekp5lu81jaecb.apps.googleusercontent.com',
  );
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  @override
  GoogleAuthState build() => const GoogleAuthState();

  Future<bool> signIn() async {
    state = state.copyWith(status: GoogleAuthStatus.loading);
    try {
      await _googleSignIn.signOut();
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        state = state.copyWith(status: GoogleAuthStatus.idle);
        return false;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCred = await _auth.signInWithCredential(credential);
      final user = userCred.user;
      if (user == null) {
        state = state.copyWith(status: GoogleAuthStatus.error, errorMessage: 'Sign-in failed.');
        return false;
      }
      await _upsertUserDoc(user, googleUser.email);
      state = state.copyWith(status: GoogleAuthStatus.success);
      return true;
    } catch (e) {
      state = state.copyWith(
        status: GoogleAuthStatus.error,
        errorMessage: 'Sign-in error: $e',
      );
      return false;
    }
  }

  Future<bool> signInWithEmailPassword(String email, String password) async {
    state = state.copyWith(status: GoogleAuthStatus.loading);
    try {
      UserCredential userCred;
      try {
        userCred = await _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found') {
          userCred = await _auth.createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );
        } else {
          rethrow;
        }
      }
      final user = userCred.user;
      if (user == null) {
        state = state.copyWith(status: GoogleAuthStatus.error, errorMessage: 'Sign-in failed.');
        return false;
      }
      await _upsertUserDoc(user, user.email ?? email.trim());
      state = state.copyWith(status: GoogleAuthStatus.success);
      return true;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        status: GoogleAuthStatus.error,
        errorMessage: isWindowsPlatform
            ? 'Auth error [${e.code}]: ${e.message ?? e.toString()}'
            : _authErrorMessage(e.code),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: GoogleAuthStatus.error,
        errorMessage: 'Sign-in error: $e',
      );
      return false;
    }
  }

  // Sends a password reset/setup email via REST API (bypasses C++ SDK).
  // Works even for accounts created with Google Sign-In.
  Future<bool> sendPasswordSetupEmail(String email) async {
    const apiKey = 'AIzaSyCFB9YZL3_bXjvRMoWaYFv8nTs_ote52GQ';
    try {
      final resp = await http.post(
        Uri.parse(
            'https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'requestType': 'PASSWORD_RESET', 'email': email.trim()}),
      );
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      if (resp.statusCode == 200) return true;
      final msg = (body['error'] as Map?)?['message'] ?? 'Unknown error';
      state = state.copyWith(
          status: GoogleAuthStatus.error, errorMessage: 'Email error: $msg');
      return false;
    } catch (e) {
      state = state.copyWith(
          status: GoogleAuthStatus.error, errorMessage: 'Email error: $e');
      return false;
    }
  }

  String _authErrorMessage(String code) => switch (code) {
    'wrong-password' || 'invalid-credential' => 'Incorrect password.',
    'invalid-email' => 'Invalid email address.',
    'weak-password' => 'Password must be at least 6 characters.',
    'too-many-requests' => 'Too many attempts. Try again later.',
    'operation-not-allowed' || 'unknown' || 'unknown-error' =>
      'Email/password sign-in is not enabled in Firebase.\n'
      'Fix: Firebase Console → Authentication → Sign-in method → Email/Password → Enable.',
    _ => 'Sign-in failed ($code).',
  };

  static bool get isWindowsPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  Future<void> _upsertUserDoc(User user, String email) async {
    final ref = _db.collection('users').doc(user.uid);
    final doc = await ref.get();
    if (!doc.exists) {
      await ref.set({
        'userId': user.uid,
        'googleUid': user.uid,
        'email': email,
        'name': user.displayName ?? '',
        'phone': '',
        'language': 'en',
        'role': 'owner',
        'businessTypes': [],
        'shopIds': [],
        'activeShopId': '',
        'tcAccepted': false,
        'trialUsed': false,
        'createdAt': Timestamp.now(),
      });
    } else {
      await ref.update({'googleUid': user.uid, 'email': email});
    }
  }

  Future<bool> hasCompletedBusinessRegistration() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final doc = await _db.collection('users').doc(user.uid).get();
    if (!doc.exists) return false;
    final data = doc.data()!;
    final types = List<String>.from(data['businessTypes'] as List? ?? []);
    return types.isNotEmpty;
  }

  Future<bool> hasShopStorefront() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final doc = await _db.collection('users').doc(user.uid).get();
    if (!doc.exists) return false;
    final data = doc.data()!;
    final shopIds = List<String>.from(data['shopIds'] as List? ?? []);
    return shopIds.isNotEmpty;
  }

  Future<bool> checkTrialAvailable(String phone) async {
    final snap = await _db
        .collection('users')
        .where('phone', isEqualTo: phone)
        .where('trialUsed', isEqualTo: true)
        .limit(1)
        .get();
    return snap.docs.isEmpty;
  }

  void reset() => state = const GoogleAuthState();
}

final googleAuthProvider =
    NotifierProvider<GoogleAuthNotifier, GoogleAuthState>(GoogleAuthNotifier.new);
