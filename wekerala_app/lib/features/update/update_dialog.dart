import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/ota_service.dart';

class UpdateDialog extends StatelessWidget {
  final OtaStatus status;

  const UpdateDialog({super.key, required this.status});

  static Future<void> showIfNeeded(BuildContext context, OtaStatus status) async {
    if (!status.hasUpdate) return;
    await showDialog(
      context: context,
      barrierDismissible: !status.forceUpdate,
      builder: (_) => UpdateDialog(status: status),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !status.forceUpdate,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.system_update, color: AppColors.primary),
            const SizedBox(width: 10),
            Text(
              status.forceUpdate ? 'Update Required' : 'New Update Available',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Text(
          status.forceUpdate
              ? 'ShopLink ${status.latestVersion} is required to continue. Please update now.'
              : 'ShopLink ${status.latestVersion} is available. Update to get the latest features.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
        ),
        actions: [
          if (!status.forceUpdate)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Later', style: TextStyle(color: Color(0xFF666666))),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _downloadUpdate(status.apkUrl),
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadUpdate(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
