/// Core domain models for toadLAUNCHER.
///
/// The launcher renders from a local app index (design principle 3:
/// "instant and offline"). In demo mode the index is seeded from
/// [DemoAppRepository]; on device it comes from the Android package
/// manager through the same interface.
library;

import 'package:material_ui/material_ui.dart';

/// One entry in the app index.
@immutable
class AppEntry {
  const AppEntry({
    required this.id,
    required this.name,
    required this.glyph,
    this.gradientIndex = 0,
    this.isFamilyToad = false,
    this.packageName,
    this.badge,
  });

  /// Stable id — android package name on device, demo id in demo mode.
  final String id;
  final String name;

  /// Glyph shown inside the gradient tile (demo icons are the proposal's
  /// hand-set characters; device mode swaps in real adaptive icons).
  final String glyph;

  /// Palette index g1..g8; ignored when [isFamilyToad] is true.
  final int gradientIndex;

  /// Family apps (toadGALLERY, toadPLAYER) render the shared toad face.
  final bool isFamilyToad;

  /// Android package to launch; null in pure demo entries.
  final String? packageName;

  /// Local-state-only badge text, e.g. "2 missed".
  final String? badge;

  AppEntry copyWith({String? badge}) => AppEntry(
        id: id,
        name: name,
        glyph: glyph,
        gradientIndex: gradientIndex,
        isFamilyToad: isFamilyToad,
        packageName: packageName,
        badge: badge ?? this.badge,
      );

  @override
  bool operator ==(Object other) => other is AppEntry && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A folder ("Media"): 3x3 card, shared-axis open, inline rename.
@immutable
class FolderData {
  const FolderData({
    required this.id,
    required this.title,
    required this.apps,
  });

  final String id;
  final String title;
  final List<AppEntry> apps;

  FolderData copyWith({String? title, List<AppEntry>? apps}) => FolderData(
        id: id,
        title: title ?? this.title,
        apps: apps ?? this.apps,
      );

  @override
  bool operator ==(Object other) => other is FolderData && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// One slot on a home page. Home pages mix plain apps with folder tiles;
/// the drawer and pond rows stay plain [AppEntry] lists.
sealed class HomeCell {
  const HomeCell();

  /// Label painted under the tile.
  String get label;
}

/// A plain app icon.
@immutable
class AppCell extends HomeCell {
  const AppCell(this.app);

  final AppEntry app;

  @override
  String get label => app.name;

  @override
  bool operator ==(Object other) => other is AppCell && other.app == app;

  @override
  int get hashCode => app.hashCode;
}

/// A folder tile: 2x2 mini preview on home, shared-axis card when opened.
@immutable
class FolderCell extends HomeCell {
  const FolderCell(this.folder);

  final FolderData folder;

  @override
  String get label => folder.title;

  @override
  bool operator ==(Object other) =>
      other is FolderCell && other.folder == folder;

  @override
  int get hashCode => folder.hashCode;
}

/// "On this day" memory strip — toadGALLERY content contract (mocked).
@immutable
class MemoryCardData {
  const MemoryCardData({
    required this.title,
    required this.meta,
    required this.photoCount,
    required this.year,
  });

  final String title; // "On this day"
  final String meta; // "3 photos · 2025"
  final int photoCount;
  final int year;
}

/// Resolved home layout: pages + dock + recents + drawer data.
@immutable
class HomeLayout {
  const HomeLayout({
    required this.pages,
    required this.dock,
    required this.recents,
    required this.allApps,
    required this.folders,
    required this.memory,
  });

  final List<List<HomeCell>> pages;
  final List<AppEntry> dock;

  /// Last 4 launched (demo-seeded; [HomeController.recordLaunch] maintains).
  final List<AppEntry> recents;

  /// Alphabetically sorted full index.
  final List<AppEntry> allApps;
  final List<FolderData> folders;
  final MemoryCardData memory;

  HomeLayout copyWith({
    List<List<HomeCell>>? pages,
    List<AppEntry>? dock,
    List<AppEntry>? recents,
    List<FolderData>? folders,
  }) {
    return HomeLayout(
      pages: pages ?? this.pages,
      dock: dock ?? this.dock,
      recents: recents ?? this.recents,
      allApps: allApps,
      folders: folders ?? this.folders,
      memory: memory,
    );
  }

  /// Current copy of a folder by id (pages and the folders list are patched
  /// together by the controller; read through here for the freshest state).
  FolderData? folderById(String id) {
    for (final f in folders) {
      if (f.id == id) return f;
    }
    return null;
  }
}
