import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/product_lookup_service.dart';
import '../../../providers/shop_provider.dart';
import '../models/scan_job.dart';
import 'batch_review_screen.dart';

class BatchScanScreen extends ConsumerStatefulWidget {
  const BatchScanScreen({super.key});

  @override
  ConsumerState<BatchScanScreen> createState() => _BatchScanScreenState();
}

class _BatchScanScreenState extends ConsumerState<BatchScanScreen> {
  final List<ScanJob> _jobs = [];
  final _picker = ImagePicker();
  bool _scanning = false;
  int _jobCounter = 0;

  String _getShopType() {
    final shopAsync = ref.read(activeShopProvider);
    return shopAsync.valueOrNull?.shopType ?? '';
  }

  List<String> _getCategories() {
    final shopAsync = ref.read(activeShopProvider);
    return shopAsync.valueOrNull?.categories ?? [];
  }

  Future<void> _takePhoto() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission required.')),
      );
      if (status.isPermanentlyDenied) openAppSettings();
      return;
    }

    setState(() => _scanning = true);
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 800,
      imageQuality: 80,
    );
    if (!mounted) return;
    if (file == null) {
      setState(() => _scanning = false);
      return;
    }

    final id = 'job_${++_jobCounter}';
    final bytes = await file.readAsBytes();
    final base64Image = base64Encode(bytes);

    final job = ScanJob(
      id: id,
      imagePath: file.path,
      base64Image: base64Image,
    );

    setState(() {
      _jobs.add(job);
      _scanning = false;
    });

    // Process in background — does not block the UI
    _processJob(job);
  }

  Future<void> _processJob(ScanJob job) async {
    final data = await ProductLookupService.lookupByPhoto(
      job.base64Image,
      _getCategories(),
      shopType: _getShopType(),
    );
    if (!mounted) return;
    setState(() {
      job.status = data != null && data.hasData ? ScanStatus.done : ScanStatus.failed;
      job.result = data;
    });
  }

  void _goToReview() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BatchReviewScreen(jobs: List.from(_jobs)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final doneCount = _jobs.where((j) => j.status == ScanStatus.done).length;
    final hasJobs = _jobs.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(hasJobs ? 'Batch Scan (${_jobs.length})' : 'Batch Scan'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (hasJobs)
            TextButton.icon(
              onPressed: _goToReview,
              icon: const Icon(Icons.checklist_rounded, color: Colors.white),
              label: Text(
                'Review ($doneCount/${_jobs.length})',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Instructions banner
          Container(
            width: double.infinity,
            color: AppColors.primary.withOpacity(0.08),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Text(
              hasJobs
                  ? 'Keep scanning products. AI identifies each one in the background.'
                  : 'Point camera at each product one by one. AI runs in the background while you scan the next.',
              style: TextStyle(fontSize: 13, color: AppColors.primary, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ),

          // Main scan button
          Expanded(
            child: Center(
              child: _scanning
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: AppColors.primary),
                        const SizedBox(height: 12),
                        const Text('Opening camera...', style: TextStyle(color: Colors.grey)),
                      ],
                    )
                  : GestureDetector(
                      onTap: _takePhoto,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.35),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt_rounded, color: Colors.white, size: 48),
                            SizedBox(height: 6),
                            Text(
                              'Scan Product',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),

          // Thumbnail strip
          if (_jobs.isNotEmpty) ...[
            const Divider(height: 1),
            Container(
              height: 100,
              color: Colors.white,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                itemCount: _jobs.length,
                itemBuilder: (ctx, i) {
                  final job = _jobs[_jobs.length - 1 - i]; // newest first
                  return _ThumbCard(job: job);
                },
              ),
            ),

            // Review button at bottom
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _goToReview,
                    icon: const Icon(Icons.checklist_rounded),
                    label: Text('Review & Add Products ($doneCount ready)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                ),
              ),
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
    return Container(
      width: 76,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: job.status == ScanStatus.done
              ? Colors.green
              : job.status == ScanStatus.failed
                  ? Colors.red.shade300
                  : Colors.orange.shade300,
          width: 2,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(job.imagePath, fit: BoxFit.cover, errorBuilder: (_, __, ___) =>
                Container(color: Colors.grey.shade100,
                  child: const Icon(Icons.image, color: Colors.grey))),
          ),
          Positioned(
            bottom: 2, right: 2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black12)],
              ),
              child: job.status == ScanStatus.scanning
                  ? SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                  : Icon(
                      job.status == ScanStatus.done ? Icons.check_circle : Icons.error,
                      size: 16,
                      color: job.status == ScanStatus.done ? Colors.green : Colors.red,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
