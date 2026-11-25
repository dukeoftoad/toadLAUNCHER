library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../settings/launcher_settings.dart';
import 'device_bridge.dart';
import 'toad_family.dart';

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

class UpdateNeedsInstallPermission extends UpdateState {
  const UpdateNeedsInstallPermission({
    required this.release,
    required this.downloadId,
  });
  final ReleaseInfo release;
  final int downloadId;
}

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
    if (ls == null) return 1;
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

class UpdateEngine extends Notifier<UpdateState> {
  bool _startupCheckDone = false;
  Timer? _pollTimer;

  @override
  UpdateState build() => const UpdateIdle();

  DeviceBridge get _bridge => ref.watch(deviceBridgeProvider);

  static const String _kLastCheckKey = 'toadlauncher.update.lastcheck';

  @visibleForTesting
  bool silentCheckAllowed(UpdatePolicy policy, int lastCheckMs, int nowMs) {
    final interval = policy.minInterval;
    if (interval == null) return false;
    return nowMs - lastCheckMs >= interval.inMilliseconds;
  }

  Future<void> silentStartupCheck() async {
    if (_startupCheckDone) return;
    _startupCheckDone = true;
    final settings = ref.read(launcherSettingsProvider);
    if (!settings.autoUpdateCheck) return;

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
    }
  }

  Future<void> _stampCheck(int nowMs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kLastCheckKey, nowMs);
    } catch (_) {}
  }

  @visibleForTesting
  Future<UpdateState?> verifyRelease(ReleaseInfo release) async {
    if (release.sha256 == null || release.sig == null) {
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

  Future<void> retryInstall() async {
    final current = state;
    if (current is! UpdateNeedsInstallPermission) return;
    await _handToInstaller(release: current.release, id: current.downloadId);
  }

  Future<void> openInstallPermissionSettings() async {
  }

  Future<void> openReleasePage() => _bridge.openUrl(kReleasePageUrl);

  void dismiss() {
    _pollTimer?.cancel();
    state = const UpdateIdle();
  }
}

final NotifierProvider<UpdateEngine, UpdateState> updateEngineProvider =
    NotifierProvider<UpdateEngine, UpdateState>(UpdateEngine.new);
