/// The device seam — typed wrapper around the Android platform channel.
///
/// Channel contract (implemented in MainActivity.kt):
///   available · versionInfo · listApps · launch · appDetails · uninstall
///   usageRecents · hasUsageAccess · openUsageAccessSettings
///   setWallpaper · pickAndSetWallpaper · toadWidgets · pinWidget
///   checkLatestRelease · enqueueApkDownload · downloadProgress
///   installDownloadedApk · openUrl
///
/// Every call is defensive: a missing plugin (tests, web, demo) degrades to
/// honest `false`/null answers, never an exception escaping the seam.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One installed app from the Android package manager.
@immutable
class DeviceApp {
  const DeviceApp({
    required this.packageId,
    required this.label,
    this.iconPng,
    this.isFamily = false,
  });

  final String packageId;
  final String label;

  /// PNG-encoded adaptive icon, already rasterized to ~96 px by the
  /// channel. Null when the app ships no drawable (rare; caller falls
  /// back to the gradient glyph tile).
  final Uint8List? iconPng;

  final bool isFamily;

  DeviceApp withFamily(bool family) =>
      DeviceApp(packageId: packageId, label: label, iconPng: iconPng, isFamily: family);
}

/// The slice of a GitHub release the launcher needs for the self-update
/// flow — mirrors toadFILES' GitHubRelease shape.
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

  /// Release notes body as plain text (markdown kept raw).
  final String? notes;
  final String? apkName;
  final String? apkUrl;
  final int apkSizeBytes;

  /// Expected SHA-256 from the release's `.sha256` asset (hex, lowercase),
  /// or null when the release ships none — the installer then skips the
  /// integrity gate and says so honestly.
  final String? sha256;

  /// Detached update signature (base64) over
  /// "tagName|sha256|assetName" from the release's `.sig` asset, signed by
  /// the update key that lives only in CI secrets (SEC-02). Null when the
  /// release ships none — the engine refuses unsigned releases.
  final String? sig;

  /// The exact string the update signature covers.
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

/// Version of the running launcher, straight from the package manager.
@immutable
class VersionInfo {
  const VersionInfo({required this.versionName, required this.versionCode});

  final String versionName;
  final int versionCode;
}

/// Snapshot of an in-flight system download (DownloadManager cursor).
@immutable
class DownloadSnapshot {
  const DownloadSnapshot({
    required this.status,
    this.bytesSoFar = 0,
    this.totalBytes = -1,
  });

  /// 'running' | 'successful' | 'failed' | 'paused' | 'unknown'
  final String status;
  final int bytesSoFar;
  final int totalBytes;

  /// 0..1, or null when the total is unknown — the UI then shows an
  /// indeterminate bar instead of a lie (toadFILES convention).
  double? get fraction {
    if (totalBytes <= 0 || bytesSoFar < 0) return null;
    return (bytesSoFar / totalBytes).clamp(0.0, 1.0);
  }

  bool get successful => status == 'successful';
  bool get failed => status == 'failed';
}

/// One real Android home-screen widget offered by a family app.
@immutable
class ToadWidgetInfo {
  const ToadWidgetInfo({
    required this.providerId,
    required this.label,
    required this.packageName,
  });

  /// Flat component string, e.g. "com.toadgallery.app/.MemoriesProvider".
  final String providerId;
  final String label;
  final String packageName;
}

/// One home-screen widget provider on the phone — the picker's shelf.
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

  /// Provider preview rendered to PNG by the channel (null → the picker
  /// falls back to the app icon).
  final Uint8List? previewPng;
  final int minWidthPx;
  final int minHeightPx;
}

/// One app shortcut as Android reports it (default-home only).
@immutable
class ToadShortcutInfo {
  const ToadShortcutInfo({required this.id, required this.label});

  final String id;
  final String label;
}

/// One battery reading from the OS (ACTION_BATTERY_CHANGED). The only
/// battery facts the launcher ever touches: level, plugged, charging
/// state — no per-app attribution, no history from the OS (the drain
/// history is ours, sampled locally).
@immutable
class BatteryStatus {
  const BatteryStatus({
    required this.level,
    required this.charging,
    this.full = false,
  });

  /// 0–100, rounded. -1 when the OS refused to answer (unknown).
  final int level;

  /// True while plugged in (AC / USB / wireless) — drain sampling pauses.
  final bool charging;

  /// True when the battery reports FULL — “the frog is full”.
  final bool full;

  factory BatteryStatus.fromMap(Map<Object?, Object?> map) => BatteryStatus(
    level: (map['level'] as num?)?.toInt() ?? -1,
    charging: (map['charging'] as bool?) ?? false,
    full: (map['full'] as bool?) ?? false,
  );
}

/// Outcome of handing an APK to the system installer (toadFILES pattern).
enum InstallHandoff {
  /// The package installer was launched.
  started,

  /// "Install unknown apps" was off; the exact settings toggle was opened.
  needsPermission,

  /// The downloaded APK failed the SHA-256 gate.
  checksumFailed,

  /// The APK's signing certificate is not one of ours (SEC-02).
  wrongCertificate,

