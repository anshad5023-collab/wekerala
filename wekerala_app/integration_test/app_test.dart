// Integration test — walks the app like a shop owner.
// Run on Android:  flutter test integration_test/app_test.dart -d emulator-5554
// Run on Windows:  flutter test integration_test/app_test.dart -d windows
//
// Firebase test phone: +91 9999999999  OTP: 123456

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wekerala/main.dart' as app;

const _testPhone = '9999999999';
const _testOtp   = '123456';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('wekerala — full shop-owner walkthrough', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 6));
    await _shot(binding, tester, '00_start');

    // ── Auth ────────────────────────────────────────────────────────────────
    if (find.text('Enter Your Phone Number').evaluate().isNotEmpty) {
      log('AUTH', 'Login screen — logging in with test number');
      await _doLogin(tester);
      await tester.pumpAndSettle(const Duration(seconds: 8));
    } else {
      log('AUTH', '✅ Already authenticated');
    }
    await _shot(binding, tester, '01_after_auth');

    // ── Home ────────────────────────────────────────────────────────────────
    await _goTab(tester, 'Home');
    await _shot(binding, tester, '02_home');
    _overflow(tester, 'Home');
    _errors(tester, 'Home');

    // ── Orders ──────────────────────────────────────────────────────────────
    await _goTab(tester, 'Orders');
    await tester.pumpAndSettle(const Duration(seconds: 3)); // wait for translations + stream
    await _shot(binding, tester, '03_orders');
    _overflow(tester, 'Orders');
    _errors(tester, 'Orders');

    // Check tab headers exist (All is first; others scroll into view)
    for (final tab in ['All', 'New', 'Confirmed', 'Processing', 'Ready', 'Delivered']) {
      if (find.text(tab).evaluate().isNotEmpty) {
        await _safeTap(tester, find.text(tab).first);
        _overflow(tester, 'Orders/$tab');
      } else {
        log('NAV ⚠️', 'Tab "$tab" not visible');
      }
    }

    // Tap first order if any
    await _goTab(tester, 'Orders');
    await _safeTapFirst(tester, find.byWidgetPredicate(
      (w) => w is InkWell && w.onTap != null,
    ), 'first order row', '04_order_detail', binding);
    // Go back if navigated
    await _goBack(tester);

    // ── Products ────────────────────────────────────────────────────────────
    await _goTab(tester, 'Products');
    await _shot(binding, tester, '05_products');
    _overflow(tester, 'Products');
    _errors(tester, 'Products');

    // Search
    final searchFields = find.byType(TextField);
    if (searchFields.evaluate().isNotEmpty) {
      await _safeTap(tester, searchFields.first);
      await tester.enterText(searchFields.first, 'a');
      await tester.pumpAndSettle();
      _overflow(tester, 'Products search');
      await _shot(binding, tester, '06_products_search');
      await tester.enterText(searchFields.first, '');
      await tester.pumpAndSettle();
    }

    // Tap first product
    await _safeTapFirst(tester, find.byWidgetPredicate(
      (w) => w is InkWell && w.onTap != null,
    ), 'first product row', '07_product_edit', binding);
    await _goBack(tester);

    // ── Billing ─────────────────────────────────────────────────────────────
    await _goTab(tester, 'Billing');
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await _shot(binding, tester, '08_billing_empty');
    _overflow(tester, 'Billing empty');
    _errors(tester, 'Billing');

    // Check product list visible
    if (find.text('PRODUCTS').evaluate().isNotEmpty) {
      log('BILLING ✅', 'Product panel visible');
    } else {
      log('BILLING ⚠️', 'Product panel "PRODUCTS" header not found');
    }

    // Check Udhar button (desktop only)
    if (find.text('Save as Udhar (Credit)').evaluate().isNotEmpty) {
      log('BILLING ✅', 'Udhar button visible in cart panel (desktop)');
    } else {
      log('BILLING ℹ️', 'Udhar button not shown — mobile (check payment bar)');
    }

    // Add a product
    final billingInkWells = find.byWidgetPredicate(
      (w) => w is InkWell && w.onTap != null,
    );
    if (billingInkWells.evaluate().isNotEmpty) {
      await _safeTap(tester, billingInkWells.first);
      await tester.pumpAndSettle();
      await _shot(binding, tester, '09_billing_with_product');
      _overflow(tester, 'Billing with product');
      // Check cart updated
      if (find.text('CART').evaluate().isNotEmpty) {
        log('BILLING ✅', 'Cart section visible after adding product');
      }
    }

    // ── Settings ────────────────────────────────────────────────────────────
    await _goTab(tester, 'Settings');
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await _shot(binding, tester, '10_settings');
    _overflow(tester, 'Settings hub');
    _errors(tester, 'Settings');

    // Check all labels are present BEFORE navigating away (avoids rebuild-timing issues)
    for (final label in ['Shop Settings', 'Account Settings', 'Subscription', 'Help & Support']) {
      if (find.text(label).evaluate().isNotEmpty) {
        log('SETTINGS ✅', '"$label" row found');
      } else {
        log('SETTINGS ⚠️', '"$label" row not found');
      }
    }
    // Navigate into Shop Settings for a deeper overflow check, then come back
    if (find.text('Shop Settings').evaluate().isNotEmpty) {
      await _safeTap(tester, find.text('Shop Settings').first);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await _shot(binding, tester, '11_shop_settings');
      _overflow(tester, 'Settings/Shop Settings');
      _errors(tester, 'Settings/Shop Settings');
      await _goBack(tester);
      await tester.pumpAndSettle(const Duration(seconds: 4));
    }

    // ── Done ────────────────────────────────────────────────────────────────
    await _goTab(tester, 'Home');
    await _shot(binding, tester, '12_done');
    log('DONE', '✅ Walkthrough complete — check [OVERFLOW/ERROR/⚠️] lines above');
  });
}

