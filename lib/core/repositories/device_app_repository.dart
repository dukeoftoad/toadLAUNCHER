library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../device/device_bridge.dart';
import '../device/toad_family.dart';
import '../models/models.dart';
import 'app_repository.dart';

const String _kRecentsKey = 'toadlauncher.recents.v1';

const List<({String pkg, String labelContains})> _kDockCandidates = [
  (pkg: 'com.google.android.dialer', labelContains: 'phone'),
  (pkg: 'com.samsung.android.dialer', labelContains: 'phone'),
  (pkg: 'com.google.android.apps.messaging', labelContains: 'messag'),
  (pkg: 'com.samsung.android.messaging', labelContains: 'messag'),
  (pkg: 'com.android.chrome', labelContains: 'chrome'),
  (pkg: 'com.google.android.googlequicksearchbox', labelContains: 'google'),
  (pkg: 'com.sec.android.app.camera', labelContains: 'camera'),
  (pkg: 'com.android.camera2', labelContains: 'camera'),
];

class DeviceAppRepository implements AppRepository {
  DeviceAppRepository(this.bridge, {this.usageOptIn = false});

  final DeviceBridge bridge;

  final bool usageOptIn;

  final Map<String, Uint8List> iconBytes = {};

  List<AppEntry> _allApps = const [];

  @override
  Future<HomeLayout> loadHomeLayout({int columnsPerRow = 4}) async {
    final deviceApps = await bridge.listApps();

    iconBytes.clear();
    final entries = <AppEntry>[];
    for (final app in deviceApps) {
      final family = isToadFamilyPackage(app.packageId);
      final display = family
          ? (toadFamilyDisplayName(app.packageId) ?? app.label)
          : app.label;
      if (app.iconPng != null) iconBytes[app.packageId] = app.iconPng!;
      entries.add(
        AppEntry(
          id: app.packageId,
          name: display,
          glyph: family
              ? ''
              : (display.isEmpty ? '?' : display.substring(0, 1).toUpperCase()),
          gradientIndex: _stableGradient(app.packageId),
          isFamilyToad: family,
          packageName: app.packageId,
        ),
      );
    }
    entries.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    _allApps = List.unmodifiable(entries);

    final all = List<AppEntry>.from(_allApps);
    final familyApps = all.where((a) => a.isFamilyToad).toList();

    final perPage = columnsPerRow * 4;
    final pageApps = all.where((a) => !familyApps.contains(a)).toList();
    final pages = <List<HomeCell>>[];
    while (pages.isEmpty || pages.length * perPage < pageApps.length) {
      final taken = pageApps
          .skip(pages.length * perPage)
          .take(perPage)
          .toList();
      pages.add([for (final a in taken) AppCell(a)]);
    }
    if (familyApps.length >= 2 && pages.isNotEmpty) {
      final targetPage = pages.length >= 2 ? 1 : 0;
      pages[targetPage].insert(
        0,
        FolderCell(
          FolderData(id: 'toad-family', title: 'toad family', apps: familyApps),
        ),
      );
    }

    return HomeLayout(
      pages: pages,
      dock: _dockFrom(all),
      recents: await _recentsFrom(all),
      allApps: all,
      folders: familyApps.length >= 2
          ? [
              FolderData(
                id: 'toad-family',
                title: 'toad family',
                apps: familyApps,
              ),
            ]
          : const [],
      memory: const MemoryCardData(
        title: 'On this day',
        meta: 'photos arrive with toadGALLERY',
        photoCount: 0,
        year: 0,
      ),
    );
  }

  @override
  Future<List<List<AppEntry>>> loadPondRows() async {
    if (_allApps.isEmpty) await loadHomeLayout();
    final pool = _allApps.take(5).toList();
    return [
      [for (final a in pool.take(3)) a],
      [
        if (pool.length > 3) pool[3],
        if (pool.length > 4) pool[4],
        const AppEntry(id: 'resident', name: 'the resident', glyph: ''),
      ],
    ];
  }

  @override
  Future<void> launch(AppEntry app) async {
    await bridge.launch(app.packageName ?? app.id);
    await _recordHistory(app.id);
  }

  @override
  Future<bool> uninstallApp(AppEntry app) =>
      bridge.uninstall(app.packageName ?? app.id);

  @override
  Future<bool> openAppDetails(AppEntry app) =>
      bridge.appDetails(app.packageName ?? app.id);

  static int _stableGradient(String packageId) {
    var h = 0;
    for (final c in packageId.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h % 8;
  }

  List<AppEntry> _dockFrom(List<AppEntry> all) {
    final dock = <AppEntry>[];
    void addByPackage(String pkg) {
      if (dock.length >= 4) return;
      final hit = all.where((a) => a.id == pkg).firstOrNull;
      if (hit != null && !dock.contains(hit)) dock.add(hit);
    }

    void addByLabel(String fragment) {
      if (dock.length >= 4) return;
      final hit = all
          .where(
            (a) =>
                a.name.toLowerCase().contains(fragment) && !dock.contains(a),
          )
          .firstOrNull;
      if (hit != null) dock.add(hit);
    }

    for (final c in _kDockCandidates.take(4)) {
      addByPackage(c.pkg);
    }
    for (final c in _kDockCandidates) {
      if (dock.length >= 4) break;
      addByLabel(c.labelContains);
    }
    for (final a in all) {
      if (dock.length >= 4) break;
      if (!dock.contains(a) && a.id != 'resident') dock.add(a);
    }
    return dock.take(4).toList();
  }

  Future<List<AppEntry>> _recentsFrom(List<AppEntry> all) async {
    final usage = usageOptIn ? await bridge.usageRecents() : null;
    if (usage != null) {
      final hits = [
        for (final pkg in usage)
          if (all.where((a) => a.id == pkg).firstOrNull != null)
            all.where((a) => a.id == pkg).firstOrNull!,
      ];
      if (hits.isNotEmpty) return hits.take(4).toList();
    }
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_kRecentsKey) ?? const [];
    return [
      for (final id in ids)
        if (all.where((a) => a.id == id).firstOrNull != null)
          all.where((a) => a.id == id).firstOrNull!,
    ].take(4).toList();
  }

  Future<void> _recordHistory(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_kRecentsKey) ?? <String>[];
      final next = [id, ...ids.where((e) => e != id)].take(16).toList();
      await prefs.setStringList(_kRecentsKey, next);
    } catch (_) {
    }
  }
}

final StateProvider<Map<String, Uint8List>> deviceIconsProvider =
    StateProvider<Map<String, Uint8List>>((ref) => const {});

bool familyInstalledBeyondLauncher(HomeLayout layout) =>
    layout.allApps.any((a) => a.isFamilyToad && a.id != 'family.toad.launcher');

List<String> decodeRecents(String raw) =>
    (jsonDecode(raw) as List<dynamic>).cast<String>();
