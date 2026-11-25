library;

import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';

import '../../../core/models/models.dart';
import '../../../core/theme/toad_theme.dart';
import '../../../core/theme/toad_tokens.dart';
import '../../../shared/widgets/toad_app_icon.dart';

class DockBar extends StatelessWidget {
  const DockBar({
    super.key,
    required this.apps,
    required this.iconShape,
    required this.onAppTap,
    required this.onDrawerTap,
    this.onAppLongPress,
    this.onSwipeDown,
    this.frostColor,
    this.borderColors,
    this.arrowColor,
  });

  final List<AppEntry> apps;
  final IconShape iconShape;
  final void Function(AppEntry app) onAppTap;
  final VoidCallback onDrawerTap;
  final void Function(AppEntry app)? onAppLongPress;

  final VoidCallback? onSwipeDown;

  final Color? frostColor;
  final Color? borderColors;
  final Color? arrowColor;

  @override
  Widget build(BuildContext context) {
    final palette = ToadTheme.of(context).palette;

    return GestureDetector(
      onVerticalDragEnd: onSwipeDown == null
          ? null
          : (details) {
              if ((details.primaryVelocity ?? 0) > 320) onSwipeDown!();
            },
      child: Container(
        margin: ToadMetrics.dockMargin,
        padding: ToadMetrics.dockPadding,
        decoration: BoxDecoration(
          color:
              frostColor ??
              palette.surface.withValues(alpha: palette.surface.a * 0.72),
          borderRadius: BorderRadius.circular(ToadRadii.dock),
          border: Border.all(
            color:
                borderColors ??
                palette.hairline.withValues(alpha: palette.hairline.a * 0.8),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ToadRadii.dock),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Row(
              children: [
                for (var i = 0; i < apps.take(4).length; i++)
                  Expanded(
                    child: Center(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onAppTap(apps[i]),
                        onLongPress: onAppLongPress == null
                            ? null
                            : () => onAppLongPress!(apps[i]),
                        child: ToadAppIcon(
                          app: apps[i],
                          size: ToadMetrics.dockIconSize,
                          shape: iconShape,
                          glyphSize: 21,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onDrawerTap,
                      child: _DrawerArrow(color: arrowColor ?? palette.ink),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerArrow extends StatelessWidget {
  const _DrawerArrow({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '⌃',
          style: ToadType.hand(
            13,
            color: color.withValues(alpha: color.a * 0.75),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'APPS',
          style: ToadType.inter(
            9,
            weight: 500,
            tracking: 9 * 0.08,
            color: color.withValues(alpha: color.a * 0.52),
          ),
        ),
      ],
    );
  }
}
