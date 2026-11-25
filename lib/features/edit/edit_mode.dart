library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/models.dart';
import '../../core/settings/launcher_settings.dart';
import '../../core/theme/toad_theme.dart';
import '../../core/theme/toad_tokens.dart';
import '../../shared/widgets/placed_widgets.dart';
import '../home/home_controller.dart';

const double _kResizeRowPitch = 68;

class GridSkeletonPainter extends CustomPainter {
  GridSkeletonPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final ink = color.withValues(alpha: color.a * 0.12);
    final paint = Paint()
      ..strokeWidth = 1
      ..color = ink;

    const gutter = 12.0;
    final cellW = (size.width - gutter * 2) / ToadMetrics.defaultColumns;
    for (var i = 0; i <= ToadMetrics.defaultColumns; i++) {
      final x = gutter + i * cellW;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    final k = size.width / ToadMetrics.referenceScreen.width;
    final rowPitch = ToadMetrics.editRowPitch * k;
    for (double y = rowPitch; y < size.height; y += rowPitch) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(GridSkeletonPainter oldDelegate) =>
      oldDelegate.color != color;
}

class DashedSelectionPainter extends CustomPainter {
  DashedSelectionPainter({required this.color, this.radius = 14});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(2);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final path = Path()..addRRect(rrect);

    const dash = 6.0;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + dash;
      }
    }
  }

  @override
  bool shouldRepaint(DashedSelectionPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

class WidgetZone extends ConsumerWidget {
  const WidgetZone({
    super.key,
    required this.pageIndex,
    required this.memory,
    required this.onClockTap,
  });

  final int pageIndex;
  final MemoryCardData? memory;

  final VoidCallback onClockTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(homeLayoutProvider).valueOrNull;
    final editMode = ref.watch(editModeProvider);
    final selectedId = ref.watch(selectedWidgetIdProvider);
    final showMemories = ref.watch(launcherSettingsProvider).showMemoriesCard;
    final widgets =
        layout
            ?.widgetsOnPage(pageIndex)
            .where((w) => w.kind != WidgetKind.memories || showMemories)
            .toList() ??
        const <PlacedWidget>[];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellW = (constraints.maxWidth - 24) / ToadMetrics.defaultColumns;
        final zoneWidth = constraints.maxWidth;

        final children = <Widget>[];
        for (var i = 0; i < widgets.length; i++) {
          final widget = widgets[i];
          children.add(
            _WidgetSlot(
              key: ValueKey(widget.id),
              widget: widget,
              memory: memory,
              zoneWidth: zoneWidth,
              selected: editMode && selectedId == widget.id,
              editMode: editMode,
              cellW: cellW,
              onSelect: () {
                final sel = ref.read(selectedWidgetIdProvider.notifier);
                selectedId == widget.id ? sel.clear() : sel.select(widget.id);
              },
              onClockTap: onClockTap,
              onRemove: () {
                ref.read(selectedWidgetIdProvider.notifier).clear();
                ref
                    .read(homeLayoutProvider.notifier)
                    .removeWidget(
                      widget.id,
                      message: 'Widget removed from this page',
                    );
              },
              itemCount: widgets.length,
              index: i,
            ),
          );
          if (i < widgets.length - 1) children.add(const SizedBox(height: 8));
        }

        return Column(children: children);
      },
    );
  }
}

class _WidgetSlot extends ConsumerStatefulWidget {
  const _WidgetSlot({
    super.key,
    required this.widget,
    required this.memory,
    required this.zoneWidth,
    required this.selected,
    required this.editMode,
    required this.cellW,
    required this.onSelect,
    required this.onClockTap,
    required this.onRemove,
    required this.itemCount,
    required this.index,
  });

  final PlacedWidget widget;
  final MemoryCardData? memory;
  final double zoneWidth;
  final bool selected;
  final bool editMode;
  final double cellW;
  final VoidCallback onSelect;
  final VoidCallback onClockTap;
  final VoidCallback onRemove;
  final int itemCount;
  final int index;

  @override
  ConsumerState<_WidgetSlot> createState() => _WidgetSlotState();
}

