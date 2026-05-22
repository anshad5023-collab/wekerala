import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';

class OtaStatus {
  final bool hasUpdate;
  final bool forceUpdate;
  final bool maintenanceMode;
  final String maintenanceMessage;
  final String latestVersion;
  final String apkUrl;

  const OtaStatus({
    required this.hasUpdate,
    required this.forceUpdate,
    required this.maintenanceMode,
    required this.maintenanceMessage,
    required this.latestVersion,
    required this.apkUrl,
  });

  static const none = OtaStatus(
    hasUpdate: false,
    forceUpdate: false,
    maintenanceMode: false,
    maintenanceMessage: '',
    latestVersion: '',
    apkUrl: '',
  );
}

class OtaService {
  static Future<OtaStatus> check() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 4),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      await remoteConfig.fetchAndActivate()
          .timeout(const Duration(seconds: 5), onTimeout: () => false);

      final maintenanceMode = remoteConfig.getBool('maintenanceMode');
      final maintenanceMessage = remoteConfig.getString('maintenanceMessage');
      final latestVersion = remoteConfig.getString('latestApkVersion');
      final apkUrl = remoteConfig.getString('latestApkUrl');
      final forceUpdate = remoteConfig.getBool('forceUpdate');

      if (maintenanceMode) {
        return OtaStatus(
          hasUpdate: false,
          forceUpdate: false,
          maintenanceMode: true,
          maintenanceMessage: maintenanceMessage,
          latestVersion: latestVersion,
          apkUrl: apkUrl,
        );
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final hasUpdate = _isNewerVersion(latestVersion, currentVersion);

      return OtaStatus(
        hasUpdate: hasUpdate,
        forceUpdate: hasUpdate && forceUpdate,
        maintenanceMode: false,
        maintenanceMessage: '',
        latestVersion: latestVersion,
        apkUrl: apkUrl,
      );
    } catch (_) {
      return OtaStatus.none;
    }
  }

  static bool _isNewerVersion(String latest, String current) {
    if (latest.isEmpty) return false;
    final l = latest.split('.').map(int.tryParse).toList();
    final c = current.split('.').map(int.tryParse).toList();
    for (int i = 0; i < 3; i++) {
      final lv = (i < l.length ? l[i] : 0) ?? 0;
      final cv = (i < c.length ? c[i] : 0) ?? 0;
      if (lv > cv) return true;
      if (lv < cv) return false;
    }
    return false;
  }
}
