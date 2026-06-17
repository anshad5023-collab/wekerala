import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/product_lookup_service.dart';
import '../../../models/shop_model.dart';
import '../../../providers/shop_provider.dart';
import '../models/scan_job.dart';
import 'batch_review_screen.dart';

/// Live Barcode Scan — the owner moves the phone along the shelf and every
/// product barcode is detected and looked up automatically. No button press,
/// no Gemini cost. Works perfectly for all packaged products (shoes, food,
/// electronics) because they all have EAN13/UPC barcodes.
///
/// Lookup cascade: community DB (free, shared across Kerala) → Open Food Facts
/// (food) → UPC Item DB (non-food). Products found here are also saved back to
/// the community DB so the next shop gets them instantly for free.
class LiveBarcodeScanScreen extends ConsumerStatefulWidget {
  const LiveBarcodeScanScreen({super.key});

  @override
  ConsumerState<LiveBarcodeScanScreen> createState() =>
      _LiveBarcodeScanScreenState();
}

class _LiveBarcodeScanScreenState
    extends ConsumerState<LiveBarcodeScanScreen> {
  final MobileScannerController _scanner = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    returnImage: false,
  );

  final List<ScanJob> _jobs = [];
  final Set<String> _seenBarcodes = {};

  // Same queue pattern as live_scan_screen — up to 4 concurrent lookups.
  final List<({String barcode, ScanJob job})> _pending = [];
  int _activeWorkers = 0;
  static const _maxWorkers = 4;

  bool _paused = false;
  bool _flashOn = false;
  int _jobCounter = 0;

  // Flash feedback when a barcode is detected.
  bool _flashFeedback = false;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  ShopModel? _getShop() {
    final shopId = ref.read(activeShopIdProvider).valueOrNull ?? '';
    if (shopId.isEmpty) return null;
    return ref.read(shopStreamProvider(shopId)).valueOrNull;
  }

  String _getShopType() => _getShop()?.shopType ?? '';
  List<String> _getCategories() => _getShop()?.categories ?? [];

  void _onDetect(BarcodeCapture capture) {
    if (_paused) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value == null || value.length < 4) continue;
      if (_seenBarcodes.contains(value)) continue;

      _seenBarcodes.add(value);

      final job = ScanJob(
        id: 'bc_${++_jobCounter}',
        imagePath: '',
        base64Image: '',
        barcode: value,
      );
      setState(() {
        _jobs.add(job);
        _flashFeedback = true;
      });
      Future.delayed(const Duration(milliseconds: 150),
          () { if (mounted) setState(() => _flashFeedback = false); });

      _pending.add((barcode: value, job: job));
      _pump();
      break; // one per detection event — prevents double-counting a single scan
    }
  }

  void _pump() {
    while (_activeWorkers < _maxWorkers && _pending.isNotEmpty) {
      final item = _pending.removeAt(0);
      _activeWorkers++;
      _processBarcode(item.barcode, item.job);
    }
  }

  Future<void> _processBarcode(String barcode, ScanJob job) async {
    try {
      final data = await ProductLookupService.lookupBarcode(
        barcode,
        _getCategories(),
        shopType: _getShopType(),
      );
      job.status =
          (data != null && data.hasData) ? ScanStatus.done : ScanStatus.failed;
      job.result = data;
    } catch (e) {
      job.status = ScanStatus.failed;
      debugPrint('Barcode lookup error: $e');
    }
    if (mounted) setState(() {});
    _activeWorkers--;
    _pump();
  }

  Future<void> _goToReview() async {
    setState(() => _paused = true);
    await _scanner.stop().catchError((_) {});
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BatchReviewScreen(jobs: List.from(_jobs)),
    ));
    if (mounted) {
      await _scanner.start().catchError((_) {});
      setState(() => _paused = false);
    }
  }

  Future<void> _toggleFlash() async {
    await _scanner.toggleTorch().catchError((_) {});
    setState(() => _flashOn = !_flashOn);
  }

  @override
  Widget build(BuildContext context) {
    final doneCount = _jobs.where((j) => j.status == ScanStatus.done).length;
    final processing = _activeWorkers > 0 || _pending.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Live Barcode Scan'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: _flashOn ? 'Flash off' : 'Flash on',
            icon: Icon(_flashOn ? Icons.flash_on : Icons.flash_off),
            onPressed: _toggleFlash,
          ),
          IconButton(
            tooltip: _paused ? 'Resume' : 'Pause',
            icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
            onPressed: () async {
              if (_paused) {
                await _scanner.start().catchError((_) {});
                setState(() => _paused = false);
              } else {
                await _scanner.stop().catchError((_) {});
                setState(() => _paused = true);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Camera + overlays
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _scanner,
                  onDetect: _onDetect,
                ),

                // Capture flash
                if (_flashFeedback)
                  Container(color: Colors.white.withOpacity(0.25)),

                // Paused overlay
                if (_paused)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Text('Paused',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),

                // Centre scan frame
                Center(
                  child: Container(
                    width: 260,
                    height: 130,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _paused
                            ? Colors.grey
                            : AppColors.primary,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                // Status pill
                Positioned(
                  top: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: _paused
                                  ? Colors.grey
                                  : processing
                                      ? Colors.orange
                                      : Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _paused
                                ? 'Paused'
                                : processing
                                    ? 'Looking up $_activeWorkers product${_activeWorkers == 1 ? "" : "s"}…'
                                    : 'Point at barcode',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Capture count badge
                if (_jobs.isNotEmpty)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_jobs.length} scanned',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Hint
          Container(
            color: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const Text(
              'Move slowly along the shelf. Each barcode is looked up automatically — no button press needed.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ),

          // Thumbnail strip
          if (_jobs.isNotEmpty)
            Container(
              height: 92,
              color: Colors.black,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: _jobs.length,
                itemBuilder: (ctx, i) =>
                    _BarcodeThumbCard(job: _jobs[_jobs.length - 1 - i]),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _jobs.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: ElevatedButton.icon(
                  onPressed: _goToReview,
                  icon: const Icon(Icons.checklist_rounded),
                  label: Text(
                      'Review & Add Products  ($doneCount / ${_jobs.length} ready)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ),
    );
  }
}

class _BarcodeThumbCard extends StatelessWidget {
  final ScanJob job;
  const _BarcodeThumbCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final borderColor = job.status == ScanStatus.done
        ? Colors.green
        : job.status == ScanStatus.failed
            ? Colors.red.shade300
            : Colors.orange.shade300;

    final name = job.result?.nameEn ?? '';

    return Container(
      width: 72,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.qr_code_2_rounded,
                  color: Colors.white38,
                  size: 28,
                ),
                if (name.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 8,
                        height: 1.2),
                  ),
                ] else if (job.barcode.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    job.barcode.length > 8
                        ? '…${job.barcode.substring(job.barcode.length - 6)}'
                        : job.barcode,
                    style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 8),
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
              child: job.status == ScanStatus.scanning
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(
                      job.status == ScanStatus.done
                          ? Icons.check_circle
                          : Icons.error,
                      size: 15,
                      color: job.status == ScanStatus.done
                          ? Colors.green
                          : Colors.red,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
