import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

/// Image-processing helpers for the Live Walk-Past Scan feature.
///
/// Two jobs, both designed to run without any cloud call:
///   1. [computeSharpness] — decide *when* a frame is in focus (cheap, runs on
///      every sampled preview frame).
///   2. [extractFrame] + [frameToJpeg] — turn the chosen YUV420 camera frame
///      into an upright JPEG we can show and send to Gemini. [frameToJpeg] is a
///      top-level function so it can run inside `compute()` on a background
///      isolate and never jank the camera preview.
///
/// Android-only: the camera stream is started with `ImageFormatGroup.yuv420`,
/// so every frame has a Y (luminance) plane plus half-resolution U/V planes.

/// Variance of the Laplacian over the luminance plane — the standard, model-free
/// blur metric. Higher = sharper. A blurry frame has little high-frequency
/// detail so neighbouring pixels are similar and the variance collapses.
///
/// Only the central 60% of the frame is measured (that's where the owner aims
/// the product) and pixels are subsampled, so this stays a few-millisecond
/// operation regardless of preview resolution.
double computeSharpness(CameraImage image) {
  if (image.planes.isEmpty) return 0;
  final yPlane = image.planes[0];
  final bytes = yPlane.bytes;
  final rowStride = yPlane.bytesPerRow;
  final width = image.width;
  final height = image.height;

  final x0 = (width * 0.2).toInt();
  final x1 = (width * 0.8).toInt();
  final y0 = (height * 0.2).toInt();
  final y1 = (height * 0.8).toInt();

  // Keep roughly ~120 samples across the region whatever the resolution.
  final step = ((x1 - x0) ~/ 120).clamp(1, 8);

  // Welford's online algorithm for variance — single pass, no big allocations.
  double mean = 0;
  double m2 = 0;
  int n = 0;
  for (int y = y0 + step; y < y1 - step; y += step) {
    final row = y * rowStride;
    final rowUp = (y - step) * rowStride;
    final rowDown = (y + step) * rowStride;
    for (int x = x0 + step; x < x1 - step; x += step) {
      final c = bytes[row + x];
      final left = bytes[row + x - step];
      final right = bytes[row + x + step];
      final up = bytes[rowUp + x];
      final down = bytes[rowDown + x];
      final lap = (4 * c - left - right - up - down).toDouble();
      n++;
      final delta = lap - mean;
      mean += delta / n;
      m2 += delta * (lap - mean);
    }
  }
  if (n < 2) return 0;
  return m2 / (n - 1);
}

/// A fast perceptual hash (8×8 "average hash") of the frame's luminance, used
/// to detect when the camera is still pointed at the *same* product so we don't
/// capture and pay to identify it again.
///
/// Samples an 8×8 grid over the central 80% of the frame, then sets one bit per
/// cell that is brighter than the grid's mean. Two frames of the same product
/// produce near-identical hashes; moving to a different product changes many
/// bits. Compare with [hammingDistance].
int averageHashY(CameraImage image) {
  if (image.planes.isEmpty) return 0;
  final bytes = image.planes[0].bytes;
  final rowStride = image.planes[0].bytesPerRow;
  final w = image.width;
  final h = image.height;

  final x0 = (w * 0.1).toInt();
  final x1 = (w * 0.9).toInt();
  final y0 = (h * 0.1).toInt();
  final y1 = (h * 0.9).toInt();
  final cellW = (x1 - x0) / 8.0;
  final cellH = (y1 - y0) / 8.0;

  final samples = List<int>.filled(64, 0);
  int sum = 0;
  for (int gy = 0; gy < 8; gy++) {
    for (int gx = 0; gx < 8; gx++) {
      final px = (x0 + (gx + 0.5) * cellW).toInt().clamp(0, w - 1);
      final py = (y0 + (gy + 0.5) * cellH).toInt().clamp(0, h - 1);
      final v = bytes[py * rowStride + px];
      samples[gy * 8 + gx] = v;
      sum += v;
    }
  }
  final mean = sum / 64.0;
  int hash = 0;
  for (int i = 0; i < 64; i++) {
    if (samples[i] > mean) hash |= (1 << i);
  }
  return hash;
}

/// Number of differing bits between two [averageHashY] values. 0 = identical
/// scene; larger = more different. ~5 or below means "same product".
int hammingDistance(int a, int b) {
  int x = a ^ b;
  int count = 0;
  while (x != 0) {
    count += x & 1;
    x = x >>> 1; // unsigned shift so the top (sign) bit is counted correctly
  }
  return count;
}

/// A copy of one camera frame's raw bytes + geometry. We snapshot this
/// synchronously inside the image-stream callback (the [CameraImage] itself is
/// only valid for the duration of that callback) so the heavy conversion can
/// then happen later on an isolate.
class CapturedFrame {
  final int width;
  final int height;
  final Uint8List y;
  final Uint8List u;
  final Uint8List v;
  final int yRowStride;
  final int uvRowStride;
  final int uvPixelStride;

  /// Degrees to rotate the decoded image so it appears upright (the back-camera
  /// sensor is usually mounted at 90°).
  final int rotation;

  const CapturedFrame({
    required this.width,
    required this.height,
    required this.y,
    required this.u,
    required this.v,
    required this.yRowStride,
    required this.uvRowStride,
    required this.uvPixelStride,
    required this.rotation,
  });
}

/// Snapshot a [CameraImage] into a self-contained [CapturedFrame]. Must be
/// called synchronously inside the stream callback, before any `await`.
CapturedFrame extractFrame(CameraImage image, int sensorOrientation) {
  return CapturedFrame(
    width: image.width,
    height: image.height,
    y: Uint8List.fromList(image.planes[0].bytes),
    u: Uint8List.fromList(image.planes[1].bytes),
    v: Uint8List.fromList(image.planes[2].bytes),
    yRowStride: image.planes[0].bytesPerRow,
    uvRowStride: image.planes[1].bytesPerRow,
    uvPixelStride: image.planes[1].bytesPerPixel ?? 1,
    rotation: sensorOrientation % 360,
  );
}

/// Convert a [CapturedFrame] (YUV420) to an upright JPEG. Top-level so it can be
/// handed to `compute()`. Runs the textbook YUV→RGB conversion, honouring the
/// U/V plane row- and pixel-strides (handles both planar and NV21-interleaved
/// layouts).
Uint8List frameToJpeg(CapturedFrame f) {
  final out = img.Image(width: f.width, height: f.height);
  final uMax = f.u.length;
  final vMax = f.v.length;

  for (int y = 0; y < f.height; y++) {
    final yRow = y * f.yRowStride;
    final uvRow = (y >> 1) * f.uvRowStride;
    for (int x = 0; x < f.width; x++) {
      final yp = f.y[yRow + x];
      var uvIndex = uvRow + (x >> 1) * f.uvPixelStride;
      if (uvIndex >= uMax) uvIndex = uMax - 1;
      final up = f.u[uvIndex];
      final vp = f.v[uvIndex < vMax ? uvIndex : vMax - 1];

      final r = (yp + 1.402 * (vp - 128)).round().clamp(0, 255);
      final g = (yp - 0.344136 * (up - 128) - 0.714136 * (vp - 128))
          .round()
          .clamp(0, 255);
      final b = (yp + 1.772 * (up - 128)).round().clamp(0, 255);
      out.setPixelRgb(x, y, r, g, b);
    }
  }

  final upright = f.rotation == 0 ? out : img.copyRotate(out, angle: f.rotation);
  return Uint8List.fromList(img.encodeJpg(upright, quality: 80));
}
