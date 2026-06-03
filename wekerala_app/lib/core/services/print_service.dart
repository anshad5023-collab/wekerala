import 'dart:io';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/bill_model.dart';
import '../../models/shop_model.dart';

class PrintService {
  static bool get _supported => !kIsWeb && Platform.isAndroid;

  static const _prefKey = 'paired_printer_address';

  static Future<void> savePrinterAddress(String address) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, address);
  }

  static Future<String?> getSavedPrinterAddress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKey);
  }

  // Returns list of already-paired Bluetooth devices (no active scan needed)
  static Future<List<BluetoothInfo>> getPairedDevices() async {
    if (!_supported) return [];
    return PrintBluetoothThermal.pairedBluetooths;
  }

  static Future<bool> connect(String macAddress) async {
    if (!_supported) return false;
    return PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
  }

  static Future<void> disconnect() async {
    if (!_supported) return;
    await PrintBluetoothThermal.disconnect;
  }

  static Future<bool> isConnected() async {
    if (!_supported) return false;
    return PrintBluetoothThermal.connectionStatus;
  }

  static Future<Generator> _generator() async {
    final profile = await CapabilityProfile.load();
    return Generator(PaperSize.mm80, profile);
  }

  static Future<void> printBill(BillModel bill, ShopModel shop) async {
    if (!_supported) return;
    final gen = await _generator();
    final bytes = <int>[];

    // Header
    bytes.addAll(gen.text(shop.shopName,
        styles: const PosStyles(bold: true, align: PosAlign.center)));
    if (shop.address.isNotEmpty) {
      bytes.addAll(gen.text(shop.address,
          styles: const PosStyles(align: PosAlign.center)));
    }
    if (shop.gstin != null && shop.gstin!.isNotEmpty) {
      bytes.addAll(gen.text('GSTIN: ${shop.gstin}',
          styles: const PosStyles(align: PosAlign.center)));
    }
    bytes.addAll(gen.hr());

    // Bill info
    final dateStr =
        '${bill.createdAt.day.toString().padLeft(2, '0')}/${bill.createdAt.month.toString().padLeft(2, '0')}/${bill.createdAt.year}';
    final billShort =
        bill.billId.length >= 8 ? bill.billId.substring(0, 8) : bill.billId;
    bytes.addAll(gen.text('Bill: $billShort  $dateStr'));
    if (bill.customerName.isNotEmpty) {
      bytes.addAll(gen.text('Customer: ${bill.customerName}'));
    }
    bytes.addAll(gen.hr());

    // Items
    for (final item in bill.items) {
      final name = item.productName.length > 16
          ? item.productName.substring(0, 16)
          : item.productName;
      final qtyStr = item.qty % 1 == 0
          ? item.qty.toInt().toString()
          : item.qty.toStringAsFixed(1);
      final line =
          '$name  ${qtyStr}x${item.price.toStringAsFixed(0)} ${(item.qty * item.price).toStringAsFixed(2)}';
      bytes.addAll(gen.text(line));
    }
    bytes.addAll(gen.hr(ch: '='));

    // Summary
    bytes.addAll(gen.text('Subtotal: Rs.${bill.totalAmount.toStringAsFixed(2)}'));
    if (bill.discountAmount > 0) {
      bytes.addAll(gen.text('Discount: -Rs.${bill.discountAmount.toStringAsFixed(2)}'));
    }
    if (bill.totalTax > 0) {
      for (final e in bill.gstBreakdown.entries) {
        final rate = int.tryParse(e.key) ?? 0;
        final half = rate / 2;
        bytes.addAll(gen.text('CGST $half%: Rs.${e.value['cgst']!.toStringAsFixed(2)}'));
        bytes.addAll(gen.text('SGST $half%: Rs.${e.value['sgst']!.toStringAsFixed(2)}'));
      }
      bytes.addAll(gen.text('Total Tax: Rs.${bill.totalTax.toStringAsFixed(2)}'));
    }
    bytes.addAll(gen.hr(ch: '='));
    bytes.addAll(gen.text('TOTAL: Rs.${bill.finalAmount.toStringAsFixed(2)}',
        styles: const PosStyles(bold: true, align: PosAlign.center)));
    bytes.addAll(gen.hr(ch: '='));
    bytes.addAll(gen.text(
        'Payment: ${bill.isUdhar ? 'Udhar' : bill.paymentMethod.toUpperCase()}'));
    bytes.addAll(gen.text('Thank you! Visit again.',
        styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(gen.feed(3));
    bytes.addAll(gen.cut());

    await PrintBluetoothThermal.writeBytes(bytes);
  }

  static Future<void> printTest() async {
    if (!_supported) return;
    final gen = await _generator();
    final bytes = <int>[];
    bytes.addAll(gen.text('Oratas - Test Print',
        styles: const PosStyles(bold: true, align: PosAlign.center)));
    bytes.addAll(gen.hr());
    bytes.addAll(gen.text('Printer connected!',
        styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(gen.feed(3));
    bytes.addAll(gen.cut());
    await PrintBluetoothThermal.writeBytes(bytes);
  }
}
