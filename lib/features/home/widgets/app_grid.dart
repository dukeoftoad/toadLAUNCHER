/// App grid — paged 4-column (5 optional) grid of icons with Patrick Hand
/// labels and halo shadows. Stage 2: cells can be folder tiles (2x2 mini
/// preview) and long-press hooks feed the context menu.
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/toad_theme.dart';
import '../../../core/theme/toad_tokens.dart';
import '../../../shared/widgets/toad_app_icon.dart';

class AppGridPageView extends StatelessWidget {
  const AppGridPageView({
    super.key,
    required this.pages,
    required this.controller,
    required this.columns,
    required this.iconShape,
    required this.onAppTap,
    this.onAppLongPress,
    this.onFolderTap,
    this.onFolderLongPress,
  });

  final List<List<HomeCell>> pages;
  final PageController controller;
  final int columns;
  final IconShape iconShape;
  final void Function(AppEntry app) onAppTap;
  final void Function(AppEntry app, Offset anchor)? onAppLongPress;

  /// Tap on a folder tile — [iconRect] is the tile's global rect, the
  /// shared-axis open animates from it.
  final void Function(FolderData folder, Rect iconRect)? onFolderTap;
  final void Function(FolderData folder, Offset anchor)? onFolderLongPress;

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: controller,
      itemCount: pages.length,
      itemBuilder: (context, index) {
        return AppGridPage(
          cells: pages[index],
          columns: columns,
          iconShape: iconShape,
          onAppTap: onAppTap,
          onAppLongPress: onAppLongPress,
          onFolderTap: onFolderTap,
          onFolderLongPress: onFolderLongPress,
        );
      },
    );
  }
}

class AppGridPage extends StatelessWidget {
  const AppGridPage({
    super.key,
    required this.cells,
    required this.columns,
    required this.iconShape,
    required this.onAppTap,
    this.onAppLongPress,
    this.onFolderTap,
    this.onFolderLongPress,
  });

  final List<HomeCell> cells;
  final int columns;
  final IconShape iconShape;
  final void Function(AppEntry app) onAppTap;
  final void Function(AppEntry app, Offset anchor)? onAppLongPress;
  final void Function(FolderData folder, Rect iconRect)? onFolderTap;
  final void Function(FolderData folder, Offset anchor)? onFolderLongPress;

  @override
  Widget build(BuildContext context) {
    final palette = ToadTheme.of(context).palette;

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: ToadMetrics.gridRowGap,
        mainAxisExtent: 84,
      ),
      itemCount: cells.length,
      itemBuilder: (context, index) {
        final cell = cells[index];
        return switch (cell) {
          AppCell() => _AppCell(
              app: cell.app,
              iconShape: iconShape,
              labelColor: palette.ink,
              haloColor: palette.labelHalo,
              onTap: () => onAppTap(cell.app),
              onLongPress: onAppLongPress == null
                  ? null
                  : (anchor) => onAppLongPress!(cell.app, anchor),
            ),
          FolderCell() => _FolderTile(
              folder: cell.folder,
              iconShape: iconShape,
              labelColor: palette.ink,
              haloColor: palette.labelHalo,
              onTap: onFolderTap == null
                  ? null
                  : (rect) => onFolderTap!(cell.folder, rect),
              onLongPress: onFolderLongPress == null
                  ? null
                  : (anchor) => onFolderLongPress!(cell.folder, anchor),
            ),
        };
      },
    );
  }
}

class _AppCell extends StatelessWidget {
  const _AppCell({
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPressStart: onLongPress == null
          ? null
          : (details) => onLongPress!(details.globalPosition),
      child: Column(
        children: [
          ToadAppIcon(app: app, shape: iconShape),
          const SizedBox(height: 5),
          ToadAppLabel(text: app.name, color: labelColor, haloColor: haloColor),
        ],
      ),
    );
  }
}

/// Folder tile on the grid: translucent squircle holding the first four
/// folder apps as a 2x2 mini preview, Patrick Hand label under it.
class _FolderTile extends StatelessWidget {
  const _FolderTile({
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
        borderRadius:
            BorderRadius.circular(effectiveRadius(ToadMetrics.gridIconSize)),
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
          child: _MiniPreview(
            apps: folder.apps.take(4).toList(),
            radius:
                iconShape == IconShape.circle ? 99 : ToadRadii.inner * 0.5,
          ),
        ),
      ),
    );

    return Builder(
      builder: (cellContext) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            // Shared-axis origin: the tile's icon area (label excluded).
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
    );
  }
}

/// 2x2 grid of gradient mini-tiles (the folder's first four apps).
class _MiniPreview extends StatelessWidget {
  const _MiniPreview({required this.apps, required this.radius});

  final List<AppEntry> apps;
  final double radius;

  @override
  Widget build(BuildContext context) {
    Widget slot(int i) {
      final app = apps.length > i ? apps[i] : null;
      if (app == null) return const SizedBox.shrink();
      final gradient = app.isFamilyToad
          ? AppIconGradients.toad
          : AppIconGradients
              .all[app.gradientIndex % AppIconGradients.all.length];
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
        Expanded(child: Row(children: [Expanded(child: slot(0)), const SizedBox(width: 2), Expanded(child: slot(1))])),
        const SizedBox(height: 2),
        Expanded(child: Row(children: [Expanded(child: slot(2)), const SizedBox(width: 2), Expanded(child: slot(3))])),
      ],
    );
  }
}

/// Elongated-pill page dots (6.5px dots, active = 18px pill).
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

    return Padding(
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
    );
  }
}