class _WidgetSlotState extends ConsumerState<_WidgetSlot> {
  ({HomeLayout layout, LauncherSettings settings})? _snapshot;
  Offset _resizeTotal = Offset.zero;
  int _baseW = 4;
  int _baseH = 1;
  double _moveTotal = 0;

  void _onResizePanStart() {
    _snapshot = ref.read(homeLayoutProvider.notifier).snapshot();
    _resizeTotal = Offset.zero;
    _baseW = widget.widget.w;
    _baseH = widget.widget.h;
  }

  void _onResizePanUpdate(Offset delta, int sx, int sy) {
    _resizeTotal += delta;
    final newW = (_baseW + sx * _resizeTotal.dx / widget.cellW).round();
    final newH = (_baseH + sy * _resizeTotal.dy / _kResizeRowPitch).round();
    ref
        .read(homeLayoutProvider.notifier)
        .resizeWidget(widget.widget.id, w: newW, h: newH);
  }

  void _onResizePanEnd() {
    ref
        .read(homeLayoutProvider.notifier)
        .commitAction(
          _snapshot,
          message: 'Resized — the clock re-rendered at every size',
        );
    _snapshot = null;
  }

  void _onMovePanStart() {
    _snapshot = ref.read(homeLayoutProvider.notifier).snapshot();
    _moveTotal = 0;
  }

  void _onMovePanUpdate(double primaryDelta) {
    if (widget.itemCount < 2) return;
    _moveTotal += primaryDelta;
    final step = widgetZoneHeight(widget.widget.h) + 8;
    if (_moveTotal.abs() >= step * 0.6) {
      final dir = _moveTotal > 0 ? 1 : -1;
      _moveTotal = 0;
      ref
          .read(homeLayoutProvider.notifier)
          .moveWidget(widget.widget.id, newIndex: widget.index + dir);
    }
  }

  void _onMovePanEnd() {
    ref
        .read(homeLayoutProvider.notifier)
        .commitAction(_snapshot, message: 'Widget moved');
    _snapshot = null;
  }

  @override
  Widget build(BuildContext context) {
    final palette = ToadTheme.of(context).palette;
    final w = widget.widget;
    final width = widget.zoneWidth * w.w / ToadMetrics.defaultColumns;

    final body = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.editMode
          ? widget.onSelect
          : (w.kind == WidgetKind.clock ? widget.onClockTap : null),
      onVerticalDragStart: widget.editMode && widget.itemCount > 1
          ? (_) => _onMovePanStart()
          : null,
      onVerticalDragUpdate: widget.editMode && widget.itemCount > 1
          ? (d) => _onMovePanUpdate(d.primaryDelta ?? 0)
          : null,
      onVerticalDragEnd: widget.editMode && widget.itemCount > 1
          ? (_) => _onMovePanEnd()
          : null,
      child: PlacedWidgetView(widget: w, memory: widget.memory),
    );

    return SizedBox(
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          body,
          if (widget.selected)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  size: Size(width, widgetZoneHeight(w.h)),
                  painter: DashedSelectionPainter(color: palette.accent),
                ),
              ),
            ),
          if (widget.selected && w.kind == WidgetKind.clock) ...[
            _Handle(
              corner: _Corner.topLeft,
              palette: palette,
              onPanStart: _onResizePanStart,
              onPanUpdate: (d) => _onResizePanUpdate(d, -1, -1),
              onPanEnd: _onResizePanEnd,
            ),
            _Handle(
              corner: _Corner.topRight,
              palette: palette,
              onPanStart: _onResizePanStart,
              onPanUpdate: (d) => _onResizePanUpdate(d, 1, -1),
              onPanEnd: _onResizePanEnd,
            ),
            _Handle(
              corner: _Corner.bottomLeft,
              palette: palette,
              onPanStart: _onResizePanStart,
              onPanUpdate: (d) => _onResizePanUpdate(d, -1, 1),
              onPanEnd: _onResizePanEnd,
            ),
            _Handle(
              corner: _Corner.bottomRight,
              palette: palette,
              onPanStart: _onResizePanStart,
              onPanUpdate: (d) => _onResizePanUpdate(d, 1, 1),
              onPanEnd: _onResizePanEnd,
            ),
          ],
          if (widget.selected)
            Positioned(
              right: 4,
              top: 4,
              child: GestureDetector(
                onTap: widget.onRemove,
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
    );
  }
}

