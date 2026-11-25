library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/device/device_bridge.dart';
import '../../../core/models/models.dart';
import '../../../core/settings/launcher_settings.dart';
import '../../../core/theme/toad_theme.dart';
import '../../../core/theme/toad_tokens.dart';
import '../../../shared/widgets/placed_widgets.dart'
    show PlacedWidgetView, widgetZoneHeight;
import '../../../shared/widgets/toad_app_icon.dart';
import '../../edit/edit_mode.dart' show DashedSelectionPainter;
import '../grid_flow.dart';
import '../home_controller.dart';

/// FEAT-01: one shared canvas per page — Android and toad widgets claim
/// rectangular spans, app and folder cells flow into the remaining cells.
/// The canvas scrolls vertically when a page overflows, exactly like the
/// old GridView did.
class FreeFormCanvas extends ConsumerWidget {
  const FreeFormCanvas({
    super.key,
    required this.cells,
    required this.widgets,
    required this.columns,
    required this.iconShape,
    required this.onAppTap,
    this.onAppLongPress,
    this.onFolderTap,
    this.onFolderLongPress,
    this.onClockTap,
    this.memory,
  });

  final List<HomeCell> cells;
  final List<PlacedWidget> widgets;
  final int columns;
  final IconShape iconShape;
  final void Function(AppEntry app) onAppTap;
  final void Function(AppEntry app, Offset anchor)? onAppLongPress;
  final void Function(FolderData folder, Rect iconRect)? onFolderTap;
  final void Function(FolderData folder, Offset anchor)? onFolderLongPress;
  final VoidCallback? onClockTap;
  final MemoryCardData? memory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ToadTheme.of(context).palette;
    final flow = computeGridFlow(
      cells: cells,
      widgets: widgets,
      columns: columns,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cellW = (width - canvasGutter * 2) / columns;

        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: SizedBox(
            width: width,
            height: (flow.rows * canvasRowPitch).clamp(
              320,
              double.infinity,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (final slot in flow.cellSlots)
                  Positioned(
                    left: canvasGutter + slot.col * cellW,
                    top: slot.row * canvasRowPitch,
                    width: cellW,
                    height: canvasRowPitch,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: switch (slot.cell) {
                        AppCell(:final app) => CanvasAppTile(
                          app: app,
                          iconShape: iconShape,
                          labelColor: palette.ink,
                          haloColor: palette.labelHalo,
                          onTap: () => onAppTap(app),
                          onLongPress: onAppLongPress == null
                              ? null
                              : (anchor) => onAppLongPress!(app, anchor),
                        ),
                        FolderCell(:final folder) => CanvasFolderTile(
                          folder: folder,
                          iconShape: iconShape,
                          labelColor: palette.ink,
                          haloColor: palette.labelHalo,
                          onTap: onFolderTap == null
                              ? null
                              : (rect) => onFolderTap!(folder, rect),
                          onLongPress: onFolderLongPress == null
                              ? null
                              : (anchor) => onFolderLongPress!(folder, anchor),
                        ),
                      },
                    ),
                  ),
                for (final entry in flow.widgetSlots.entries)
                  () {
                    final widget =
                        widgets.where((w) => w.id == entry.key).firstOrNull;
                    if (widget == null) {
                      return const SizedBox.shrink();
                    }
                    final slot = entry.value;
                    final w = widget.w.clamp(1, columns);
                    return Positioned(
                      left: canvasGutter + slot.col * cellW,
                      top: slot.row * canvasRowPitch,
                      width: w * cellW,
                      height: widget.h * canvasRowPitch,
                      child: CanvasWidgetChrome(
                        widget: widget,
                        memory: memory,
                        cellW: cellW,
                        rowPitch: canvasRowPitch,
                        spanWidth: w * cellW,
                        spanHeight: widget.h * canvasRowPitch,
                        onClockTap: onClockTap,
                        legacyHeight: widgetZoneHeight(widget.h),
                      ),
                    );
                  }(),
              ],
            ),
          ),
        );
      },
    );
  }
}

class CanvasAppTile extends StatelessWidget {
  const CanvasAppTile({
    super.key,
    required this.app,
    required this.iconShape,
    required this.labelColor,
    required this.haloColor,
    required this.onTap,
    this.onLongPress,
  });

