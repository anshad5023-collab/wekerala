import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../models/bill_model.dart';
import '../../models/shop_model.dart';

class InvoicePdfService {
  static final _fmt = NumberFormat('#,##0.00', 'en_IN');

  static Future<void> shareInvoice(BillModel bill, ShopModel shop) async {
    final pdf = await _buildPdf(bill, shop);
    final bytes = await pdf.save();

    final dir = await getTemporaryDirectory();
    final invoiceNum = bill.invoiceNumber ?? bill.billId.substring(0, 8).toUpperCase();
    final file = File('${dir.path}/invoice_$invoiceNum.pdf');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'Invoice $invoiceNum from ${shop.shopName}',
    );
  }

  static Future<pw.Document> _buildPdf(BillModel bill, ShopModel shop) async {
    final doc = pw.Document(
      title: 'Invoice ${bill.invoiceNumber ?? bill.billId}',
      author: shop.shopName,
    );

    final primaryColor = _hexToColor(shop.themeColor ?? '#1B2838');
    final lightGrey = PdfColor.fromHex('#F5F5F5');
    final textDark = PdfColor.fromHex('#1A1A2E');
    final textMuted = PdfColor.fromHex('#757575');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        build: (ctx) => [
          _header(shop, bill, primaryColor, textDark, textMuted),
          pw.SizedBox(height: 20),
          _customerBlock(bill, textDark, textMuted),
          pw.SizedBox(height: 16),
          _itemsTable(bill, primaryColor, lightGrey, textDark, textMuted),
          pw.SizedBox(height: 12),
          _totalsBlock(bill, primaryColor, textDark, textMuted),
          pw.SizedBox(height: 16),
          _gstBreakdownTable(bill, lightGrey, textDark, textMuted),
          pw.SizedBox(height: 20),
          _footer(shop, textMuted),
        ],
      ),
    );

    return doc;
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  static pw.Widget _header(ShopModel shop, BillModel bill,
      PdfColor primary, PdfColor textDark, PdfColor textMuted) {
    final invoiceNum = bill.invoiceNumber ?? bill.billId.substring(0, 8).toUpperCase();
    final dateStr = DateFormat('dd MMM yyyy').format(bill.createdAt);
    final timeStr = DateFormat('hh:mm a').format(bill.createdAt);

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: primary,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      padding: const pw.EdgeInsets.all(18),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  shop.shopName,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                if (shop.address.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    shop.address,
                    style: pw.TextStyle(fontSize: 9, color: const PdfColor(1, 1, 1, 0.7)),
                  ),
                ],
                if (shop.gstin != null && shop.gstin!.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'GSTIN: ${shop.gstin}',
                    style: pw.TextStyle(fontSize: 9, color: const PdfColor(1, 1, 1, 0.7)),
                  ),
                ],
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'TAX INVOICE',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'Invoice #: $invoiceNum',
                style: pw.TextStyle(fontSize: 9, color: const PdfColor(1, 1, 1, 0.7)),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Date: $dateStr  $timeStr',
                style: pw.TextStyle(fontSize: 9, color: const PdfColor(1, 1, 1, 0.7)),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Payment: ${_paymentLabel(bill.paymentMethod)}',
                style: pw.TextStyle(fontSize: 9, color: const PdfColor(1, 1, 1, 0.7)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Customer block ─────────────────────────────────────────────────────────

  static pw.Widget _customerBlock(
      BillModel bill, PdfColor textDark, PdfColor textMuted) {
    if (bill.customerName.isEmpty && bill.customerPhone.isEmpty) {
      return pw.SizedBox();
    }
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColor.fromHex('#E0E0E0')),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Row(
        children: [
          pw.Text('Bill To: ',
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: textMuted)),
          pw.Text(
            [
              if (bill.customerName.isNotEmpty) bill.customerName,
              if (bill.customerPhone.isNotEmpty) bill.customerPhone,
            ].join('  |  '),
            style: pw.TextStyle(fontSize: 9, color: textDark),
          ),
        ],
      ),
    );
  }

  // ── Items table ────────────────────────────────────────────────────────────

  static pw.Widget _itemsTable(BillModel bill, PdfColor primary,
      PdfColor lightGrey, PdfColor textDark, PdfColor textMuted) {
    final headers = ['#', 'Item', 'HSN', 'Qty', 'Rate', 'GST%', 'Amount'];
    final colWidths = [
      pw.FlexColumnWidth(0.5),
      pw.FlexColumnWidth(3.5),
      pw.FlexColumnWidth(1.2),
      pw.FlexColumnWidth(1.0),
      pw.FlexColumnWidth(1.2),
      pw.FlexColumnWidth(0.8),
      pw.FlexColumnWidth(1.4),
    ];

    return pw.Table(
      columnWidths: {
        0: colWidths[0],
        1: colWidths[1],
        2: colWidths[2],
        3: colWidths[3],
        4: colWidths[4],
        5: colWidths[5],
        6: colWidths[6],
      },
      border: pw.TableBorder.all(
          color: PdfColor.fromHex('#E0E0E0'), width: 0.5),
      children: [
        // Header row
        pw.TableRow(
          decoration: pw.BoxDecoration(color: primary),
          children: headers.map((h) {
            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: pw.Text(
                h,
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                textAlign: h == '#' || h == 'Qty' || h == 'Rate' || h == 'GST%' || h == 'Amount'
                    ? pw.TextAlign.right
                    : pw.TextAlign.left,
              ),
            );
          }).toList(),
        ),
        // Data rows
        ...bill.items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          final bg = i.isOdd ? lightGrey : PdfColors.white;
          return pw.TableRow(
            decoration: pw.BoxDecoration(color: bg),
            children: [
              _cell('${i + 1}', textDark, align: pw.TextAlign.right),
              _cell(item.productName, textDark),
              _cell(item.hsnCode ?? '-', textMuted, align: pw.TextAlign.center),
              _cell('${item.qty.toStringAsFixed(item.qty % 1 == 0 ? 0 : 2)} ${item.unit}',
                  textDark, align: pw.TextAlign.right),
              _cell('₹${_fmt.format(item.price)}', textDark,
                  align: pw.TextAlign.right),
              _cell('${item.gstRate}%', textMuted,
                  align: pw.TextAlign.right),
              _cell('₹${_fmt.format(item.subtotal)}', textDark,
                  align: pw.TextAlign.right, bold: true),
            ],
          );
        }),
      ],
    );
  }

  // ── Totals block ───────────────────────────────────────────────────────────

  static pw.Widget _totalsBlock(BillModel bill, PdfColor primary,
      PdfColor textDark, PdfColor textMuted) {
    final rows = <_TotalsRow>[];

    rows.add(_TotalsRow('Subtotal', '₹${_fmt.format(bill.totalAmount)}'));

    if (bill.discountAmount > 0) {
      rows.add(_TotalsRow('Discount', '-₹${_fmt.format(bill.discountAmount)}',
          isNeg: true));
    }

    // GST summary from breakdown map
    double totalGst = 0;
    if (bill.gstBreakdown.isNotEmpty) {
      bill.gstBreakdown.forEach((rate, slab) {
        final cgst = (slab['cgst'] as num?)?.toDouble() ?? 0;
        final sgst = (slab['sgst'] as num?)?.toDouble() ?? 0;
        totalGst += cgst + sgst;
      });
      rows.add(_TotalsRow('GST (CGST + SGST)', '₹${_fmt.format(totalGst)}'));
    }

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          width: 240,
          child: pw.Column(
            children: [
              ...rows.map((r) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 3),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(r.label,
                            style: pw.TextStyle(
                                fontSize: 9, color: textMuted)),
                        pw.Text(r.value,
                            style: pw.TextStyle(
                                fontSize: 9,
                                color: r.isNeg
                                    ? PdfColor.fromHex('#E53935')
                                    : textDark)),
                      ],
                    ),
                  )),
              pw.Divider(color: PdfColor.fromHex('#BDBDBD'), thickness: 0.5),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: primary,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('TOTAL',
                        style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white)),
                    pw.Text('₹${_fmt.format(bill.finalAmount)}',
                        style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── GST breakdown table ────────────────────────────────────────────────────

  static pw.Widget _gstBreakdownTable(BillModel bill, PdfColor lightGrey,
      PdfColor textDark, PdfColor textMuted) {
    if (bill.gstBreakdown.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('GST Summary',
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: textMuted)),
        pw.SizedBox(height: 4),
        pw.Table(
          border: pw.TableBorder.all(
              color: PdfColor.fromHex('#E0E0E0'), width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(1),
            1: const pw.FlexColumnWidth(1.5),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(1),
            4: const pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: lightGrey),
              children: ['GST Rate', 'Taxable Amount', 'CGST', 'SGST', 'Total Tax']
                  .map((h) => pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 6, vertical: 5),
                        child: pw.Text(h,
                            style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                                color: textDark)),
                      ))
                  .toList(),
            ),
            ...bill.gstBreakdown.entries.map((e) {
              final rate = e.key;
              final slab = e.value;
              final taxable = (slab['taxableAmount'] as num?)?.toDouble() ?? 0;
              final cgst = (slab['cgst'] as num?)?.toDouble() ?? 0;
              final sgst = (slab['sgst'] as num?)?.toDouble() ?? 0;
              return pw.TableRow(
                children: [
                  _cell('$rate%', textDark, align: pw.TextAlign.right),
                  _cell('₹${_fmt.format(taxable)}', textDark,
                      align: pw.TextAlign.right),
                  _cell('₹${_fmt.format(cgst)}', textDark,
                      align: pw.TextAlign.right),
                  _cell('₹${_fmt.format(sgst)}', textDark,
                      align: pw.TextAlign.right),
                  _cell('₹${_fmt.format(cgst + sgst)}', textDark,
                      align: pw.TextAlign.right, bold: true),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────────────

  static pw.Widget _footer(ShopModel shop, PdfColor textMuted) {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColor.fromHex('#E0E0E0'), thickness: 0.5),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              'Thank you for shopping at ${shop.shopName}!  •  Powered by weKerala',
              style: pw.TextStyle(fontSize: 8, color: textMuted),
            ),
          ],
        ),
      ],
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static pw.Widget _cell(String text, PdfColor color,
      {pw.TextAlign align = pw.TextAlign.left, bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 8,
          color: color,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static PdfColor _hexToColor(String hex) {
    final clean = hex.replaceFirst('#', '');
    if (clean.length == 6) {
      final r = int.parse(clean.substring(0, 2), radix: 16);
      final g = int.parse(clean.substring(2, 4), radix: 16);
      final b = int.parse(clean.substring(4, 6), radix: 16);
      return PdfColor.fromInt(0xFF000000 | (r << 16) | (g << 8) | b);
    }
    return PdfColor.fromHex('#1B2838');
  }

  static String _paymentLabel(String method) {
    switch (method.toLowerCase()) {
      case 'cash':   return 'Cash';
      case 'upi':    return 'UPI';
      case 'card':   return 'Card';
      case 'udhar':  return 'Credit (Udhar)';
      default:       return method;
    }
  }
}

class _TotalsRow {
  final String label;
  final String value;
  final bool isNeg;
  const _TotalsRow(this.label, this.value, {this.isNeg = false});
}
