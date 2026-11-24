/// App grid — paged 4-column (5 optional) grid of icons with Patrick Hand
/// labels and halo shadows. Real 54px tiles, 14px row gap. Long-press hooks
/// arrive with the stage-2 context menu.
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
  });

  final List<List<AppEntry>> pages;
  final PageController controller;
  final int columns;
  final IconShape iconShape;
  final void Function(AppEntry app) onAppTap;
  final void Function(AppEntry app)? onAppLongPress;

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: controller,
      itemCount: pages.length,
      itemBuilder: (context, index) {
        return AppGridPage(
          apps: pages[index],
          columns: columns,
          iconShape: iconShape,
          onAppTap: onAppTap,
          onAppLongPress: onAppLongPress,
        );
      },
    );
  }
}

class AppGridPage extends StatelessWidget {
  const AppGridPage({
    super.key,
    required this.apps,
    required this.columns,
    required this.iconShape,
    required this.onAppTap,
    this.onAppLongPress,
  });

  final List<AppEntry> apps;
  final int columns;
  final IconShape iconShape;
  final void Function(AppEntry app) onAppTap;
  final void Function(AppEntry app)? onAppLongPress;

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
      itemCount: apps.length,
      itemBuilder: (context, index) {
        final app = apps[index];
        return _AppCell(
          app: app,
          iconShape: iconShape,
          labelColor: palette.ink,
          haloColor: palette.labelHalo,
          onTap: () => onAppTap(app),
          onLongPress:
              onAppLongPress == null ? null : () => onAppLongPress!(app),
        );
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
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
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
