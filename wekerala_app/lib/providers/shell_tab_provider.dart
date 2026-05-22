import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Controls which tab the AppShell is showing.
/// Tab indices: 0=Home, 1=Orders, 2=Products, 3=Billing, 4=Settings
final shellTabProvider = StateProvider<int>((ref) => 0);

/// Use from any widget (StatelessWidget or ConsumerWidget) to switch AppShell tabs
/// without pushing a new route (which would hide the bottom navigation bar).
extension ShellTabX on BuildContext {
  void switchTab(int index) {
    ProviderScope.containerOf(this).read(shellTabProvider.notifier).state = index;
  }
}
