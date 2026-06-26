import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Detect a barcode inside an already-captured still image (e.g. an AI-scan
/// photo). This lets packaged products get their real EAN/UPC linked
/// automatically from the same photo the owner took to identify them — no
/// separate barcode scan step.
///
/// A controller is created and disposed per call so it never competes with a
/// live camera stream that may be running elsewhere.
class BarcodeReader {
  /// Returns the first usable barcode found in [imagePath], or '' if none.
  static Future<String> fromImage(String imagePath) async {
    if (imagePath.isEmpty) return '';
    final controller = MobileScannerController();
    try {
      final result = await controller.analyzeImage(imagePath);
      final code = result?.barcodes.isNotEmpty == true
          ? result!.barcodes.first.rawValue
          : null;
      // Require a plausible product barcode length to avoid stray short codes.
      if (code != null && code.trim().length >= 6) return code.trim();
    } catch (e) {
      debugPrint('BarcodeReader.fromImage failed: $e');
    } finally {
      await controller.dispose();
    }
    return '';
  }
}