  /// Installer launch failed for another reason.
  failed,
}

/// Typed, human-readable update-check failures (toadFILES convention:
/// messages are ready to show, no raw stack traces).
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

/// The bridge over `family.toad.launcher/device`.
class DeviceBridge {
  /// Positional optional so tests can inject a fake channel; the default
  /// talks to the real MethodChannel.
  DeviceBridge([this._channel]);

  final MethodChannel? _channel;

  static const String channelName = 'family.toad.launcher/device';

  bool get _wired => _channel != null;

  /// True when this bridge carries a real platform channel — i.e. we are
  /// plausibly on an Android device. The honest-device banner keys off
  /// this: "Android is not answering" only makes sense on Android.
  bool get wired => _wired;

  Future<Object?> _invoke(String method, [Map<String, Object?>? args]) async {
    if (!_wired) throw MissingPluginException();
    return _channel!.invokeMethod(method, args);
  }

  /// True when the Android side answers — the demo/device gate.
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

  // -- launcher-grade system integrations ---------------------------------

  /// True when this launcher currently holds the HOME role.
  Future<bool> isDefaultHome() async {
    try {
      return await _invoke('isDefaultHome') == true;
    } catch (_) {
      return false;
    }
  }

  /// Opens the system role dialog (API 29+) / home settings (26–28).
  Future<bool> requestDefaultHome() async {
    try {
      return await _invoke('requestDefaultHome') == true;
    } catch (_) {
      return false;
    }
  }

  /// Pulls the real notification shade down. False when the hidden
  /// status-bar API is unavailable on this ROM — the UI then says so.
  Future<bool> openNotifications() async {
    try {
      return await _invoke('openNotifications') == true;
    } catch (_) {
      return false;
    }
  }

  /// Lock via the accessibility service; false when it is not enabled —
  /// callers deep-link to the exact settings page and explain.
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

  /// App shortcuts for long-press menus (empty when not default home —
  /// Android only lets the home app query them).
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

  /// Real share sheet for an app (chooser with its name).
  Future<bool> shareApp(String packageId) async {
    try {
      return await _invoke('shareApp', {'packageId': packageId}) == true;
    } catch (_) {
      return false;
    }
  }

  // -- battery (v0.12) -------------------------------------------------------

