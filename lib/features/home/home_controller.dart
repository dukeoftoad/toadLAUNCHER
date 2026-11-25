library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/device/device_bridge.dart';
import '../../core/reliability/safe_store.dart';
import '../../core/repositories/app_repository.dart';
import '../../core/repositories/device_app_repository.dart';
import '../../core/settings/launcher_settings.dart';
import 'grid_flow.dart' show resolveDropAnchor;

const String _kHostedWidgetsKey = 'toadlauncher.hosted.widgets.v1';
final SafeStore _kHostedStore = SafeStore(
  _kHostedWidgetsKey,
  schemaVersion: 2,
);

final AsyncNotifierProvider<HomeController, HomeLayout> homeLayoutProvider =
    AsyncNotifierProvider<HomeController, HomeLayout>(HomeController.new);

class HomeController extends AsyncNotifier<HomeLayout> {
  final List<({HomeLayout layout, LauncherSettings settings})> _undoStack = [];

  bool _refreshing = false;

  @override
  Future<HomeLayout> build() async {
    final repo = ref.watch(appRepositoryProvider);
    final settings = ref.read(launcherSettingsProvider);

    HomeLayout layout;
    if (repo is DeviceAppRepository) {
      ref.read(deviceIconsProvider.notifier).state = Map<String, Uint8List>.of(
        repo.iconBytes,
      );
      ref
          .read(deviceIconsMonoProvider.notifier)
          .state = Map<String, Uint8List>.of(repo.iconMonoBytes);
      layout =
          await repo.loadFromSnapshot() ?? await repo.loadHomeLayout();
      unawaited(_refreshFromBridge(repo));
    } else {
      layout = await repo.loadHomeLayout();
    }

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

    var hosted = await _restoreHosted();

    if (hosted.isNotEmpty && repo is DeviceAppRepository) {
      hosted = await _cleanupHostOrphans(layout, hosted);
    }

    if (seeded.isEmpty) {
      return layout.copyWith(widgets: [...hosted, ...layout.widgets]);
    }
    return layout.copyWith(widgets: [
      ...seeded,
      ...hosted,
      ...layout.widgets,
    ]);
  }

  /// PERF-01: after the snapshot fast path rendered home, quietly re-index
  /// from PackageManager and re-persist the snapshot. Failures keep the
  /// snapshot on screen; the device banner surfaces bridge problems.
  Future<void> _refreshFromBridge(DeviceAppRepository repo) async {
    if (_refreshing || !ref.read(launcherSettingsProvider).deviceMode) return;
    _refreshing = true;
    try {
      final fresh = await repo.loadHomeLayout();
      ref.read(deviceIconsProvider.notifier).state = Map<String, Uint8List>.of(
        repo.iconBytes,
      );
      ref
          .read(deviceIconsMonoProvider.notifier)
          .state = Map<String, Uint8List>.of(repo.iconMonoBytes);
      final current = state.value;
      if (current == null) return;
      state = AsyncData(
        current.copyWith(
          pages: fresh.pages,
          dock: fresh.dock,
          recents: fresh.recents,
          allApps: fresh.allApps,
          folders: fresh.folders,
        ),
      );
    } catch (_) {
      // snapshot stays; banner reports bridge trouble
    } finally {
      _refreshing = false;
    }
  }

  /// PLT-07: reconcile placements against the widget host. Host ids we no
  /// longer have placements for are freed; placements whose ids the host
  /// lost are dropped and the survivors re-persisted.
  Future<List<PlacedWidget>> _cleanupHostOrphans(
    HomeLayout layout,
    List<PlacedWidget> hosted,
  ) async {
    try {
      final bridge = ref.read(deviceBridgeProvider);
      final hostIds = (await bridge.hostedAppWidgetIds()).toSet();
      final placedIds = hosted
          .map((w) => w.appWidgetId)
          .whereType<int>()
          .toSet();
      for (final id in hostIds.difference(placedIds)) {
        await bridge.deleteHostedWidget(id);
      }
      final survivors = [
        for (final w in hosted)
          if (w.appWidgetId == null || hostIds.contains(w.appWidgetId)) w,
      ];
      if (survivors.length != hosted.length) {
        final next = layout.copyWith(widgets: [...survivors, ...layout.widgets]);
        await _persistHosted(next);
        return survivors;
      }
      return hosted;
    } catch (_) {
      return hosted;
    }
  }

