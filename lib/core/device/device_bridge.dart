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

  factory ReleaseInfo.fromMap(Map<Object?, Object?> map) => ReleaseInfo(
    tagName: map['tagName'] as String? ?? '',
    htmlUrl: map['htmlUrl'] as String? ?? '',
    notes: map['notes'] as String?,
    apkName: map['apkName'] as String?,
    apkUrl: map['apkUrl'] as String?,
    apkSizeBytes: (map['apkSizeBytes'] as num?)?.toInt() ?? 0,
    sha256: map['sha256'] as String?,
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

/// Outcome of handing an APK to the system installer (toadFILES pattern).
enum InstallHandoff {
  /// The package installer was launched.
  started,

  /// "Install unknown apps" was off; the exact settings toggle was opened.
  needsPermission,

  /// The downloaded APK failed the SHA-256 gate.
  checksumFailed,

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
        _ => InstallHandoff.failed,
      };
    } catch (_) {
      return InstallHandoff.failed;
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
  (ref) => DeviceBridge(),
);