// ── Login ─────────────────────────────────────────────────────────────────────

Future<void> _doLogin(WidgetTester tester) async {
  // Accept terms dialog if present
  if (find.text('I Agree').evaluate().isNotEmpty) {
    await _safeTap(tester, find.text('I Agree'));
  }
  // Check terms checkbox
  if (find.byType(Checkbox).evaluate().isNotEmpty) {
    await _safeTap(tester, find.byType(Checkbox).first);
  }
  // Phone number
  if (find.byType(TextField).evaluate().isNotEmpty) {
    await tester.enterText(find.byType(TextField).first, _testPhone);
    await tester.pumpAndSettle();
  }
  // Send OTP
  final sendOtp = find.text('Send OTP');
  if (sendOtp.evaluate().isNotEmpty) {
    await _safeTap(tester, sendOtp.first);
  } else if (find.byType(ElevatedButton).evaluate().isNotEmpty) {
    await _safeTap(tester, find.byType(ElevatedButton).first);
  }
  await tester.pumpAndSettle(const Duration(seconds: 5));

  // OTP fields
  final fields = find.byType(TextField);
  if (fields.evaluate().length >= 6) {
    for (int i = 0; i < 6; i++) {
      await tester.enterText(fields.at(i), _testOtp[i]);
      await tester.pumpAndSettle();
    }
  } else if (fields.evaluate().isNotEmpty) {
    await tester.enterText(fields.first, _testOtp);
    await tester.pumpAndSettle();
  }
  // Verify
  if (find.text('Verify').evaluate().isNotEmpty) {
    await _safeTap(tester, find.text('Verify').first);
    await tester.pumpAndSettle(const Duration(seconds: 8));
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Future<void> _goTab(WidgetTester tester, String label) async {
  // 1. Try text tap (works on desktop sidebar)
  final byText = find.text(label);
  if (byText.evaluate().isNotEmpty) {
    try {
      await tester.tap(byText.first);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      return;
    } catch (_) {}
  }
  // 2. Semantic label (works on Android NavigationBar — each destination gets a semantic label)
  final bySemantic = find.bySemanticsLabel(RegExp(label, caseSensitive: false));
  if (bySemantic.evaluate().isNotEmpty) {
    try {
      await tester.tap(bySemantic.first);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      return;
    } catch (_) {}
  }
  // 3. Fallback: outlined icon (Android unselected tab state)
  final icon = _tabIcon(label);
  if (icon != null) {
    final byIcon = find.byIcon(icon);
    if (byIcon.evaluate().isNotEmpty) {
      try {
        await tester.tap(byIcon.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));
        return;
      } catch (_) {}
    }
  }
  log('NAV ⚠️', 'Tab "$label" not tappable');
}

IconData? _tabIcon(String label) {
  switch (label) {
    case 'Home':     return Icons.home_outlined;
    case 'Orders':   return Icons.receipt_long_outlined;
    case 'Products': return Icons.inventory_2_outlined;
    case 'Billing':  return Icons.point_of_sale_outlined;
    case 'Settings': return Icons.settings_outlined;
    default:         return null;
  }
}

Future<void> _goBack(WidgetTester tester) async {
  final back = find.byTooltip('Back');
  if (back.evaluate().isNotEmpty) {
    try {
      await tester.tap(back.first);
      await tester.pumpAndSettle(const Duration(seconds: 2));
    } catch (_) {}
  }
}

Future<void> _safeTap(WidgetTester tester, Finder finder) async {
  try {
    await tester.tap(finder);
    await tester.pumpAndSettle(const Duration(seconds: 2));
  } catch (e) {
    log('TAP ⚠️', 'Could not tap: $e');
  }
}

Future<void> _safeTapFirst(
  WidgetTester tester,
  Finder finder,
  String desc,
  String shotName,
  IntegrationTestWidgetsFlutterBinding binding,
) async {
  final found = finder.evaluate();
  if (found.isEmpty) {
    log('TAP ⚠️', 'No "$desc" found to tap');
    return;
  }
  try {
    await tester.tap(finder.first);
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await _shot(binding, tester, shotName);
    _overflow(tester, shotName);
    _errors(tester, shotName);
  } catch (e) {
    log('TAP ⚠️', '"$desc" tap failed: $e');
  }
}

Future<void> _shot(
  IntegrationTestWidgetsFlutterBinding b,
  WidgetTester t,
  String name,
) async {
  await t.pumpAndSettle();
  try {
    await b.takeScreenshot(name);
    log('📸', name);
  } catch (_) {
    log('📸', '$name (not supported on this platform)');
  }
}

void _overflow(WidgetTester tester, String screen) {
  if (find.textContaining('overflowed').evaluate().isNotEmpty) {
    log('OVERFLOW ❌', '$screen — layout overflow!');
  } else {
    log('LAYOUT ✅', '$screen — no overflow');
  }
}

void _errors(WidgetTester tester, String screen) {
  if (find.byType(ErrorWidget).evaluate().isNotEmpty) {
    log('ERROR ❌', '$screen — ErrorWidget found (crash)');
  }
}

void log(String tag, String msg) => print('[$tag] $msg'); // ignore: avoid_print
