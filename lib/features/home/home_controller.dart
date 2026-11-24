/// Home screen state — loads the app index, tracks the visible page and
/// applies the stage-2 layout mutations (recents, remove, folder rename).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/repositories/app_repository.dart';

/// Async home layout from the repository (demo-seeded for this alpha).
final AsyncNotifierProvider<HomeController, HomeLayout> homeLayoutProvider =
    AsyncNotifierProvider<HomeController, HomeLayout>(HomeController.new);

class HomeController extends AsyncNotifier<HomeLayout> {
  @override
  Future<HomeLayout> build() async {
    final repo = ref.read(appRepositoryProvider);
    return repo.loadHomeLayout();
  }

  /// Launch through the repository, then feed the drawer recents row.
  Future<void> launch(AppEntry app) async {
    final repo = ref.read(appRepositoryProvider);
    await repo.launch(app);
    recordLaunch(app);
  }

  /// "Recents row: last 4 launched apps" — newest first, deduped.
  void recordLaunch(AppEntry app) {
    final current = state.value;
    if (current == null) return;
    final recents = <AppEntry>[
      app,
      ...current.recents.where((a) => a.id != app.id),
    ].take(4).toList();
    state = AsyncData(current.copyWith(recents: recents));
  }

  /// Remove a tile from one page ("Remove takes the icon off this page
  /// only"). A page left empty disappears; the page count follows.
  void removePageCell(int pageIndex, int cellIndex) {
    final current = state.value;
    if (current == null) return;
    if (pageIndex < 0 || pageIndex >= current.pages.length) return;
    final page = List<HomeCell>.from(current.pages[pageIndex])
      ..removeAt(cellIndex);

    var pages = List<List<HomeCell>>.from(current.pages);
    if (page.isEmpty && pages.length > 1) {
      pages = [...pages]..removeAt(pageIndex);
    } else {
      pages[pageIndex] = page;
    }
    state = AsyncData(current.copyWith(pages: pages));
  }

  /// Pull an app out of the dock.
  void removeFromDock(String appId) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        dock: current.dock.where((a) => a.id != appId).toList(),
      ),
    );
  }

  /// Inline folder rename — patches both the folders list and the tile.
  void renameFolder(String folderId, String title) {
    final clean = title.trim();
    if (clean.isEmpty) return;
    final current = state.value;
    if (current == null) return;

    final folders = [
      for (final f in current.folders)
        if (f.id == folderId) f.copyWith(title: clean) else f,
    ];
    final pages = [
      for (final page in current.pages)
        [
          for (final cell in page)
            if (cell is FolderCell && cell.folder.id == folderId)
              FolderCell(cell.folder.copyWith(title: clean))
            else
              cell,
        ],
    ];
    state = AsyncData(current.copyWith(pages: pages, folders: folders));
  }

  /// Remove one app from inside a folder. A folder that runs empty comes
  /// off the page — folders are only a way to group apps.
  void removeAppFromFolder(String folderId, String appId) {
    final current = state.value;
    if (current == null) return;

    FolderData? updated;
    final folders = <FolderData>[];
    for (final f in current.folders) {
      if (f.id != folderId) {
        folders.add(f);
      } else {
        updated = f.copyWith(
          apps: f.apps.where((a) => a.id != appId).toList(),
        );
        if (updated.apps.isNotEmpty) folders.add(updated);
      }
    }

    final pages = [
      for (final page in current.pages)
        [
          for (final cell in page)
            if (cell is FolderCell && cell.folder.id == folderId)
              (updated == null || updated.apps.isEmpty)
                  ? null // empty folder leaves the page
                  : FolderCell(updated)
            else
              cell,
        ].whereType<HomeCell>().toList(),
    ];

    state = AsyncData(current.copyWith(pages: pages, folders: folders));
  }
}

/// Current home page index (drives the pill dots).
class CurrentPageController extends Notifier<int> {
  @override
  int build() => 0;

  void set(int page) => state = page;
}

final NotifierProvider<CurrentPageController, int> currentPageProvider =
    NotifierProvider<CurrentPageController, int>(CurrentPageController.new);

/// Drawer visibility. Hosts own their overlay stack; the provider keeps the
/// state testable and shared between the sketchbook and pond homes.
class DrawerVisibilityController extends Notifier<bool> {
  @override
  bool build() => false;

  void open() => state = true;
  void close() => state = false;
  void toggle() => state = !state;
}

final NotifierProvider<DrawerVisibilityController, bool> drawerOpenProvider =
    NotifierProvider<DrawerVisibilityController, bool>(
  DrawerVisibilityController.new,
);

/// One-shot demo feedback (snackbar). Demo mode is honest about what is
/// real: launches record recents, device-only actions say so.
class ToastController extends Notifier<String?> {
  @override
  String? build() => null;

  void show(String message) => state = message;

  void consume() => state = null;
}

final NotifierProvider<ToastController, String?> toastProvider =
    NotifierProvider<ToastController, String?>(ToastController.new);