  Future<void> launch(AppEntry app) async {
    final repo = ref.read(appRepositoryProvider);
    await repo.launch(app);
    recordLaunch(app);
  }

  void recordLaunch(AppEntry app) {
    final current = state.value;
    if (current == null) return;
    final recents = <AppEntry>[
      app,
      ...current.recents.where((a) => a.id != app.id),
    ].take(4).toList();
    state = AsyncData(current.copyWith(recents: recents));
  }

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

  void removeFromDock(String appId) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(dock: current.dock.where((a) => a.id != appId).toList()),
    );
  }

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
                  ? null
                  : FolderCell(updated)
            else
              cell,
        ].whereType<HomeCell>().toList(),
    ];

    state = AsyncData(current.copyWith(pages: pages, folders: folders));
  }

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

  ({HomeLayout layout, LauncherSettings settings})? snapshot() {
    final layout = state.value;
    if (layout == null) return null;
    return (layout: layout, settings: ref.read(launcherSettingsProvider));
  }

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
          a[i].row != b[i].row ||
          a[i].col != b[i].col ||
          a[i].w != b[i].w ||
          a[i].h != b[i].h) {
        return false;
      }
    }
    return true;
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    final entry = _undoStack.removeLast();
    state = AsyncData(entry.layout);
    ref.read(launcherSettingsProvider.notifier).patch(entry.settings);
    ref.read(toastProvider.notifier).show('Moved back one step');
  }

  bool get canUndo => _undoStack.isNotEmpty;

  bool placeWidget(
    WidgetKind kind, {
    required int page,
    int? index,
    int? row,
    int? col,
  }) {
    final current = state.value;
    if (current == null) return false;
    if (kind != WidgetKind.androidHosted &&
        current.widgets.any((w) => w.kind == kind)) {
      return false;
    }

    final settings = ref.read(launcherSettingsProvider);
    final snap = snapshot();
    final w = _defaultW(kind, settings);
    final h = _defaultH(kind, settings);
    final anchor = resolveDropAnchor(
      existing: current.widgets.where((x) => x.page == page).toList(),
      row: row ?? 0,
      col: col ?? 0,
      w: w,
      h: h,
      columns: settings.gridColumns,
    );
    final widget = PlacedWidget(
      id: 'widget-${kind.name}-${DateTime.now().microsecondsSinceEpoch}',
      kind: kind,
      page: page,
      row: anchor.row,
      col: anchor.col,
      w: w,
      h: h,
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

  bool placeHostedWidget({
    required int page,
    int? index,
    int? row,
    int? col,
    required String providerId,
    required String label,
    required String packageName,
    required int appWidgetId,
    String? configureComponent,
  }) {
    final current = state.value;
    if (current == null) return false;
    final settings = ref.read(launcherSettingsProvider);
    final snap = snapshot();
    final w = 4.clamp(1, settings.gridColumns);
    final anchor = resolveDropAnchor(
      existing: current.widgets.where((x) => x.page == page).toList(),
      row: row ?? 0,
      col: col ?? 0,
      w: w,
      h: 2,
      columns: settings.gridColumns,
    );
    final widget = PlacedWidget(
      id: 'hosted-$appWidgetId',
      kind: WidgetKind.androidHosted,
      page: page,
      row: anchor.row,
      col: anchor.col,
      w: w,
      h: 2,
      providerId: providerId,
      appWidgetId: appWidgetId,
      configureComponent: configureComponent,
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
    ref
        .read(launcherSettingsProvider.notifier)
        .setClockSpan(w: clampedW, h: clampedH);
  }

  ({HomeLayout layout, LauncherSettings settings})? _resizeSnap;

  void beginWidgetGesture() => _resizeSnap = snapshot();

  void endWidgetGesture({String? message}) {
    final snap = _resizeSnap;
    _resizeSnap = null;
    if (snap != null) commitAction(snap, message: message);
  }

  /// FEAT-01: move a widget on the free-form canvas. The anchor slides down
  /// from the target like every placement, so the move never overlaps and
  /// app cells simply re-flow.
  void moveWidgetTo(
    String id, {
    required int row,
    required int col,
  }) {
    final current = state.value;
    if (current == null) return;
    final widget = current.widgets.where((w) => w.id == id).firstOrNull;
    if (widget == null) return;
    final settings = ref.read(launcherSettingsProvider);
    final w = widget.w.clamp(1, settings.gridColumns);
    final safeCol = col.clamp(0, settings.gridColumns - w);
    final safeRow = row.clamp(0, 1 << 20);
    if (widget.row == safeRow && widget.col == safeCol) return;

    final next = current.copyWith(
      widgets: [
        for (final item in current.widgets)
          if (item.id == id) item.copyWith(row: safeRow, col: safeCol) else item,
      ],
    );
    state = AsyncData(next);
    _persistHosted(next);
  }

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
    if (from < to) to--;
    pageWidgets.insert(to, widget);

    final others = current.widgets.where((w) => w.page != widget.page).toList();
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

  Map<String, Object?> _hostedToJson(PlacedWidget w) => {
    'id': w.id,
    'providerId': w.providerId,
    'appWidgetId': w.appWidgetId,
    'configure': w.configureComponent,
    'label': w.label,
    'packageName': w.packageName,
    'page': w.page,
    'row': w.row,
    'col': w.col,
    'w': w.w,
    'h': w.h,
  };

  Future<void> _persistHosted(HomeLayout layout) async {
    try {
      final hosted = layout.widgets
          .where((w) => w.kind == WidgetKind.androidHosted)
          .map(_hostedToJson)
          .toList();
      await _kHostedStore.write(hosted);
    } catch (_) {
    }
  }

  Future<List<PlacedWidget>> _restoreHosted() async {
    try {
      final list = await _kHostedStore.read<List<Object?>>(
        (json) => json is List ? json : null,
      );
      if (list == null) return const [];
      return [
        for (final item in list)
          if (item is Map &&
              item['appWidgetId'] != null &&
              item['providerId'] != null)
            PlacedWidget(
              id: item['id'] as String? ?? 'hosted-${item['appWidgetId']}',
              kind: WidgetKind.androidHosted,
              page: (item['page'] as num?)?.toInt() ?? 0,
              row: (item['row'] as num?)?.toInt(),
              col: (item['col'] as num?)?.toInt(),
              w: ((item['w'] as num?)?.toInt() ?? 4).clamp(2, 4),
              h: ((item['h'] as num?)?.toInt() ?? 2).clamp(1, 4),
              providerId: item['providerId'] as String?,
              appWidgetId: (item['appWidgetId'] as num?)?.toInt(),
              configureComponent: item['configure'] as String?,
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

class CurrentPageController extends Notifier<int> {
  @override
  int build() => 0;

  void set(int page) => state = page;
}

final NotifierProvider<CurrentPageController, int> currentPageProvider =
    NotifierProvider<CurrentPageController, int>(CurrentPageController.new);

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

class ToastEvent {
  const ToastEvent(this.message, {this.undoable = false});

  final String message;

  final bool undoable;
}

class ToastController extends Notifier<ToastEvent?> {
  @override
  ToastEvent? build() => null;

  void show(String message) => state = ToastEvent(message);

  void showUndoable(String message) =>
      state = ToastEvent(message, undoable: true);

  void consume() => state = null;
}

final NotifierProvider<ToastController, ToastEvent?> toastProvider =
    NotifierProvider<ToastController, ToastEvent?>(ToastController.new);

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

class PlacementController extends Notifier<WidgetKind?> {
  @override
  WidgetKind? build() => null;

  void begin(WidgetKind kind) => state = kind;
  void cancel() => state = null;
}

final NotifierProvider<PlacementController, WidgetKind?> placementProvider =
    NotifierProvider<PlacementController, WidgetKind?>(PlacementController.new);
