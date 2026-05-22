import 'dart:io';

import 'package:bluetooth_print/bluetooth_print.dart';
import 'package:bluetooth_print/bluetooth_print_model.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/bill_model.dart';
import '../../models/shop_model.dart';

class PrintService {
  static bool get _supported => !kIsWeb && Platform.isAndroid;

  static const _prefKey = 'paired_printer_address';
  static final BluetoothPrint _bt = BluetoothPrint.instance;

  // Save paired printer address
  static Future<void> savePrinterAddress(String address) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, address);
  }

  // Get saved printer address
  static Future<String?> getSavedPrinterAddress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKey);
  }

  // Scan for nearby Bluetooth devices
  static Stream<List<BluetoothDevice>> scanDevices() {
    if (!_supported) return const Stream.empty();
    _bt.startScan(timeout: const Duration(seconds: 5));
    return _bt.scanResults;
  }

  static Future<void> stopScan() async {
    if (!_supported) return;
    await _bt.stopScan();
  }

  // Connect to a device
  static Future<bool> connect(BluetoothDevice device) async {
    if (!_supported) return false;
    await _bt.connect(device);
    // Wait up to 3 seconds for connection
    for (int i = 0; i < 6; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      final state = await _bt.state.first;
      if (state == BluetoothPrint.CONNECTED) return true;
    }
    return false;
  }

  static Future<void> disconnect() async {
    if (!_supported) return;
    await _bt.disconnect();
  }

  // Print a bill
  static Future<void> printBill(BillModel bill, ShopModel shop) async {
    if (!_supported) return;
    final Map<String, dynamic> config = {};
    final List<LineText> list = [];

    // Header
    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: shop.shopName,
      weight: 1,
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));
    if (shop.address.isNotEmpty) {
      list.add(LineText(
        type: LineText.TYPE_TEXT,
        content: shop.address,
        align: LineText.ALIGN_CENTER,
        linefeed: 1,
      ));
    }
    if (shop.gstin != null && shop.gstin!.isNotEmpty) {
      list.add(LineText(
        type: LineText.TYPE_TEXT,
        content: 'GSTIN: ${shop.gstin}',
        align: LineText.ALIGN_CENTER,
        linefeed: 1,
      ));
    }
    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: '--------------------------------',
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));

    // Bill info
    final dateStr =
        '${bill.createdAt.day.toString().padLeft(2, '0')}/${bill.createdAt.month.toString().padLeft(2, '0')}/${bill.createdAt.year}';
    final billShort = bill.billId.length >= 8 ? bill.billId.substring(0, 8) : bill.billId;
    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'Bill: $billShort  $dateStr',
      linefeed: 1,
    ));
    if (bill.customerName.isNotEmpty) {
      list.add(LineText(
        type: LineText.TYPE_TEXT,
        content: 'Customer: ${bill.customerName}',
        linefeed: 1,
      ));
    }
    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: '--------------------------------',
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));

    // Items
    for (final item in bill.items) {
      final name = item.productName.length > 16
          ? item.productName.substring(0, 16)
          : item.productName;
      final qtyStr = item.qty % 1 == 0
          ? item.qty.toInt().toString()
          : item.qty.toStringAsFixed(1);
      final priceStr =
          '${qtyStr}x${item.price.toStringAsFixed(0)} ${(item.qty * item.price).toStringAsFixed(2)}';
      list.add(LineText(
        type: LineText.TYPE_TEXT,
        content: '$name  $priceStr',
        linefeed: 1,
      ));
    }
    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: '--------------------------------',
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));

    // Summary
    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'Subtotal: Rs.${bill.totalAmount.toStringAsFixed(2)}',
      linefeed: 1,
    ));
    if (bill.discountAmount > 0) {
      list.add(LineText(
        type: LineText.TYPE_TEXT,
        content: 'Discount: -Rs.${bill.discountAmount.toStringAsFixed(2)}',
        linefeed: 1,
      ));
    }
    if (bill.totalTax > 0) {
      for (final e in bill.gstBreakdown.entries) {
        final rate = int.tryParse(e.key) ?? 0;
        final half = rate / 2;
        list.add(LineText(
          type: LineText.TYPE_TEXT,
          content: 'CGST $half%: Rs.${e.value['cgst']!.toStringAsFixed(2)}',
          linefeed: 1,
        ));
        list.add(LineText(
          type: LineText.TYPE_TEXT,
          content: 'SGST $half%: Rs.${e.value['sgst']!.toStringAsFixed(2)}',
          linefeed: 1,
        ));
      }
      list.add(LineText(
        type: LineText.TYPE_TEXT,
        content: 'Total Tax: Rs.${bill.totalTax.toStringAsFixed(2)}',
        linefeed: 1,
      ));
    }
    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: '================================',
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));
    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'TOTAL: Rs.${bill.finalAmount.toStringAsFixed(2)}',
      weight: 1,
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));
    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: '================================',
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));
    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'Payment: ${bill.isUdhar ? 'Udhar' : bill.paymentMethod.toUpperCase()}',
      linefeed: 1,
    ));
    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: '',
      linefeed: 1,
    ));
    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'Thank you! Visit again.',
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));
    list.add(LineText(type: LineText.TYPE_TEXT, content: '', linefeed: 1));
    list.add(LineText(type: LineText.TYPE_TEXT, content: '', linefeed: 1));
    list.add(LineText(type: LineText.TYPE_TEXT, content: '', linefeed: 1));

    await _bt.printReceipt(config, list);
  }

  // Print a short test receipt
  static Future<void> printTest() async {
    if (!_supported) return;
    final Map<String, dynamic> config = {};
    final List<LineText> list = [];
    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'Oratas - Test Print',
      weight: 1,
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));
    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: '----------------',
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));
    list.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'Printer connected!',
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));
    list.add(LineText(type: LineText.TYPE_TEXT, content: '', linefeed: 1));
    list.add(LineText(type: LineText.TYPE_TEXT, content: '', linefeed: 1));
    list.add(LineText(type: LineText.TYPE_TEXT, content: '', linefeed: 1));
    await _bt.printReceipt(config, list);
  }
}
