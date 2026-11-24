/// Home screen — sketchbook skins (Light / Dark / AMOLED).
///
/// Layout per page: widget zone (Caveat clock + friends) → app grid →
/// page dots → dock. Stage 3: edit mode (grid skeleton, dashed selection,
/// resize handles, undoable actions), the widget picker with pick-to-place,
/// the wallpaper underlay, and the full gesture map — swipe up (drawer),
/// swipe down (shade demo), pinch (edit), double-tap (sleep demo),
/// dock-area swipe (search).
library;

import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/models.dart';
import '../../core/settings/launcher_settings.dart';
import '../../core/theme/toad_theme.dart';
import '../../core/theme/toad_tokens.dart';
import '../../shared/widgets/placed_widgets.dart' show widgetZoneHeight;
import '../../shared/widgets/sketchbook_wallpaper.dart';
import '../../shared/widgets/toad_toast.dart';
import '../../shared/widgets/wallpaper_glow.dart';
import '../context_menu/app_context_menu.dart';
import '../drawer/app_drawer.dart' show AppDrawer, drawerMenuBridgeProvider;
import '../edit/edit_mode.dart'
    show EditBottomStrip, EditHintBubble, GridSkeletonPainter, WidgetZone;
import '../folder/folder_overlay.dart'
    show
        FolderOverlay,
        OpenFolderRequest,
        openFolderProvider,
        openFolderMenuProvider;
import '../settings/settings_hub.dart' show openSettingsHub;
import '../wallpaper_style/wallpaper_style_screen.dart'
    show WallpaperStyleScreen;
import '../widget_picker/widget_picker_sheet.dart'
    show PlacementGhost, showWidgetPicker;
