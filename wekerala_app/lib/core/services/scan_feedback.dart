import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Audible + haptic feedback for barcode scanning at the counter — so it feels
/// like a real supermarket POS: a crisp high "beep" when an item is added, and
/// a lower buzz when something's wrong (unknown barcode / out of stock).
///
/// Two dedicated players are kept in low-latency mode and reused, so repeated
/// rapid scans fire instantly without re-loading the asset. If audio can't play
/// for any reason, the system click + haptic still fire, so feedback never
/// fully disappears.
class ScanFeedback {
  ScanFeedback._();

  static final AudioPlayer _success = AudioPlayer()
    ..setPlayerMode(PlayerMode.lowLatency)
    ..setReleaseMode(ReleaseMode.stop);
  static final AudioPlayer _error = AudioPlayer()
    ..setPlayerMode(PlayerMode.lowLatency)
    ..setReleaseMode(ReleaseMode.stop);

  static bool _ready = false;

  /// Preload both tones so the first scan of a session is instant. Safe to call
  /// more than once. Call from a billing/scan screen's initState.
  static Future<void> preload() async {
    if (_ready) return;
    try {
      await _success.setSource(AssetSource('sounds/scan_success.wav'));
      await _error.setSource(AssetSource('sounds/scan_error.wav'));
      _ready = true;
    } catch (e) {
      debugPrint('ScanFeedback preload failed: $e');
    }
  }

  /// Item accepted — crisp beep + light/medium haptic.
  static Future<void> success() async {
    HapticFeedback.mediumImpact();
    await _play(_success, 'sounds/scan_success.wav');
  }

  /// Item rejected (unknown barcode / out of stock) — low buzz + strong haptic.
  static Future<void> error() async {
    HapticFeedback.heavyImpact();
    await _play(_error, 'sounds/scan_error.wav');
  }

  static Future<void> _play(AudioPlayer player, String asset) async {
    try {
      // Restart from the beginning each time for back-to-back scans.
      await player.stop();
      await player.play(AssetSource(asset));
    } catch (e) {
      // Last-resort fallback so there's always *some* audible cue.
      SystemSound.play(SystemSoundType.click);
      debugPrint('ScanFeedback play failed: $e');
    }
  }

  static Future<void> dispose() async {
    await _success.dispose();
    await _error.dispose();
    _ready = false;
  }
}
