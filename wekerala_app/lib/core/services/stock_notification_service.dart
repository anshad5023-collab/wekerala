import 'package:cloud_firestore/cloud_firestore.dart';
import 'local_notification_service.dart';

/// Queries the shop's products and fires a local notification when there are
/// low-stock or soon-to-expire items.  Notifications are non-critical — any
/// error is silently swallowed so the app never crashes because of them.
class StockNotificationService {
  static Future<void> checkAndNotify(String shopId) async {
    try {
      final productsSnap = await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('products')
          .where('isHidden', isEqualTo: false)
          .get();

      int lowStockCount = 0;
      int expiringCount = 0;
      final now = DateTime.now();
      final sevenDaysFromNow = now.add(const Duration(days: 7));

      for (final doc in productsSnap.docs) {
        final data = doc.data();
        final stockQty = data['stockQty'] as int?;
        final lowThreshold =
            (data['lowStockThreshold'] as num?)?.toInt() ?? 5;
        final expiryTs = data['expiryDate'] as dynamic;

        if (stockQty != null && stockQty < lowThreshold) {
          lowStockCount++;
        }

        if (expiryTs != null) {
          DateTime? expiry;
          if (expiryTs is Timestamp) expiry = expiryTs.toDate();
          if (expiry != null &&
              expiry.isAfter(now) &&
              expiry.isBefore(sevenDaysFromNow)) {
            expiringCount++;
          }
        }
      }

      await LocalNotificationService.scheduleDailyStockAlert(
        lowStockCount: lowStockCount,
        expiringCount: expiringCount,
      );
    } catch (_) {
      // Notifications are non-critical — never crash the app
    }
  }
}
