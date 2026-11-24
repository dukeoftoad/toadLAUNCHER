/// Home screen state — loads the app index, tracks the visible page and
/// applies layout mutations (recents, remove, folder rename) plus the
/// stage-3 widget engine (place / resize / move / undo) and the v0.11
/// real-widget engine (AppWidgetHost placements that survive restarts).
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/models.dart';
import '../../core/device/device_bridge.dart';
import '../../core/repositories/app_repository.dart';
import '../../core/repositories/device_app_repository.dart';
import '../../core/settings/launcher_settings.dart';

const String _kHostedWidgetsKey = 'toadlauncher.hosted.widgets.v1';

/// Async home layout from the repository (demo-seeded for this alpha).
final AsyncNotifierProvider<HomeController, HomeLayout> homeLayoutProvider =
    AsyncNotifierProvider<HomeController, HomeLayout>(HomeController.new);

class HomeController extends AsyncNotifier<HomeLayout> {
  /// Undo history — one snapshot per action ("every move is undoable").
  final List<({HomeLayout layout, LauncherSettings settings})> _undoStack = [];

  @override
  Future<HomeLayout> build() async {
    // Watched: flipping Device/Demo in settings rebuilds the home from the
    // newly active repository.
    final repo = ref.watch(appRepositoryProvider);
    final layout = await repo.loadHomeLayout();

    // Device mode: publish the real adaptive icons for the tile renderer.
    if (repo is DeviceAppRepository) {
      ref.read(deviceIconsProvider.notifier).state = Map<String, Uint8List>.of(
        repo.iconBytes,
      );
    }
    final settings = ref.read(launcherSettingsProvider);

    // The Caveat clock is the hero widget — seeded on page 0 unless the
    // demo layout already carries one. Its span follows the persisted
    // settings (the resized size survives restarts).
    final seeded = <PlacedWidget>[];
    if (!layout.widgets.any((w) => w.kind == WidgetKind.clock)) {
      seeded.add(
        PlacedWidget(
          id: 'widget-clock',
          kind: WidgetKind.clock,
          page: 0,
          w: settings.clockSpanW,
          h: settings.clockSpanH,
        ),
      );
    }
    // toadGALLERY's Memories strip is the featured widget of the toad
    // family — it appears only when the gallery is installed (demo id or
    // the real package id from device mode).
    final galleryInstalled = layout.allApps.any(
      (a) => a.id == 'family.toad.gallery' || a.id == 'com.toadgallery.app',
    );
    if (galleryInstalled &&
        !layout.widgets.any((w) => w.kind == WidgetKind.memories)) {
      seeded.add(
        const PlacedWidget(
          id: 'widget-memories',
          kind: WidgetKind.memories,
          page: 0,
          w: 4,
          h: 2,
        ),
      );
    }

    // Real Android widgets (AppWidgetHost ids survive restarts — the OS
    // keeps the binding as long as we never delete the id).
    final hosted = await _restoreHosted();

    if (seeded.isEmpty) {
      return layout.copyWith(widgets: [...hosted, ...layout.widgets]);
    }
    return layout.copyWith(widgets: [
      ...seeded,
      ...hosted,
      ...layout.widgets,
    ]);
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
      current.copyWith(dock: current.dock.where((a) => a.id != appId).toList()),
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
        updated = f.copyWith(apps: f.apps.where((a) => a.id != appId).toList());
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

  // -------------------------------------------------------------------------
  // Stage 3 — widget engine (place / resize / move / undo)
  // -------------------------------------------------------------------------

  /// Default spans per kind; the clock follows the persisted settings span.
  static int _defaultW(WidgetKind kind, LauncherSettings settings) =>
      switch (kind) {
        WidgetKind.clock => settings.clockSpanW,
        WidgetKind.memories => 4,
        WidgetKind.calendar => 4,
        WidgetKind.sticky => 2,
        WidgetKind.androidHosted => 4,
      };

  static int _defaultH(WidgetKind kind, LauncherSettings settings) =>
      switch (kind) {
        WidgetKind.clock => settings.clockSpanH,
        WidgetKind.memories => 2,
        WidgetKind.calendar => 4,
        WidgetKind.sticky => 2,
        WidgetKind.androidHosted => 2,
      };

  /// Capture the pre-action state. Call once at the start of a gesture;
  /// pass the snapshot to [commitAction] when the gesture ends.
  ({HomeLayout layout, LauncherSettings settings})? snapshot() {
    final layout = state.value;
    if (layout == null) return null;
    return (layout: layout, settings: ref.read(launcherSettingsProvider));
  }

  /// Register a finished action: push its snapshot onto the undo stack and
  /// surface the toast with an Undo pill.
  void commitAction(
    ({HomeLayout layout, LauncherSettings settings})? snap, {
    String? message,
  }) {
    final current = state.value;
    if (snap != null && current != null) {
      final changed =
          snap.layout.widgets.length != current.widgets.length ||
          !_sameWidgets(snap.layout.widgets, current.widgets) ||
          snap.settings.clockSpanW !=
              ref.read(launcherSettingsProvider).clockSpanW ||
          snap.settings.clockSpanH !=
              ref.read(launcherSettingsProvider).clockSpanH;
      if (changed) {
        _undoStack.add(snap);
        if (_undoStack.length > 20) _undoStack.removeAt(0);
      }
    }
    if (message != null) {
      ref.read(toastProvider.notifier).showUndoable(message);
    }
  }

  bool _sameWidgets(List<PlacedWidget> a, List<PlacedWidget> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].page != b[i].page ||
          a[i].w != b[i].w ||
          a[i].h != b[i].h) {
        return false;
      }
    }
    return true;
  }

  /// Roll the last action back and confirm with a calm toast.
  void undo() {
    if (_undoStack.isEmpty) return;
    final entry = _undoStack.removeLast();
    state = AsyncData(entry.layout);
    ref.read(launcherSettingsProvider.notifier).patch(entry.settings);
    ref.read(toastProvider.notifier).show('Moved back one step');
  }

  bool get canUndo => _undoStack.isNotEmpty;

  /// Place a widget from the picker. One of each local kind — the picker
  /// already explains that honestly, this is the guard. Hosted widgets
  /// are not limited: a home can carry as many real widgets as fit.
  bool placeWidget(WidgetKind kind, {required int page, int? index}) {
    final current = state.value;
    if (current == null) return false;
    if (kind != WidgetKind.androidHosted &&
        current.widgets.any((w) => w.kind == kind)) {
      return false;
    }

    final settings = ref.read(launcherSettingsProvider);
    final snap = snapshot();
    final widget = PlacedWidget(
      id: 'widget-${kind.name}-${DateTime.now().microsecondsSinceEpoch}',
      kind: kind,
      page: page,
      w: _defaultW(kind, settings),
      h: _defaultH(kind, settings),
    );
    final pageWidgets = [...current.widgets.where((w) => w.page == page)];
    final others = current.widgets.where((w) => w.page != page).toList();
    final insertAt = (index == null || index > pageWidgets.length)
        ? pageWidgets.length
        : index.clamp(0, pageWidgets.length);
    pageWidgets.insert(insertAt, widget);

    state = AsyncData(current.copyWith(widgets: [...pageWidgets, ...others]));
    commitAction(snap);
    return true;
  }

  /// Remove a placed widget (edit mode long-press menu / picker swap).
  /// Hosted Android widgets also release their AppWidgetHost id.
  void removeWidget(String id, {String? message}) {
    final current = state.value;
    if (current == null) return;
    final victim = current.widgets.where((w) => w.id == id).firstOrNull;
    if (victim == null) return;
    final snap = snapshot();
    state = AsyncData(
      current.copyWith(
        widgets: current.widgets.where((w) => w.id != id).toList(),
      ),
    );
    if (victim.kind == WidgetKind.androidHosted) {
      _forgetHosted(victim);
      final appWidgetId = victim.appWidgetId;
      if (appWidgetId != null) {
        ref.read(deviceBridgeProvider).deleteHostedWidget(appWidgetId);
      }
    }
    commitAction(snap, message: message ?? 'Widget removed');
  }

  // -----------------------------------------------------------------------
  // v0.11 — real Android widgets (AppWidgetHost)
  // -----------------------------------------------------------------------

  /// Place a freshly bound real widget at the top of [page]'s stack.
  bool placeHostedWidget({
    required int page,
    int? index,
    required String providerId,
    required String label,
    required String packageName,
    required int appWidgetId,
  }) {
    final current = state.value;
    if (current == null) return false;
    final snap = snapshot();
    final widget = PlacedWidget(
      id: 'hosted-$appWidgetId',
      kind: WidgetKind.androidHosted,
      page: page,
      w: 4,
      h: 2,
      providerId: providerId,
      appWidgetId: appWidgetId,
      label: label,
      packageName: packageName,
    );
    final pageWidgets = [...current.widgets.where((w) => w.page == page)];
    final others = current.widgets.where((w) => w.page != page).toList();
    final insertAt = (index == null || index > pageWidgets.length)
        ? pageWidgets.length
        : index.clamp(0, pageWidgets.length);
    pageWidgets.insert(insertAt, widget);

    final next = current.copyWith(widgets: [...pageWidgets, ...others]);
    state = AsyncData(next);
    _persistHosted(next);
    commitAction(snap);
    return true;
  }

  /// Live resize — the clock re-renders at every size (screen 7). Spans
  /// clamp to the proposal's 2×1 … 4×4; non-clock kinds are fixed-size and
  /// never reach here.
  void resizeWidget(String id, {required int w, required int h}) {
    final current = state.value;
    if (current == null) return;
    final clampedW = w.clamp(2, 4);
    final clampedH = h.clamp(1, 4);

    state = AsyncData(
      current.copyWith(
        widgets: [
          for (final widget in current.widgets)
            if (widget.id == id)
              widget.copyWith(w: clampedW, h: clampedH)
            else
              widget,
        ],
      ),
    );
    // The clock's span is the persisted source of truth.
    ref
        .read(launcherSettingsProvider.notifier)
        .setClockSpan(w: clampedW, h: clampedH);
  }

  /// Reorder within a page's widget stack (drag body up/down in edit mode).
  void moveWidget(String id, {required int newIndex}) {
    final current = state.value;
    if (current == null) return;
    final widget = current.widgets.where((w) => w.id == id).firstOrNull;
    if (widget == null) return;

    final pageWidgets = current.widgets
        .where((w) => w.page == widget.page)
        .toList();
    final from = pageWidgets.indexWhere((w) => w.id == id);
    var to = newIndex.clamp(0, pageWidgets.length - 1);
    if (from == to) return;

    pageWidgets.removeAt(from);
    // Account for the removal shift.
    if (from < to) to--;
    pageWidgets.insert(to, widget);

    final others = current.widgets.where((w) => w.page != widget.page).toList();
    // Rebuild the full list preserving cross-page order.
    final rebuilt = <PlacedWidget>[];
    var pi = 0;
    for (final w in current.widgets) {
      if (w.page != widget.page) {
        rebuilt.add(others[pi++]);
      } else {
        rebuilt.add(pageWidgets.removeAt(0));
      }
    }
    final next = current.copyWith(widgets: rebuilt);
    state = AsyncData(next);
    _persistHosted(next);
  }

  // -- hosted persistence ---------------------------------------------------

  Map<String, Object?> _hostedToJson(PlacedWidget w) => {
    'id': w.id,
    'providerId': w.providerId,
    'appWidgetId': w.appWidgetId,
    'label': w.label,
    'packageName': w.packageName,
    'page': w.page,
    'w': w.w,
    'h': w.h,
  };

  Future<void> _persistHosted(HomeLayout layout) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hosted = layout.widgets
          .where((w) => w.kind == WidgetKind.androidHosted)
          .map(_hostedToJson)
          .toList();
      await prefs.setString(_kHostedWidgetsKey, jsonEncode(hosted));
    } catch (_) {
      // Best-effort; the OS keeps the binding either way.
    }
  }

  Future<List<PlacedWidget>> _restoreHosted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kHostedWidgetsKey);
      if (raw == null || raw.isEmpty) return const [];
      final list = (jsonDecode(raw) as List<dynamic>).cast<Map<dynamic, dynamic>>();
      return [
        for (final item in list)
          if (item['appWidgetId'] != null && item['providerId'] != null)
            PlacedWidget(
              id: item['id'] as String? ?? 'hosted-${item['appWidgetId']}',
              kind: WidgetKind.androidHosted,
              page: (item['page'] as num?)?.toInt() ?? 0,
              w: ((item['w'] as num?)?.toInt() ?? 4).clamp(2, 4),
              h: ((item['h'] as num?)?.toInt() ?? 2).clamp(1, 4),
              providerId: item['providerId'] as String?,
              appWidgetId: (item['appWidgetId'] as num?)?.toInt(),
              label: item['label'] as String?,
              packageName: item['packageName'] as String?,
            ),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _forgetHosted(PlacedWidget victim) async {
    final current = state.value;
    if (current == null) return;
    await _persistHosted(
      current.copyWith(
        widgets: current.widgets.where((w) => w.id != victim.id).toList(),
      ),
    );
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
class ToastEvent {
  const ToastEvent(this.message, {this.undoable = false});

  final String message;

  /// True when the toast should carry an Undo pill (edit-mode actions).
  final bool undoable;
}

class ToastController extends Notifier<ToastEvent?> {
  @override
  ToastEvent? build() => null;

  void show(String message) => state = ToastEvent(message);

  /// Edit-mode actions end with an undoable toast ("per-action undo").
  void showUndoable(String message) =>
      state = ToastEvent(message, undoable: true);

  void consume() => state = null;
}

final NotifierProvider<ToastController, ToastEvent?> toastProvider =
    NotifierProvider<ToastController, ToastEvent?>(ToastController.new);

/// Edit mode (screen 7) — grid skeleton, selection handles, honest
/// snapping. Entered from the context menu, the pinch gesture or the
/// picker's pick-to-place flow; left via the Done pill or back.
class EditModeController extends Notifier<bool> {
  @override
  bool build() => false;

  void enter() => state = true;

  void exit() {
    ref.read(selectedWidgetIdProvider.notifier).clear();
    ref.read(placementProvider.notifier).cancel();
    state = false;
  }

  void toggle() => state ? exit() : enter();
}

final NotifierProvider<EditModeController, bool> editModeProvider =
    NotifierProvider<EditModeController, bool>(EditModeController.new);

/// The widget currently wearing the dashed selection outline.
class SelectedWidgetController extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String id) => state = id;
  void clear() => state = null;
}

final NotifierProvider<SelectedWidgetController, String?>
selectedWidgetIdProvider = NotifierProvider<SelectedWidgetController, String?>(
  SelectedWidgetController.new,
);

/// Pick-to-place: set while the freshly picked widget rides the finger;
/// cleared on drop or cancel.
class PlacementController extends Notifier<WidgetKind?> {
  @override
  WidgetKind? build() => null;

  void begin(WidgetKind kind) => state = kind;
  void cancel() => state = null;
}

final NotifierProvider<PlacementController, WidgetKind?> placementProvider =
    NotifierProvider<PlacementController, WidgetKind?>(PlacementController.new);
