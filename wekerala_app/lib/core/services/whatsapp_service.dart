import 'package:url_launcher/url_launcher.dart';

/// WeKerala WhatsApp service.
///
/// Opens WhatsApp with a pre-filled message using the official wa.me URL scheme.
/// No third-party API key needed on the Flutter side.
///
/// All automated notifications (daily summary, stock alerts, udhar reminders,
/// broadcasts, AI auto-replies) are handled server-side by Firebase Cloud
/// Functions using Meta WhatsApp Cloud API — see functions/index.js.
/// Configure META_PHONE_NUMBER_ID and META_ACCESS_TOKEN in functions/.env.
class WhatsAppService {
  /// Opens WhatsApp with [message] pre-filled for [phone].
  ///
  /// [phone] — Indian mobile number, 10-digit or with 91 prefix.
  /// Returns true if WhatsApp launched successfully.
  static Future<bool> openChat({
    required String phone,
    required String message,
  }) async {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return false;
    final e164 = digits.startsWith('91') && digits.length == 12
        ? digits
        : '91${digits.substring(digits.length - 10)}';
    final uri = Uri.parse(
      'https://wa.me/$e164?text=${Uri.encodeComponent(message)}',
    );
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Returns true if WhatsApp is installed on this device.
  static Future<bool> get isInstalled async =>
      canLaunchUrl(Uri.parse('whatsapp://send?phone=919999999999'));
}
