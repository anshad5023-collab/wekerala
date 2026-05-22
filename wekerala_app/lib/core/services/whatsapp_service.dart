import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// WeKerala WhatsApp messaging service via Gupshup API.
///
/// Setup: Add GUPSHUP_API_KEY and GUPSHUP_APP_NAME to your .env file.
/// Get your API key at: https://www.gupshup.io/developer/dashboard
class WhatsAppService {
  static String get _apiKey => dotenv.env['GUPSHUP_API_KEY'] ?? '';
  static String get _appName => dotenv.env['GUPSHUP_APP_NAME'] ?? '';
  static const _baseUrl = 'https://api.gupshup.io/sm/api/v1/msg';

  static bool get isConfigured => _apiKey.isNotEmpty && _appName.isNotEmpty;

  /// Send a plain text WhatsApp message to a phone number.
  /// [phone] must be 10-digit Indian number (without country code).
  static Future<bool> sendText({
    required String phone,
    required String message,
  }) async {
    if (!isConfigured) return false;
    if (phone.length < 10) return false;

    final e164 = phone.startsWith('91') ? phone : '91$phone';

    try {
      final resp = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'apikey': _apiKey,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'channel': 'whatsapp',
          'source': _appName,
          'destination': e164,
          'message': jsonEncode({'type': 'text', 'text': message}),
          'src.name': _appName,
        },
      );
      return resp.statusCode == 202 || resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Notify the shop owner about a new order.
  static Future<bool> notifyOwnerNewOrder({
    required String ownerPhone,
    required String orderNumber,
    required String customerName,
    required double totalAmount,
    required List<String> itemNames,
  }) async {
    final items = itemNames.take(3).join(', ');
    final more = itemNames.length > 3 ? ' +${itemNames.length - 3} more' : '';
    final msg = '🛍 *New Order #$orderNumber*\n'
        'Customer: $customerName\n'
        'Items: $items$more\n'
        'Total: ₹${totalAmount.toStringAsFixed(0)}\n\n'
        'Open Oratas app to confirm.';
    return sendText(phone: ownerPhone, message: msg);
  }

  /// Send order status update to customer.
  static Future<bool> sendOrderStatusToCustomer({
    required String customerPhone,
    required String orderNumber,
    required String status,
    String? shopName,
  }) async {
    final statusMessages = {
      'confirmed': '✅ Your order #$orderNumber has been confirmed by ${shopName ?? 'the shop'}.',
      'processing': '👨‍🍳 Your order #$orderNumber is being prepared.',
      'ready': '📦 Your order #$orderNumber is ready! Please collect or wait for delivery.',
      'delivered': '🎉 Your order #$orderNumber has been delivered. Thank you for shopping!',
      'cancelled': '❌ Your order #$orderNumber has been cancelled. Please contact the shop.',
    };
    final msg = statusMessages[status];
    if (msg == null) return false;
    return sendText(phone: customerPhone, message: msg);
  }

  /// Send daily sales summary to shop owner.
  static Future<bool> sendDailySummary({
    required String ownerPhone,
    required String shopName,
    required double revenue,
    required int orderCount,
    required int newOrders,
    required int lowStockCount,
  }) async {
    final msg = '📊 *Daily Summary — $shopName*\n'
        '─────────────────\n'
        '💰 Revenue: ₹${revenue.toStringAsFixed(0)}\n'
        '📦 Orders: $orderCount\n'
        '🆕 New (unconfirmed): $newOrders\n'
        '⚠️ Low stock items: $lowStockCount\n'
        '─────────────────\n'
        'Open Oratas to manage your shop.';
    return sendText(phone: ownerPhone, message: msg);
  }

  /// Send monthly khata (credit) statement to a customer.
  static Future<bool> sendMonthlyStatement({
    required String customerPhone,
    required String customerName,
    required String shopName,
    required double totalCredit,
    required double amountPaid,
    required double outstanding,
    required String month,
  }) async {
    final msg = '📋 *Monthly Statement — $month*\n'
        '*$customerName* — $shopName\n\n'
        'Total Credit: ₹${totalCredit.toStringAsFixed(0)}\n'
        'Amount Paid: ₹${amountPaid.toStringAsFixed(0)}\n'
        '*Outstanding: ₹${outstanding.toStringAsFixed(0)}*\n\n'
        'Please settle at your earliest convenience.\n'
        '_Powered by Oratas_';
    return sendText(phone: customerPhone, message: msg);
  }

  /// Send festive offer to a customer.
  static Future<bool> sendFestiveOffer({
    required String customerPhone,
    required String customerName,
    required String festivalName,
    required String shopName,
    required String offerText,
    required String storefrontUrl,
  }) async {
    final msg = '🎉 *${festivalName} Wishes from $shopName!*\n\n'
        'Dear $customerName,\n'
        '$offerText\n\n'
        'Shop now: $storefrontUrl\n\n'
        '_Oratas — Your neighbourhood shop, online_';
    return sendText(phone: customerPhone, message: msg);
  }
}
