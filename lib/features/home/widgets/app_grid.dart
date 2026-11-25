library;

import 'package:material_ui/material_ui.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/toad_theme.dart';
import '../../../core/theme/toad_tokens.dart';
import '../grid_flow.dart' show canvasRowPitch;
import 'canvas_page.dart' show FreeFormCanvas;

class AppGridPageView extends StatelessWidget {
  const AppGridPageView({
    super.key,
    required this.pages,
    required this.controller,
    required this.columns,
    required this.iconShape,
    required this.onAppTap,
    this.widgets = const [],
    this.memory,
    this.onAppLongPress,
    this.onFolderTap,
    this.onFolderLongPress,
    this.onClockTap,
  });

  final List<List<HomeCell>> pages;
  final PageController controller;
  final int columns;
  final IconShape iconShape;
  final void Function(AppEntry app) onAppTap;

  /// Placed widgets for all pages; only those on page [index] render there.
  /// Callers filter out hidden kinds (e.g. memories when the card is off).
  final List<PlacedWidget> widgets;
  final MemoryCardData? memory;
  final void Function(AppEntry app, Offset anchor)? onAppLongPress;

  final void Function(FolderData folder, Rect iconRect)? onFolderTap;
  final void Function(FolderData folder, Offset anchor)? onFolderLongPress;

  final VoidCallback? onClockTap;

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: controller,
      itemCount: pages.length,
      itemBuilder: (context, index) {
        return FreeFormCanvas(
          cells: pages[index],
          widgets: [
            for (final w in widgets)
              if (w.page == index) w,
          ],
          columns: columns,
          iconShape: iconShape,
          memory: memory,
          onAppTap: onAppTap,
          onAppLongPress: onAppLongPress,
          onFolderTap: onFolderTap,
          onFolderLongPress: onFolderLongPress,
          onClockTap: onClockTap,
        );
      },
    );
  }
}

/// Vertical space the canvas needs for [rows] unit rows — kept as a helper
/// so host layouts can reason about the canvas without importing
/// grid_flow internals.
double canvasMinExtent(int rows) => rows * canvasRowPitch;

class PageDots extends StatelessWidget {
  const PageDots({
    super.key,
    required this.count,
    required this.activeIndex,
    this.dotColor,
    this.padding = const EdgeInsets.symmetric(vertical: 4),
  });

  final int count;
  final int activeIndex;
  final Color? dotColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final palette = ToadTheme.of(context).palette;
    final base = dotColor ?? palette.ink;

    return Semantics(
      label: 'Page ${activeIndex + 1} of $count',
      child: Padding(
        padding: padding,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) const SizedBox(width: 7),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                width: i == activeIndex
                    ? ToadMetrics.pageDotActiveWidth
                    : ToadMetrics.pageDotSize,
                height: ToadMetrics.pageDotSize,
                decoration: BoxDecoration(
                  color: base.withValues(
                    alpha: base.a * (i == activeIndex ? 0.85 : 0.28),
                  ),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
