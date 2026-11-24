/// Auto-update engine — the toadFILES self-update pattern, ported to the
/// launcher's Riverpod state and its zero-INTERNET promise.
///
/// Flow (identical user-visible behavior to toadFILES v2.x):
///   · one silent check per process on start — failure is invisible
///   · a subtle "vX available" banner card when a newer release with an
///     APK asset exists
///   · the manual check (Settings → Device & updates) shows errors
///   · download via the system DownloadManager (its process holds the
///     network, ours never needs the INTERNET permission)
///   · progress polled every 500 ms from the same system job
///   · SHA-256 gate, then the system installer dialog
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/launcher_settings.dart';
import 'device_bridge.dart';
import 'toad_family.dart';

/// All the engine can be in. Honest states — nothing pretends.
sealed class UpdateState {
  const UpdateState();
}

class UpdateIdle extends UpdateState {
  const UpdateIdle();
}

class UpdateChecking extends UpdateState {
  const UpdateChecking({this.silent = false});
  final bool silent;
}

class UpdateUpToDate extends UpdateState {
  const UpdateUpToDate({required this.version});
  final String version;
}

class UpdateAvailable extends UpdateState {
  const UpdateAvailable({required this.release});
  final ReleaseInfo release;
}

class UpdateDownloading extends UpdateState {
  const UpdateDownloading({
    required this.release,
    required this.downloadId,
    this.snapshot = const DownloadSnapshot(status: 'running'),
  });

  final ReleaseInfo release;
  final int downloadId;
  final DownloadSnapshot snapshot;

  double? get fraction => snapshot.fraction;
}

class UpdateReadyToInstall extends UpdateState {
  const UpdateReadyToInstall({required this.release, required this.downloadId});
  final ReleaseInfo release;
  final int downloadId;
}

/// The APK is downloaded but "Install unknown apps" is off — the exact
/// settings toggle was opened; the user retries from the banner.
class UpdateNeedsInstallPermission extends UpdateState {
  const UpdateNeedsInstallPermission({
    required this.release,
    required this.downloadId,
  });
  final ReleaseInfo release;
  final int downloadId;
}

class UpdateChecksumFailed extends UpdateState {
  const UpdateChecksumFailed({required this.release});
  final ReleaseInfo release;
}

class UpdateFailed extends UpdateState {
  const UpdateFailed(this.message);
  final String message;
}

/// Semver-ish compare, tolerant of the pubspec flavor: "v0.10.0-beta",
/// "0.10.0", "0.10.0-beta+30". Numeric dot-parts first; a suffix makes a
/// version LOWER than the same version without one (release > beta).
int compareVersions(String a, String b) {
  (List<int>, String?) parseV(String v) {
    var s = v.trim().toLowerCase().replaceFirst(RegExp(r'^v'), '');
    final plus = s.indexOf('+');
    if (plus >= 0) s = s.substring(0, plus);
    final dash = s.indexOf('-');
    final core = dash >= 0 ? s.substring(0, dash) : s;
    final suffix = dash >= 0 ? s.substring(dash + 1) : null;
    final parts = [
      for (final p in core.split('.')) int.tryParse(p) ?? 0,
    ];
    return (parts, suffix);
  }

  final (aParts, aSuffix) = parseV(a);
  final (bParts, bSuffix) = parseV(b);

  final len = aParts.length > bParts.length ? aParts.length : bParts.length;
  for (var i = 0; i < len; i++) {
    final ai = i < aParts.length ? aParts[i] : 0;
    final bi = i < bParts.length ? bParts[i] : 0;
    if (ai != bi) return ai.compareTo(bi);
  }
  // Equal cores: no-suffix beats any suffix; suffix ties go lexicographic.
  if (aSuffix == null && bSuffix == null) return 0;
  if (aSuffix == null) return 1;
  if (bSuffix == null) return -1;
  return aSuffix.compareTo(bSuffix);
}

/// Riverpod state holder for the update flow.
class UpdateEngine extends Notifier<UpdateState> {
  bool _startupCheckDone = false;
  Timer? _pollTimer;

  @override
  UpdateState build() => const UpdateIdle();

  DeviceBridge get _bridge => ref.watch(deviceBridgeProvider);

