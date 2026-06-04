import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/bill_model.dart';
import '../../../providers/billing_provider.dart';
import '../../../providers/shop_provider.dart';

class Gstr1Screen extends ConsumerStatefulWidget {
  const Gstr1Screen({super.key});

  @override
  ConsumerState<Gstr1Screen> createState() => _Gstr1ScreenState();
}

class _Gstr1ScreenState extends ConsumerState<Gstr1Screen> {
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  BillDateRange get _range {
    final start = DateTime(_selectedYear, _selectedMonth);
    final end = DateTime(_selectedYear, _selectedMonth + 1)
        .subtract(const Duration(microseconds: 1));
    return BillDateRange(start, end);
  }

  @override
  Widget build(BuildContext context) {
    final shopAsync = ref.watch(activeShopIdProvider);
    final shopId = shopAsync.valueOrNull ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('GST Summary (GSTR-1)'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: shopId.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(shopId),
    );
  }

  Widget _buildBody(String shopId) {
    final billsAsync = ref.watch(billHistoryProvider((shopId: shopId, range: _range)));
    final shopAsync2 = ref.watch(shopStreamProvider(shopId));
    final shop = shopAsync2.valueOrNull;
    final shopName = shop?.shopName ?? '';
    final gstin = shop?.gstin ?? '';

    return Column(
      children: [
        _PeriodSelector(
          month: _selectedMonth,
          year: _selectedYear,
          onChanged: (m, y) => setState(() {
            _selectedMonth = m;
            _selectedYear = y;
          }),
        ),
        Expanded(
          child: billsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (bills) => _GstrReport(
              bills: bills.where((b) => !b.isVoided).toList(),
              month: _selectedMonth,
              year: _selectedYear,
              shopName: shopName,
              gstin: gstin,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Period Selector ──────────────────────────────────────────────────────────

class _PeriodSelector extends StatelessWidget {
  final int month;
  final int year;
  final void Function(int month, int year) onChanged;

  const _PeriodSelector({
    required this.month,
    required this.year,
    required this.onChanged,
  });

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.calendar_month_outlined, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          const Text('Period:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: month,
                isExpanded: true,
                items: List.generate(12, (i) => DropdownMenuItem(
                  value: i + 1,
                  child: Text(_months[i], style: const TextStyle(fontSize: 14)),
                )),
                onChanged: (v) => onChanged(v ?? month, year),
              ),
            ),
          ),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: year,
              items: List.generate(3, (i) {
                final y = DateTime.now().year - i;
                return DropdownMenuItem(value: y, child: Text('$y', style: const TextStyle(fontSize: 14)));
              }),
              onChanged: (v) => onChanged(month, v ?? year),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Report Body ──────────────────────────────────────────────────────────────

class _GstrReport extends StatelessWidget {
  final List<BillModel> bills;
  final int month;
  final int year;
  final String shopName;
  final String gstin;

  const _GstrReport({
    required this.bills,
    required this.month,
    required this.year,
    required this.shopName,
    required this.gstin,
  });

  static const _months = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  // Group items by GST rate and compute aggregates
  Map<int, _GstSlab> _buildSlabs() {
    final slabs = <int, _GstSlab>{};
    for (final bill in bills) {
      for (final item in bill.items) {
        final rate = item.gstRate;
        if (rate == 0) continue;

        double taxable;
        if (item.priceIncludesGst) {
          taxable = item.subtotal / (1 + rate / 100);
        } else {
          taxable = item.subtotal;
        }
        final tax = taxable * rate / 100;
        final cgst = tax / 2;
        final sgst = tax / 2;

        slabs[rate] = _GstSlab(
          rate: rate,
          taxable: (slabs[rate]?.taxable ?? 0) + taxable,
          cgst: (slabs[rate]?.cgst ?? 0) + cgst,
          sgst: (slabs[rate]?.sgst ?? 0) + sgst,
          total: (slabs[rate]?.total ?? 0) + item.subtotal,
        );
      }
    }
    return slabs;
  }

  double get _grandTotal => bills.fold(0.0, (s, b) => s + b.finalAmount);
  double get _totalTax => bills.fold(0.0, (s, b) => s + b.totalTax);
  double get _exemptSales {
    double ex = 0;
    for (final bill in bills) {
      for (final item in bill.items) {
        if (item.gstRate == 0) ex += item.subtotal;
      }
    }
    return ex;
  }

  String _buildCsvText(Map<int, _GstSlab> slabs) {
    final sb = StringBuffer();
    sb.writeln('GSTR-1 Summary — ${_months[month]} $year');
    sb.writeln('Generated by Oratas');
    sb.writeln();
    sb.writeln('GST Rate,Taxable Amount,CGST,SGST,Total Tax,Gross Sales');
    for (final s in slabs.values.toList()..sort((a, b) => a.rate - b.rate)) {
      sb.writeln('${s.rate}%,${s.taxable.toStringAsFixed(2)},${s.cgst.toStringAsFixed(2)},${s.sgst.toStringAsFixed(2)},${(s.cgst + s.sgst).toStringAsFixed(2)},${s.total.toStringAsFixed(2)}');
    }
    sb.writeln();
    sb.writeln('Exempt/0% Sales,${_exemptSales.toStringAsFixed(2)}');
    sb.writeln('Total Tax,${_totalTax.toStringAsFixed(2)}');
    sb.writeln('Grand Total,${_grandTotal.toStringAsFixed(2)}');
    sb.writeln('Number of Invoices,${bills.length}');
    return sb.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (bills.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'No bills for ${_months[month]} $year',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
            ),
          ],
        ),
      );
    }

    final slabs = _buildSlabs();
    final sortedSlabs = slabs.values.toList()..sort((a, b) => a.rate - b.rate);
    final csvText = _buildCsvText(slabs);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Header summary card ──────────────────────────────────────────────
        _SummaryCard(
          month: _months[month],
          year: year,
          billCount: bills.length,
          grandTotal: _grandTotal,
          totalTax: _totalTax,
        ),
        const SizedBox(height: 16),

        // ── GST slab breakdown ───────────────────────────────────────────────
        if (sortedSlabs.isNotEmpty) ...[
          const Text('GST Slab Breakdown',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _SlabHeader(),
                ...sortedSlabs.map((s) => _SlabRow(slab: s)),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── Exempt sales ─────────────────────────────────────────────────────
        if (_exemptSales > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Exempt / 0% GST Sales',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                Text('₹${_exemptSales.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── Export buttons ───────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  await _generateAndSharePdf(
                    context,
                    slabs,
                    month: _months[month],
                    year: year,
                    billCount: bills.length,
                    grandTotal: _grandTotal,
                    totalTax: _totalTax,
                    exemptSales: _exemptSales,
                    shopName: shopName,
                    gstin: gstin,
                  );
                },
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('Download PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: csvText));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('GSTR-1 CSV copied to clipboard')),
                  );
                },
                icon: const Icon(Icons.copy_outlined, size: 18),
                label: const Text('Copy CSV'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  side: const BorderSide(color: AppColors.primary),
                  foregroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Download PDF to share via WhatsApp or paste CSV into Google Sheets.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

// ─── PDF generation ───────────────────────────────────────────────────────────

Future<void> _generateAndSharePdf(
  BuildContext context,
  Map<int, _GstSlab> slabs, {
  required String month,
  required int year,
  required int billCount,
  required double grandTotal,
  required double totalTax,
  required double exemptSales,
  required String shopName,
  required String gstin,
}) async {
  final pdf = pw.Document();
  final sortedSlabs = slabs.values.toList()..sort((a, b) => a.rate - b.rate);

  pdf.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(32),
    build: (pw.Context ctx) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(16),
            decoration: const pw.BoxDecoration(color: PdfColors.green800),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('GSTR-1 Summary Report',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text('$month $year',
                    style: const pw.TextStyle(
                        color: PdfColors.white, fontSize: 14)),
                if (gstin.isNotEmpty)
                  pw.Text('GSTIN: $gstin',
                      style: const pw.TextStyle(
                          color: PdfColors.white, fontSize: 12)),
                if (shopName.isNotEmpty)
                  pw.Text(shopName,
                      style: const pw.TextStyle(
                          color: PdfColors.white, fontSize: 12)),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Summary row
          pw.Row(children: [
            pw.Expanded(
                child: _pdfStatBox(
                    'Total Sales', '₹${grandTotal.toStringAsFixed(2)}')),
            pw.SizedBox(width: 12),
            pw.Expanded(
                child: _pdfStatBox(
                    'GST Collected', '₹${totalTax.toStringAsFixed(2)}')),
            pw.SizedBox(width: 12),
            pw.Expanded(child: _pdfStatBox('Invoices', '$billCount')),
          ]),
          pw.SizedBox(height: 16),

          // Table
          pw.Text('GST Slab Breakdown',
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, fontSize: 14)),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              pw.TableRow(
                decoration:
                    const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _pdfCell('GST Rate', bold: true),
                  _pdfCell('Taxable Amount', bold: true),
                  _pdfCell('CGST', bold: true),
                  _pdfCell('SGST', bold: true),
                  _pdfCell('Total Tax', bold: true),
                ],
              ),
              ...sortedSlabs.map((s) => pw.TableRow(children: [
                    _pdfCell('${s.rate}%'),
                    _pdfCell('₹${s.taxable.toStringAsFixed(2)}'),
                    _pdfCell('₹${s.cgst.toStringAsFixed(2)}'),
                    _pdfCell('₹${s.sgst.toStringAsFixed(2)}'),
                    _pdfCell(
                        '₹${(s.cgst + s.sgst).toStringAsFixed(2)}'),
                  ])),
            ],
          ),

          if (exemptSales > 0) ...[
            pw.SizedBox(height: 12),
            pw.Text(
                'Exempt / 0% GST Sales: ₹${exemptSales.toStringAsFixed(2)}',
                style: const pw.TextStyle(fontSize: 12)),
          ],

          pw.SizedBox(height: 24),
          pw.Text('Generated by weKerala',
              style: const pw.TextStyle(
                  color: PdfColors.grey500, fontSize: 10)),
          pw.Text(
              'Date: ${DateTime.now().toString().substring(0, 10)}',
              style: const pw.TextStyle(
                  color: PdfColors.grey500, fontSize: 10)),
        ],
      );
    },
  ));

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/GSTR1_${month}_$year.pdf');
  await file.writeAsBytes(await pdf.save());

  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'application/pdf')],
    subject: 'GSTR-1 Report $month $year',
  );
}

