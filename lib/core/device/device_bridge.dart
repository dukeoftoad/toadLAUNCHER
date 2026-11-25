library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class DeviceApp {
  const DeviceApp({
    required this.packageId,
    required this.label,
    this.iconPng,
    this.iconMonoPng,
    this.isFamily = false,
  });

  final String packageId;
  final String label;

  final Uint8List? iconPng;

  final Uint8List? iconMonoPng;

  final bool isFamily;

  DeviceApp withFamily(bool family) => DeviceApp(
    packageId: packageId,
    label: label,
    iconPng: iconPng,
    iconMonoPng: iconMonoPng,
    isFamily: family,
  );
}

@immutable
class WidgetBindResult {
  const WidgetBindResult({this.appWidgetId, this.configure});

  final int? appWidgetId;

  /// Flattened ComponentName of the provider's configure activity, when the
  /// bound widget declares one (PLT-07). Empty string means none.
  final String? configure;

  bool get bound => appWidgetId != null;

  bool get needsConfigure => bound && (configure ?? '').isNotEmpty;
}

@immutable
class ReleaseInfo {
  const ReleaseInfo({
    required this.tagName,
    required this.htmlUrl,
    this.notes,
    this.apkName,
    this.apkUrl,
    this.apkSizeBytes = 0,
    this.sha256,
    this.sig,
  });

  final String tagName;
  final String htmlUrl;

  final String? notes;
  final String? apkName;
  final String? apkUrl;
  final int apkSizeBytes;

  final String? sha256;

  final String? sig;

  String get signedMessage => '$tagName|$sha256|$apkName';

  factory ReleaseInfo.fromMap(Map<Object?, Object?> map) => ReleaseInfo(
    tagName: map['tagName'] as String? ?? '',
    htmlUrl: map['htmlUrl'] as String? ?? '',
    notes: map['notes'] as String?,
    apkName: map['apkName'] as String?,
    apkUrl: map['apkUrl'] as String?,
    apkSizeBytes: (map['apkSizeBytes'] as num?)?.toInt() ?? 0,
    sha256: map['sha256'] as String?,
    sig: map['sig'] as String?,
  );
}

@immutable
class VersionInfo {
  const VersionInfo({required this.versionName, required this.versionCode});

  final String versionName;
  final int versionCode;
}

@immutable
class DownloadSnapshot {
  const DownloadSnapshot({
    required this.status,
    this.bytesSoFar = 0,
    this.totalBytes = -1,
  });

  final String status;
  final int bytesSoFar;
  final int totalBytes;

  double? get fraction {
    if (totalBytes <= 0 || bytesSoFar < 0) return null;
    return (bytesSoFar / totalBytes).clamp(0.0, 1.0);
  }

  bool get successful => status == 'successful';
  bool get failed => status == 'failed';
}

@immutable
class ToadWidgetInfo {
  const ToadWidgetInfo({
    required this.providerId,
    required this.label,
    required this.packageName,
  });

  final String providerId;
  final String label;
  final String packageName;
}

@immutable
class HostableWidgetInfo {
  const HostableWidgetInfo({
    required this.providerId,
    required this.label,
    required this.packageName,
    this.previewPng,
    this.minWidthPx = 0,
    this.minHeightPx = 0,
  });

  final String providerId;
  final String label;
  final String packageName;

  final Uint8List? previewPng;
  final int minWidthPx;
  final int minHeightPx;
}

@immutable
class ToadShortcutInfo {
  const ToadShortcutInfo({required this.id, required this.label});

  final String id;
  final String label;
}

@immutable
class BatteryStatus {
  const BatteryStatus({
    required this.level,
    required this.charging,
    this.full = false,
  });

  final int level;

  final bool charging;

  final bool full;

  factory BatteryStatus.fromMap(Map<Object?, Object?> map) => BatteryStatus(
    level: (map['level'] as num?)?.toInt() ?? -1,
    charging: (map['charging'] as bool?) ?? false,
    full: (map['full'] as bool?) ?? false,
  );
}

