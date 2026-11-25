/// REL-01 — crash-loop protection for a Home app.
///
/// A launcher that crashes on start is the user's entire phone UI, so the
/// pond keeps a small, local, honest crash ledger:
///
///   · every uncaught Flutter/zone/platform error is recorded with a
///     timestamp and the boot id of the process it happened in
///   ///   · at startup, if the last 5 minutes hold crashes from ≥ 3 distinct
///     boots, the launcher starts in SAFE MODE (own minimal UI: pond off,
///     no platform-view widgets, plain app grid — the phone stays usable)
///   · safe mode offers: try again · reset layout · share the crash log ·
///     choose another Home — recovery without adb
///
/// Everything stays on-device (the no-network promise covers crashes too:
/// nothing is ever uploaded). The ledger lives in SharedPreferences —
/// always available, no async file dance at crash time. The shareable
/// crash-log FILE is written on demand from the ledger.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../device/device_bridge.dart';

/// Pure decision logic — unit-testable without a device.
@visibleForTesting
bool shouldEnterSafeMode(List<CrashEntry> entries, DateTime now) {
  final windowStart =
      now.millisecondsSinceEpoch - CrashGuard.kWindow.inMilliseconds;
  final recentBoots = entries
      .where((e) => e.atMs >= windowStart)
      .map((e) => e.boot)
      .toSet();
  return recentBoots.length >= CrashGuard.kDistinctBoots;
}

class CrashEntry {
  const CrashEntry({
    required this.atMs,
    required this.boot,
    required this.kind,
    required this.message,
  });

  final int atMs;
  final String boot;
  final String kind;
  final String message;

  Map<String, Object> toJson() => {
    'at': atMs,
    'boot': boot,
    'kind': kind,
    'message': message,
  };

  factory CrashEntry.fromJson(Map<String, Object?> json) => CrashEntry(
    atMs: (json['at'] as num?)?.toInt() ?? 0,
    boot: json['boot'] as String? ?? '',
    kind: json['kind'] as String? ?? '',
    message: json['message'] as String? ?? '',
  );
}

class CrashGuard {
  static const String _kLedgerKey = 'toadlauncher.crashlog.v1';

  /// Crashes from ≥ 3 distinct boots inside the window = safe mode.
  static const int kDistinctBoots = 3;
  static const Duration kWindow = Duration(minutes: 5);

  /// Ledger cap — the pond remembers, but not forever.
  static const int kMaxEntries = 50;

  /// Identifies this process run (crashes from one boot that recovers are
  /// not a crash LOOP; a loop restarts the process).
  static final String bootId =
      DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  static Future<List<CrashEntry>> _read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kLedgerKey);
      if (raw == null || raw.isEmpty) return <CrashEntry>[];
      final list = jsonDecode(raw) as List<Object?>;
      return <CrashEntry>[
        for (final e in list)
          if (e is Map) CrashEntry.fromJson(e.cast<String, Object?>()),
      ];
    } catch (_) {
      return <CrashEntry>[];
    }
  }

  static Future<void> _write(List<CrashEntry> entries) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kLedgerKey,
        jsonEncode([for (final e in entries) e.toJson()]),
      );
    } catch (_) {
      // The ledger is best-effort; a crash while crashing is not fixable.
    }
  }

  /// Record one uncaught error (bounded: message + stack head, no payloads).
  static Future<void> record(String kind, Object error, StackTrace? stack) async {
    final buffer = StringBuffer('$error');
    if (stack != null) {
      final tail = stack.toString().split('\n').take(8).join('\n');
      buffer.write('\n$tail');
    }
    final text = buffer.toString();
    final entries = await _read();
    entries.add(
      CrashEntry(
        atMs: DateTime.now().millisecondsSinceEpoch,
        boot: bootId,
        kind: kind,
        message: text.length > 1200 ? text.substring(0, 1200) : text,
      ),
    );
    await _write(entries.length > kMaxEntries
        ? entries.sublist(entries.length - kMaxEntries)
        : entries);
  }

  /// The startup verdict: true → open in safe mode.
  static Future<bool> verdict() async {
    final entries = await _read();
    return shouldEnterSafeMode(entries, DateTime.now());
  }

  /// "Try again" — clear the ledger and re-run the normal launcher.
  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kLedgerKey);
    } catch (_) {}
  }

  /// The ledger as a readable text log (what safe mode shares).
  static Future<String> ledgerText() async {
    final entries = await _read();
    if (entries.isEmpty) return 'no crashes recorded';
    final buffer = StringBuffer('toadLAUNCHER crash log (local, never sent)\n');
    for (final e in entries) {
      final at = DateTime.fromMillisecondsSinceEpoch(e.atMs);
      buffer.write(
        '\n--- ${at.toIso8601String()} · ${e.kind} · boot ${e.boot}\n'
        '${e.message}\n',
      );
    }
    return buffer.toString();
  }

  /// Write the ledger to the app-private files dir and return the path —
  /// safe mode shares THIS file through the system sheet (user-chosen
  /// target; the file never leaves the phone on its own).
  static Future<String?> exportLogFile() async {
    try {
      final bridge = DeviceBridge();
      // Only the real channel can answer; tests/desktop get null.
      final dir = await bridge.appFilesDir();
      if (dir == null) return null;
      final file = File('$dir/crash-log.txt');
      await file.writeAsString(await ledgerText());
      return file.path;
    } catch (_) {
      return null;
    }
  }

  // -- install points -------------------------------------------------------

  /// Wire every Dart-level error stream into the ledger.
  static void install() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      record('flutter', details.exception, details.stack);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      record('platform', error, stack);
      return true;
    };
  }
}
