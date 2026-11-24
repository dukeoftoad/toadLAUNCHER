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

  final List<List<AppEntry>> pages;
  final List<AppEntry> dock;

  /// Last 4 launched (demo-seeded).
  final List<AppEntry> recents;

  /// Alphabetically sorted full index.
  final List<AppEntry> allApps;
  final List<FolderData> folders;
  final MemoryCardData memory;
}