  /// Current battery reading — level 0–100, charging flag. The sticky
  /// ACTION_BATTERY_CHANGED intent answers instantly, no permission.
  /// Null when the OS does not answer (demo/web) — the monitor then runs
  /// its honest simulated pond battery.
  Future<BatteryStatus?> batteryStatus() async {
    try {
      final map = (await _invoke('batteryStatus')) as Map<Object?, Object?>?;
      if (map == null) return null;
      return BatteryStatus.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  // -- real widget hosting --------------------------------------------------

  /// Every widget provider on the phone (preview PNGs included).
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

  /// Allocate + bind. Returns the appWidgetId, or null when refused —
  /// refusal means "not the default home"; the UI explains that.
  Future<int?> hostWidget(String providerId) async {
    try {
      return (await _invoke('hostWidget', {
        'providerId': providerId,
      })) as int?;
    } catch (_) {
      return null;
    }
  }

  /// Release the id when a hosted widget leaves the home screen.
  Future<bool> deleteHostedWidget(int appWidgetId) async {
    try {
      return await _invoke('deleteHostedWidget', {
        'appWidgetId': appWidgetId,
      }) == true;
    } catch (_) {
      return false;
    }
  }

  // -- OS → Dart events -----------------------------------------------------

  final List<void Function(String packageId, String action)>
  _packagesChangedListeners = [];

  final List<void Function(Map<String, int> counts)>
  _notificationCountListeners = [];

  final List<void Function(BatteryStatus status)> _batteryListeners = [];

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
      }
      return null;
    });
  }

  /// The index refresh trigger — fires on install / update / remove.
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

  /// Live notification counts per package (dots on icons).
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

  /// Live battery pushes — the OS broadcasts ACTION_BATTERY_CHANGED on
  /// every level tick; the channel relays it here.
  void addBatteryListener(void Function(BatteryStatus status) listener) {
    _installEventHandler();
    _batteryListeners.add(listener);
  }

  void removeBatteryListener(void Function(BatteryStatus status) listener) {
    _batteryListeners.remove(listener);
  }

  /// Package ids sorted by last use (newest first). Returns null when the
  /// usage-access special permission has not been granted — callers must
  /// treat null as "not opted in", never as "nothing was used".
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

  /// Apply PNG bytes as the system wallpaper (WallpaperManager.setBitmap).
  Future<bool> setWallpaper(Uint8List png) async {
    try {
      return await _invoke('setWallpaper', {'png': png}) == true;
    } catch (_) {
      return false;
    }
  }

  /// SAF photo pick, then apply as wallpaper — one flow, no storage
  /// permission (persistable document URI never needed).
  Future<bool> pickAndSetWallpaper() async {
    try {
      return await _invoke('pickAndSetWallpaper') == true;
    } catch (_) {
      return false;
    }
  }

  /// Real home-screen widgets published by family apps.
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

  /// System pin flow (user confirms; launcher never binds silently).
  Future<bool> pinWidget(String providerId) async {
    try {
      return await _invoke('pinWidget', {'providerId': providerId}) == true;
    } catch (_) {
      return false;
    }
  }

  /// Latest GitHub release for this repo, fetched THROUGH the system
  /// download service — the launcher itself holds no INTERNET permission.
  ///
  /// Throws [UpdateRateLimitException], [UpdateUnreachableException] or
  /// [UpdateNoApkException]; never a raw PlatformException.
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

  /// Enqueue the APK download via DownloadManager; returns the job id.
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

  /// SHA-256 the downloaded file, compare, then hand to the system
  /// installer (PackageInstaller session → user confirmation dialog).
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

  // -- SEC-02 / REL-01 / PLT-03 / PLT-07 ----------------------------------

  /// Verify a release's detached update signature (ECDSA P-256 over the
  /// UTF-8 message) against the embedded update-signing public key. The
  /// decision to trust lives in Dart; the primitive is OS-side Java.
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

  /// App-private files dir (crash log + diagnostics live here).
  Future<String?> appFilesDir() async {
    try {
      return await _invoke('appFilesDir') as String?;
    } catch (_) {
      return null;
    }
  }

  /// The device's Android SDK level (e.g. 33 = Android 13), or -1 when
  /// the platform is not Android. The ask flow uses it to decide whether
  /// the Restricted Settings pre-step is needed (PLT-01).
  Future<int> osSdkInt() async {
    try {
      return (await _invoke('osSdkInt') as num?)?.toInt() ?? -1;
    } catch (_) {
      return -1;
    }
  }

  /// SHA-256 hex of our own signing certificate — Settings → About shows
  /// it so anyone can cross-check the installed build against SECURITY.md.
  Future<String?> signingCertFingerprint() async {
    try {
      return await _invoke('signingCertFingerprint') as String?;
    } catch (_) {
      return null;
    }
  }

  /// The system Home picker — the safe mode escape hatch.
  Future<bool> openHomeSettings() async {
    try {
      return await _invoke('openHomeSettings') == true;
    } catch (_) {
      return false;
    }
  }

  /// Share the local crash log through the system sheet (text; the user
  /// picks the target — nothing is ever uploaded by us).
  Future<bool> shareDiagnosticsFile(String path) async {
    try {
      return await _invoke('shareDiagnosticsFile', {'path': path}) == true;
    } catch (_) {
      return false;
    }
  }

  /// Tell a hosted Android widget its new size in dp so responsive
  /// providers re-render (PLT-07).
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

  /// Screenshot through the accessibility global action (needs the lock
  /// service consent, API 28+). False when unavailable — never pretend.
  Future<bool> takeScreenshot() async {
    try {
      return await _invoke('takeScreenshot') == true;
    } catch (_) {
      return false;
    }
  }

  /// Open a URL in the browser — the browser holds the network, we don't.
  Future<bool> openUrl(String url) async {
    try {
      return await _invoke('openUrl', {'url': url}) == true;
    } catch (_) {
      return false;
    }
  }

  static const String kRepoSlug = 'dukeoftoad/toadLAUNCHER';
}

/// The bridge as a provider — overridable in tests.
final Provider<DeviceBridge> deviceBridgeProvider = Provider<DeviceBridge>(
  (ref) {
    // The real channel ONLY on Android — tests, web and desktop keep the
    // channel-free bridge that answers honestly. (v0.10 shipped this
    // provider with a permanently null channel: device mode could never
    // engage. The review caught it; fixed here.)
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return DeviceBridge(const MethodChannel(DeviceBridge.channelName));
    }
    return DeviceBridge();
  },
);

/// Does this launcher currently hold the HOME role? (Probed on demand;
/// refreshed by the home screen on resume and after the role dialog.)
final FutureProvider<bool> isDefaultHomeProvider = FutureProvider<bool>(
  (ref) => ref.watch(deviceBridgeProvider).isDefaultHome(),
);

/// Is Notification access granted (the dots service needs it)? Probed on
/// demand; the settings page refreshes when the user returns.
final FutureProvider<bool> notificationAccessProvider = FutureProvider<bool>(
  (ref) => ref.watch(deviceBridgeProvider).hasNotificationAccess(),
);

/// Live notification counts per package, pushed by the listener service.
final StateProvider<Map<String, int>> notificationCountsProvider =
    StateProvider<Map<String, int>>((ref) => const {});

/// The running launcher's version, straight from the package manager.
/// Falls back to the pubspec-flavored name when Android is not answering
/// (demo builds) — the About page never lies about what is installed.
final FutureProvider<String> currentVersionProvider = FutureProvider<String>(
  (ref) async {
    final bridge = ref.watch(deviceBridgeProvider);
    final reachable = await bridge.available();
    if (!reachable) return kFallbackVersion;
    final info = await bridge.versionInfo();
    return info.versionName == '0.0.0' ? kFallbackVersion : info.versionName;
  },
);

/// The version this source tree ships as (pubspec twin, kept in step).
const String kFallbackVersion = 'v1.1.0';
