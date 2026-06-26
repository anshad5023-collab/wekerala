import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// One printable shelf/product label: name + price + a scannable barcode.
class LabelData {
  final String name;
  final double price;
  final String barcode;
  const LabelData({
    required this.name,
    required this.price,
    required this.barcode,
  });
}

/// Shared barcode-label generation + printing, used by Add Product, Batch
/// Review and the Print Labels screen so the label format and the internal
/// barcode rules live in exactly one place.
///
/// Internal (shop-generated) barcodes use the EAN-13 in-store prefix **20**, so
/// they never clash with a real manufacturer barcode and stay meaningful only
/// inside the shop that created them. Lookups at billing are always scoped to
/// `shops/{shopId}/products`, so two shops generating the same number can never
/// collide.
class LabelPrintService {
  /// Generate a valid EAN-13 internal barcode (prefix 20 = in-store range).
  ///
  /// [salt] disambiguates codes generated in the same microsecond — pass the
  /// item index when generating many in a tight loop (batch printing) so they
  /// don't collide.
  static String generateInternalEan13([int salt = 0]) {
    final n =
        (DateTime.now().microsecondsSinceEpoch + salt * 7919) % 10000000000;
    final base = '20${n.toString().padLeft(10, '0')}';
    final digits = base.split('').map(int.parse).toList();
    var sum = 0;
    for (var i = 0; i < 12; i++) {
      sum += digits[i] * (i.isEven ? 1 : 3);
    }
    final check = (10 - (sum % 10)) % 10;
    return '$base$check';
  }

  /// Build the labels PDF (3 labels per row, A4, paginated) and open the system
  /// print dialog. Works on Android (system print services / saved Bluetooth)
  /// and Windows (USB printer dialog).
  static Future<void> printLabels(List<LabelData> items) async {
    if (items.isEmpty) return;
    final doc = await _buildLabelsPdf(items);
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  static Future<pw.Document> _buildLabelsPdf(List<LabelData> items) async {
    final doc = pw.Document();
    const perRow = 3;

    final rows = <List<LabelData>>[];
    for (var i = 0; i < items.length; i += perRow) {
      rows.add(items.sublist(
          i, i + perRow > items.length ? items.length : i + perRow));
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(18),
        build: (ctx) => rows
            .map((row) => pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: List.generate(perRow, (c) {
                    if (c >= row.length) {
                      return pw.Expanded(child: pw.SizedBox());
                    }
                    return pw.Expanded(child: _label(row[c]));
                  }),
                ))
            .toList(),
      ),
    );
    return doc;
  }

  static pw.Widget _label(LabelData d) {
    return pw.Container(
      margin: const pw.EdgeInsets.all(4),
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            d.name,
            maxLines: 2,
            overflow: pw.TextOverflow.clip,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 3),
          pw.Text('₹${d.price.toStringAsFixed(0)}',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 3),
          pw.BarcodeWidget(
            barcode: pw.Barcode.code128(),
            data: d.barcode,
            drawText: false,
            height: 26,
            width: 120,
          ),
        ],
      ),
    );
  }
}
