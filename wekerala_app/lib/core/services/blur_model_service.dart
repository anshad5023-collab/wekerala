import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// On-device blur classifier (MobileNetV2, classes [BLUR, SHARP]) used as a
/// lenient, fail-open quality gate for Live Walk-Past Scan. It NEVER blocks the
/// feature: if the model is missing, fails to load, or errors, callers get
/// `null` and fall back to the Laplacian + best-shot + MLKit-text gates.
///
/// Model input: 224x224 RGB, pixels scaled to [0,1] (imageMean 0, imageStd 255).
/// Output: softmax over [BLUR, SHARP]; we return P(SHARP).
class BlurModelService {
  static Interpreter? _interp;
  static bool _triedLoad = false;
  static bool _disabled = false;

  static Future<void> _ensureLoaded() async {
    if (_triedLoad) return;
    _triedLoad = true;
    try {
      _interp = await Interpreter.fromAsset('assets/models/blur_model.tflite');
    } catch (e) {
      debugPrint('BlurModelService: model load failed, disabling: $e');
      _interp = null;
      _disabled = true;
    }
  }

  /// Probability (0..1) that the JPEG is sharp. `null` when the model is
  /// unavailable or inference fails — callers must treat null as "no opinion".
  static Future<double?> sharpProbabilityFromJpeg(Uint8List jpeg) async {
    if (_disabled) return null;
    await _ensureLoaded();
    final interp = _interp;
    if (interp == null) return null;
    try {
      final decoded = img.decodeJpg(jpeg);
      if (decoded == null) return null;
      final resized = img.copyResize(decoded, width: 224, height: 224);

      // Build [1,224,224,3] float input normalised to [0,1].
      final input = List.generate(
        1,
        (_) => List.generate(
          224,
          (y) => List.generate(224, (x) {
            final p = resized.getPixel(x, y);
            return [p.r / 255.0, p.g / 255.0, p.b / 255.0];
          }),
        ),
      );
      final output = List.generate(1, (_) => List.filled(2, 0.0));
      interp.run(input, output);
      // labels.txt order: index 0 = BLUR, index 1 = SHARP
      final sharp = output[0][1];
      return sharp.toDouble();
    } catch (e) {
      debugPrint('BlurModelService: inference failed, disabling: $e');
      _disabled = true;
      return null;
    }
  }
}