enum InstallHandoff {
  started,

  needsPermission,

  checksumFailed,

  wrongCertificate,

  failed,
}

class UpdateCheckException implements Exception {
  UpdateCheckException(this.message);
  final String message;
}

class UpdateRateLimitException extends UpdateCheckException {
  UpdateRateLimitException()
    : super(
        'GitHub rate limit hit — wait a few minutes, or open the release '
        'page on github.com.',
      );
}

class UpdateUnreachableException extends UpdateCheckException {
  UpdateUnreachableException()
    : super(
        'The pond is offline — check for updates again once the device has '
        'network.',
      );
}

class UpdateNoApkException extends UpdateCheckException {
  UpdateNoApkException() : super('The newest release ships no launcher APK yet.');
}

class DeviceBridge {
  DeviceBridge([this._channel]);

  final MethodChannel? _channel;

  static const String channelName = 'family.toad.launcher/device';

  bool get _wired => _channel != null;

  bool get wired => _wired;

  Future<Object?> _invoke(String method, [Map<String, Object?>? args]) async {
    if (!_wired) throw MissingPluginException();
    return _channel!.invokeMethod(method, args);
  }

  Future<bool> available() async {
    try {
      return (await _invoke('available')) == true;
    } catch (_) {
      return false;
    }
  }

  Future<VersionInfo> versionInfo() async {
    final map = (await _invoke('versionInfo')) as Map<Object?, Object?>?;
    return VersionInfo(
      versionName: map?['versionName'] as String? ?? '0.0.0',
      versionCode: (map?['versionCode'] as num?)?.toInt() ?? 0,
    );
  }

  Future<List<DeviceApp>> listApps() async {
    final raw = (await _invoke('listApps')) as List<Object?>?;
    if (raw == null) return const [];
    return [
      for (final item in raw)
        if (item is Map)
          DeviceApp(
            packageId: item['packageId'] as String? ?? '',
            label: item['label'] as String? ?? '',
            iconPng: item['iconPng'] as Uint8List?,
            iconMonoPng: item['iconMonoPng'] as Uint8List?,
          ),
    ];
  }