pw.Widget _pdfStatBox(String label, String value) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey300),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(value,
            style: pw.TextStyle(
                fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.Text(label,
            style: const pw.TextStyle(
                fontSize: 10, color: PdfColors.grey600)),
      ],
    ),
  );
}

pw.Widget _pdfCell(String text, {bool bold = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(text,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight:
              bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        )),
  );
}

// ─── Summary card ─────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String month;
  final int year;
  final int billCount;
  final double grandTotal;
  final double totalTax;

  const _SummaryCard({
    required this.month,
    required this.year,
    required this.billCount,
    required this.grandTotal,
    required this.totalTax,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$month $year',
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          Text('₹${grandTotal.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
          const Text('Total Sales', style: TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 12),
          Row(
            children: [
              _Stat(label: 'Invoices', value: '$billCount'),
              const SizedBox(width: 24),
              _Stat(label: 'GST Collected', value: '₹${totalTax.toStringAsFixed(2)}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }
}

// ─── Slab table ───────────────────────────────────────────────────────────────

class _GstSlab {
  final int rate;
  final double taxable;
  final double cgst;
  final double sgst;
  final double total;
  const _GstSlab({
    required this.rate,
    required this.taxable,
    required this.cgst,
    required this.sgst,
    required this.total,
  });
}

class _SlabHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: const Row(
        children: [
          Expanded(flex: 1, child: Text('Rate', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
          Expanded(flex: 2, child: Text('Taxable', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary), textAlign: TextAlign.right)),
          Expanded(flex: 2, child: Text('CGST', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary), textAlign: TextAlign.right)),
          Expanded(flex: 2, child: Text('SGST', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary), textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _SlabRow extends StatelessWidget {
  final _GstSlab slab;
  const _SlabRow({required this.slab});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('${slab.rate}%',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ),
          ),
          Expanded(flex: 2, child: Text('₹${slab.taxable.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
          Expanded(flex: 2, child: Text('₹${slab.cgst.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
          Expanded(flex: 2, child: Text('₹${slab.sgst.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}
