library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../device/device_bridge.dart';

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

  static const int kDistinctBoots = 3;
  static const Duration kWindow = Duration(minutes: 5);

  static const int kMaxEntries = 50;

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
    }
  }

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

  static Future<bool> verdict() async {
    final entries = await _read();
    return shouldEnterSafeMode(entries, DateTime.now());
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kLedgerKey);
    } catch (_) {}
  }

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

  static Future<String?> exportLogFile() async {
    try {
      final bridge = DeviceBridge();
      final dir = await bridge.appFilesDir();
      if (dir == null) return null;
      final file = File('$dir/crash-log.txt');
      await file.writeAsString(await ledgerText());
      return file.path;
    } catch (_) {
      return null;
    }
  }

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
