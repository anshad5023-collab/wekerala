import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  StorageService._();

  static Future<String> uploadBanner(String shopId, File file) async {
    final ref = FirebaseStorage.instance.ref('shops/$shopId/banner.jpg');
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  static Future<String> uploadProductImage(
      String shopId, String productId, File file) async {
    final ref = FirebaseStorage.instance
        .ref('shops/$shopId/products/$productId.jpg');
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  static Future<String> uploadShopPhoto(
      String shopId, String photoId, File file) async {
    final ref = FirebaseStorage.instance
        .ref('shops/$shopId/photos/$photoId.jpg');
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }
}
