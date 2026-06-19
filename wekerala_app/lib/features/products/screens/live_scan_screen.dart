import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/blur_model_service.dart';
import '../../../core/services/product_lookup_service.dart';
import '../../../core/utils/frame_analysis.dart';
import '../../../models/shop_model.dart';
import '../../../providers/shop_provider.dart';
import '../models/scan_job.dart';
import 'batch_review_screen.dart';

/// Live Walk-Past Scan.
///
/// The owner slowly moves the phone across the shelves. Each frame is checked
/// on-device for sharpness (free, no cloud call); when a product label comes
/// into focus the frame is captured automatically — no button press. Captures
/// are converted to JPEG on a background isolate and queued; up to 3 are sent to
/// Gemini concurrently so identification keeps pace with scanning. When done the
/// owner taps Review to reuse the normal batch review/save screen.
class LiveScanScreen extends ConsumerStatefulWidget {
  const LiveScanScreen({super.key});

  @override
  ConsumerState<LiveScanScreen> createState() => _LiveScanScreenState();
}

class _LiveScanScreenState extends ConsumerState<LiveScanScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _initializing = true;
  String? _error;

  // Auto-capture tuning
  bool _paused = false;
  bool _converting = false;
  double _sensitivity = 0.5; // 0 = only very sharp, 1 = capture eagerly
  double _lastSharpness = 0;
  int _sharpStreak = 0;
  DateTime _lastProcess = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastCaptureAt = DateTime.fromMillisecondsSinceEpoch(0);

  // Capture feedback
  bool _flash = false;

  // On-device text recognition — only capture frames that contain a product
  // label, so floors / walls / empty shelves are never captured.
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);
  bool _mlkitBroken = false; // if MLKit ever errors, fail open (capture anyway)

  // Duplicate detection — perceptual hashes of recent captures.
  final List<int> _recentHashes = [];
  int _duplicatesSkipped = 0;

  // Jobs + background processing queue
  final List<ScanJob> _jobs = [];
  final List<ScanJob> _pending = [];
  int _activeWorkers = 0;
  int _jobCounter = 0;
  static const _maxWorkers = 3;

  // Throttle UI rebuilds for the live sharpness bar.
  DateTime _lastBarUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  // Best-shot burst: once a product is detected, sample frames for a short
  // window and keep the SHARPEST one before sending — much better than grabbing
  // whatever single frame happened to trip the trigger.
  bool _collecting = false;
  DateTime _burstStart = DateTime.fromMillisecondsSinceEpoch(0);
  double _burstBestSharp = 0;
  CapturedFrame? _burstBest;
  int _burstHash = 0;
  static const _burstMs = 450;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _recognizer.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      c.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _init();
    }
  }

  ShopModel? _getShop() {
    final shopId = ref.read(activeShopIdProvider).valueOrNull ?? '';
    if (shopId.isEmpty) return null;
    return ref.read(shopStreamProvider(shopId)).valueOrNull;
  }

  String _getShopType() => _getShop()?.shopType ?? '';
  List<String> _getCategories() => _getShop()?.categories ?? [];

  Future<void> _init() async {
    setState(() {
      _initializing = true;
      _error = null;
    });

    final status = await Permission.camera.request();
    if (!mounted) return;
    if (!status.isGranted) {
      setState(() {
        _initializing = false;
        _error = 'Camera permission is required for live scan.';
      });
      if (status.isPermanentlyDenied) openAppSettings();
      return;
    }

    try {
      final cameras = await availableCameras();
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.high, // 720p — needed for sharpness detection + MLKit text gate + Gemini label reading
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      await controller.startImageStream(_onFrame);
      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = 'Could not start camera: $e';
      });
    }
  }

  /// Map the sensitivity slider to a Laplacian-variance threshold. Higher
  /// sensitivity → lower threshold → captures more readily.
  double get _threshold {
    // 0.0 -> 600 (strict, only crisp labels), 1.0 -> 120 (eager)
    return 600 - (_sensitivity * 480);
  }

  void _onFrame(CameraImage image) {
    final now = DateTime.now();
    if (_paused) return;

    // ── Best-shot burst in progress: sample every frame, keep the sharpest ──
    if (_collecting) {
      final s = computeSharpness(image);
      if (s > _burstBestSharp) {
        _burstBestSharp = s;
        final so = _controller?.description.sensorOrientation ?? 90;
        _burstBest = extractFrame(image, so);
      }
      if (now.difference(_burstStart).inMilliseconds >= _burstMs) {
        _collecting = false;
        final best = _burstBest;
        _burstBest = null;
        if (best != null) {
          _converting = true;
          _handleCandidate(best, _burstHash);
        }
      }
      return;
    }

    // Sample ~5 frames/sec for detection — light on CPU.
    if (now.difference(_lastProcess).inMilliseconds < 180) return;
    _lastProcess = now;
    if (_converting) return;

    final sharp = computeSharpness(image);
    _lastSharpness = sharp;

    if (sharp >= _threshold) {
      _sharpStreak++;
    } else {
      _sharpStreak = 0;
    }

    final cooldownOk = now.difference(_lastCaptureAt).inMilliseconds > 1100;

    // Three consecutive sharp samples = the camera has genuinely settled on a
    // product, not a blur passing through focus during a fast pan or a brief
    // glance at the floor while walking.
    if (_sharpStreak >= 3 && cooldownOk) {
      _sharpStreak = 0;
      // Duplicate guard: skip if it looks like the product we just captured.
      final hash = averageHashY(image);
      if (_isDuplicateScene(hash)) {
        _lastCaptureAt = now;
        return;
      }
      _lastCaptureAt = now;
      // Start a best-shot burst: seed with this frame, then keep the sharpest
      // over the next ~450ms before handing off for capture.
      final so = _controller?.description.sensorOrientation ?? 90;
      _burstBest = extractFrame(image, so);
      _burstBestSharp = sharp;
      _burstHash = hash;
      _burstStart = now;
      _collecting = true;
    }

    // Throttle the sharpness-bar rebuild to ~8 fps.
    if (now.difference(_lastBarUpdate).inMilliseconds > 120) {
      _lastBarUpdate = now;
      if (mounted) setState(() {});
    }
  }

  /// Decide whether a settled frame is actually a product label, then capture.
  Future<void> _handleCandidate(CapturedFrame frame, int hash) async {
    try {
      // Text gate: a product label has printed text; an empty floor, wall or
      // shelf does not. Skip frames with no readable text so we never capture
      // (or pay to identify) emptiness.
      if (!_mlkitBroken) {
        bool hasText;
        try {
          hasText = await _frameHasText(frame);
        } catch (e) {
          debugPrint('MLKit text gate failed — disabling it: $e');
          _mlkitBroken = true;
          hasText = true; // fail open: keep the feature working
        }
        if (!hasText) return; // not a product label → skip silently
      }

      // Confirmed label → remember the scene (for dedup) and capture.
      _recentHashes.add(hash);
      if (_recentHashes.length > 18) _recentHashes.removeAt(0);
      await _convertAndQueue(frame);
    } finally {
      _converting = false;
    }
  }

  Future<bool> _frameHasText(CapturedFrame frame) async {
    final bytes = grayNv21FromFrame(frame);
    final input = InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(frame.width.toDouble(), frame.height.toDouble()),
        rotation: InputImageRotationValue.fromRawValue(frame.rotation) ??
            InputImageRotation.rotation0deg,
        format: InputImageFormat.nv21,
        bytesPerRow: frame.width,
      ),
    );
    final result = await _recognizer.processImage(input);
    // Require a clearly readable label, not a stray reflection or one faint
    // character. We look for a decent amount of recognised text spread over at
    // least two separate lines — that reliably means a real product label is in
    // view and legible, while floors/walls/blurry frames produce little or none.
    final chars = result.text.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    int lines = 0;
    for (final block in result.blocks) {
      lines += block.lines.length;
    }
    return (chars.length >= 8 && lines >= 1) ||
        (chars.length >= 5 && lines >= 2);
  }

  Future<void> _convertAndQueue(CapturedFrame frame) async {
    if (mounted) setState(() => _flash = true);
    try {
      final jpeg = await compute(frameToJpeg, frame);

      // Lenient blur gate (fail-open): only discard if the on-device model is
      // confident the shot is blurry. null = model unavailable → don't block.
      final sharpProb = await BlurModelService.sharpProbabilityFromJpeg(jpeg);
      if (sharpProb != null && sharpProb < 0.25) {
        debugPrint('Blur model rejected frame (P_sharp=$sharpProb)');
        return;
      }

      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/livescan_${DateTime.now().microsecondsSinceEpoch}.jpg';
      await File(path).writeAsBytes(jpeg, flush: false);

      final job = ScanJob(
        id: 'job_${++_jobCounter}',
        imagePath: path,
        base64Image: base64Encode(jpeg),
      );
      if (mounted) {
        setState(() => _jobs.add(job));
      } else {
        _jobs.add(job);
      }
      _enqueue(job);
    } catch (e) {
      debugPrint('Live capture conversion failed: $e');
    } finally {
      if (mounted) setState(() => _flash = false);
    }
  }

  // ── Background identification queue ──────────────────────────────────────

  void _enqueue(ScanJob job) {
    _pending.add(job);
    _pump();
  }

  void _pump() {
    while (_activeWorkers < _maxWorkers && _pending.isNotEmpty) {
      final job = _pending.removeAt(0);
      _activeWorkers++;
      _process(job);
    }
  }

  Future<void> _process(ScanJob job) async {
    try {
      final data = await ProductLookupService.lookupByPhoto(
        job.base64Image,
        _getCategories(),
        shopType: _getShopType(),
      );
      final done = data != null && data.hasData;

      // Name-level duplicate guard.
      if (done) {
        final norm = _normName(data!.nameEn);
        final isDup = norm.isNotEmpty &&
            _jobs.any((j) =>
                !identical(j, job) &&
                j.status == ScanStatus.done &&
                j.result != null &&
                _normName(j.result!.nameEn) == norm);
        if (isDup) {
          _jobs.remove(job);
          _duplicatesSkipped++;
          _toast('Already scanned: ${data.nameEn}');
          if (mounted) setState(() {});
          _activeWorkers--;
          _pump();
          return;
        }
      }

      job.status = done ? ScanStatus.done : ScanStatus.failed;
      job.result = data;
    } catch (e) {
      // Network error, timeout, etc. — mark failed so the queue keeps moving.
      job.status = ScanStatus.failed;
      debugPrint('Live scan identify error: $e');
    }
    if (mounted) setState(() {});
    _activeWorkers--;
    _pump();
  }

  bool _isDuplicateScene(int hash) {
    for (final h in _recentHashes) {
      if (hammingDistance(h, hash) <= 5) return true;
    }
    return false;
  }

  String _normName(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Navigation ───────────────────────────────────────────────────────────

  Future<void> _goToReview() async {
    setState(() => _paused = true);
    await _controller?.stopImageStream().catchError((_) {});
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BatchReviewScreen(jobs: List.from(_jobs)),
    ));
    // Coming back: resume scanning if the controller is still alive.
    if (mounted && (_controller?.value.isInitialized ?? false)) {
      try {
        await _controller!.startImageStream(_onFrame);
        setState(() => _paused = false);
      } catch (_) {}
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final doneCount = _jobs.where((j) => j.status == ScanStatus.done).length;
    final isSharp = _lastSharpness >= _threshold;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Live Walk-Past Scan'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: _paused ? 'Resume' : 'Pause',
            icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
            onPressed: () => setState(() => _paused = !_paused),
          ),
        ],
      ),
      body: _buildBody(isSharp),
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

  Widget _buildBody(bool isSharp) {
    if (_initializing) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 12),
            Text('Starting camera…', style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off, color: Colors.white54, size: 48),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _init, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // Camera preview with overlays
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(controller),

              // Capture flash
              if (_flash)
                Container(color: Colors.white.withOpacity(0.35)),

              // Centre focus frame — green when sharp enough to capture
              Center(
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _paused
                          ? Colors.grey
                          : isSharp
                              ? Colors.greenAccent
                              : Colors.white54,
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),

              // Status pill
              Positioned(
                top: 12,
                left: 0,
                right: 0,
                child: Center(child: _statusPill(isSharp)),
              ),

              // Counter
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _duplicatesSkipped > 0
                        ? '${_jobs.length} captured · $_duplicatesSkipped dup skipped'
                        : '${_jobs.length} captured',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Controls + thumbnails
        Container(
          color: Colors.black,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.tune, color: Colors.white54, size: 18),
                  const SizedBox(width: 8),
                  const Text('Capture sensitivity',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Expanded(
                    child: Slider(
                      value: _sensitivity,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setState(() => _sensitivity = v),
                    ),
                  ),
                ],
              ),
              const Text(
                'Move slowly. The box turns green and captures automatically '
                'when a label is in focus.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),

        if (_jobs.isNotEmpty)
          Container(
            height: 92,
            color: Colors.black,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _jobs.length,
              itemBuilder: (ctx, i) =>
                  _ThumbCard(job: _jobs[_jobs.length - 1 - i]),
            ),
          ),
      ],
    );
  }

  Widget _statusPill(bool isSharp) {
    final processing = _activeWorkers > 0 || _pending.isNotEmpty;
    final String label;
    final Color color;
    if (_paused) {
      label = 'Paused';
      color = Colors.grey;
    } else if (isSharp) {
      label = 'In focus — capturing';
      color = Colors.green;
    } else {
      label = 'Move closer / hold steady';
      color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
          if (processing) ...[
            const SizedBox(width: 8),
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }
}

class _ThumbCard extends StatelessWidget {
  final ScanJob job;
  const _ThumbCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final borderColor = job.status == ScanStatus.done
        ? Colors.green
        : job.status == ScanStatus.failed
            ? Colors.red.shade300
            : Colors.orange.shade300;
    return Container(
      width: 72,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(job.imagePath),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey.shade800,
                child: const Icon(Icons.image, color: Colors.grey),
              ),
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