import 'home_controller.dart';
import 'widgets/app_grid.dart';
import 'widgets/dock_bar.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final PageController _pageController;
  int _pageCount = 3;

  /// Menu raised from the grid / dock / empty space (local to this host).
  MenuRequest? _menu;

  /// Dock-area swipe opens the drawer with search focused.
  bool _drawerWithSearch = false;

  /// Pinch tracking via raw pointers — the scale recognizer loses the
  /// arena to the page's horizontal drag, so pinch is measured directly
  /// (distance between the two pointers shrinking past 25%).
  final Map<int, Offset> _pointerPositions = {};
  double? _pinchStartDistance;
  bool _pinchFired = false;

  /// Two-finger screenshot detection (opt-in switch).
  final Set<int> _activePointers = {};
  bool _twoFingerFired = false;

  /// Page-area key — converts placement drops into stack slots.
  final GlobalKey _pageAreaKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(() {
      final page = _pageController.page?.round() ?? 0;
      if (ref.read(currentPageProvider) != page) {
        ref.read(currentPageProvider.notifier).set(page);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _launch(AppEntry app) {
    ref.read(homeLayoutProvider.notifier).launch(app);
  }

  void _toast(String message) {
    ref.read(toastProvider.notifier).show(message);
  }

  bool get _overlayBusy =>
      ref.read(editModeProvider) ||
      ref.read(drawerOpenProvider) ||
      ref.read(openFolderProvider) != null;

  void _dismissMenu() {
    ref.read(drawerMenuBridgeProvider.notifier).consume();
    ref.read(openFolderMenuProvider.notifier).consume();
    if (_menu != null) setState(() => _menu = null);
  }

  void _closeTopOverlay() {
    if (ref.read(placementProvider) != null) {
      ref.read(placementProvider.notifier).cancel();
    } else if (_menu != null) {
      _dismissMenu();
    } else if (ref.read(openFolderProvider) != null) {
      ref.read(openFolderProvider.notifier).close();
    } else if (ref.read(drawerOpenProvider)) {
      ref.read(drawerOpenProvider.notifier).close();
    } else if (ref.read(editModeProvider)) {
      ref.read(editModeProvider.notifier).exit();
    }
  }

  void _openDrawer({bool withSearch = false}) {
    setState(() => _drawerWithSearch = withSearch);
    ref.read(drawerOpenProvider.notifier).open();
  }

  void _enterEdit() {
    _dismissMenu();
    ref.read(editModeProvider.notifier).enter();
  }

  void _openWallpaperStyle() {
    _dismissMenu();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const WallpaperStyleScreen()),
    );
  }

  void _openSettings() {
    _dismissMenu();
    openSettingsHub(context);
  }

  void _openWidgets() {
    _dismissMenu();
    showWidgetPicker(context);
  }

  /// Gesture map: "Tap — clock area of hero — open Clock app".
  void _openClockApp() {
    final layout = ref.read(homeLayoutProvider).valueOrNull;
    final clock = layout?.allApps.where((a) => a.id == 'clock').firstOrNull;
    if (clock != null) _launch(clock);
  }

  /// Locate a cell by id across the pages (folders included).
  (int, int)? _locateCell(String id) {
    final layout = ref.read(homeLayoutProvider).valueOrNull;
    if (layout == null) return null;
    for (var p = 0; p < layout.pages.length; p++) {
      for (var c = 0; c < layout.pages[p].length; c++) {
        final cell = layout.pages[p][c];
        final cellId = switch (cell) {
          AppCell() => cell.app.id,
          FolderCell() => cell.folder.id,
        };
        if (cellId == id) return (p, c);
      }
    }
    return null;
  }

  void _openFolder(FolderData folder, Rect iconRect) {
    ref
        .read(openFolderProvider.notifier)
        .open(OpenFolderRequest(folder: folder, originRect: iconRect));
  }

  void _openFolderAtAnchor(
    FolderData folder,
    Offset anchor, {
    bool startInRename = false,
  }) {
    ref
        .read(openFolderProvider.notifier)
        .open(
          OpenFolderRequest(
            folder: folder,
            originRect: Rect.fromCircle(
              center: anchor,
              radius: ToadRadii.iconTile,
            ),
            startInRename: startInRename,
          ),
        );
  }

  void _showMenu(
    MenuContext variant, {
    Offset? anchor,
    AppEntry? app,
    FolderData? folder,
    String? folderId,
  }) {
    final size = MediaQuery.sizeOf(context);
    final effectiveAnchor =
        anchor ?? Offset(size.width / 2, size.height * 0.82); // dock rows
    setState(() {
      _menu = MenuRequest(
        context: variant,
        anchor: effectiveAnchor,
        app: app,
        folder: folder,
        actions: _actionsFor(
          variant,
          app: app,
          folder: folder,
          folderId: folderId,
        ),
      );
    });
  }

  MenuActions _actionsFor(
    MenuContext variant, {
    AppEntry? app,
    FolderData? folder,
    String? folderId,
  }) {
    final notifier = ref.read(homeLayoutProvider.notifier);

    void removeFromPage() {
      final appId = app?.id ?? folder?.id;
      if (appId == null) return;
      final location = _locateCell(appId);
      if (location == null) return;
      notifier.removePageCell(location.$1, location.$2);
      _toast(
        folder != null
            ? 'Removed "${folder.title}" from this page'
            : 'Removed "${app!.name}" from this page',
      );
    }

    return MenuActions(
      onAppInfo: () {
        _dismissMenu();
        _toast('App info is a device feature — demo stays offline');
      },
      onWidgets: _openWidgets,
      onShare: () {
        _dismissMenu();
        _toast('Share is a device feature — demo stays offline');
      },
      onUninstall: () {
        _dismissMenu();
        _toast('Uninstall needs a real device — demo keeps everything');
      },
      onEditHome:
          variant == MenuContext.homeApp || variant == MenuContext.dockApp
          ? _enterEdit
          : null,
      onRemove:
          variant == MenuContext.homeApp ||
              variant == MenuContext.dockApp ||
              variant == MenuContext.folderTile ||
              variant == MenuContext.folderApp
          ? () {
              if (variant == MenuContext.dockApp && app != null) {
                notifier.removeFromDock(app.id);
                _toast('Removed "${app.name}" from the dock');
              } else if (variant == MenuContext.folderApp && app != null) {
                final id = folderId ?? folder?.id;
                if (id != null) notifier.removeAppFromFolder(id, app.id);
                _toast('Removed "${app.name}" from the folder');
              } else {
                removeFromPage();
              }
              _dismissMenu();
            }
          : null,
      onRename: variant == MenuContext.folderTile && folder != null
          ? () {
              final anchor = _menu?.anchor;
              setState(() => _menu = null);
              if (anchor != null) {
                _openFolderAtAnchor(folder, anchor, startInRename: true);
              }
            }
          : null,
      onOpen: variant == MenuContext.folderTile && folder != null
          ? () {
              final anchor = _menu?.anchor;
              setState(() => _menu = null);
              if (anchor != null) _openFolderAtAnchor(folder, anchor);
            }
          : null,
      onWallpaper: _openWallpaperStyle,
      onHomeSettings: _openSettings,
    );
  }

  // ---------------------------------------------------------------------------
  // Gesture map (screen 11)
  // ---------------------------------------------------------------------------

  void _onScaleEnd(ScaleEndDetails details) {
    if (_overlayBusy) return;

    final settings = ref.read(launcherSettingsProvider);
    final v = details.velocity.pixelsPerSecond;
    final vertical = v.dy.abs() > v.dx.abs();
    if (!vertical) return;

    if (v.dy < -320) {
      // Swipe up → drawer.
      if (settings.swipeUpDrawer) _openDrawer();
    } else if (v.dy > 320) {
      // Swipe down → pull the notification shade (demo stays honest).
      if (settings.swipeDownNotifications) {
        _toast(
          'The notification shade is a system surface — the demo '
          'stays inside',
        );
      }
    }
  }

  /// Opt-in double-tap sleep — honest in demo: no write-settings here.
  void _onDoubleTap() {
    if (_overlayBusy) return;
    final settings = ref.read(launcherSettingsProvider);
    if (settings.doubleTapSleep) {
      _toast(
        'Double-tap sleep needs the write-settings permission — '
        'the demo keeps the paper lit',
      );
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    _activePointers.add(event.pointer);
    _pointerPositions[event.pointer] = event.position;

    if (_activePointers.length == 2 && !_twoFingerFired) {
      final settings = ref.read(launcherSettingsProvider);
      if (settings.twoFingerScreenshot && !_overlayBusy) {
        _twoFingerFired = true;
        _toast(
          'Two-finger screenshot needs a real device — the demo keeps '
          'your pixels',
        );
      }
    }
    if (_activePointers.length == 2) {
      final pts = _pointerPositions.values.toList();
      _pinchStartDistance = (pts[0] - pts[1]).distance;
      _pinchFired = false;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_pointerPositions.containsKey(event.pointer)) return;
    _pointerPositions[event.pointer] = event.position;

    // Pinch in → edit mode: the two-pointer distance shrinks past 25%.
    if (_activePointers.length >= 2 &&
        !_pinchFired &&
        _pinchStartDistance != null &&
        _pinchStartDistance! > 0) {
      final pts = _pointerPositions.values.toList();
      final d = (pts[0] - pts[1]).distance;
      if (d < _pinchStartDistance! * 0.75) {
        _pinchFired = true;
        final settings = ref.read(launcherSettingsProvider);
        if (settings.pinchEditMode && !_overlayBusy) _enterEdit();
      }
    }
  }

  void _onPointerUp(PointerEvent event) {
    _activePointers.remove(event.pointer);
    _pointerPositions.remove(event.pointer);
    if (_activePointers.length < 2) {
      _pinchStartDistance = null;
      _pinchFired = false;
    }
    if (_activePointers.isEmpty) _twoFingerFired = false;
  }

  // ---------------------------------------------------------------------------
  // Pick-to-place
  // ---------------------------------------------------------------------------

  void _placeDropped(DragTargetDetails<WidgetKind> details) {
    final box = _pageAreaKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(details.offset);
    final kind = details.data;

    final page = ref.read(currentPageProvider);
    final layout = ref.read(homeLayoutProvider).valueOrNull;

    // Snap to the nearest stack slot (honest: no invisible offsets).
    var index = 0;
    var acc = 0.0;
    for (final w in layout?.widgetsOnPage(page) ?? const <PlacedWidget>[]) {
      final h = widgetZoneHeight(w.h);
      if (local.dy > acc + h / 2) {
        index++;
        acc += h + 8;
      } else {
        break;
      }
    }

    final placed = ref
        .read(homeLayoutProvider.notifier)
        .placeWidget(kind, page: page, index: index);
    ref.read(placementProvider.notifier).cancel();
    if (placed) {
      ref
          .read(toastProvider.notifier)
          .showUndoable('Placed on page ${page + 1} — drag its body to move');
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final skin = ToadTheme.of(context);
    final palette = skin.palette;
    final settings = ref.watch(launcherSettingsProvider);
    final layoutAsync = ref.watch(homeLayoutProvider);

    final drawerOpen = ref.watch(drawerOpenProvider);
    final folderRequest = ref.watch(openFolderProvider);
    final editMode = ref.watch(editModeProvider);
    final drawerMenu = ref.watch(drawerMenuBridgeProvider);
    final folderMenu = ref.watch(openFolderMenuProvider);

    final layout = layoutAsync.valueOrNull;

    // Menu raised from inside an overlay (drawer rows, folder grid).
    MenuRequest? bridgeMenu;
    if (drawerMenu != null) {
      bridgeMenu = MenuRequest(
        context: MenuContext.drawerApp,
        anchor: drawerMenu.anchor,
        app: drawerMenu.app,
        actions: _actionsFor(MenuContext.drawerApp, app: drawerMenu.app),
      );
    } else if (folderMenu != null) {
      final hostFolder = layout?.folders
          .where((f) => f.apps.any((a) => a.id == folderMenu.app.id))
          .firstOrNull;
      bridgeMenu = MenuRequest(
        context: MenuContext.folderApp,
        anchor: folderMenu.anchor,
        app: folderMenu.app,
        folder: hostFolder,
        actions: _actionsFor(
          MenuContext.folderApp,
          app: folderMenu.app,
          folderId: hostFolder?.id,
        ),
      );
    }

    ref.listen<ToastEvent?>(toastProvider, (prev, event) {
      if (event == null || identical(event, prev)) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          toadToast(
            context,
            event,
            onUndo: () => ref.read(homeLayoutProvider.notifier).undo(),
          ),
        );
      ref.read(toastProvider.notifier).consume();
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (ref.read(placementProvider) != null ||
            _menu != null ||
            folderRequest != null ||
            ref.read(drawerOpenProvider) ||
            editMode) {
          _closeTopOverlay();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: skin.palette.statusIconBrightness,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: skin.palette.statusIconBrightness,
        ),
        child: Scaffold(
          backgroundColor: palette.paper,
          body: Stack(
            children: [
              // ---- Base home ----
              WallpaperIndexScope(
                index: settings.wallpaperIndex,
                child: SketchbookWallpaper(
                  child: WallpaperGlow(
                    child: Listener(
                      onPointerDown: _onPointerDown,
                      onPointerMove: _onPointerMove,
                      onPointerUp: _onPointerUp,
                      onPointerCancel: _onPointerUp,
                      child: GestureDetector(
                        // Vertical flings (drawer / shade); pinch is
                        // raw-pointer based; long-press on empty space
                        // raises the smaller menu.
                        onScaleEnd: _onScaleEnd,
                        onDoubleTap: _onDoubleTap,
                        onLongPressStart: _overlayBusy
                            ? null
                            : (details) => _showMenu(
                                MenuContext.emptySpace,
                                anchor: details.globalPosition,
                              ),
                        child: SafeArea(
                          bottom: false,
                          child: Column(
                            children: [
                              Expanded(
                                child: layoutAsync.maybeWhen(
                                  data: (layout) {
                                    if (_pageCount != layout.pages.length) {
                                      _pageCount = layout.pages.length;
                                    }
                                    // Edit mode paints the honest grid
                                    // skeleton over the page area.
                                    return CustomPaint(
                                      key: _pageAreaKey,
                                      foregroundPainter: editMode
                                          ? GridSkeletonPainter(
                                              color: palette.ink,
                                            )
                                          : null,
                                      child: DragTarget<WidgetKind>(
                                        onWillAcceptWithDetails: (details) =>
                                            editMode,
                                        onAcceptWithDetails: (details) =>
                                            _placeDropped(details),
                                        builder: (context, _, _) =>
                                            AppGridPageView(
                                              pages: layout.pages,
                                              controller: _pageController,
                                              columns: settings.gridColumns,
                                              iconShape: settings.iconShape,
                                              onAppTap: _launch,
                                              onAppLongPress: (app, anchor) =>
                                                  _showMenu(
                                                    MenuContext.homeApp,
                                                    anchor: anchor,
                                                    app: app,
                                                  ),
                                              onFolderTap: _openFolder,
                                              onFolderLongPress:
                                                  (folder, anchor) => _showMenu(
                                                    MenuContext.folderTile,
                                                    anchor: anchor,
                                                    folder: folder,
                                                  ),
                                              buildPageHeader: (pageIndex) =>
                                                  WidgetZone(
                                                    pageIndex: pageIndex,
                                                    memory: layout.memory,
                                                    onClockTap: _openClockApp,
                                                  ),
                                            ),
                                      ),
                                    );
                                  },
                                  orElse: () => const SizedBox.shrink(),
                                ),
                              ),
                              PageDots(
                                count: _pageCount,
                                activeIndex: ref.watch(currentPageProvider),
                              ),
                              if (editMode) const EditHintBubble(),
                              layoutAsync.maybeWhen(
                                data: (layout) => editMode
                                    ? EditBottomStrip(
                                        onWallpapers: _openWallpaperStyle,
                                        onWidgets: _openWidgets,
                                        onSettings: _openSettings,
                                        onDone: () => ref
                                            .read(editModeProvider.notifier)
                                            .exit(),
                                      )
                                    : DockBar(
                                        apps: layout.dock,
                                        iconShape: settings.iconShape,
                                        onAppTap: _launch,
                                        onDrawerTap: () => _openDrawer(),
                                        onSwipeDown: () {
                                          final s = ref.read(
                                            launcherSettingsProvider,
                                          );
                                          if (s.dockAreaSwipeSearch &&
                                              !_overlayBusy) {
                                            _openDrawer(withSearch: true);
                                          }
                                        },
                                        onAppLongPress: (app) {
                                          final box =
                                              context.findRenderObject()!
                                                  as RenderBox;
                                          final dockCenter = Offset(
                                            box.size.width / 2,
                                            box.size.height - 42,
                                          );
                                          _showMenu(
                                            MenuContext.dockApp,
                                            anchor: dockCenter,
                                            app: app,
                                          );
                                        },
                                      ),
                                orElse: () =>
                                    SizedBox(height: editMode ? 78 : 84),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ---- Folder (screen 5) ----
              if (folderRequest != null)
                FolderOverlay(
                  folder:
                      layout?.folderById(folderRequest.folder.id) ??
                      folderRequest.folder,
                  originRect: folderRequest.originRect,
                  startInRename: folderRequest.startInRename,
                ),

              // ---- Drawer (screen 4) ----
              if (drawerOpen) AppDrawer(startWithSearch: _drawerWithSearch),

              // ---- Pick-to-place ghost (screen 8) ----
              const PlacementGhost(),

              // ---- Context menu (screen 6) — topmost ----
              if (_menu != null)
                ContextMenuLayer(request: _menu!, onDismissed: _dismissMenu)
              else if (bridgeMenu != null)
                ContextMenuLayer(
                  request: bridgeMenu,
                  onDismissed: _dismissMenu,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
