import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;

/// Uploads images to Firebase Storage. Every image is compressed first — a raw
/// phone photo is 2–4 MB, which costs storage AND is re-downloaded by every
/// customer who views the shop website, forever. Resizing + JPEG re-encoding
/// brings that to ~80–200 KB (10–30× smaller) with no visible quality loss at
/// the sizes products are actually shown, cutting both storage and bandwidth
/// bills dramatically as the number of shops and visitors grows.
class StorageService {
  StorageService._();

  static Future<String> uploadBanner(String shopId, File file) async {
    final bytes = await _compressFile(file, maxDim: 1400, quality: 75);
    final ref = FirebaseStorage.instance.ref('shops/$shopId/banner.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  static Future<String> uploadProductImage(
      String shopId, String productId, File file) async {
    final bytes = await _compressFile(file, maxDim: 1000, quality: 70);
    final ref = FirebaseStorage.instance
        .ref('shops/$shopId/products/$productId.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  static Future<String> uploadShopPhoto(
      String shopId, String photoId, File file) async {
    final bytes = await _compressFile(file, maxDim: 1200, quality: 72);
    final ref = FirebaseStorage.instance
        .ref('shops/$shopId/photos/$photoId.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  /// Read + compress on a background isolate. Falls back to the raw bytes if the
  /// image can't be decoded, so an upload never fails because of compression.
  static Future<Uint8List> _compressFile(File file,
      {required int maxDim, required int quality}) async {
    final raw = await file.readAsBytes();
    try {
      return await compute(
          _compressBytes, _CompressArgs(raw, maxDim, quality));
    } catch (_) {
      return raw;
    }
  }
}

class _CompressArgs {
  final Uint8List bytes;
  final int maxDim;
  final int quality;
  const _CompressArgs(this.bytes, this.maxDim, this.quality);
}

/// Top-level so it can run inside `compute()`. Decodes, downscales the longer
/// side to [maxDim] (only if larger), and re-encodes as JPEG.
Uint8List _compressBytes(_CompressArgs a) {
  final decoded = img.decodeImage(a.bytes);
  if (decoded == null) return a.bytes;
  img.Image out = decoded;
  final longest =
      decoded.width > decoded.height ? decoded.width : decoded.height;
  if (longest > a.maxDim) {
    out = decoded.width >= decoded.height
        ? img.copyResize(decoded, width: a.maxDim)
        : img.copyResize(decoded, height: a.maxDim);
  }
  return Uint8List.fromList(img.encodeJpg(out, quality: a.quality));
}
