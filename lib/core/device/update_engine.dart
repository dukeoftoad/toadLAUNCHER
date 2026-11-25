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

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// SEC-02: the release could not be proven ours — the detached signature
/// was missing or invalid. The update is refused BEFORE any banner says
/// “available”; the honest fix is the release page in the browser.
class UpdateUnverified extends UpdateState {
  const UpdateUnverified({required this.release});
  final ReleaseInfo release;
}

class UpdateChecksumFailed extends UpdateState {
  const UpdateChecksumFailed({required this.release});
  final ReleaseInfo release;
}

class UpdateFailed extends UpdateState {
  const UpdateFailed(this.message);
  final String message;
}

/// Component-wise version compare — a faithful port of toadFILES'
/// VersionCompare (the shape GitHub tags actually use): optional leading
/// "v", dot/dash parts compare numerically ("1.10.0" > "1.9.0"), a
/// missing pre-release suffix means the stable release ("1.7.0-beta" <
/// "1.7.0"), and build metadata ("+41") rides inside the suffix. A tag
/// with no numeric parts at all parses as 0 — a malformed tag can never
/// push an update. Pure Dart, no platform calls — unit-testable.
int compareVersions(String a, String b) {
  final left = _parseVersion(a);
  final right = _parseVersion(b);
  if (left == null || right == null) return 0;
  final len = left.length > right.length ? left.length : right.length;
  for (var i = 0; i < len; i++) {
    final l = i < left.length ? left[i] : _missingComponent;
    final r = i < right.length ? right[i] : _missingComponent;
    if (l.number != r.number) return l.number.compareTo(r.number);
    final ls = l.suffix;
    final rs = r.suffix;
    if (ls == rs) continue;
    if (ls == null) return 1; // stable outranks its own pre-releases
    if (rs == null) return -1;
    final c = ls.compareTo(rs);
    if (c != 0) return c;
  }
  return 0;
}

class _VersionComponent {
  const _VersionComponent(this.number, this.suffix);

  final int number;
  final String? suffix;
}

const _VersionComponent _missingComponent = _VersionComponent(0, null);

List<_VersionComponent>? _parseVersion(String version) {
  var cleaned = version.trim().toLowerCase();
  while (cleaned.startsWith('v')) {
    cleaned = cleaned.substring(1);
  }
  // Semver rule: build metadata ("+41") never changes precedence —
  // "0.12.0-beta+41" == "0.12.0-beta" (pinned by device_mode_test).
  final plus = cleaned.indexOf('+');
  if (plus >= 0) cleaned = cleaned.substring(0, plus);
  if (cleaned.isEmpty) return null;
  final out = <_VersionComponent>[];
  for (final part in cleaned.split(RegExp(r'[.-]'))) {
    final m = RegExp(r'^(\d*)(.*)$').firstMatch(part);
    final digits = m?.group(1) ?? '';
    final rest = m?.group(2) ?? '';
    out.add(
      _VersionComponent(
        digits.isEmpty ? 0 : (int.tryParse(digits) ?? 0),
        rest.isEmpty ? null : rest,
      ),
    );
  }
  return out;
}

/// Riverpod state holder for the update flow.
class UpdateEngine extends Notifier<UpdateState> {
  bool _startupCheckDone = false;
  Timer? _pollTimer;

  @override
  UpdateState build() => const UpdateIdle();

  DeviceBridge get _bridge => ref.watch(deviceBridgeProvider);

  /// SEC-04: the persisted last-check timestamp (epoch ms).
  static const String _kLastCheckKey = 'toadlauncher.update.lastcheck';

  /// True when the policy allows a silent check right now. Pure and
  /// unit-testable: [nowMs] - [lastCheckMs] >= policy interval.
  @visibleForTesting
  bool silentCheckAllowed(UpdatePolicy policy, int lastCheckMs, int nowMs) {
    final interval = policy.minInterval;
    if (interval == null) return false; // off / manual
    return nowMs - lastCheckMs >= interval.inMilliseconds;
  }

  /// One silent check per process on start — now throttled by the update
  /// policy (SEC-04: daily by default, not “every process”).
  /// Respects the settings switch; swallows every failure quietly.
  Future<void> silentStartupCheck() async {
    if (_startupCheckDone) return;
    _startupCheckDone = true;
    final settings = ref.read(launcherSettingsProvider);
    if (!settings.autoUpdateCheck) return;

    // The throttle: never more often than the policy allows.
    int lastCheck = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      lastCheck = prefs.getInt(_kLastCheckKey) ?? 0;
    } catch (_) {}
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!silentCheckAllowed(settings.updatePolicy, lastCheck, now)) return;

    try {
      final release = await _bridge.checkLatestRelease();
      final current = (await _bridge.versionInfo()).versionName;
      if (compareVersions(release.tagName, current) > 0) {
        final verified = await _verifyRelease(release);
        if (verified != null) state = verified;
      }
      _stampCheck(now);
    } catch (_) {
      // Intentionally invisible — airplane mode, GitHub down, rate limit.
      // A failed check does NOT stamp the clock: the next process may try
      // again (honesty beats strictness for a once-a-day budget).
    }
  }

  Future<void> _stampCheck(int nowMs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kLastCheckKey, nowMs);
    } catch (_) {}
  }

  /// SEC-02: verify the detached signature over
  /// “tagName|sha256|assetName” with the embedded update key. Returns the
  /// state to publish (UpdateAvailable / UpdateUnverified), or null when
  /// verification is impossible here (let the caller decide).
  @visibleForTesting
  Future<UpdateState?> verifyRelease(ReleaseInfo release) async {
    if (release.sha256 == null || release.sig == null) {
      // Unsigned release — refuse with the honest handoff.
      return UpdateUnverified(release: release);
    }
    final ok = await _bridge.verifyUpdateSignature(
      release.signedMessage,
      release.sig!,
    );
    if (!ok) return UpdateUnverified(release: release);
    return UpdateAvailable(release: release);
  }

  Future<UpdateState?> _verifyRelease(ReleaseInfo release) =>
      verifyRelease(release);

  /// The explicit check from the settings page — errors surface. Manual
  /// checks ignore the throttle (the user asked) but still verify the
  /// signature before offering anything.
  Future<void> manualCheck() async {
    state = const UpdateChecking();
    try {
      final release = await _bridge.checkLatestRelease();
      final current = (await _bridge.versionInfo()).versionName;
      if (compareVersions(release.tagName, current) > 0) {
        final verified = await _verifyRelease(release);
        state = verified ?? UpdateUpToDate(version: current);
      } else {
        state = UpdateUpToDate(version: current);
      }
      _stampCheck(DateTime.now().millisecondsSinceEpoch);
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

  /// SHA-256 gate + signer-certificate gate, then the system installer
  /// (or the exact settings toggle when "Install unknown apps" is off —
  /// toadFILES behavior).
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
      case InstallHandoff.wrongCertificate:
        state = const UpdateFailed(
          'The download did not come from us — refused. Open the release '
          'page instead if you still want it.',
        );
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