enum _Corner { topLeft, topRight, bottomLeft, bottomRight }

class _Handle extends StatelessWidget {
  const _Handle({
    required this.corner,
    required this.palette,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  final _Corner corner;
  final ToadPalette palette;
  final VoidCallback onPanStart;
  final void Function(Offset delta) onPanUpdate;
  final VoidCallback onPanEnd;

  bool get _left => corner == _Corner.topLeft || corner == _Corner.bottomLeft;
  bool get _top => corner == _Corner.topLeft || corner == _Corner.topRight;

  @override
  Widget build(BuildContext context) {
    final s = ToadMetrics.resizeHandleSize;
    return Positioned(
      left: _left ? -s / 2 : null,
      right: _left ? null : -s / 2,
      top: _top ? -s / 2 : null,
      bottom: _top ? null : -s / 2,
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
    );
  }
}

class EditBottomStrip extends StatelessWidget {
  const EditBottomStrip({
    super.key,
    required this.onWallpapers,
    required this.onWidgets,
    required this.onSettings,
    required this.onDone,
  });

  final VoidCallback onWallpapers;
  final VoidCallback onWidgets;
  final VoidCallback onSettings;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final skin = ToadTheme.of(context);
    final palette = skin.palette;
    final dark = skin.isDark;
    final ink = dark ? const Color(0xFFE8E2D4) : palette.ink;

    return Container(
      margin: ToadMetrics.dockMargin,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: palette.surface.a * 0.72),
        borderRadius: BorderRadius.circular(ToadRadii.dock),
        border: Border.all(
          color: palette.hairline.withValues(alpha: palette.hairline.a * 0.8),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StripItem(
              icon: '▤',
              label: 'Wallpapers',
              ink: ink,
              chip: palette.accentWash,
              onTap: onWallpapers,
            ),
          ),
          Expanded(
            child: _StripItem(
              icon: '▦',
              label: 'Widgets',
              ink: ink,
              chip: palette.accentWash,
              onTap: onWidgets,
            ),
          ),
          Expanded(
            child: _StripItem(
              icon: '⚙',
              label: 'Settings',
              ink: ink,
              chip: palette.accentWash,
              onTap: onSettings,
            ),
          ),
          GestureDetector(
            onTap: onDone,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: palette.accent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Done',
                style: ToadType.hand(14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StripItem extends StatelessWidget {
  const _StripItem({
    required this.icon,
    required this.label,
    required this.ink,
    required this.chip,
    required this.onTap,
  });

  final String icon;
  final String label;
  final Color ink;
  final Color chip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: chip,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              icon,
              style: TextStyle(
                fontSize: 15,
                height: 1,
                fontFamily: ToadType.fontHand,
                color: ink,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ToadType.hand(11.5, color: ink),
          ),
        ],
      ),
    );
  }
}

class EditHintBubble extends ConsumerWidget {
  const EditHintBubble({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(launcherSettingsProvider);
    if (!ref.watch(editModeProvider) || settings.editHintDismissed) {
      return const SizedBox.shrink();
    }
    final palette = ToadTheme.of(context).palette;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(ToadRadii.card),
        border: Border.all(color: palette.accent.withValues(alpha: 0.5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33140F05),
            offset: Offset(0, 10),
            blurRadius: 24,
            spreadRadius: -8,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Tap a widget to select it. Pull a corner to resize — the clock '
              're-renders at every size.',
              style: ToadType.hand(
                13,
                height: 1.25,
                color: palette.ink.withValues(alpha: palette.ink.a * 0.9),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => ref
                .read(launcherSettingsProvider.notifier)
                .setEditHintDismissed(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: palette.accentWash,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Got it',
                style: ToadType.hand(12.5, color: palette.accentInk),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
