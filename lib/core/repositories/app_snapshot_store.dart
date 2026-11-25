library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../device/device_bridge.dart';

/// PERF-01: the persisted app index behind fast cold starts.
///
/// The last good index (apps, labels, icon bytes, dock, recents) lives in
/// the app-private dir as one JSON file plus one PNG per icon. Cold start
/// reads it and renders home before PackageManager is ever asked; the
/// bridge refresh then re-persists. Any decode/validation failure returns
/// null and the caller falls through to the normal live load — a broken
/// snapshot can never brick the index.
class AppSnapshotStore {
  AppSnapshotStore({Future<String?> Function()? resolveDir})
    : _resolveDir = resolveDir ?? _defaultDir;

  static const int _kVersion = 1;

  final Future<String?> Function() _resolveDir;

  static Future<String?> _defaultDir() async {
    try {
      final root = await DeviceBridge().appFilesDir();
      if (root == null || root.isEmpty) return null;
      return '$root/snapshot';
    } catch (_) {
      return null;
    }
  }

  Future<Directory?> _dir() async {
    try {
      final path = await _resolveDir();
      if (path == null || path.isEmpty) return null;
      return await Directory(path).create(recursive: true);
    } catch (_) {
      return null;
    }
  }

  Future<PersistedIndex?> load() async {
    try {
      final dir = await _dir();
      if (dir == null) return null;
      final raw = await File('${dir.path}/index.json').readAsString();
      final json = jsonDecode(raw);
      if (json is! Map || (json['v'] as num?)?.toInt() != _kVersion) {
        return null;
      }
      final apps = <_PersistedApp>[];
      final appList = json['apps'];
      if (appList is! List) return null;
      for (final item in appList) {
        if (item is! Map) continue;
        final id = item['id'] as String? ?? '';
        if (id.isEmpty) continue;
        apps.add(
          _PersistedApp(
            id: id,
            label: item['label'] as String? ?? '',
            family: (item['family'] as bool?) ?? false,
            mono: (item['mono'] as bool?) ?? false,
          ),
        );
      }
      if (apps.isEmpty) return null;
      final icons = <String, Uint8List?>{};
      final monos = <String, Uint8List?>{};
      await Future.wait([
        for (final app in apps)
          () async {
            icons[app.id] = await _readPng(dir, '${app.id}.png');
            if (app.mono) {
              monos[app.id] = await _readPng(dir, '${app.id}.mono.png');
            }
          }(),
      ]);
      return PersistedIndex(
        savedAt: (json['at'] as num?)?.toInt() ?? 0,
        apps: [
          for (final app in apps)
            DeviceApp(
              packageId: app.id,
              label: app.label,
              iconPng: icons[app.id],
              iconMonoPng: monos[app.id],
              isFamily: app.family,
            ),
        ],
        dockIds: [
          for (final id in json['dock'] as List? ?? const [])
            if (id is String) id,
        ],
        recentIds: [
          for (final id in json['recents'] as List? ?? const [])
            if (id is String) id,
        ],
      );
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _readPng(Directory dir, String name) async {
    try {
      return await File('${dir.path}/icons/$name').readAsBytes();
    } catch (_) {
      return null;
    }
  }

  Future<void> save({
    required List<DeviceApp> apps,
    required List<String> dockIds,
    required List<String> recentIds,
  }) async {
    try {
      final dir = await _dir();
      if (dir == null) return;
      final iconsDir = Directory('${dir.path}/icons');
      if (!iconsDir.existsSync()) iconsDir.createSync(recursive: true);

      final entries = <Map<String, Object?>>[];
      final keep = <String>{};
      for (final app in apps) {
        final hasIcon = app.iconPng != null;
        final hasMono = app.iconMonoPng != null;
        if (hasIcon) {
          await _writePng(iconsDir, '${app.packageId}.png', app.iconPng!);
          keep.add('${app.packageId}.png');
        }
        if (hasMono) {
          await _writePng(
            iconsDir,
            '${app.packageId}.mono.png',
            app.iconMonoPng!,
          );
          keep.add('${app.packageId}.mono.png');
        }
        entries.add(<String, Object?>{
          'id': app.packageId,
          'label': app.label,
          'family': app.isFamily,
          'mono': hasMono,
        });
      }

      for (final stale in iconsDir.listSync()) {
        if (stale is File && !keep.contains(fileUriName(stale))) {
          try {
            stale.deleteSync();
          } catch (_) {}
        }
      }

      final payload = jsonEncode(<String, Object?>{
        'v': _kVersion,
        'at': DateTime.now().millisecondsSinceEpoch,
        'apps': entries,
        'dock': dockIds,
        'recents': recentIds,
      });
      final tmp = File('${dir.path}/index.json.tmp');
      await tmp.writeAsString(payload);
      await tmp.rename('${dir.path}/index.json');
    } catch (_) {
    }
  }

  String fileUriName(File file) => file.uri.pathSegments.last;

  Future<void> _writePng(Directory dir, String name, Uint8List bytes) async {
    try {
      await File('${dir.path}/$name').writeAsBytes(bytes, flush: true);
    } catch (_) {}
  }

  Future<void> clear() async {
    try {
      final dir = await _dir();
      if (dir == null || !dir.existsSync()) return;
      await dir.delete(recursive: true);
    } catch (_) {}
  }
}

@immutable
class _PersistedApp {
  const _PersistedApp({
    required this.id,
    required this.label,
    required this.family,
    required this.mono,
  });

  final String id;
  final String label;
  final bool family;
  final bool mono;
}

@immutable
class PersistedIndex {
  const PersistedIndex({
    required this.savedAt,
    required this.apps,
    required this.dockIds,
    required this.recentIds,
  });

  final int savedAt;
  final List<DeviceApp> apps;
  final List<String> dockIds;
  final List<String> recentIds;

  bool get fresh {
    final age = DateTime.now().millisecondsSinceEpoch - savedAt;
    return age >= 0 && age < const Duration(hours: 72).inMilliseconds;
  }
}