  /// One silent check per process on start (toadFILES v1.7.1 behavior).
  /// Respects the settings switch; swallows every failure quietly.
  Future<void> silentStartupCheck() async {
    if (_startupCheckDone) return;
    _startupCheckDone = true;
    if (!ref.read(launcherSettingsProvider).autoUpdateCheck) return;

    try {
      final release = await _bridge.checkLatestRelease();
      final current = (await _bridge.versionInfo()).versionName;
      if (compareVersions(release.tagName, current) > 0) {
        state = UpdateAvailable(release: release);
      }
    } catch (_) {
      // Intentionally invisible — airplane mode, GitHub down, rate limit.
    }
  }

  /// The explicit check from the settings page — errors surface.
  Future<void> manualCheck() async {
    state = const UpdateChecking();
    try {
      final release = await _bridge.checkLatestRelease();
      final current = (await _bridge.versionInfo()).versionName;
      if (compareVersions(release.tagName, current) > 0) {
        state = UpdateAvailable(release: release);
      } else {
        state = UpdateUpToDate(version: current);
      }
    } on UpdateCheckException catch (e) {
      state = UpdateFailed(e.message);
    } catch (_) {
      state = const UpdateFailed('Something went sideways — try again.');
    }
  }

  /// "Download & install" — enqueue via DownloadManager, start polling.
  Future<void> download() async {
    final current = state;
    if (current is! UpdateAvailable) return;
    final release = current.release;
    try {
      final id = await _bridge.enqueueApkDownload(
        url: release.apkUrl!,
        fileName: release.apkName ?? 'toadlauncher-update.apk',
      );
      state = UpdateDownloading(
        release: release,
        downloadId: id,
      );
      _startPolling(release: release, id: id);
    } on UpdateUnreachableException {
      state = const UpdateFailed(
        'The system download service is unavailable — opening the release '
        'page in the browser instead.',
      );
      await _bridge.openUrl(release.htmlUrl);
    }
  }

  void _startPolling({required ReleaseInfo release, required int id}) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      final snap = await _bridge.downloadProgress(id);
      final current = state;
      if (current is! UpdateDownloading || current.downloadId != id) {
        timer.cancel();
        return;
      }
      state = UpdateDownloading(
        release: current.release,
        downloadId: id,
        snapshot: snap,
      );
      if (snap.successful) {
        timer.cancel();
        await _handToInstaller(release: current.release, id: id);
      } else if (snap.failed) {
        timer.cancel();
        state = const UpdateFailed('The download did not make it — try again.');
      }
    });
  }

  /// SHA-256 gate, then the system installer (or the exact settings
  /// toggle when "Install unknown apps" is off — toadFILES behavior).
  Future<void> _handToInstaller({
    required ReleaseInfo release,
    required int id,
  }) async {
    final handoff = await _bridge.installDownloadedApk(
      id: id,
      expectedSha256: release.sha256,
    );
    switch (handoff) {
      case InstallHandoff.started:
        state = UpdateIdle();
      case InstallHandoff.needsPermission:
        state = UpdateNeedsInstallPermission(release: release, downloadId: id);
      case InstallHandoff.checksumFailed:
        state = UpdateChecksumFailed(release: release);
      case InstallHandoff.failed:
        state = const UpdateFailed('The installer would not start — try again.');
    }
  }

  /// Retry the install handoff after the user granted the toggle.
  Future<void> retryInstall() async {
    final current = state;
    if (current is! UpdateNeedsInstallPermission) return;
    await _handToInstaller(release: current.release, id: current.downloadId);
  }

  /// Open the exact "Install unknown apps" toggle for this package.
  Future<void> openInstallPermissionSettings() async {
    // The channel opened it during the failed handoff (toadFILES pattern);
    // nothing more to do here — kept as a hook for the banner's retry row.
  }

  /// Open the GitHub release page in the browser (the browser has network;
  /// we never do).
  Future<void> openReleasePage() => _bridge.openUrl(kReleasePageUrl);

  /// Back to calm. Banner dismissed, errors cleared. Any in-flight poll
  /// cancels itself on its next tick because the state no longer matches.
  void dismiss() {
    _pollTimer?.cancel();
    state = const UpdateIdle();
  }
}

/// The bridge itself as a provider lives in device_bridge.dart next to
/// its class — import that, not this file, for the bridge.
final NotifierProvider<UpdateEngine, UpdateState> updateEngineProvider =
    NotifierProvider<UpdateEngine, UpdateState>(UpdateEngine.new);