  final AppEntry app;
  final IconShape iconShape;
  final Color labelColor;
  final Color haloColor;
  final VoidCallback onTap;
  final void Function(Offset anchor)? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: app.name,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPressStart: onLongPress == null
            ? null
            : (details) => onLongPress!(details.globalPosition),
        child: Column(
          children: [
            ToadAppIcon(app: app, shape: iconShape),
            const SizedBox(height: 5),
            ToadAppLabel(
              text: app.name,
              color: labelColor,
              haloColor: haloColor,
            ),
          ],
        ),
      ),
    );
  }
}

class CanvasFolderTile extends StatelessWidget {
  const CanvasFolderTile({
    super.key,
    required this.folder,
    required this.iconShape,
    required this.labelColor,
    required this.haloColor,
    required this.onTap,
    this.onLongPress,
  });

  final FolderData folder;
  final IconShape iconShape;
  final Color labelColor;
  final Color haloColor;
  final void Function(Rect iconRect)? onTap;
  final void Function(Offset anchor)? onLongPress;

  @override
  Widget build(BuildContext context) {
    final palette = ToadTheme.of(context).palette;

    double effectiveRadius(double size) => switch (iconShape) {
      IconShape.squircle => ToadRadii.iconTile,
      IconShape.circle => size / 2,
      IconShape.rounded => size * 0.38,
    };

    final preview = Container(
      width: ToadMetrics.gridIconSize,
      height: ToadMetrics.gridIconSize,
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: palette.surface.a * 0.9),
        borderRadius: BorderRadius.circular(
          effectiveRadius(ToadMetrics.gridIconSize),
        ),
        border: Border.all(
          color: palette.hairline.withValues(alpha: palette.hairline.a * 0.9),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            offset: Offset(0, 3),
            blurRadius: 8,
            spreadRadius: -2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(5),
      child: Center(
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: MiniFolderPreview(
            apps: folder.apps.take(4).toList(),
            radius: iconShape == IconShape.circle ? 99 : ToadRadii.inner * 0.5,
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      label: 'Folder ${folder.title}, ${folder.apps.length} apps',
      child: Builder(
        builder: (cellContext) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              final box = cellContext.findRenderObject()! as RenderBox;
              final topLeft = box.localToGlobal(Offset.zero);
              onTap?.call(
                Rect.fromLTWH(topLeft.dx, topLeft.dy, box.size.width, 54),
              );
            },
            onLongPressStart: onLongPress == null
                ? null
                : (d) => onLongPress!(d.globalPosition),
            child: Column(
              children: [
                preview,
                const SizedBox(height: 5),
                ToadAppLabel(
                  text: folder.title,
                  color: labelColor,
                  haloColor: haloColor,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class MiniFolderPreview extends StatelessWidget {
  const MiniFolderPreview({super.key, required this.apps, required this.radius});

  final List<AppEntry> apps;
  final double radius;

  @override
  Widget build(BuildContext context) {
    Widget slot(int i) {
      final app = apps.length > i ? apps[i] : null;
      if (app == null) return const SizedBox.shrink();
      final gradient = app.isFamilyToad
          ? AppIconGradients.toad
          : AppIconGradients.all[app.gradientIndex %
                AppIconGradients.all.length];
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
            transform: const GradientRotation(145 * 3.14159 / 180),
          ),
        ),
        alignment: Alignment.center,
        child: app.isFamilyToad
            ? CustomPaint(
                size: const Size.square(10),
                painter: ToadFacePainter(),
              )
            : Text(
                app.glyph,
                style: TextStyle(
                  fontSize: 9,
                  height: 1,
                  color: Colors.white,
                  fontFamily: ToadType.fontHand,
                ),
              ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: slot(0)),
              const SizedBox(width: 2),
              Expanded(child: slot(1)),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Expanded(
          child: Row(
            children: [
              Expanded(child: slot(2)),
              const SizedBox(width: 2),
              Expanded(child: slot(3)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Selection chrome, resize handles, drag-to-move and the remove/setup
/// chips for one placed widget on the canvas.
class CanvasWidgetChrome extends ConsumerStatefulWidget {
  const CanvasWidgetChrome({
    super.key,
    required this.widget,
    required this.memory,
    required this.cellW,
    required this.rowPitch,
    required this.spanWidth,
    required this.spanHeight,
    required this.legacyHeight,
    this.onClockTap,
  });

  final PlacedWidget widget;
  final MemoryCardData? memory;
  final double cellW;
  final double rowPitch;
  final double spanWidth;
  final double spanHeight;
  final double legacyHeight;
  final VoidCallback? onClockTap;

  @override
  ConsumerState<CanvasWidgetChrome> createState() =>
      _CanvasWidgetChromeState();
}

class _CanvasWidgetChromeState extends ConsumerState<CanvasWidgetChrome> {
  Offset _moveTotal = Offset.zero;
  Offset _resizeTotal = Offset.zero;
  int _resizeBaseW = 4;
  int _resizeBaseH = 1;

  void _onMovePanStart() {
    ref.read(homeLayoutProvider.notifier).beginWidgetGesture();
    _moveTotal = Offset.zero;
  }

  void _onMovePanUpdate(Offset delta) {
    _moveTotal += delta;
    final stepCol = widget.cellW;
    final stepRow = widget.rowPitch;
    if (_moveTotal.dx.abs() < stepCol * 0.55 &&
        _moveTotal.dy.abs() < stepRow * 0.55) {
      return;
    }
    final layout = ref.read(homeLayoutProvider).valueOrNull;
    if (layout == null) return;
    final slot = flowSlotOf(layout, widget.widget);
    if (slot == null) return;
    final dCol = (_moveTotal.dx / stepCol).round();
    final dRow = (_moveTotal.dy / stepRow).round();
    if (dCol == 0 && dRow == 0) return;
    _moveTotal = Offset(
      _moveTotal.dx - dCol * stepCol,
      _moveTotal.dy - dRow * stepRow,
    );
    ref
        .read(homeLayoutProvider.notifier)
        .moveWidgetTo(
          widget.widget.id,
          row: slot.row + dRow,
          col: slot.col + dCol,
        );
  }

  void _onMovePanEnd() {
    ref
        .read(homeLayoutProvider.notifier)
        .endWidgetGesture(message: 'Widget moved');
    _moveTotal = Offset.zero;
  }

  GridSlot? flowSlotOf(HomeLayout layout, PlacedWidget target) {
    final columns = ref.read(launcherSettingsProvider).gridColumns;
    final pageWidgets = layout.widgetsOnPage(target.page);
    final flow = computeGridFlow(
      cells: const [],
      widgets: pageWidgets,
      columns: columns,
    );
    return flow.slotOf(target.id);
  }

  void _onResizePanStart() {
    ref.read(homeLayoutProvider.notifier).beginWidgetGesture();
    _resizeBaseW = widget.widget.w;
    _resizeBaseH = widget.widget.h;
    _resizeTotal = Offset.zero;
  }

  void _onResizePanUpdate(Offset delta, int sx, int sy) {
    _resizeTotal += delta;
    final newW = (_resizeBaseW + sx * _resizeTotal.dx / widget.cellW).round();
    final newH = (_resizeBaseH + sy * _resizeTotal.dy / widget.rowPitch)
        .round();
    ref
        .read(homeLayoutProvider.notifier)
        .resizeWidget(widget.widget.id, w: newW, h: newH);
  }

  void _onResizePanEnd() {
    ref
        .read(homeLayoutProvider.notifier)
        .endWidgetGesture(
          message: 'Resized — the widget re-rendered at every size',
        );
    _resizeTotal = Offset.zero;
  }

  Future<void> _launchSetup() async {
    final id = widget.widget.appWidgetId;
    if (id == null) return;
    ref.read(selectedWidgetIdProvider.notifier).clear();
    await ref.read(deviceBridgeProvider).launchWidgetConfigure(id);
  }

  @override
  Widget build(BuildContext context) {
    final palette = ToadTheme.of(context).palette;
    final editMode = ref.watch(editModeProvider);
    final selectedId = ref.watch(selectedWidgetIdProvider);
    final selected = editMode && selectedId == widget.widget.id;
    final w = widget.widget;

    final body = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: editMode
          ? () {
              final sel = ref.read(selectedWidgetIdProvider.notifier);
              selectedId == w.id ? sel.clear() : sel.select(w.id);
            }
          : (w.kind == WidgetKind.clock
                ? widget.onClockTap
                : null),
      onPanStart: editMode ? (_) => _onMovePanStart() : null,
      onPanUpdate: editMode ? (d) => _onMovePanUpdate(d.delta) : null,
      onPanEnd: editMode ? (_) => _onMovePanEnd() : null,
      child: PlacedWidgetView(
        widget: w,
        memory: widget.memory,
        height: widget.spanHeight - 8,
      ),
    );

    return Semantics(
      label: switch (w.kind) {
        WidgetKind.clock => 'Clock widget',
        WidgetKind.memories => 'Memories widget',
        WidgetKind.calendar => 'Calendar widget',
        WidgetKind.sticky => 'toadLIST widget',
        WidgetKind.androidHosted =>
          'Android widget${w.label == null ? '' : ' ${w.label}'}',
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: body),
          if (selected)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: DashedSelectionPainter(
                    color: palette.accent,
                    radius: 14,
                  ),
                ),
              ),
            ),
          if (selected) ...[
            _CanvasHandle(
              corner: _CanvasCorner.topLeft,
              palette: palette,
              onPanStart: _onResizePanStart,
              onPanUpdate: (d) => _onResizePanUpdate(d, -1, -1),
              onPanEnd: _onResizePanEnd,
            ),
            _CanvasHandle(
              corner: _CanvasCorner.topRight,
              palette: palette,
              onPanStart: _onResizePanStart,
              onPanUpdate: (d) => _onResizePanUpdate(d, 1, -1),
              onPanEnd: _onResizePanEnd,
            ),
            _CanvasHandle(
              corner: _CanvasCorner.bottomLeft,
              palette: palette,
              onPanStart: _onResizePanStart,
              onPanUpdate: (d) => _onResizePanUpdate(d, -1, 1),
              onPanEnd: _onResizePanEnd,
            ),
            _CanvasHandle(
              corner: _CanvasCorner.bottomRight,
              palette: palette,
              onPanStart: _onResizePanStart,
              onPanUpdate: (d) => _onResizePanUpdate(d, 1, 1),
              onPanEnd: _onResizePanEnd,
            ),
          ],
          if (selected)
            Positioned(
              right: 4,
              top: 4,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (w.kind == WidgetKind.androidHosted &&
                      (w.configureComponent ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Semantics(
                        button: true,
                        label: 'Set up widget',
                        child: GestureDetector(
                          onTap: _launchSetup,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: palette.accent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Set up',
                              style: ToadType.hand(
                                12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Semantics(
                    button: true,
                    label: 'Remove widget',
                    child: GestureDetector(
                      onTap: () {
                        ref.read(selectedWidgetIdProvider.notifier).clear();
                        ref
                            .read(homeLayoutProvider.notifier)
                            .removeWidget(
                              w.id,
                              message: 'Widget removed from this page',
                            );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: palette.danger,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Remove',
                          style: ToadType.hand(12, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

enum _CanvasCorner { topLeft, topRight, bottomLeft, bottomRight }

class _CanvasHandle extends StatelessWidget {
  const _CanvasHandle({
    required this.corner,
    required this.palette,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  final _CanvasCorner corner;
  final ToadPalette palette;
  final VoidCallback onPanStart;
  final void Function(Offset delta) onPanUpdate;
  final VoidCallback onPanEnd;

  bool get _left =>
      corner == _CanvasCorner.topLeft || corner == _CanvasCorner.bottomLeft;
  bool get _top =>
      corner == _CanvasCorner.topLeft || corner == _CanvasCorner.topRight;

  @override
  Widget build(BuildContext context) {
    final s = ToadMetrics.resizeHandleSize;
    return Positioned(
      left: _left ? -s / 2 : null,
      right: _left ? null : -s / 2,
      top: _top ? -s / 2 : null,
      bottom: _top ? null : -s / 2,
      child: Semantics(
        button: true,
        label: 'Resize handle',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => onPanStart(),
          onPanUpdate: (d) => onPanUpdate(d.delta),
          onPanEnd: (_) => onPanEnd(),
          child: Container(
            width: s,
            height: s,
            decoration: BoxDecoration(
              color: palette.surface,
              shape: BoxShape.circle,
              border: Border.all(color: palette.accent, width: 2),
            ),
          ),
        ),
      ),
    );
  }
}
