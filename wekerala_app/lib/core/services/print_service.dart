import 'dart:io';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
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

  // Request Bluetooth runtime permission (Android 12+ requires BLUETOOTH_CONNECT)
  static Future<bool> _requestBluetoothPermission() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.bluetoothConnect.request();
    return status.isGranted;
  }

  // Returns list of already-paired Bluetooth devices (no active scan needed)
  static Future<List<BluetoothInfo>> getPairedDevices() async {
    if (!_supported) return [];
    await _requestBluetoothPermission();
    return PrintBluetoothThermal.pairedBluetooths;
  }

  static Future<bool> connect(String macAddress) async {
    if (!_supported) return false;
    if (!await _requestBluetoothPermission()) return false;
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

  // Windows/desktop USB printing via system print dialog (pdf/printing package)
  static Future<void> printBillWindows(BillModel bill, ShopModel shop) async {
    if (kIsWeb || !Platform.isWindows) return;
    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 4 * PdfPageFormat.mm),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Center(child: pw.Text(shop.shopName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14))),
          if (shop.address.isNotEmpty) pw.Center(child: pw.Text(shop.address, style: const pw.TextStyle(fontSize: 9))),
          pw.Divider(),
          pw.Text('Invoice: ${bill.invoiceNumber}', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Date: ${bill.createdAt.day}/${bill.createdAt.month}/${bill.createdAt.year}', style: const pw.TextStyle(fontSize: 9)),
          if (bill.customerName.isNotEmpty) pw.Text('Customer: ${bill.customerName}', style: const pw.TextStyle(fontSize: 9)),
          pw.Divider(),
          ...bill.items.map((item) => pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(child: pw.Text('${item.productName} x${item.qty}', style: const pw.TextStyle(fontSize: 9))),
              pw.Text('₹${item.subtotal.toStringAsFixed(0)}', style: const pw.TextStyle(fontSize: 9)),
            ],
          )),
          pw.Divider(),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
            pw.Text('₹${bill.finalAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
          ]),
          pw.Text('Payment: ${bill.paymentMethod.toUpperCase()}', style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 12),
          pw.Center(child: pw.Text('Thank you!', style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 9))),
        ],
      ),
    ));
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  static Future<void> printBill(BillModel bill, ShopModel shop) async {
    if (!kIsWeb && Platform.isWindows) {
      await printBillWindows(bill, shop);
      return;
    }
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
    if (bill.billNote != null && bill.billNote!.isNotEmpty) {
      bytes.addAll(gen.text('Note: ${bill.billNote}'));
    }
    if (bill.billedByName != null && bill.billedByName!.isNotEmpty) {
      bytes.addAll(gen.text('Billed by: ${bill.billedByName}'));
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
      if (item.batchNumber != null && item.batchNumber!.isNotEmpty) {
        bytes.addAll(gen.text('  Batch: ${item.batchNumber}',
            styles: const PosStyles(height: PosTextSize.size1)));
      }
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
