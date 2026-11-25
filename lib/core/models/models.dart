library;

import 'package:material_ui/material_ui.dart';

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

  final String id;
  final String name;

  final String glyph;

  final int gradientIndex;

  final bool isFamilyToad;

  final String? packageName;

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

@immutable
class FolderData {
  const FolderData({required this.id, required this.title, required this.apps});

  final String id;
  final String title;
  final List<AppEntry> apps;

  FolderData copyWith({String? title, List<AppEntry>? apps}) =>
      FolderData(id: id, title: title ?? this.title, apps: apps ?? this.apps);

  @override
  bool operator ==(Object other) => other is FolderData && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

sealed class HomeCell {
  const HomeCell();

  String get label;
}

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

@immutable
class MemoryCardData {
  const MemoryCardData({
    required this.title,
    required this.meta,
    required this.photoCount,
    required this.year,
  });

  final String title;
  final String meta;
  final int photoCount;
  final int year;
}

@immutable
class HomeLayout {
  const HomeLayout({
    required this.pages,
    required this.dock,
    required this.recents,
    required this.allApps,
    required this.folders,
    required this.memory,
    this.widgets = const [],
  });

  final List<List<HomeCell>> pages;
  final List<AppEntry> dock;

  final List<AppEntry> recents;

  final List<AppEntry> allApps;
  final List<FolderData> folders;
  final MemoryCardData memory;

  final List<PlacedWidget> widgets;

  HomeLayout copyWith({
    List<List<HomeCell>>? pages,
    List<AppEntry>? dock,
    List<AppEntry>? recents,
    List<FolderData>? folders,
    List<PlacedWidget>? widgets,
  }) {
    return HomeLayout(
      pages: pages ?? this.pages,
      dock: dock ?? this.dock,
      recents: recents ?? this.recents,
      allApps: allApps,
      folders: folders ?? this.folders,
      memory: memory,
      widgets: widgets ?? this.widgets,
    );
  }

  List<PlacedWidget> widgetsOnPage(int page) =>
      widgets.where((w) => w.page == page).toList();

  FolderData? folderById(String id) {
    for (final f in folders) {
      if (f.id == id) return f;
    }
    return null;
  }
}

enum WidgetKind { clock, memories, calendar, sticky, androidHosted }

@immutable
class PlacedWidget {
  const PlacedWidget({
    required this.id,
    required this.kind,
    required this.page,
    required this.w,
    required this.h,
    this.providerId,
    this.appWidgetId,
    this.label,
    this.packageName,
  });

  final String id;
  final WidgetKind kind;
  final int page;
  final int w;
  final int h;

  final String? providerId;
  final int? appWidgetId;
  final String? label;
  final String? packageName;

  PlacedWidget copyWith({int? page, int? w, int? h}) => PlacedWidget(
    id: id,
    kind: kind,
    page: page ?? this.page,
    w: w ?? this.w,
    h: h ?? this.h,
    providerId: providerId,
    appWidgetId: appWidgetId,
    label: label,
    packageName: packageName,
  );

  @override
  bool operator ==(Object other) => other is PlacedWidget && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
