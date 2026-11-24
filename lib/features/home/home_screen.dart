/// Home screen — sketchbook skins (Light / Dark / AMOLED).
///
/// Layout top→bottom: hero zone → memories card → paged app grid →
/// page dots → dock. Stage 2 layers: swipe up (or the dock chevron) opens
/// the A–Z drawer, folder tiles open their shared-axis card, long-presses
/// raise the context menu — "always with an escape, never with a surprise".
library;

import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/models.dart';
import '../../core/settings/launcher_settings.dart';
import '../../core/theme/toad_theme.dart';
import '../../core/theme/toad_tokens.dart';
import '../../shared/widgets/toad_toast.dart';
import '../../shared/widgets/wallpaper_glow.dart';
import '../context_menu/app_context_menu.dart';
import '../drawer/app_drawer.dart'
    show AppDrawer, drawerMenuBridgeProvider;
import '../folder/folder_overlay.dart'
    show
        FolderOverlay,
        OpenFolderRequest,
        openFolderProvider,
        openFolderMenuProvider;
import 'home_controller.dart';
import 'widgets/app_grid.dart';
import 'widgets/dock_bar.dart';
import 'widgets/hero_zone.dart';
import 'widgets/memories_card.dart';

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
      ref.read(drawerOpenProvider) || ref.read(openFolderProvider) != null;

  void _dismissMenu() {
    ref.read(drawerMenuBridgeProvider.notifier).consume();
    ref.read(openFolderMenuProvider.notifier).consume();
    if (_menu != null) setState(() => _menu = null);
  }

  void _closeTopOverlay() {
    if (_menu != null) {
      _dismissMenu();
    } else if (ref.read(openFolderProvider) != null) {
      ref.read(openFolderProvider.notifier).close();
    } else if (ref.read(drawerOpenProvider)) {
      ref.read(drawerOpenProvider.notifier).close();
    }
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
    ref.read(openFolderProvider.notifier).open(
          OpenFolderRequest(folder: folder, originRect: iconRect),
        );
  }

  void _openFolderAtAnchor(FolderData folder, Offset anchor,
      {bool startInRename = false}) {
    ref.read(openFolderProvider.notifier).open(
          OpenFolderRequest(
            folder: folder,
            originRect:
                Rect.fromCircle(center: anchor, radius: ToadRadii.iconTile),
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
      onWidgets: () {
        _dismissMenu();
        _toast('Widget picker arrives in stage 3');
      },
      onShare: () {
        _dismissMenu();
        _toast('Share is a device feature — demo stays offline');
      },
      onUninstall: () {
        _dismissMenu();
        _toast('Uninstall needs a real device — demo keeps everything');
      },
      onEditHome: variant == MenuContext.homeApp
          ? () {
              _dismissMenu();
              _toast('Edit mode arrives in stage 3');
            }
          : null,
      onRemove: variant == MenuContext.homeApp ||
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
      onWallpaper: () {
        _dismissMenu();
        _toast('Wallpaper & style arrive in stage 3');
      },
      onHomeSettings: () {
        _dismissMenu();
        _toast('Home settings arrive in stage 3');
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final skin = ToadTheme.of(context);
    final settings = ref.watch(launcherSettingsProvider);
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final layoutAsync = ref.watch(homeLayoutProvider);

    final drawerOpen = ref.watch(drawerOpenProvider);
    final folderRequest = ref.watch(openFolderProvider);
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

    final hero = buildHeroData(now, pond: false, pondNight: false);

    ref.listen<String?>(toastProvider, (prev, message) {
      if (message == null || message == prev) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(toadToast(context, message));
      ref.read(toastProvider.notifier).consume();
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_menu != null ||
            folderRequest != null ||
            ref.read(drawerOpenProvider)) {
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
          backgroundColor: skin.palette.paper,
          body: Stack(
            children: [
              // ---- Base home ----
              WallpaperGlow(
                child: GestureDetector(
                  // "Swipe up anywhere on the home opens the drawer."
                  onVerticalDragEnd: (details) {
                    final v = details.primaryVelocity ?? 0;
                    if (settings.swipeUpDrawer && v < -320 && !_overlayBusy) {
                      ref.read(drawerOpenProvider.notifier).open();
                    }
                  },
                  // Long-press on empty space → the smaller menu.
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
                        HeroZone(data: hero),
                        if (settings.showMemoriesCard)
                          layoutAsync.maybeWhen(
                            data: (layout) => MemoriesCard(
                              data: layout.memory,
                              onOpen: () => _launch(
                                layout.allApps.firstWhere(
                                  (a) => a.id == 'family.toad.gallery',
                                  orElse: () => layout.allApps.first,
                                ),
                              ),
                            ),
                            orElse: () => const SizedBox(
                              height: 118,
                              width: double.infinity,
                            ),
                          ),
                        Expanded(
                          child: layoutAsync.maybeWhen(
                            data: (layout) {
                              if (_pageCount != layout.pages.length) {
                                _pageCount = layout.pages.length;
                              }
                              return AppGridPageView(
                                pages: layout.pages,
                                controller: _pageController,
                                columns: settings.gridColumns,
                                iconShape: settings.iconShape,
                                onAppTap: _launch,
                                onAppLongPress: (app, anchor) => _showMenu(
                                  MenuContext.homeApp,
                                  anchor: anchor,
                                  app: app,
                                ),
                                onFolderTap: _openFolder,
                                onFolderLongPress: (folder, anchor) =>
                                    _showMenu(
                                  MenuContext.folderTile,
                                  anchor: anchor,
                                  folder: folder,
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
                        layoutAsync.maybeWhen(
                          data: (layout) => DockBar(
                            apps: layout.dock,
                            iconShape: settings.iconShape,
                            onAppTap: _launch,
                            onDrawerTap: () =>
                                ref.read(drawerOpenProvider.notifier).open(),
                            onAppLongPress: (app) {
                              final box = context.findRenderObject()!
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
                          orElse: () => const SizedBox(height: 84),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ---- Folder (screen 5) ----
              if (folderRequest != null)
                FolderOverlay(
                  folder: layout?.folderById(folderRequest.folder.id) ??
                      folderRequest.folder,
                  originRect: folderRequest.originRect,
                  startInRename: folderRequest.startInRename,
                ),

              // ---- Drawer (screen 4) ----
              if (drawerOpen) const AppDrawer(),

              // ---- Context menu (screen 6) — topmost ----
              if (_menu != null)
                ContextMenuLayer(
                  request: _menu!,
                  onDismissed: _dismissMenu,
                )
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

