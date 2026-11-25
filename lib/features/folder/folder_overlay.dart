library;

import 'dart:ui' show ImageFilter;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/models.dart';
import '../../core/theme/toad_theme.dart';
import '../../core/theme/toad_tokens.dart';
import '../../shared/widgets/toad_app_icon.dart';
import '../drawer/app_drawer.dart' show DrawerMenuRequest;
import '../home/home_controller.dart';
import '../home/widgets/app_grid.dart' show PageDots;

class FolderOverlay extends ConsumerStatefulWidget {
  const FolderOverlay({
    super.key,
    required this.folder,
    required this.originRect,
    required this.startInRename,
  });

  final FolderData folder;
  final Rect originRect;
  final bool startInRename;

  @override
  ConsumerState<FolderOverlay> createState() => _FolderOverlayState();
}

class _FolderOverlayState extends ConsumerState<FolderOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  final PageController _pageController = PageController();
  final TextEditingController _rename = TextEditingController();
  final FocusNode _renameFocus = FocusNode();
  bool _renaming = false;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: ToadMotion.sharedAxisFolderOpen,
    )..forward();
    _renaming = widget.startInRename;
    _renameFocus.addListener(() {
      if (!_renameFocus.hasFocus && _renaming) _commitRename();
    });
  }

  @override
  void dispose() {
    _entrance.dispose();
    _pageController.dispose();
    _rename.dispose();
    _renameFocus.dispose();
    super.dispose();
  }

  void _close() {
    if (_renaming) _commitRename();
    if (!_entrance.isCompleted) return;
    _entrance.reverse().then((_) {
      if (mounted) ref.read(openFolderProvider.notifier).close();
    });
  }

  void _commitRename() {
    _renaming = false;
    ref
        .read(homeLayoutProvider.notifier)
        .renameFolder(widget.folder.id, _rename.text);
    if (mounted) setState(() {});
  }

  void _launch(AppEntry app) {
    ref.read(homeLayoutProvider.notifier).launch(app);
  }

  void _addApp() {
    ref
        .read(toastProvider.notifier)
        .show('Adding apps to folders arrives in stage 3');
  }

  @override
  Widget build(BuildContext context) {
    final skin = ToadTheme.of(context);
    final palette = skin.palette;
    final size = MediaQuery.sizeOf(context);
    final dark = skin.isDark;

    final folder =
        ref
            .watch(homeLayoutProvider)
            .valueOrNull
            ?.folderById(widget.folder.id) ??
        widget.folder;

    final cardAlpha = skin.skin == ResolvedSkin.amoled
        ? 0.97
        : (dark ? 0.96 : 0.94);
    final cardColor = palette.surface.withValues(
      alpha: palette.surface.a * cardAlpha,
    );
    final labelColor = dark ? const Color(0xFFE8E2D4) : palette.ink;

    final cells = <_FolderCellData>[
      for (final app in folder.apps) _FolderCellData.app(app),
      const _FolderCellData.addApp(),
    ];

    final pageCount = (cells.length / 9).ceil();
    final viewportRows = pageCount > 1
        ? 3
        : ((cells.length / 3).ceil()).clamp(1, 3);
    const double cellExtent = 72;
    final gridHeight =
        viewportRows * cellExtent + (viewportRows - 1) * ToadMetrics.gridRowGap;

    const double cardMargin = 18;
    final cardWidth = size.width - cardMargin * 2;
    final cardHeight =
        16 + 30 + 10 + gridHeight + 10 + 15 + 14;
    final finalRect = Rect.fromLTWH(
      cardMargin,
      (size.height - cardHeight) / 2 - 40,
      cardWidth,
      cardHeight,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
        child: AnimatedBuilder(
          animation: _entrance,
          builder: (context, _) {
            final t = CurvedAnimation(
              parent: _entrance,
              curve: Curves.easeOutCubic,
            ).value;
            final rect = Rect.lerp(widget.originRect, finalRect, t)!;
            final contentOpacity = ((t - 0.35) / 0.65).clamp(0.0, 1.0);

            return Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _close,
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                        child: const ColoredBox(color: Color(0x730C0A07)),
                      ),
                    ),
                  ),
                ),
                Positioned.fromRect(
                  rect: rect,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      ToadRadii.folder * t.clamp(0.0, 1.0),
                    ),
                    child: Opacity(
                      opacity: contentOpacity,
                      child: _FolderCard(
                        folder: folder,
                        cardColor: cardColor,
                        labelColor: labelColor,
                        cardWidth: cardWidth,
                        cardHeight: cardHeight,
                        gridHeight: gridHeight,
                        pageCount: pageCount,
                        pageController: _pageController,
                        cells: cells,
                        renaming: _renaming,
                        renameController: _rename,
                        renameFocus: _renameFocus,
                        onLaunch: _launch,
                        onAddApp: _addApp,
                        onStartRename: () {
                          _rename.text = folder.title;
                          setState(() => _renaming = true);
                          _renameFocus.requestFocus();
                        },
                        onLongPressItem: (app, anchor) => ref
                            .read(openFolderMenuProvider.notifier)
                            .raise(app: app, anchor: anchor),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

@immutable
class _FolderCellData {
  const _FolderCellData.app(this.app) : isAddSlot = false;
  const _FolderCellData.addApp() : app = null, isAddSlot = true;

  final AppEntry? app;
  final bool isAddSlot;
}

class _FolderCard extends StatelessWidget {
  const _FolderCard({
    required this.folder,
    required this.cardColor,
    required this.labelColor,
    required this.cardWidth,
    required this.cardHeight,
    required this.gridHeight,
    required this.pageCount,
    required this.pageController,
    required this.cells,
    required this.renaming,
    required this.renameController,
    required this.renameFocus,
    required this.onLaunch,
    required this.onAddApp,
    required this.onStartRename,
    required this.onLongPressItem,
  });

  final FolderData folder;
  final Color cardColor;
  final Color labelColor;
  final double cardWidth;
  final double cardHeight;
  final double gridHeight;
  final int pageCount;
  final PageController pageController;
  final List<_FolderCellData> cells;
  final bool renaming;
  final TextEditingController renameController;
  final FocusNode renameFocus;
  final void Function(AppEntry app) onLaunch;
  final VoidCallback onAddApp;
  final VoidCallback onStartRename;
  final void Function(AppEntry app, Offset anchor) onLongPressItem;

  @override
  Widget build(BuildContext context) {
    final palette = ToadTheme.of(context).palette;
    final activePage = pageController.hasClients
        ? (pageController.page?.round() ?? 0)
        : 0;

    return Container(
      width: cardWidth,
      height: cardHeight,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border.all(color: palette.hairline),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66140F05),
            offset: Offset(0, 24),
            blurRadius: 60,
            spreadRadius: -20,
          ),
        ],
      ),
      child: Column(
        children: [
          _FolderTitle(
            folder: folder,
            renaming: renaming,
            renameController: renameController,
            renameFocus: renameFocus,
            labelColor: labelColor,
            onStartRename: onStartRename,
          ),
          const SizedBox(height: 10),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) => false,
              child: PageView.builder(
                controller: pageController,
                itemCount: pageCount,
                itemBuilder: (context, page) {
                  final slice = cells.skip(page * 9).take(9).toList();
                  return GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisExtent: 72,
                          mainAxisSpacing: ToadMetrics.gridRowGap,
                          crossAxisSpacing: 12,
                        ),
                    children: [
                      for (final cell in slice)
                        _FolderGridItem(
                          cell: cell,
                          labelColor: labelColor,
                          onLaunch: onLaunch,
                          onAddApp: onAddApp,
                          onLongPress: cell.app == null
                              ? null
                              : (anchor) => onLongPressItem(cell.app!, anchor),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (pageCount > 1)
            PageDots(
              count: pageCount,
              activeIndex: activePage,
              padding: EdgeInsets.zero,
            ),
          const SizedBox(height: 2),
          Text(
            pageCount > 1
                ? '${folder.apps.length} apps · page ${activePage + 1} of $pageCount'
                : '${folder.apps.length} apps · long-press an icon to drag out',
            maxLines: 1,
            style: ToadType.inter(
              11,
              color: palette.ink.withValues(alpha: palette.ink.a * 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _FolderTitle extends StatelessWidget {
  const _FolderTitle({
    required this.folder,
    required this.renaming,
    required this.renameController,
    required this.renameFocus,
    required this.labelColor,
    required this.onStartRename,
  });

  final FolderData folder;
  final bool renaming;
  final TextEditingController renameController;
  final FocusNode renameFocus;
  final Color labelColor;
  final VoidCallback onStartRename;

  @override
  Widget build(BuildContext context) {
    final palette = ToadTheme.of(context).palette;

    if (!renaming) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onStartRename,
        child: Text(
          folder.title,
          maxLines: 1,
          textAlign: TextAlign.center,
          style: ToadType.caveat(27, color: labelColor, height: 1),
        ),
      );
    }

    return TextField(
      controller: renameController,
      focusNode: renameFocus,
      autofocus: true,
      textAlign: TextAlign.center,
      cursorColor: palette.accent,
      cursorWidth: 1.6,
      style: ToadType.caveat(27, color: labelColor, height: 1),
      decoration: InputDecoration(isCollapsed: true, border: InputBorder.none),
      onSubmitted: (_) => renameFocus.unfocus(),
    );
  }
}

class _FolderGridItem extends StatelessWidget {
  const _FolderGridItem({
    required this.cell,
    required this.labelColor,
    required this.onLaunch,
    required this.onAddApp,
    required this.onLongPress,
  });

  final _FolderCellData cell;
  final Color labelColor;
  final void Function(AppEntry app) onLaunch;
  final VoidCallback onAddApp;
  final void Function(Offset anchor)? onLongPress;

  @override
  Widget build(BuildContext context) {
    if (cell.isAddSlot) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onAddApp,
        child: Column(
          children: [
            ToadAppIcon(
              app: const AppEntry(
                id: 'add-app',
                name: 'Add app',
                glyph: '＋',
                gradientIndex: 0,
              ),
              shape: IconShape.squircle,
            ),
            const SizedBox(height: 4),
            ToadAppLabel(
              text: 'Add app',
              color: labelColor,
              haloColor: Colors.transparent,
              fontSize: 10.5,
            ),
          ],
        ),
      );
    }

    final app = cell.app!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onLaunch(app),
      onLongPressStart: onLongPress == null
          ? null
          : (d) => onLongPress!(d.globalPosition),
      child: Column(
        children: [
          ToadAppIcon(app: app, shape: IconShape.squircle),
          const SizedBox(height: 4),
          ToadAppLabel(
            text: app.name,
            color: labelColor,
            haloColor: Colors.transparent,
            fontSize: 10.5,
          ),
        ],
      ),
    );
  }
}

final StateNotifierProvider<OpenFolderController, OpenFolderRequest?>
openFolderProvider =
    StateNotifierProvider<OpenFolderController, OpenFolderRequest?>(
      (ref) => OpenFolderController(),
    );

@immutable
class OpenFolderRequest {
  const OpenFolderRequest({
    required this.folder,
    required this.originRect,
    this.startInRename = false,
  });

  final FolderData folder;
  final Rect originRect;
  final bool startInRename;
}

class OpenFolderController extends StateNotifier<OpenFolderRequest?> {
  OpenFolderController() : super(null);

  void open(OpenFolderRequest request) => state = request;

  void close() => state = null;
}

final StateNotifierProvider<FolderItemMenuController, DrawerMenuRequest?>
openFolderMenuProvider =
    StateNotifierProvider<FolderItemMenuController, DrawerMenuRequest?>(
      (ref) => FolderItemMenuController(),
    );

class FolderItemMenuController extends StateNotifier<DrawerMenuRequest?> {
  FolderItemMenuController() : super(null);

  void raise({required AppEntry app, required Offset anchor}) =>
      state = DrawerMenuRequest(app: app, anchor: anchor);

  void consume() => state = null;
}