  Future<bool> launch(String packageId) async {
    try {
      return await _invoke('launch', {'packageId': packageId}) == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> appDetails(String packageId) async {
    try {
      return await _invoke('appDetails', {'packageId': packageId}) == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> uninstall(String packageId) async {
    try {
      return await _invoke('uninstall', {'packageId': packageId}) == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isDefaultHome() async {
    try {
      return await _invoke('isDefaultHome') == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestDefaultHome() async {
    try {
      return await _invoke('requestDefaultHome') == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> openNotifications() async {
    try {
      return await _invoke('openNotifications') == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> lockScreen() async {
    try {
      return await _invoke('lockScreen') == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isLockServiceEnabled() async {
    try {
      return await _invoke('isLockServiceEnabled') == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> openAccessibilitySettings() async {
    try {
      return await _invoke('openAccessibilitySettings') == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> hasNotificationAccess() async {
    try {
      return await _invoke('hasNotificationAccess') == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> openNotificationListenerSettings() async {
    try {
      return await _invoke('openNotificationListenerSettings') == true;
    } catch (_) {
      return false;
    }
  }

  Future<List<ToadShortcutInfo>> appShortcuts(String packageId) async {
    try {
      final raw =
          (await _invoke('appShortcuts', {
            'packageId': packageId,
          })) as List<Object?>?;
      if (raw == null) return const [];
      return [
        for (final item in raw)
          if (item is Map)
            ToadShortcutInfo(
              id: item['id'] as String? ?? '',
              label: item['label'] as String? ?? '',
            ),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<bool> startShortcut(String packageId, String shortcutId) async {
    try {
      return await _invoke('startShortcut', {
        'packageId': packageId,
        'shortcutId': shortcutId,
      }) == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> shareApp(String packageId) async {
    try {
      return await _invoke('shareApp', {'packageId': packageId}) == true;
    } catch (_) {
      return false;
    }
  }

  Future<BatteryStatus?> batteryStatus() async {
    try {
      final map = (await _invoke('batteryStatus')) as Map<Object?, Object?>?;
      if (map == null) return null;
      return BatteryStatus.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  Future<List<HostableWidgetInfo>> listHostableWidgets() async {
    try {
      final raw = (await _invoke('listHostableWidgets')) as List<Object?>?;
      if (raw == null) return const [];
      return [
        for (final item in raw)
          if (item is Map)
            HostableWidgetInfo(
              providerId: item['providerId'] as String? ?? '',
              label: item['label'] as String? ?? '',
              packageName: item['packageName'] as String? ?? '',
              previewPng: item['previewPng'] as Uint8List?,
              minWidthPx: (item['minWidth'] as num?)?.toInt() ?? 0,
              minHeightPx: (item['minHeight'] as num?)?.toInt() ?? 0,
            ),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<WidgetBindResult> hostWidget(String providerId) async {
    try {
      final raw = await _invoke('hostWidget', {
        'providerId': providerId,
      });
      if (raw is Map) {
        return WidgetBindResult(
          appWidgetId: (raw['appWidgetId'] as num?)?.toInt(),
          configure: raw['configure'] as String?,
        );
      }
      return const WidgetBindResult();
    } catch (_) {
      return const WidgetBindResult();
    }
  }

  /// Opens the bound widget's configure activity. Resolves true only when
  /// the activity finished with RESULT_OK; false on cancel, on launch
  /// failure, or when the widget has no configure activity.
  Future<bool> launchWidgetConfigure(int appWidgetId) async {
    try {
      return await _invoke('launchWidgetConfigure', {
        'appWidgetId': appWidgetId,
      }) == true;
    } catch (_) {
      return false;
    }
  }

  /// All app widget ids the host currently holds — the source of truth for
  /// orphan cleanup at startup (PLT-07).
  Future<List<int>> hostedAppWidgetIds() async {
    try {
      final raw = await _invoke('hostedAppWidgetIds') as List<Object?>?;
      if (raw == null) return const [];
      return [
        for (final item in raw) (item as num).toInt(),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<bool> deleteHostedWidget(int appWidgetId) async {
    try {
      return await _invoke('deleteHostedWidget', {
        'appWidgetId': appWidgetId,
      }) == true;
    } catch (_) {
      return false;
    }
  }

  final List<void Function(String packageId, String action)>
  _packagesChangedListeners = [];

  final List<void Function(Map<String, int> counts)>
  _notificationCountListeners = [];

  final List<void Function(BatteryStatus status)> _batteryListeners = [];

  final List<void Function()> _homePressedListeners = [];

  bool _eventHandlerInstalled = false;

  void _installEventHandler() {
    if (_eventHandlerInstalled || !_wired) return;
    _eventHandlerInstalled = true;
    _channel!.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'packagesChanged':
          final args = call.arguments;
          final packageId = args is Map
              ? args['packageId'] as String? ?? ''
              : '';
          final action = args is Map ? args['action'] as String? ?? '' : '';
          for (final listener in _packagesChangedListeners.toList()) {
            listener(packageId, action);
          }
        case 'notificationCounts':
          final raw = call.arguments;
          final counts = <String, int>{};
          if (raw is Map) {
            for (final entry in raw.entries) {
              counts[entry.key as String? ?? ''] =
                  (entry.value as num?)?.toInt() ?? 0;
            }
          }
          for (final listener in _notificationCountListeners.toList()) {
            listener(counts);
          }
        case 'batteryChanged':
          final raw = call.arguments;
          if (raw is Map) {
            final status = BatteryStatus.fromMap(
              raw.cast<Object?, Object?>(),
            );
            for (final listener in _batteryListeners.toList()) {
              listener(status);
            }
          }
        case 'homePressed':
          for (final listener in _homePressedListeners.toList()) {
            listener();
          }
      }
      return null;
    });
  }

  void addPackagesChangedListener(
    void Function(String packageId, String action) listener,
  ) {
    _installEventHandler();
    _packagesChangedListeners.add(listener);
  }

  void removePackagesChangedListener(
    void Function(String packageId, String action) listener,
  ) {
    _packagesChangedListeners.remove(listener);
  }

  void addNotificationCountsListener(
    void Function(Map<String, int> counts) listener,
  ) {
    _installEventHandler();
    _notificationCountListeners.add(listener);
  }

  void removeNotificationCountsListener(
    void Function(Map<String, int> counts) listener,
  ) {
    _notificationCountListeners.remove(listener);
  }

  void addBatteryListener(void Function(BatteryStatus status) listener) {
    _installEventHandler();
    _batteryListeners.add(listener);
  }

  void removeBatteryListener(void Function(BatteryStatus status) listener) {
    _batteryListeners.remove(listener);
  }

  void addHomePressedListener(void Function() listener) {
    _installEventHandler();
    _homePressedListeners.add(listener);
  }

  void removeHomePressedListener(void Function() listener) {
    _homePressedListeners.remove(listener);
  }

  Future<List<String>?> usageRecents() async {
    try {
      final raw = (await _invoke('usageRecents')) as List<Object?>?;
      return raw?.whereType<String>().toList();
    } on PlatformException catch (e) {
      if (e.code == 'noAccess') return null;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasUsageAccess() async {
    try {
      return await _invoke('hasUsageAccess') == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> openUsageAccessSettings() async {
    try {
      await _invoke('openUsageAccessSettings');
    } catch (_) {}
  }

  Future<bool> setWallpaper(Uint8List png) async {
    try {
      return await _invoke('setWallpaper', {'png': png}) == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> pickAndSetWallpaper() async {
    try {
      return await _invoke('pickAndSetWallpaper') == true;
    } catch (_) {
      return false;
    }
  }

  Future<List<ToadWidgetInfo>> toadWidgets(List<String> familyIds) async {
    try {
      final raw = (await _invoke('toadWidgets', {
        'familyIds': familyIds,
      })) as List<Object?>?;
      if (raw == null) return const [];
      return [
        for (final item in raw)
          if (item is Map)
            ToadWidgetInfo(
              providerId: item['providerId'] as String? ?? '',
              label: item['label'] as String? ?? '',
              packageName: item['packageName'] as String? ?? '',
            ),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<bool> pinWidget(String providerId) async {
    try {
      return await _invoke('pinWidget', {'providerId': providerId}) == true;
    } catch (_) {
      return false;
    }
  }

  Future<ReleaseInfo> checkLatestRelease() async {
    Object? raw;
    try {
      raw = await _invoke('checkLatestRelease', {'repo': kRepoSlug});
    } on PlatformException catch (e) {
      throw switch (e.code) {
        'rateLimit' => UpdateRateLimitException(),
        'noApkAsset' => UpdateNoApkException(),
        _ => UpdateUnreachableException(),
      };
    } on MissingPluginException {
      throw UpdateUnreachableException();
    }
    if (raw is! Map) throw UpdateUnreachableException();
    final release = ReleaseInfo.fromMap(raw.cast<Object?, Object?>());
    if (release.apkUrl == null || release.apkUrl!.isEmpty) {
      throw UpdateNoApkException();
    }
    return release;
  }

  Future<int> enqueueApkDownload({
    required String url,
    required String fileName,
  }) async {
    try {
      final id = await _invoke('enqueueApkDownload', {
        'url': url,
        'fileName': fileName,
        'title': 'toadLAUNCHER update',
      });
      return (id as num).toInt();
    } on PlatformException {
      throw UpdateUnreachableException();
    }
  }

  Future<DownloadSnapshot> downloadProgress(int id) async {
    try {
      final map =
          (await _invoke('downloadProgress', {'id': id}))
              as Map<Object?, Object?>?;
      return DownloadSnapshot(
        status: map?['status'] as String? ?? 'unknown',
        bytesSoFar: (map?['bytesSoFar'] as num?)?.toInt() ?? 0,
        totalBytes: (map?['totalBytes'] as num?)?.toInt() ?? -1,
      );
    } catch (_) {
      return const DownloadSnapshot(status: 'unknown');
    }
  }

  Future<InstallHandoff> installDownloadedApk({
    required int id,
    String? expectedSha256,
  }) async {
    try {
      final result = await _invoke('installDownloadedApk', {
        'id': id,
        'expectedSha256': expectedSha256,
      });
      return switch (result) {
        'started' => InstallHandoff.started,
        'needsPermission' => InstallHandoff.needsPermission,
        'checksumFailed' => InstallHandoff.checksumFailed,
        'wrongCertificate' => InstallHandoff.wrongCertificate,
        _ => InstallHandoff.failed,
      };
    } catch (_) {
      return InstallHandoff.failed;
    }
  }

  Future<bool> verifyUpdateSignature(String message, String signature) async {
    try {
      return await _invoke('verifyUpdateSignature', {
        'message': message,
        'signature': signature,
      }) == true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> appFilesDir() async {
    try {
      return await _invoke('appFilesDir') as String?;
    } catch (_) {
      return null;
    }
  }

  Future<int> osSdkInt() async {
    try {
      return (await _invoke('osSdkInt') as num?)?.toInt() ?? -1;
    } catch (_) {
      return -1;
    }
  }

  Future<String?> signingCertFingerprint() async {
    try {
      return await _invoke('signingCertFingerprint') as String?;
    } catch (_) {
      return null;
    }
  }

  Future<bool> openHomeSettings() async {
    try {
      return await _invoke('openHomeSettings') == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> shareDiagnosticsFile(String path) async {
    try {
      return await _invoke('shareDiagnosticsFile', {'path': path}) == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> resizeHostedWidget({
    required int appWidgetId,
    required int widthDp,
    required int heightDp,
  }) async {
    try {
      return await _invoke('resizeHostedWidget', {
        'appWidgetId': appWidgetId,
        'widthDp': widthDp,
        'heightDp': heightDp,
      }) == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> takeScreenshot() async {
    try {
      return await _invoke('takeScreenshot') == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> openUrl(String url) async {
    try {
      return await _invoke('openUrl', {'url': url}) == true;
    } catch (_) {
      return false;
    }
  }

  static const String kRepoSlug = 'dukeoftoad/toadLAUNCHER';
}

final Provider<DeviceBridge> deviceBridgeProvider = Provider<DeviceBridge>(
  (ref) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return DeviceBridge(const MethodChannel(DeviceBridge.channelName));
    }
    return DeviceBridge();
  },
);

final FutureProvider<bool> isDefaultHomeProvider = FutureProvider<bool>(
  (ref) => ref.watch(deviceBridgeProvider).isDefaultHome(),
);

final FutureProvider<bool> notificationAccessProvider = FutureProvider<bool>(
  (ref) => ref.watch(deviceBridgeProvider).hasNotificationAccess(),
);

final StateProvider<Map<String, int>> notificationCountsProvider =
    StateProvider<Map<String, int>>((ref) => const {});

final FutureProvider<String> currentVersionProvider = FutureProvider<String>(
  (ref) async {
    final bridge = ref.watch(deviceBridgeProvider);
    final reachable = await bridge.available();
    if (!reachable) return kFallbackVersion;
    final info = await bridge.versionInfo();
    return info.versionName == '0.0.0' ? kFallbackVersion : info.versionName;
  },
);

const String kFallbackVersion = 'v1.1.0';
