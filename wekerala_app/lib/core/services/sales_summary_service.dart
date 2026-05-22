import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/bill_model.dart';

class SalesSummaryService {
  static Future<Map<String, dynamic>> getTodaySummary(String shopId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final snapshot = await FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .collection('bills')
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .get();

    final bills =
        snapshot.docs.map((d) => BillModel.fromFirestore(d)).toList();

    double totalSales = 0;
    double cashTotal = 0;
    double upiTotal = 0;
    double udharTotal = 0;
    final Map<String, double> productSales = {};

    for (final bill in bills) {
      totalSales += bill.finalAmount;
      if (bill.isUdhar) {
        udharTotal += bill.finalAmount;
      } else if (bill.paymentMethod == 'upi') {
        upiTotal += bill.finalAmount;
      } else {
        cashTotal += bill.finalAmount;
      }
      for (final item in bill.items) {
        final name = item.productName;
        productSales[name] =
            (productSales[name] ?? 0) + (item.qty * item.price);
      }
    }

    // Top 3 products by sales amount
    final topProducts = productSales.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top3 = topProducts
        .take(3)
        .map((e) => '${e.key}: ₹${e.value.toStringAsFixed(0)}')
        .toList();

    return {
      'totalSales': totalSales,
      'billCount': bills.length,
      'cashTotal': cashTotal,
      'upiTotal': upiTotal,
      'udharTotal': udharTotal,
      'topProducts': top3,
      'date': '${now.day}/${now.month}/${now.year}',
    };
  }

  static String formatSummaryText(
      Map<String, dynamic> summary, String shopName) {
    final topList = summary['topProducts'] as List;
    final top = topList.isNotEmpty ? topList.join('\n  ') : 'No sales yet';
    return '''
📊 *Daily Sales Report — ${summary['date']}*
🏪 $shopName

💰 Total Sales: ₹${(summary['totalSales'] as double).toStringAsFixed(2)}
🧾 Bills: ${summary['billCount']}

💵 Cash: ₹${(summary['cashTotal'] as double).toStringAsFixed(2)}
📱 UPI: ₹${(summary['upiTotal'] as double).toStringAsFixed(2)}
📝 Udhar: ₹${(summary['udharTotal'] as double).toStringAsFixed(2)}

🏆 Top Products:
  $top

Sent from Oratas app''';
  }
}
